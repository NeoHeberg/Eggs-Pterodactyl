#!/bin/sh


. /common.sh
ROOTFS_DIR="/home/container"
BASE_URL="https://images.linuxcontainers.org/images"
ARCH=$(uname -m)

# Conversion architecture pour linuxcontainers
case "$ARCH" in
    x86_64) ARCH_ALT="amd64" ;;
    aarch64) ARCH_ALT="arm64" ;;
    riscv64) ARCH_ALT="riscv64" ;;
    *) error_exit "Architecture non supportée : $ARCH" ;;
esac

# Liste des distributions
DISTROS="
1:Debian:debian
2:Ubuntu:ubuntu
3:Kali Linux:kali
4:Fedora:fedora
5:Amazon Linux:amazonlinux
"

error_exit() {
    log "ERREUR" "$1" "$RED"
    exit 1
}

# Vérification de la connexion réseau
check_network() {
    curl -s --head "$BASE_URL" >/dev/null || error_exit "Impossible de joindre $BASE_URL"
}

# Téléchargement et extraction du rootfs
download_rootfs() {
    distro_id="$1"
    version="$2"
    url="${BASE_URL}/${distro_id}/${version}/${ARCH_ALT}/default/"

    # Récupérer le dernier snapshot 
    latest=$(curl -s "$url" | grep -oE '[0-9]{8}_[0-9]{2}:[0-9]{2}/' | sort -r | head -n1)
    [ -z "$latest" ] && error_exit "Aucune version trouvée pour ${distro_id} ${version}"

    log "INFO" "Téléchargement de l'image..." "$GREEN"
    mkdir -p "$ROOTFS_DIR"
    curl -Ls "${url}${latest}rootfs.tar.xz" -o "$ROOTFS_DIR/rootfs.tar.xz" || error_exit "Échec du téléchargement"

    log "INFO" "Extraction de l'image..." "$GREEN"
    tar -xf "$ROOTFS_DIR/rootfs.tar.xz" -C "$ROOTFS_DIR" || error_exit "Échec de l'extraction"

    rm -f "$ROOTFS_DIR/rootfs.tar.xz"
    rm -f "$ROOTFS_DIR/etc/resolv.conf"
    mkdir -p "$ROOTFS_DIR/home/container"
}

clear
print_main_banner
printf "\n${YELLOW}Choisissez une distribution :${NC}\n\n"
echo "$DISTROS" | while IFS=: read -r num name id; do
    [ -n "$num" ] && printf "* [%s] %s\n" "$num" "$name"
done
printf "\n${YELLOW}Entrez le numéro (1-5) : ${NC}"
read -r choice

distro_line=$(echo "$DISTROS" | grep "^${choice}:")
[ -z "$distro_line" ] && error_exit "Choix invalide"

distro_name=$(echo "$distro_line" | cut -d: -f2)
distro_id=$(echo "$distro_line" | cut -d: -f3)

check_network

# Récupération des versions 
log "INFO" "Recherche des versions pour $distro_name..." "$GREEN"
versions=$(curl -s "${BASE_URL}/${distro_id}/" | grep -oE 'href="[^"]+/"' | sed 's/href="//;s/\/"//' | grep -v '^\.\.$' | sort -V)

if [ -z "$versions" ]; then
    error_exit "Aucune version trouvée pour $distro_name"
fi

# Compter et afficher les versions
version_count=$(echo "$versions" | wc -l)
if [ "$version_count" -eq 1 ]; then
    selected_version="$versions"
else
    printf "\n${YELLOW}Versions disponibles :${NC}\n"
    i=1
    echo "$versions" | while read -r ver; do
        printf "  [%d] %s\n" "$i" "$ver"
        i=$((i+1))
    done
    printf "\n${YELLOW}Choisissez la version (1-$version_count) : ${NC}"
    read -r ver_choice
    selected_version=$(echo "$versions" | sed -n "${ver_choice}p")
    [ -z "$selected_version" ] && error_exit "Choix de version invalide"
fi

log "INFO" "Installation de $distro_name $selected_version..." "$GREEN"
download_rootfs "$distro_id" "$selected_version"

# Copie des scripts de démarrage
cp /common.sh /run.sh "$ROOTFS_DIR"
chmod +x "$ROOTFS_DIR/common.sh" "$ROOTFS_DIR/run.sh"

log "SUCCÈS" "Installation terminée !" "$GREEN"
exit 0