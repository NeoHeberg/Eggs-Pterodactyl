#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
#  NeoHeberg · Egg Node.js — entrypoint
#  ---------------------------------------------------------------------------
#  - Premier démarrage   : lance le setup interactif (type de service + version
#                          Node) puis installe la version choisie.
#  - Démarrages suivants : relit la configuration depuis le marqueur
#                          .neoheberg_installed et lance l'application.
#
#  La version de Node est gérée par fnm et installée dans le volume persistant
#  (/home/container/.fnm), donc elle survit aux redémarrages.
#
#  Ce script est copié dans le volume (/home/container/.neoheberg) au moment de
#  l'installation ; on résout donc les chemins par rapport à sa propre position.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HOME="${HOME:-/home/container}"
export FNM_DIR="${FNM_DIR:-/home/container/.fnm}"
export FNM_VERSION_FILE_STRATEGY="local"
export PATH="/usr/local/bin:${FNM_DIR}:${PATH}"

cd /home/container

MARKER="/home/container/.neoheberg_installed"

# fnm doit être présent, sinon l'image est incomplète.
if ! command -v fnm >/dev/null 2>&1; then
    echo "ERREUR : fnm est introuvable. L'image Docker est incomplète."
    exit 1
fi

# --- Setup interactif (premier démarrage uniquement) ---
if [[ ! -f "$MARKER" ]]; then
    echo ""
    echo "=================================================="
    echo "        NeoHeberg · Node.js — Premier lancement"
    echo "=================================================="
    echo ""
    bash "$SCRIPT_DIR/setup.sh"
fi

# --- Lecture de la configuration ---
NODE_VERSION="$(grep -E '^NODE_VERSION=' "$MARKER" | head -n1 | cut -d= -f2- | tr -d '[:space:]')"
if [[ -z "$NODE_VERSION" ]]; then
    echo "ERREUR : version Node introuvable dans $MARKER."
    echo "Supprimez le fichier .neoheberg_installed puis redémarrez le serveur."
    exit 1
fi

# --- Installation de la version (idempotent) ---
if ! fnm list 2>/dev/null | grep -qwE "v?${NODE_VERSION#v}"; then
    echo ""
    echo ">>> Installation de Node.js ${NODE_VERSION} (téléchargement, première fois)..."
    fnm install "${NODE_VERSION}"
fi

fnm use "${NODE_VERSION}"
eval "$(fnm env)"

echo ""
echo ">>> Node.js : $(node --version) · npm : $(npm --version)"

# --- Dépendances npm (si package.json présent et node_modules absent) ---
if [[ -f package.json && ! -d node_modules ]]; then
    echo ">>> Installation des dépendances npm..."
    npm install
fi

# --- Lancement de l'application ---
cd /home/container

# 1) Commande personnalisée (variable STARTUP_CMD).
if [[ -n "${STARTUP_CMD:-}" ]]; then
    exec bash -c "$STARTUP_CMD"
fi

# 2) Sinon : script "start" du package.json.
if [[ -f package.json ]] \
    && node -e "const p=require('./package.json');process.exit(p.scripts&&p.scripts.start?0:1)" 2>/dev/null; then
    exec npm start
fi

# 3) Sinon : fichier principal (variable MAIN_FILE).
exec node "${MAIN_FILE:-index.js}"
