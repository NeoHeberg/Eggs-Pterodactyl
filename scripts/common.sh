#!/bin/sh

# Couleurs
PURPLE='\033[0;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log() {
    level=$1
    message=$2
    color=$3
    [ -z "$color" ] && color="$NC"
    printf "${color}[$level]${NC} $message\n"
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        riscv64) echo "riscv64" ;;
        *) log "ERROR" "Architecture non supportée: $ARCH" "$RED" >&2; return 1 ;;
    esac
}

print_main_banner() {
    printf "\033c"

    printf "${BOLD}"
    printf "╔══════════════════════════════════════════════╗\n"
    printf "║                                              ║\n"
    printf "║              🚀  NeoHeberg                    ║\n"
    printf "║                                              ║\n"
    printf "╚══════════════════════════════════════════════╝\n"
    printf "${NC}"

    printf "\n"
    printf "> Basé sur le travail de ${YELLOW}${BOLD}ysdragon${NC}\n"
    printf "> Version simplifiée par ${YELLOW}${BOLD}NeoHeberg${NC}\n"
    printf "> Version: ${YELLOW}${BOLD}1.0.4${NC}\n"
    printf "\n"
}

print_help_banner() {
    printf "${BOLD}${WHITE}Commandes disponibles${NC}\n"
    printf "${CYAN}──────────────────────────────────────────────${NC}\n"

    printf "  ${GREEN}clear / cls${NC}     Nettoyer l'écran\n"
    printf "  ${GREEN}exit${NC}            Arrêter le conteneur\n"
    printf "  ${GREEN}history${NC}         Afficher l'historique\n"
    printf "  ${GREEN}reinstall${NC}       Réinstaller le système\n"
    printf "  ${GREEN}status${NC}          Afficher l'état du système\n"
    printf "  ${GREEN}help${NC}            Afficher cette aide\n"

    printf "\n"
}