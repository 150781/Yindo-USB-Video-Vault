#!/bin/bash
# macOS Verification Script - Complete App Validation
# USB Video Vault - Vérification complète après notarisation

set -e

# Configuration
APP_NAME="USB Video Vault"
APP_PATH="${APP_PATH:-dist/mac/${APP_NAME}.app}"
VERBOSE=${VERBOSE:-false}

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[VERIFY]${NC} $1"; }
success() { echo -e "${GREEN}[VERIFY]${NC} ✅ $1"; }
warn() { echo -e "${YELLOW}[VERIFY]${NC} ⚠️ $1"; }
error() { echo -e "${RED}[VERIFY]${NC} ❌ $1"; }

# Tests de vérification
verify_app_structure() {
    log "Vérification de la structure de l'application..."
    
    if [ ! -d "$APP_PATH" ]; then
        error "Application non trouvée: $APP_PATH"
        return 1
    fi
    
    # Vérifier structure basique
    local required_files=(
        "Contents/Info.plist"
        "Contents/MacOS/"
        "Contents/Resources/"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -e "$APP_PATH/$file" ]; then
            error "Fichier requis manquant: $file"
            return 1
        fi
    done
    
    success "Structure de l'application valide"
    return 0
}

verify_code_signature() {
    log "Vérification de la signature de code..."
    
    # Vérification basique
    if ! codesign --verify --verbose "$APP_PATH" 2>/dev/null; then
        error "Signature de code invalide"
        return 1
    fi
    
    # Vérifier signature stricte
    if ! codesign --verify --strict --verbose "$APP_PATH" 2>/dev/null; then
        warn "Signature stricte échouée"
    fi
    
    # Afficher détails signature
    local signature_info
    signature_info=$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)
    
    if [ "$VERBOSE" = true ]; then
        echo "$signature_info"
    fi
    
    # Vérifier Developer ID
    if echo "$signature_info" | grep -q "Developer ID Application"; then
        success "Signature Developer ID détectée"
    else
        warn "Pas de signature Developer ID"
    fi
    
    # Vérifier hardened runtime
    if echo "$signature_info" | grep -q "runtime"; then
        success "Hardened Runtime activé"
    else
        warn "Hardened Runtime non détecté"
    fi
    
    success "Signature de code valide"
    return 0
}

verify_notarization() {
    log "Vérification de la notarisation..."
    
    # Vérifier ticket de notarisation
    if xcrun stapler validate "$APP_PATH" 2>/dev/null; then
        success "Ticket de notarisation valide"
    else
        warn "Aucun ticket de notarisation détecté"
        return 1
    fi
    
    # Vérifier avec spctl
    local spctl_output
    spctl_output=$(spctl --assess --type execute --verbose "$APP_PATH" 2>&1)
    
    if echo "$spctl_output" | grep -q "accepted"; then
        success "Application acceptée par Gatekeeper"
    else
        error "Application rejetée par Gatekeeper"
        echo "$spctl_output"
        return 1
    fi
    
    return 0
}

verify_entitlements() {
    log "Vérification des entitlements..."
    
    local entitlements
    entitlements=$(codesign -d --entitlements - "$APP_PATH" 2>/dev/null)
    
    if [ -n "$entitlements" ]; then
        success "Entitlements présents"
        
        if [ "$VERBOSE" = true ]; then
            echo "$entitlements"
        fi
        
        # Vérifier entitlements critiques
        if echo "$entitlements" | grep -q "com.apple.security.cs.allow-jit"; then
            success "JIT autorisé"
        fi
        
        if echo "$entitlements" | grep -q "com.apple.security.cs.disable-library-validation"; then
            warn "Validation des bibliothèques désactivée"
        fi
    else
        warn "Aucun entitlement détecté"
    fi
}

verify_info_plist() {
    log "Vérification de Info.plist..."
    
    local plist_path="$APP_PATH/Contents/Info.plist"
    
    # Vérifier lisibilité
    if ! plutil -lint "$plist_path" > /dev/null 2>&1; then
        error "Info.plist malformé"
        return 1
    fi
    
    # Vérifier champs requis
    local required_keys=(
        "CFBundleIdentifier"
        "CFBundleName"
        "CFBundleVersion"
        "CFBundleShortVersionString"
        "CFBundleExecutable"
    )
    
    for key in "${required_keys[@]}"; do
        if ! /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" > /dev/null 2>&1; then
            error "Clé manquante dans Info.plist: $key"
            return 1
        fi
    done
    
    # Afficher informations clés
    local bundle_id
    bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist_path")
    local version
    version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist_path")
    
    log "Bundle ID: $bundle_id"
    log "Version: $version"
    
    success "Info.plist valide"
    return 0
}

