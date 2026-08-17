#!/usr/bin/env bash
# Pas de `set -e` ici : le script est interactif (lecture clavier via la
# console Pterodactyl) et gère lui-même les réponses invalides.
set -uo pipefail

# =============================================================================
#  NeoHeberg · Egg Node.js — setup interactif
#  Exécuté au premier démarrage (quand .neoheberg_installed n'existe pas).
#  Étapes :
#    1. Confirmation d'installation (non => arrêt)
#    2. Choix du type de service (Web / Bot Discord / API / Autre)
#    3. Choix de la version Node.js (liste paginée, curatée)
#    4. Confirmation finale (non => arrêt)
#    5. Génération des fichiers par défaut + écriture du marqueur
# =============================================================================

R="\e[0m"; B="\e[1m"; RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"; CYN="\e[36m"

VERSIONS_FILE="/usr/local/share/neoheberg/versions.txt"
MARKER="/home/container/.neoheberg_installed"

echo -e "${CYN}${B}Bienvenue sur NeoHeberg Node.js !${R}"
echo "Une configuration initiale est nécessaire avant le premier démarrage."
echo ""

# --- Étape 1 : confirmation d'installation -----------------------------------
while true; do
    read -r -p "Souhaitez-vous procéder à l'installation du serveur ? [o/n] : " ANS
    case "${ANS,,}" in
        o|oui|y|yes) break ;;
        n|non|no)
            echo ""
            echo -e "${YLW}Installation annulée. Le serveur va s'arrêter.${R}"
            echo -e "${YLW}Redémarrez-le lorsque vous serez prêt.${R}"
            exit 1
            ;;
        *) echo -e "${RED}Répondez par 'o' (oui) ou 'n' (non).${R}" ;;
    esac
done

# --- Étape 2 : type de service ----------------------------------------------
echo ""
echo -e "${CYN}Quel type de service souhaitez-vous héberger ?${R}"
echo "  1) Site web"
echo "  2) Bot Discord"
echo "  3) API REST"
echo "  4) Autre / projet déjà prêt"
while true; do
    read -r -p "Votre choix [1-4] : " TYPE
    case "$TYPE" in
        1) SERVICE_TYPE="web";     SERVICE_LABEL="Site web" ;;
        2) SERVICE_TYPE="discord"; SERVICE_LABEL="Bot Discord" ;;
        3) SERVICE_TYPE="api";     SERVICE_LABEL="API REST" ;;
        4) SERVICE_TYPE="other";   SERVICE_LABEL="Autre / projet prêt" ;;
        *) echo -e "${RED}Choix invalide.${R}"; continue ;;
    esac
    break
done

# --- Étape 3 : version Node (liste paginée) ----------------------------------
mapfile -t VERSIONS < <(tr -d '\r' < "$VERSIONS_FILE" | grep -vE '^\s*(#|$)')
TOTAL="${#VERSIONS[@]}"
if [[ "$TOTAL" -eq 0 ]]; then
    echo -e "${RED}ERREUR : aucune version de Node disponible dans $VERSIONS_FILE.${R}"
    exit 1
fi

PER_PAGE=10
PAGE=1
PAGES=$(( (TOTAL + PER_PAGE - 1) / PER_PAGE ))

while true; do
    START=$(( (PAGE - 1) * PER_PAGE ))
    END=$(( START + PER_PAGE - 1 ))
    [[ "$END" -ge "$TOTAL" ]] && END=$(( TOTAL - 1 ))

    echo ""
    echo -e "${CYN}Choisissez la version de Node.js (page ${PAGE}/${PAGES}) :${R}"
    for ((i=START; i<=END; i++)); do
        LINE="${VERSIONS[$i]}"
        VER="${LINE%%|*}"
        LABEL="${LINE#*|}"
        [[ "$LABEL" == "$LINE" ]] && LABEL=""
        printf "  %3d) %-9s  %s\n" "$((i+1))" "$VER" "${LABEL:+[${LABEL}]}"
    done
    echo ""
    echo -e "  ${B}n${R}) page suivante    ${B}p${R}) page précédente    ${B}q${R}) annuler"
    read -r -p "Votre choix : " CHOICE

    case "${CHOICE,,}" in
        n|next)
            if [[ "$PAGE" -lt "$PAGES" ]]; then PAGE=$((PAGE+1)); else echo -e "${YLW}Déjà sur la dernière page.${R}"; fi
            ;;
        p|prev)
            if [[ "$PAGE" -gt 1 ]]; then PAGE=$((PAGE-1)); else echo -e "${YLW}Déjà sur la première page.${R}"; fi
            ;;
        q|quit)
            echo -e "${YLW}Installation annulée. Le serveur va s'arrêter.${R}"
            exit 1
            ;;
        ''|*[!0-9]*)
            echo -e "${RED}Choix invalide.${R}"
            ;;
        *)
            IDX=$(( CHOICE - 1 ))
            if [[ "$IDX" -ge 0 && "$IDX" -lt "$TOTAL" ]]; then
                NODE_VERSION="${VERSIONS[$IDX]%%|*}"
                break
            fi
            echo -e "${RED}Choix invalide.${R}"
            ;;
    esac
