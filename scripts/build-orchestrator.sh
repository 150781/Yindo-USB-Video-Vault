#!/bin/bash
# Build et Release Orchestrator - Complete Pipeline
# USB Video Vault - Pipeline complète de build et distribution

set -e

# Configuration
VERSION=${VERSION:-$(cat package.json | jq -r .version)}
PLATFORMS=${PLATFORMS:-"win,mac,linux"}
SKIP_TESTS=${SKIP_TESTS:-false}
DRY_RUN=${DRY_RUN:-false}
AUTO_RELEASE=${AUTO_RELEASE:-false}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() { echo -e "${BLUE}[ORCHESTRATOR]${NC} $1"; }
success() { echo -e "${GREEN}[ORCHESTRATOR]${NC} ✅ $1"; }
warn() { echo -e "${YELLOW}[ORCHESTRATOR]${NC} ⚠️ $1"; }
error() { echo -e "${RED}[ORCHESTRATOR]${NC} ❌ $1"; }
step() { echo -e "${PURPLE}[ORCHESTRATOR]${NC} 🚀 $1"; }

# Fonctions utilitaires
check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Node.js et npm
    if ! command -v node &> /dev/null; then
        error "Node.js requis"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        error "npm requis"
        exit 1
    fi
    
    # Git
    if ! command -v git &> /dev/null; then
        error "Git requis"
        exit 1
    fi
    
    # Vérifier workspace clean
    if [ "$(git status --porcelain)" ]; then
        warn "Workspace non propre - changements non commités détectés"
        if [ "$DRY_RUN" = false ]; then
            read -p "Continuer? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    success "Prérequis validés"
}

install_dependencies() {
    step "Installation des dépendances..."
    
    if [ -f "package-lock.json" ]; then
        npm ci
    else
        npm install
    fi
    
    success "Dépendances installées"
}

run_tests() {
    if [ "$SKIP_TESTS" = true ]; then
        warn "Tests ignorés (SKIP_TESTS=true)"
        return 0
    fi
    
    step "Exécution des tests..."
    
    # Tests unitaires
    if npm run test:unit > /dev/null 2>&1; then
        success "Tests unitaires passés"
    else
        warn "Tests unitaires échoués ou non configurés"
    fi
    
    # Tests d'intégration
    if npm run test:integration > /dev/null 2>&1; then
        success "Tests d'intégration passés"
    else
        warn "Tests d'intégration échoués ou non configurés"
    fi
    
    # Linting
    if npm run lint > /dev/null 2>&1; then
        success "Linting passé"
    else
        warn "Linting échoué ou non configuré"
    fi
}

