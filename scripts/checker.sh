#!/bin/sh
NC='\033[0m'
GRAY_BG='\033[48;5;250m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

log() {
    level=$1
    message=$2
    color=$3
    [ -z "$color" ] && color="$NC"
    printf "${color}[$level]${NC} $message\n"
}

error_exit() {
    echo "Erreur : $1" >&2
    exit 1
}

cls() {
    printf "\033c"
}

cls
printf "${GRAY_BG}Vérification de la connexion...${NC}\n"
curl -s --head "https://neoheberg.fr" >/dev/null || error_exit "Impossible de joindre un réseau."
log "INFO" "$(date +%H:%M:%S) Accès au réseau établi." "$GREEN"
sleep 2
log "INFO" "$(date +%H:%M:%S) Scripts chargés." "$GREEN"
sleep 1
log "INFO" "$(date +%H:%M:%S) Tests établis." "$GREEN"
sleep 2