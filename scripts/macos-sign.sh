#!/bin/bash
# macOS Application Signing Script
# USB Video Vault - Code Signing avec Developer ID

set -e

# Configuration
APP_NAME="USB Video Vault"
APP_PATH="dist/mac/${APP_NAME}.app"
ENTITLEMENTS_PATH="build/entitlements.plist"
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: Your Name (TEAM_ID)}"
VERBOSE=${VERBOSE:-false}

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[SIGN]${NC} $1"
}

success() {
    echo -e "${GREEN}[SIGN]${NC} ✅ $1"
}

warn() {
    echo -e "${YELLOW}[SIGN]${NC} ⚠️ $1"
}

error() {
    echo -e "${RED}[SIGN]${NC} ❌ $1"
    exit 1
}

# Vérifier les prérequis
check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Vérifier Xcode Command Line Tools
    if ! command -v codesign &> /dev/null; then
        error "codesign non trouvé. Installez Xcode Command Line Tools: xcode-select --install"
    fi
    
    # Vérifier l'application
    if [ ! -d "$APP_PATH" ]; then
        error "Application non trouvée: $APP_PATH"
    fi
    
    # Vérifier les entitlements
    if [ ! -f "$ENTITLEMENTS_PATH" ]; then
        warn "Entitlements non trouvés: $ENTITLEMENTS_PATH - Création automatique..."
        create_default_entitlements
    fi
    
    # Vérifier l'identité de signature
    if ! security find-identity -v -p codesigning | grep -q "$DEVELOPER_ID"; then
        error "Identité de signature non trouvée: $DEVELOPER_ID"
    fi
    
    success "Prérequis validés"
}

# Créer entitlements par défaut
create_default_entitlements() {
    mkdir -p "$(dirname "$ENTITLEMENTS_PATH")"
    
    cat > "$ENTITLEMENTS_PATH" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Accès réseau pour vérification de licence -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- Accès fichiers utilisateur -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <!-- Accès périphériques USB -->
    <key>com.apple.security.device.usb</key>
    <true/>
    
    <!-- Hardened Runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
    
    <!-- Debugging (dev seulement) -->
    <!-- <key>com.apple.security.cs.debugger</key>
    <true/> -->
</dict>
</plist>
EOF
    
    log "Entitlements par défaut créés: $ENTITLEMENTS_PATH"
}

# Nettoyer les signatures existantes
clean_existing_signatures() {
    log "Nettoyage signatures existantes..."
    
    # Supprimer signatures existantes de tous les exécutables
    find "$APP_PATH" -type f \( -perm +111 -o -name "*.dylib" -o -name "*.so" \) -exec codesign --remove-signature {} \; 2>/dev/null || true
    
    success "Signatures nettoyées"
}

# Signer les frameworks et bibliothèques internes
sign_frameworks() {
    log "Signature des frameworks internes..."
    
    # Trouver et signer tous les frameworks
    find "$APP_PATH/Contents/Frameworks" -name "*.framework" -type d 2>/dev/null | while read framework; do
        if [ -d "$framework" ]; then
            log "Signature framework: $(basename "$framework")"
            
            if [ "$VERBOSE" = true ]; then
                codesign --force --verify --verbose --sign "$DEVELOPER_ID" "$framework"
            else
                codesign --force --sign "$DEVELOPER_ID" "$framework"
            fi
        fi
    done
    
    # Signer les bibliothèques dynamiques
    find "$APP_PATH" -name "*.dylib" -o -name "*.so" 2>/dev/null | while read lib; do
        if [ -f "$lib" ]; then
            log "Signature bibliothèque: $(basename "$lib")"
            
            if [ "$VERBOSE" = true ]; then
                codesign --force --verify --verbose --sign "$DEVELOPER_ID" "$lib"
            else
                codesign --force --sign "$DEVELOPER_ID" "$lib"
            fi
        fi
    done
    
    success "Frameworks et bibliothèques signés"
}

