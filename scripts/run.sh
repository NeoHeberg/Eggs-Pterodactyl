#!/bin/sh


. /common.sh
HOSTNAME="MyVPS"
HISTORY_FILE="${HOME}/.custom_shell_history"
MAX_HISTORY=1000

# Vérifier si l'OS est installé
if [ ! -e "/.installed" ]; then
    rm -f /rootfs.tar.xz /rootfs.tar.gz 2>/dev/null
    rm -rf /tmp/sbin
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    touch "/.installed"
fi

# Script d'autorun
[ ! -e "/autorun.sh" ] && touch /autorun.sh && chmod +x /autorun.sh

printf "\033c"
print_main_banner
log "INFO" "Tapez 'help' pour voir les commandes disponibles." "$YELLOW"

# Fonctions utilitaires
get_formatted_dir() {
    current_dir="$PWD"
    case "$current_dir" in
        "$HOME"*) echo "~${current_dir#$HOME}" ;;
        *) echo "$current_dir" ;;
    esac
}

save_to_history() {
    [ -n "$1" ] && echo "$1" >> "$HISTORY_FILE"
    tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" 2>/dev/null && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

reinstall_os() {
    log "AVERTISSEMENT" "Réinstallation de l'OS... toutes les données seront perdues !" "$RED"
    find / -mindepth 1 -xdev -delete 2>/dev/null
    exit 2
}

show_status() {
    echo "=== Système ==="
    uptime
    echo "=== Mémoire ==="
    free -h
    echo "=== Disque ==="
    df -h
}

print_help() {
    print_help_banner
}

while true; do
    printf "\n${GREEN}root@${HOSTNAME}${NC}:${RED}$(get_formatted_dir)${NC}# "
    read -r cmd

    save_to_history "$cmd"

    case "$cmd" in
        clear|cls) printf "\033c" ;;
        exit) log "INFO" "Au revoir !" "$GREEN"; exit 0 ;;
        history) [ -f "$HISTORY_FILE" ] && cat "$HISTORY_FILE" ;;
        reinstall) reinstall_os ;;
        status) show_status ;;
        help) print_help ;;
        sudo*|su*) log "ERREUR" "Vous êtes déjà root." "$RED" ;;
        "") ;;
        *) eval "$cmd" ;;
    esac
done