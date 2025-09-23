#!/bin/bash
# macOS Application Notarization Script
# USB Video Vault - Notarisation Apple

set -e

# Configuration
APP_NAME="USB Video Vault"
APP_PATH="dist/mac/${APP_NAME}.app"
ZIP_PATH="dist/${APP_NAME}-notarization.zip"
APPLE_ID="${APPLE_ID}"
APPLE_ID_PASSWORD="${APPLE_ID_PASSWORD}"
TEAM_ID="${TEAM_ID}"
VERBOSE=${VERBOSE:-false}

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[NOTARIZE]${NC} $1"
}

success() {
    echo -e "${GREEN}[NOTARIZE]${NC} ✅ $1"
}

warn() {
    echo -e "${YELLOW}[NOTARIZE]${NC} ⚠️ $1"
}

error() {
    echo -e "${RED}[NOTARIZE]${NC} ❌ $1"
    exit 1
}

# Vérifier les prérequis
check_prerequisites() {
    log "Vérification des prérequis de notarisation..."
    
    # Vérifier xcrun
    if ! command -v xcrun &> /dev/null; then
        error "xcrun non trouvé. Installez Xcode Command Line Tools"
    fi
    
    # Vérifier l'application
    if [ ! -d "$APP_PATH" ]; then
        error "Application non trouvée: $APP_PATH"
    fi
    
    # Vérifier que l'app est signée
    if ! codesign --verify "$APP_PATH" 2>/dev/null; then
        error "Application non signée. Exécutez d'abord: ./scripts/macos-sign.sh"
    fi
    
    # Vérifier les credentials Apple
    if [ -z "$APPLE_ID" ]; then
        error "APPLE_ID requis pour la notarisation"
    fi
    
    if [ -z "$APPLE_ID_PASSWORD" ]; then
        error "APPLE_ID_PASSWORD requis (app-specific password)"
    fi
    
    if [ -z "$TEAM_ID" ]; then
        error "TEAM_ID requis pour la notarisation"
    fi
    
    success "Prérequis validés"
}

# Créer l'archive ZIP pour notarisation
create_notarization_archive() {
    log "Création archive pour notarisation..."
    
    # Supprimer archive existante
    if [ -f "$ZIP_PATH" ]; then
        rm "$ZIP_PATH"
    fi
    
    # Créer répertoire de destination
    mkdir -p "$(dirname "$ZIP_PATH")"
    
    # Créer archive ZIP
    (cd "$(dirname "$APP_PATH")" && zip -r "$(basename "$ZIP_PATH")" "$(basename "$APP_PATH")")
    
    # Déplacer l'archive au bon endroit
    if [ ! -f "$ZIP_PATH" ]; then
        mv "$(dirname "$APP_PATH")/$(basename "$ZIP_PATH")" "$ZIP_PATH"
    fi
    
    local size=$(ls -lh "$ZIP_PATH" | awk '{print $5}')
    success "Archive créée: $ZIP_PATH ($size)"
}

# Soumettre pour notarisation
submit_for_notarization() {
    log "Soumission pour notarisation Apple..."
    
    local notarize_args=(
        --notarize-app
        --primary-bundle-id "com.yindo.usbvideovault"
        --username "$APPLE_ID"
        --password "$APPLE_ID_PASSWORD"
        --asc-provider "$TEAM_ID"
        --file "$ZIP_PATH"
    )
    
    if [ "$VERBOSE" = true ]; then
        notarize_args+=(--verbose)
    fi
    
    # Soumettre et capturer l'ID de soumission
    local result
    result=$(xcrun altool "${notarize_args[@]}" 2>&1)
    
    echo "$result"
    
    # Extraire RequestUUID
    local request_uuid
    request_uuid=$(echo "$result" | grep "RequestUUID" | awk '{print $3}')
    
    if [ -z "$request_uuid" ]; then
        error "Échec soumission notarisation"
    fi
    
    success "Soumission réussie - RequestUUID: $request_uuid"
    echo "$request_uuid" > "build/notarization-request-uuid.txt"
    
    return 0
}

# Vérifier le statut de notarisation
check_notarization_status() {
    local request_uuid="$1"
    
    if [ -z "$request_uuid" ]; then
        if [ -f "build/notarization-request-uuid.txt" ]; then
            request_uuid=$(cat "build/notarization-request-uuid.txt")
        else
            error "RequestUUID requis pour vérifier le statut"
        fi
    fi
    
    log "Vérification statut notarisation: $request_uuid"
    
    local status_args=(
        --notarization-info "$request_uuid"
        --username "$APPLE_ID"
        --password "$APPLE_ID_PASSWORD"
    )
    
    xcrun altool "${status_args[@]}" 2>&1
}