# Signer les exécutables Node.js/Electron
sign_executables() {
    log "Signature des exécutables..."
    
    # Trouver tous les exécutables
    find "$APP_PATH/Contents" -type f -perm +111 | while read executable; do
        # Ignorer les scripts shell
        if file "$executable" | grep -q "Mach-O"; then
            log "Signature exécutable: $(basename "$executable")"
            
            if [ "$VERBOSE" = true ]; then
                codesign --force --verify --verbose --sign "$DEVELOPER_ID" "$executable"
            else
                codesign --force --sign "$DEVELOPER_ID" "$executable"
            fi
        fi
    done
    
    success "Exécutables signés"
}

# Signer l'application principale
sign_main_app() {
    log "Signature application principale..."
    
    local sign_args=(
        --force
        --sign "$DEVELOPER_ID"
        --entitlements "$ENTITLEMENTS_PATH"
        --options runtime
        --timestamp
    )
    
    if [ "$VERBOSE" = true ]; then
        sign_args+=(--verify --verbose)
    fi
    
    sign_args+=("$APP_PATH")
    
    codesign "${sign_args[@]}"
    
    success "Application principale signée"
}

# Vérifier la signature
verify_signature() {
    log "Vérification de la signature..."
    
    # Vérification de base
    if codesign --verify --verbose=4 "$APP_PATH" 2>&1 | grep -q "valid on disk"; then
        success "Signature valide"
    else
        error "Signature invalide"
    fi
    
    # Vérification Gatekeeper
    if spctl --assess --type execute --verbose "$APP_PATH" 2>&1 | grep -q "accepted"; then
        success "Gatekeeper: Application acceptée"
    else
        warn "Gatekeeper: Application non acceptée (normal avant notarisation)"
    fi
    
    # Affichage des détails
    if [ "$VERBOSE" = true ]; then
        log "Détails de la signature:"
        codesign -dv --verbose=4 "$APP_PATH" 2>&1 | head -20
    fi
}

# Créer un rapport de signature
create_signature_report() {
    local report_file="build/signature-report-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "USB Video Vault - Rapport de Signature macOS"
        echo "=============================================="
        echo "Date: $(date)"
        echo "Application: $APP_PATH"
        echo "Developer ID: $DEVELOPER_ID"
        echo ""
        echo "Détails de signature:"
        codesign -dv --verbose=4 "$APP_PATH" 2>&1
        echo ""
        echo "Vérification Gatekeeper:"
        spctl --assess --type execute --verbose "$APP_PATH" 2>&1 || echo "Échec (normal avant notarisation)"
        echo ""
        echo "Entitlements:"
        codesign -d --entitlements - "$APP_PATH" 2>/dev/null || echo "Aucun entitlement"
    } > "$report_file"
    
    log "Rapport sauvegardé: $report_file"
}

# Fonction principale
main() {
    log "Début signature macOS - USB Video Vault"
    log "======================================="
    
    check_prerequisites
    clean_existing_signatures
    sign_frameworks
    sign_executables
    sign_main_app
    verify_signature
    create_signature_report
    
    success "Signature terminée avec succès!"
    log "Prêt pour notarisation: ./scripts/macos-notarize.sh"
}

# Gestion des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        --developer-id)
            DEVELOPER_ID="$2"
            shift 2
            ;;
        --entitlements)
            ENTITLEMENTS_PATH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --app-path PATH       Chemin vers l'application (.app)"
            echo "  --developer-id ID     Identité Developer ID"
            echo "  --entitlements PATH   Chemin vers entitlements.plist"
            echo "  --verbose             Mode verbeux"
            echo "  --help                Afficher cette aide"
            echo ""
            echo "Variables d'environnement:"
            echo "  DEVELOPER_ID          Identité de signature"
            echo "  VERBOSE               Mode verbeux (true/false)"
            exit 0
            ;;
        *)
            error "Option inconnue: $1"
            ;;
    esac
done

# Exécution
main