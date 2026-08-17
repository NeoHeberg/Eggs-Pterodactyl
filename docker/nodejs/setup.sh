#!/usr/bin/env bash
# Pas de `set -e` ici : le script est interactif (lecture clavier via la
# console Pterodactyl) et gère lui-même les réponses invalides.
set -uo pipefail

# =============================================================================
#  NeoHeberg · Egg Node.js — setup interactif
#  Exécuté au premier démarrage (quand .neoheberg_installed n'existe pas).
# =============================================================================

R=$'\e[0m'; B=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYN=$'\e[36m'

# Copié dans le volume avec start.sh : on résout les chemins par rapport
# à la position du script (fonctionne aussi bien dans le volume que dans l'image).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSIONS_FILE="$SCRIPT_DIR/versions.txt"
MARKER="/home/container/.neoheberg_installed"

# Efface la console (séquence ANSI, pas besoin de `clear`/ncurses).
clear_screen() {
    printf '\033[2J\033[H'
}

cancel() {
    echo ""
    echo -e "${YLW}Installation annulée. Le serveur va s'arrêter.${R}"
    echo -e "${YLW}Redémarrez-le lorsque vous serez prêt.${R}"
    exit 1
}

# --- En-tête + description ---------------------------------------------------
clear_screen
echo -e "  ${CYN}${B}NeoHeberg · Node.js${R}"
echo -e "  ${DIM}─────────────────────────────────────────${R}"
echo ""
echo "Bienvenue ! Nous allons configurer votre serveur en 3 étapes :"
echo "  1. Le type de service (site web, bot Discord, API, autre) ;"
echo "  2. La version de Node.js ;"
echo "  3. Une confirmation avant l'installation."
echo ""
echo -e "${DIM}Vous pouvez annuler à tout moment : le serveur s'arrêtera et aucune${R}"
echo -e "${DIM}modification ne sera effectuée.${R}"
echo ""

# --- Étape 1 : confirmation d'installation -----------------------------------
clear_screen
echo -e "${CYN}${B}Étape 1/3 — Installation${R}"
echo ""
echo "Souhaitez-vous procéder à l'installation ? [o/n]"
echo ""
echo ""
echo -e "  ${DIM}c : annuler${R}"
while true; do
    read -r ANS
    case "${ANS,,}" in
        o|oui|y|yes) break ;;
        n|non|no) cancel ;;
        c|cancel|annuler) cancel ;;
        *) echo -e "${RED}Réponse invalide — « o » pour continuer, « n » ou « c » pour annuler.${R}" ;;
    esac
done

# --- Étape 2 : type de service ----------------------------------------------
clear_screen
echo -e "${CYN}${B}Étape 2/3 — Type de service${R}"
echo ""
echo "  1) Site web"
echo "  2) Bot Discord"
echo "  3) API REST"
echo "  4) Autre / projet déjà prêt"
echo ""
echo "Votre choix [1-4]"
echo ""
echo ""
echo -e "  ${DIM}c : annuler${R}"
while true; do
    read -r TYPE
    case "$TYPE" in
        1) SERVICE_TYPE="web";     SERVICE_LABEL="Site web" ;;
        2) SERVICE_TYPE="discord"; SERVICE_LABEL="Bot Discord" ;;
        3) SERVICE_TYPE="api";     SERVICE_LABEL="API REST" ;;
        4) SERVICE_TYPE="other";   SERVICE_LABEL="Autre / projet prêt" ;;
        c|cancel|annuler) cancel ;;
        *) echo -e "${RED}Choix invalide (1-4) — ou « c » pour annuler.${R}"; continue ;;
    esac
    break
done

# --- Étape 3 : version Node --------------------------------------------------
mapfile -t VERSIONS < <(tr -d '\r' < "$VERSIONS_FILE" | grep -vE '^\s*(#|$)')
TOTAL="${#VERSIONS[@]}"
if [[ "$TOTAL" -eq 0 ]]; then
    echo -e "${RED}ERREUR : aucune version de Node disponible dans $VERSIONS_FILE.${R}"
    exit 1
fi

clear_screen
echo -e "${CYN}${B}Étape 3/3 — Version de Node.js${R}"
echo ""
for ((i=0; i<TOTAL; i++)); do
    LINE="${VERSIONS[$i]}"
    VER="${LINE%%|*}"
    LABEL="${LINE#*|}"
    [[ "$LABEL" == "$LINE" ]] && LABEL=""
    printf "  %2d) %-9s  %s\n" "$((i+1))" "$VER" "${LABEL:+${DIM}[${LABEL}]${R}}"
done
echo ""
echo "Votre choix [1-${TOTAL}]"
echo ""
echo ""
echo -e "  ${DIM}c : annuler${R}"
while true; do
    read -r CHOICE
    case "$CHOICE" in
        c|cancel|annuler) cancel ;;
        ''|*[!0-9]*) echo -e "${RED}Choix invalide (1-${TOTAL}) — ou « c » pour annuler.${R}" ;;
        *)
            if [[ "$CHOICE" -ge 1 && "$CHOICE" -le "$TOTAL" ]]; then
                NODE_VERSION="${VERSIONS[$((CHOICE-1))]%%|*}"
                break
            fi
            echo -e "${RED}Choix invalide (1-${TOTAL}) — ou « c » pour annuler.${R}" ;;
    esac
done

# --- Étape 4 : confirmation --------------------------------------------------
clear_screen
echo -e "${B}Récapitulatif${R}"
echo ""
echo "  Type de service : ${SERVICE_LABEL}"
echo "  Version Node.js : ${NODE_VERSION}"
echo ""
echo "Confirmer l'installation ? [o/n]"
echo ""
echo ""
echo -e "  ${DIM}c : annuler${R}"
while true; do
    read -r CONFIRM
    case "${CONFIRM,,}" in
        o|oui|y|yes) break ;;
        n|non|no) cancel ;;
        c|cancel|annuler) cancel ;;
        *) echo -e "${RED}Réponse invalide — « o » pour confirmer, « n » ou « c » pour annuler.${R}" ;;
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
  console.log('⚠️  Variable DISCORD_TOKEN non définie (onglet Variables du panel).');
  console.log('Renseignez le token de votre bot puis redémarrez le serveur.');
  process.exit(0);
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