done

# --- Étape 4 : confirmation --------------------------------------------------
echo ""
echo -e "${B}=== Récapitulatif ===${R}"
echo "  Type de service : ${SERVICE_LABEL}"
echo "  Version Node.js : ${NODE_VERSION}"
echo ""
while true; do
    read -r -p "Confirmer l'installation ? [o/n] : " CONFIRM
    case "${CONFIRM,,}" in
        o|oui|y|yes) break ;;
        n|non|no)
            echo ""
            echo -e "${YLW}Installation annulée. Le serveur va s'arrêter.${R}"
            echo -e "${YLW}Aucun fichier n'a été modifié. Redémarrez pour recommencer.${R}"
            exit 1
            ;;
        *) echo -e "${RED}Répondez par 'o' (oui) ou 'n' (non).${R}" ;;
    esac
done

# --- Étape 5 : génération des fichiers par défaut (si absents) ---------------
cd /home/container

if [[ ! -f package.json ]]; then
    case "$SERVICE_TYPE" in
        discord)
            cat > package.json <<'EOF'
{
  "name": "neoheberg-bot",
  "version": "1.0.0",
  "private": true,
  "main": "index.js",
  "scripts": { "start": "node index.js" },
  "dependencies": { "discord.js": "^14.14.1" }
}
EOF
            ;;
        *)
            cat > package.json <<'EOF'
{
  "name": "neoheberg-app",
  "version": "1.0.0",
  "private": true,
  "main": "index.js",
  "scripts": { "start": "node index.js" }
}
EOF
            ;;
    esac
fi

if [[ ! -f index.js ]]; then
    case "$SERVICE_TYPE" in
        web)
            cat > index.js <<'EOF'
const http = require('http');
const port = Number(process.env.SERVER_PORT) || 3000;
http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Bienvenue sur votre serveur NeoHeberg Node.js\n');
}).listen(port, '0.0.0.0', () => {
  console.log(`Serveur web démarré sur le port ${port}`);
});
EOF
            ;;
        api)
            cat > index.js <<'EOF'
const http = require('http');
const port = Number(process.env.SERVER_PORT) || 3000;
http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify({ status: 'ok', service: 'NeoHeberg API' }));
}).listen(port, '0.0.0.0', () => {
  console.log(`API démarrée sur le port ${port}`);
});
EOF
            ;;
        discord)
            cat > index.js <<'EOF'
const { Client, GatewayIntentBits } = require('discord.js');
const token = process.env.DISCORD_TOKEN;
if (!token) {
  console.error('Erreur : variable DISCORD_TOKEN non définie (onglet Variables).');
  process.exit(1);
}
const client = new Client({ intents: [GatewayIntentBits.Guilds] });
client.once('ready', () => {
  console.log(`Bot Discord prêt · connecté en tant que ${client.user.tag}`);
});
client.login(token);
EOF
            ;;
        other)
            cat > index.js <<'EOF'
console.log('NeoHeberg Node.js — projet vide. Ajoutez votre code puis redémarrez.');
EOF
            ;;
    esac
fi

# --- Écriture du marqueur de configuration ----------------------------------
{
    echo "NODE_VERSION=${NODE_VERSION}"
    echo "SERVICE_TYPE=${SERVICE_TYPE}"
    echo "SERVICE_LABEL=${SERVICE_LABEL}"
    echo "INSTALLED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
} > "$MARKER"

echo ""
echo -e "${GRN}Configuration enregistrée. Lancement de l'installation...${R}"