# Attendre la completion de la notarisation
wait_for_notarization() {
    local request_uuid="$1"
    local max_attempts=60  # 30 minutes max
    local attempt=0
    
    log "Attente completion notarisation (max 30 min)..."
    
    while [ $attempt -lt $max_attempts ]; do
        local status_output
        status_output=$(check_notarization_status "$request_uuid")
        
        if echo "$status_output" | grep -q "Status: success"; then
            success "Notarisation réussie!"
            return 0
        elif echo "$status_output" | grep -q "Status: invalid"; then
            error "Notarisation échouée. Vérifiez les logs Apple."
        elif echo "$status_output" | grep -q "Status: in progress"; then
            log "En cours... (tentative $((attempt + 1))/$max_attempts)"
        else
            warn "Statut inconnu, continue..."
        fi
        
        sleep 30
        ((attempt++))
    done
    
    error "Timeout: notarisation non terminée après 30 minutes"
}

# Agrafer le ticket de notarisation
staple_notarization_ticket() {
    log "Agrafage du ticket de notarisation..."
    
    if xcrun stapler staple "$APP_PATH"; then
        success "Ticket agrafé avec succès"
    else
        error "Échec agrafage du ticket"
    fi
    
    # Vérifier l'agrafage
    if xcrun stapler validate "$APP_PATH"; then
        success "Validation ticket réussie"
    else
        warn "Validation ticket échouée"
    fi
}

# Vérification finale
final_verification() {
    log "Vérification finale de l'application notarisée..."
    
    # Vérifier signature et notarisation
    local spctl_output
    spctl_output=$(spctl --assess --type execute --verbose "$APP_PATH" 2>&1)
    
    if echo "$spctl_output" | grep -q "accepted"; then
        success "Application notarisée et acceptée par Gatekeeper"
    else
        warn "Application non acceptée par Gatekeeper"
        echo "$spctl_output"
    fi
    
    # Vérifier le ticket
    if codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -q "Ticket"; then
        success "Ticket de notarisation détecté"
    else
        warn "Aucun ticket de notarisation détecté"
    fi
}

# Créer rapport de notarisation
create_notarization_report() {
    local report_file="build/notarization-report-$(date +%Y%m%d-%H%M%S).txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "USB Video Vault - Rapport de Notarisation macOS"
        echo "==============================================="
        echo "Date: $(date)"
        echo "Application: $APP_PATH"
        echo "Archive: $ZIP_PATH"
        echo "Apple ID: $APPLE_ID"
        echo "Team ID: $TEAM_ID"
        echo ""
        echo "Statut Gatekeeper:"
        spctl --assess --type execute --verbose "$APP_PATH" 2>&1 || echo "Échec assessment"
        echo ""
        echo "Détails de signature:"
        codesign -dv --verbose=4 "$APP_PATH" 2>&1
        echo ""
        echo "Validation stapler:"
        xcrun stapler validate "$APP_PATH" 2>&1 || echo "Pas de ticket"
    } > "$report_file"
    
    log "Rapport sauvegardé: $report_file"
}

# Fonction principale
main() {
    log "Début notarisation macOS - USB Video Vault"
    log "=========================================="
    
    check_prerequisites
    create_notarization_archive
    
    # Soumettre pour notarisation
    submit_for_notarization
    
    # Lire l'UUID de la soumission
    local request_uuid
    if [ -f "build/notarization-request-uuid.txt" ]; then
        request_uuid=$(cat "build/notarization-request-uuid.txt")
    fi
    
    # Attendre la completion
    wait_for_notarization "$request_uuid"
    
    # Agrafer le ticket
    staple_notarization_ticket
    
    # Vérification finale
    final_verification
    
    # Rapport
    create_notarization_report
    
    success "Notarisation terminée avec succès!"
    log "Application prête pour distribution: $APP_PATH"
}

# Gestion des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-path)
            APP_PATH="$2"
            shift 2
            ;;
        --apple-id)
            APPLE_ID="$2"
            shift 2
            ;;
        --password)
            APPLE_ID_PASSWORD="$2"
            shift 2
            ;;
        --team-id)
            TEAM_ID="$2"
            shift 2
            ;;
        --check-status)
            check_notarization_status "$2"
            exit 0
            ;;
        --wait-only)
            if [ -f "build/notarization-request-uuid.txt" ]; then
                request_uuid=$(cat "build/notarization-request-uuid.txt")
                wait_for_notarization "$request_uuid"
                staple_notarization_ticket
                final_verification
            else
                error "Aucune soumission en cours trouvée"
            fi
            exit 0
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
            echo "  --apple-id EMAIL      Apple ID pour notarisation"
            echo "  --password PASS       App-specific password"
            echo "  --team-id ID          Team ID Apple Developer"
            echo "  --check-status UUID   Vérifier statut d'une soumission"
            echo "  --wait-only           Attendre soumission en cours"
            echo "  --verbose             Mode verbeux"
            echo "  --help                Afficher cette aide"
            echo ""
            echo "Variables d'environnement:"
            echo "  APPLE_ID              Apple ID email"
            echo "  APPLE_ID_PASSWORD     App-specific password"
            echo "  TEAM_ID               Team ID"
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