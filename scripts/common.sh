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
    printf "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}\n"
    printf "${CYAN}│${NC}                                                             ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}           🚀  ${YELLOW}${BOLD}NeoHeberg${NC}                                      ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}   ⚡  Basé sur le travail de ${YELLOW}ysdragon${NC}                        ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}   🔧  Version simplifiée par ${YELLOW}NeoHeberg${NC}                       ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}                                                             ${CYAN}│${NC}\n"
    printf "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}\n"
    printf "\n"
}

print_help_banner() {
    printf "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}\n"
    printf "${CYAN}│${NC}               ${WHITE}${BOLD}📋 Commandes disponibles    ${NC}                   ${CYAN}│${NC}\n"
    printf "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}\n"
    printf "${CYAN}│${NC}  🧹  ${BLUE}clear / cls${NC}   ${GREEN}→${NC}  Effacer l'écran                        ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}  🔌  ${RED}exit${NC}          ${GREEN}→${NC}  Arrêter le conteneur                   ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}  📜  ${PURPLE}history${NC}      ${GREEN}→${NC}  Afficher l'historique                   ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}  🔄  ${BLUE}reinstall${NC}     ${GREEN}→${NC}  Réinstaller le système                 ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}  📊  ${BLUE}status${NC}        ${GREEN}→${NC}  Afficher l'état du système             ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}  ❓  ${WHITE}help${NC}          ${GREEN}→${NC}  Afficher cette aide                    ${CYAN}│${NC}\n"
    printf "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}\n"
    printf "\n"
}