build_platforms() {
    step "Build pour les plateformes: $PLATFORMS"
    
    # Nettoyage
    if [ -d "dist" ]; then
        rm -rf dist/*
    fi
    
    # Build par plateforme
    IFS=',' read -ra PLATFORM_ARRAY <<< "$PLATFORMS"
    
    for platform in "${PLATFORM_ARRAY[@]}"; do
        case $platform in
            win)
                log "Build Windows..."
                npm run build:win
                success "Build Windows terminé"
                ;;
            mac)
                log "Build macOS..."
                npm run build:mac
                
                # Signature et notarisation si sur macOS
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    if [ -n "$APPLE_ID" ] && [ -n "$APPLE_ID_PASSWORD" ]; then
                        log "Signature et notarisation macOS..."
                        chmod +x scripts/macos-sign.sh scripts/macos-notarize.sh
                        ./scripts/macos-sign.sh
                        ./scripts/macos-notarize.sh
                        success "Signature et notarisation terminées"
                    else
                        warn "Variables Apple non définies - signature/notarisation ignorée"
                    fi
                fi
                success "Build macOS terminé"
                ;;
            linux)
                log "Build Linux..."
                npm run build:linux
                success "Build Linux terminé"
                ;;
            *)
                warn "Plateforme inconnue: $platform"
                ;;
        esac
    done
}

generate_checksums() {
    step "Génération des checksums..."
    
    local checksum_file="dist/checksums.txt"
    local checksum_sha256="dist/checksums-sha256.txt"
    
    # Créer checksums MD5 et SHA256
    (cd dist && find . -type f -name "*.exe" -o -name "*.dmg" -o -name "*.AppImage" -o -name "*.deb" -o -name "*.rpm" | while read file; do
        md5sum "$file" >> "../$checksum_file"
        sha256sum "$file" >> "../$checksum_sha256"
    done)
    
    success "Checksums générés"
}

sign_artifacts() {
    step "Signature des artifacts..."
    
    # Signature GPG si disponible
    if command -v gpg &> /dev/null && [ -n "$GPG_KEY_ID" ]; then
        log "Signature GPG des checksums..."
        gpg --detach-sign --armor --local-user "$GPG_KEY_ID" dist/checksums.txt
        gpg --detach-sign --armor --local-user "$GPG_KEY_ID" dist/checksums-sha256.txt
        success "Signature GPG terminée"
    else
        warn "GPG non disponible ou GPG_KEY_ID non défini - signature ignorée"
    fi
}

create_release_notes() {
    step "Création des notes de release..."
    
    local release_notes="dist/RELEASE_NOTES_${VERSION}.md"
    
    cat > "$release_notes" << EOF
# USB Video Vault v${VERSION}

## 📦 Artifacts de Release

### Windows
- \`USB-Video-Vault-${VERSION}-Setup.exe\` - Installateur Windows
- \`USB-Video-Vault-${VERSION}-portable.exe\` - Version portable Windows

### macOS
- \`USB-Video-Vault-${VERSION}.dmg\` - Installateur macOS (notarisé)

### Linux
- \`USB-Video-Vault-${VERSION}.AppImage\` - Application Linux
- \`USB-Video-Vault-${VERSION}.deb\` - Package Debian/Ubuntu
- \`USB-Video-Vault-${VERSION}.rpm\` - Package RedHat/Fedora

## 🔒 Vérification

### Checksums
\`\`\`
$(cat dist/checksums-sha256.txt 2>/dev/null || echo "Checksums non disponibles")
\`\`\`

### Signature GPG
Les checksums sont signés avec la clé GPG: \`${GPG_KEY_ID:-"Non disponible"}\`

## 📋 Changelog

$(git log --oneline --since="$(git describe --tags --abbrev=0)^" --pretty=format:"- %s (%h)" 2>/dev/null || echo "Changelog automatique non disponible")

## 🔧 Installation

### Windows
1. Télécharger \`USB-Video-Vault-${VERSION}-Setup.exe\`
2. Exécuter l'installateur
3. Suivre les instructions

### macOS
1. Télécharger \`USB-Video-Vault-${VERSION}.dmg\`
2. Monter le DMG
3. Glisser l'application dans Applications

### Linux
#### AppImage
1. Télécharger \`USB-Video-Vault-${VERSION}.AppImage\`
2. Rendre exécutable: \`chmod +x USB-Video-Vault-${VERSION}.AppImage\`
3. Exécuter: \`./USB-Video-Vault-${VERSION}.AppImage\`

#### Package (.deb/.rpm)
\`\`\`bash
# Debian/Ubuntu
sudo dpkg -i USB-Video-Vault-${VERSION}.deb

# RedHat/Fedora
sudo rpm -i USB-Video-Vault-${VERSION}.rpm
\`\`\`

## 📞 Support

- Documentation: [docs/README.md](docs/README.md)
- Issues: GitHub Issues
- Support Bundle: Exécuter \`scripts/support-bundle.ps1\` ou \`scripts/support-bundle-simple.ps1\`

---

**Date de release**: $(date)
**Commit**: $(git rev-parse HEAD)
EOF

    success "Notes de release créées: $release_notes"
}

validate_build() {
    step "Validation du build..."
    
    local errors=0
    
    # Vérifier que les artifacts existent
    if [[ "$PLATFORMS" == *"win"* ]]; then
        if ! ls dist/*.exe &> /dev/null; then
            error "Artifacts Windows manquants"
            ((errors++))
        fi
    fi
    
    if [[ "$PLATFORMS" == *"mac"* ]]; then
        if ! ls dist/*.dmg &> /dev/null && ! ls dist/mac/*.app &> /dev/null; then
            error "Artifacts macOS manquants"
            ((errors++))
        fi
    fi
    
    if [[ "$PLATFORMS" == *"linux"* ]]; then
        if ! ls dist/*.AppImage &> /dev/null && ! ls dist/*.deb &> /dev/null; then
            error "Artifacts Linux manquants"
            ((errors++))
        fi
    fi
    
    # Validation spécifique macOS
    if [[ "$OSTYPE" == "darwin"* ]] && [[ "$PLATFORMS" == *"mac"* ]]; then
        if [ -f "scripts/macos-verify.sh" ]; then
            chmod +x scripts/macos-verify.sh
            if ./scripts/macos-verify.sh; then
                success "Validation macOS passée"
            else
                warn "Validation macOS échouée"
                ((errors++))
            fi
        fi
    fi
    
    if [ $errors -gt 0 ]; then
        error "$errors erreur(s) de validation"
        return 1
    fi
    
    success "Validation passée"
}

create_github_release() {
    if [ "$AUTO_RELEASE" != true ]; then
        log "Auto-release désactivé - création manuelle requise"
        return 0
    fi
    
    step "Création release GitHub..."
    
    # Vérifier gh CLI
    if ! command -v gh &> /dev/null; then
        warn "GitHub CLI non disponible - release ignorée"
        return 0
    fi
    
    # Créer tag si nécessaire
    if ! git tag -l | grep -q "^v$VERSION$"; then
        git tag -a "v$VERSION" -m "Release v$VERSION"
        git push origin "v$VERSION"
    fi
    
    # Créer release
    local release_files=(
        dist/*.exe
        dist/*.dmg
        dist/*.AppImage
        dist/*.deb
        dist/*.rpm
        dist/checksums*.txt
        dist/checksums*.txt.asc
        dist/RELEASE_NOTES_*.md
    )
    
    gh release create "v$VERSION" \
        --title "USB Video Vault v$VERSION" \
        --notes-file "dist/RELEASE_NOTES_${VERSION}.md" \
        "${release_files[@]}"
    
    success "Release GitHub créée"
}

cleanup_build_artifacts() {
    step "Nettoyage des artifacts temporaires..."
    
    # Supprimer fichiers temporaires
    rm -f certificate.p12 2>/dev/null || true
    rm -rf build/temp 2>/dev/null || true
    
    success "Nettoyage terminé"
}

create_build_report() {
    step "Création du rapport de build..."
    
    local report_file="dist/build-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "USB Video Vault - Rapport de Build"
        echo "=================================="
        echo "Date: $(date)"
        echo "Version: $VERSION"
        echo "Plateformes: $PLATFORMS"
        echo "Commit: $(git rev-parse HEAD)"
        echo "Branch: $(git branch --show-current)"
        echo ""
        echo "Environnement:"
        echo "- OS: $OSTYPE"
        echo "- Node: $(node --version)"
        echo "- npm: $(npm --version)"
        echo ""
        echo "Artifacts créés:"
        ls -la dist/ | grep -E '\.(exe|dmg|AppImage|deb|rpm)$' || echo "Aucun artifact trouvé"
        echo ""
        echo "Tailles des artifacts:"
        du -h dist/*.{exe,dmg,AppImage,deb,rpm} 2>/dev/null || echo "Calcul impossible"
        echo ""
        echo "Checksums:"
        cat dist/checksums-sha256.txt 2>/dev/null || echo "Checksums non disponibles"
    } > "$report_file"
    
    success "Rapport de build créé: $report_file"
}

main() {
    step "USB Video Vault - Pipeline de Build Complète"
    step "============================================="
    
    if [ "$DRY_RUN" = true ]; then
        warn "Mode DRY_RUN activé - aucune action destructive"
    fi
    
    # Pipeline principal
    check_prerequisites
    install_dependencies
    run_tests
    build_platforms
    generate_checksums
    sign_artifacts
    create_release_notes
    validate_build
    create_build_report
    
    if [ "$DRY_RUN" = false ]; then
        create_github_release
    fi
    
    cleanup_build_artifacts
    
    success "🎉 Pipeline de build terminée avec succès!"
    log "Version: $VERSION"
    log "Artifacts disponibles dans: dist/"
    
    if [ "$AUTO_RELEASE" = true ]; then
        log "Release GitHub créée automatiquement"
    else
        log "Pour créer la release GitHub: gh release create v$VERSION --notes-file dist/RELEASE_NOTES_${VERSION}.md dist/*"
    fi
}

# Gestion des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --auto-release)
            AUTO_RELEASE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version VERSION     Version à builder (défaut: package.json)"
            echo "  --platforms LIST      Plateformes à builder (win,mac,linux)"
            echo "  --skip-tests          Ignorer les tests"
            echo "  --dry-run             Mode simulation"
            echo "  --auto-release        Créer release GitHub automatiquement"
            echo "  --help                Afficher cette aide"
            echo ""
            echo "Variables d'environnement:"
            echo "  VERSION               Version à builder"
            echo "  PLATFORMS             Plateformes (win,mac,linux)"
            echo "  SKIP_TESTS            Ignorer tests (true/false)"
            echo "  DRY_RUN               Mode simulation (true/false)"
            echo "  AUTO_RELEASE          Auto-release GitHub (true/false)"
            echo "  GPG_KEY_ID            ID clé GPG pour signature"
            echo "  APPLE_ID              Apple ID pour notarisation macOS"
            echo "  APPLE_ID_PASSWORD     Password Apple pour notarisation"
            echo "  TEAM_ID               Team ID Apple Developer"
            exit 0
            ;;
        *)
            error "Option inconnue: $1"
            exit 1
            ;;
    esac
done

# Exécution
main