verify_dependencies() {
    log "Vérification des dépendances..."
    
    local executable_path="$APP_PATH/Contents/MacOS/$APP_NAME"
    
    if [ ! -f "$executable_path" ]; then
        # Trouver l'exécutable
        executable_path=$(find "$APP_PATH/Contents/MacOS" -type f -perm +111 | head -1)
    fi
    
    if [ ! -f "$executable_path" ]; then
        error "Exécutable non trouvé"
        return 1
    fi
    
    # Vérifier dépendances avec otool
    local deps
    deps=$(otool -L "$executable_path" 2>/dev/null)
    
    if [ "$VERBOSE" = true ]; then
        echo "Dépendances:"
        echo "$deps"
    fi
    
    # Vérifier dépendances système
    if echo "$deps" | grep -q "/usr/lib/"; then
        success "Dépendances système détectées"
    fi
    
    # Vérifier dépendances bundlées
    if echo "$deps" | grep -q "@executable_path"; then
        success "Dépendances bundlées détectées"
    fi
    
    success "Dépendances vérifiées"
    return 0
}

test_launch() {
    log "Test de lancement (non-interactif)..."
    
    # Test avec timeout pour éviter blocage
    if timeout 10s open "$APP_PATH" --args --version > /dev/null 2>&1; then
        success "Application peut être lancée"
    else
        warn "Test de lancement échoué ou timeout"
    fi
    
    # Vérifier dans les logs système si l'app a été bloquée
    local recent_logs
    recent_logs=$(log show --predicate 'subsystem == "com.apple.syspolicy"' --last 5m 2>/dev/null | grep -i "deny\|block" | grep "$APP_NAME" || true)
    
    if [ -n "$recent_logs" ]; then
        warn "Application potentiellement bloquée par le système:"
        echo "$recent_logs"
    fi
}

create_verification_report() {
    local report_file="build/verification-report-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "USB Video Vault - Rapport de Vérification macOS"
        echo "=============================================="
        echo "Date: $(date)"
        echo "Application: $APP_PATH"
        echo ""
        
        echo "Structure de l'application:"
        ls -la "$APP_PATH/Contents/" 2>/dev/null || echo "Erreur listing"
        echo ""
        
        echo "Info.plist:"
        plutil -p "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "Erreur lecture Info.plist"
        echo ""
        
        echo "Signature de code:"
        codesign -dv --verbose=4 "$APP_PATH" 2>&1
        echo ""
        
        echo "Entitlements:"
        codesign -d --entitlements - "$APP_PATH" 2>&1
        echo ""
        
        echo "Validation stapler:"
        xcrun stapler validate "$APP_PATH" 2>&1 || echo "Pas de ticket"
        echo ""
        
        echo "Assessment Gatekeeper:"
        spctl --assess --type execute --verbose "$APP_PATH" 2>&1
        echo ""
        
        echo "Dépendances:"
        local executable
        executable=$(find "$APP_PATH/Contents/MacOS" -type f -perm +111 | head -1)
        if [ -n "$executable" ]; then
            otool -L "$executable" 2>/dev/null || echo "Erreur analyse dépendances"
        fi
        
    } > "$report_file"
    
    log "Rapport de vérification sauvegardé: $report_file"
}

main() {
    log "Vérification complète macOS - USB Video Vault"
    log "============================================"
    
    local errors=0
    
    # Tests de vérification
    verify_app_structure || ((errors++))
    verify_info_plist || ((errors++))
    verify_code_signature || ((errors++))
    verify_entitlements
    verify_notarization || ((errors++))
    verify_dependencies || ((errors++))
    test_launch
    
    # Créer rapport
    create_verification_report
    
    # Résumé
    echo ""
    if [ $errors -eq 0 ]; then
        success "✅ Toutes les vérifications passées avec succès!"
        log "Application prête pour distribution"
        exit 0
    else
        error "❌ $errors erreur(s) détectée(s)"
        log "Consultez le rapport pour plus de détails"
        exit 1
    fi
}

# Gestion des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --report-only)
            create_verification_report
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --app-path PATH       Chemin vers l'application (.app)"
            echo "  --verbose             Mode verbeux"
            echo "  --report-only         Créer uniquement le rapport"
            echo "  --help                Afficher cette aide"
            echo ""
            echo "Variables d'environnement:"
            echo "  APP_PATH              Chemin vers l'application"
            echo "  VERBOSE               Mode verbeux (true/false)"
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