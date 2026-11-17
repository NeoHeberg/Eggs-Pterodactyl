#!/usr/bin/env bash
# Pas de `set -e` : ce script est le superviseur (PID 1) du conteneur et doit
# survivre aux erreurs des commandes console.
set -uo pipefail

# =============================================================================
#  NeoHeberg · Egg LibreTranslate — start.sh (script de démarrage)
#  ---------------------------------------------------------------------------
#  - Lance LibreTranslate (serveur waitress) sur le port alloué par Pterodactyl.
#    Les modèles de langue sont téléchargés au premier démarrage dans le volume.
#  - Lance (optionnellement) un Cloudflare Tunnel supervisé et auto-mis à jour
#    (voir tunnel.sh).
#  - Lit la console Pterodactyl pour quelques commandes utiles
#    (gestion des clés API, tunnel) : tapez « help ».
#
#  Ce script est copié dans le volume (/home/container/.neoheberg) au moment de
#  l'installation ; on résout donc les chemins par rapport à sa propre position.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export HOME="/home/container"
export PYTHONUNBUFFERED=1
export ARGOS_CHUNK_TYPE="${ARGOS_CHUNK_TYPE:-MINISBD}"

LT_VENV="/opt/libretranslate/venv"
API_KEYS_DB="/home/container/db/api_keys.db"

R=$'\e[0m'; B=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; CYN=$'\e[36m'

log()  { echo -e "${CYN}[neoheberg]${R} $*"; }
warn() { echo -e "${YLW}[neoheberg]${R} $*"; }
err()  { echo -e "${RED}[neoheberg]${R} $*"; }

# Normalise un booléen de variable Pterodactyl -> true / false.
bool() {
    case "${1,,}" in
        1|true|yes|oui|on) echo true ;;
        *) echo false ;;
    esac
}

cd /home/container
mkdir -p db

if [[ ! -x "${LT_VENV}/bin/libretranslate" ]]; then
    err "LibreTranslate est introuvable dans l'image (${LT_VENV}). L'image Docker est incomplète."
    exit 1
fi

# --- Variables du panel ------------------------------------------------------
SERVER_PORT="${SERVER_PORT:-5000}"
LANGUAGES="$(echo "${LANGUAGES:-}" | tr -d '[:space:]')"
THREADS="${THREADS:-4}"
CHAR_LIMIT="${CHAR_LIMIT:--1}"
REQ_LIMIT="${REQ_LIMIT:--1}"
API_KEYS="$(bool "${API_KEYS:-false}")"
WEB_UI="$(bool "${WEB_UI:-true}")"
UPDATE_MODELS="$(bool "${UPDATE_MODELS:-false}")"
EXTRA_ARGS="${EXTRA_ARGS:-}"

CF_TUNNEL_MODE="${CF_TUNNEL_MODE:-off}"
CF_TUNNEL_TOKEN="$(echo "${CF_TUNNEL_TOKEN:-}" | tr -d '[:space:]')"
CF_AUTOUPDATE="$(bool "${CF_AUTOUPDATE:-true}")"
CF_UPDATE_INTERVAL="${CF_UPDATE_INTERVAL:-24}"
[[ "$CF_UPDATE_INTERVAL" =~ ^[0-9]+$ ]] || CF_UPDATE_INTERVAL=24
export SERVER_PORT CF_TUNNEL_MODE CF_TUNNEL_TOKEN CF_AUTOUPDATE CF_UPDATE_INTERVAL

# --- En-tête -----------------------------------------------------------------
LT_VERSION="$("${LT_VENV}/bin/pip" show libretranslate 2>/dev/null | awk '/^Version:/{print $2}')"
echo ""
echo -e "  ${CYN}${B}NeoHeberg · LibreTranslate${R} ${DIM}v${LT_VERSION:-?}${R}"
echo -e "  ${DIM}─────────────────────────────────────────${R}"
echo -e "  Port        : ${SERVER_PORT}"
echo -e "  Langues     : ${LANGUAGES:-toutes ${YLW}(plusieurs Go de modèles !)${R}}"
echo -e "  Clés API    : ${API_KEYS}"
echo -e "  Tunnel CF   : ${CF_TUNNEL_MODE}$( [[ "$CF_TUNNEL_MODE" != off ]] && echo " (auto-update : ${CF_AUTOUPDATE})")"
echo -e "  ${DIM}Tapez « help » dans la console pour la liste des commandes.${R}"
echo ""

# --- Arguments LibreTranslate ------------------------------------------------
LT_ARGS=(--host 0.0.0.0 --port "$SERVER_PORT" --threads "$THREADS"
         --char-limit "$CHAR_LIMIT" --req-limit "$REQ_LIMIT")
[[ -n "$LANGUAGES" ]]          && LT_ARGS+=(--load-only "$LANGUAGES")
[[ "$API_KEYS" == true ]]      && LT_ARGS+=(--api-keys --api-keys-db-path "$API_KEYS_DB")
[[ "$WEB_UI" == false ]]       && LT_ARGS+=(--disable-web-ui)
[[ "$UPDATE_MODELS" == true ]] && LT_ARGS+=(--update-models)
if [[ -n "$EXTRA_ARGS" ]]; then
    read -r -a EXTRA <<< "$EXTRA_ARGS"
    LT_ARGS+=("${EXTRA[@]}")
fi

if [[ ! -d "${HOME}/.local/share/argos-translate/packages" ]]; then
    log "Premier démarrage : téléchargement des modèles de langue, cela peut prendre plusieurs minutes..."
fi

# --- Cloudflare Tunnel -------------------------------------------------------
CF_SUP_PID=""
# shellcheck source=tunnel.sh
source "${SCRIPT_DIR}/tunnel.sh"

case "$CF_TUNNEL_MODE" in
    off) ;;
    token|quick)
        if [[ "$CF_TUNNEL_MODE" == token && -z "$CF_TUNNEL_TOKEN" ]]; then
            warn "Mode tunnel « token » mais aucun token renseigné (variable CF_TUNNEL_TOKEN) — tunnel désactivé."
        elif cf_ensure_binary; then
            if [[ "$CF_TUNNEL_MODE" == quick ]]; then
                warn "Tunnel rapide (trycloudflare.com) : URL aléatoire qui change à chaque redémarrage, réservé aux tests."
            fi
            cf_supervisor &
            CF_SUP_PID=$!
        else
            err "Impossible d'initialiser cloudflared — tunnel désactivé."
        fi
        ;;
    *) warn "Mode tunnel inconnu « ${CF_TUNNEL_MODE} » (attendu : off, token, quick) — tunnel désactivé." ;;
esac

# --- LibreTranslate ----------------------------------------------------------
"${LT_VENV}/bin/libretranslate" "${LT_ARGS[@]}" &
LT_PID=$!

# --- Arrêt propre (^C envoyé par le panel / SIGTERM de Docker) ---------------
# Les processus lancés en arrière-plan ignorent SIGINT (shell non interactif) :
# on leur transmet donc SIGTERM.
STOPPING=0
shutdown() {
    (( STOPPING )) && return
    STOPPING=1
    echo ""
    log "Arrêt en cours..."
    [[ -n "$CF_SUP_PID" ]] && kill -TERM "$CF_SUP_PID" 2>/dev/null
    kill -TERM "$LT_PID" 2>/dev/null
}
trap shutdown INT TERM

# --- Commandes console -------------------------------------------------------
ltmanage() {
    if [[ "$API_KEYS" != true ]]; then
        warn "Les clés API sont désactivées (variable « Clés API » du panel)."
        return
    fi
    if [[ ! -f "$API_KEYS_DB" ]]; then
        warn "Base des clés API pas encore créée — attendez la fin du démarrage de LibreTranslate."
        return
    fi
    "${LT_VENV}/bin/ltmanage" keys --api-keys-db-path "$API_KEYS_DB" "$@"
}

tunnel_signal() {
    if [[ -z "$CF_SUP_PID" ]] || ! kill -0 "$CF_SUP_PID" 2>/dev/null; then
        warn "Le tunnel Cloudflare n'est pas actif."
        return 1
    fi
    kill "-$1" "$CF_SUP_PID"
}

print_help() {
    echo -e "${B}Commandes disponibles :${R}"
    echo "  help                          Affiche cette aide"
    echo "  keys                          Liste les clés API"
    echo "  keys add <req/min> [chars]    Crée une clé API (limite de requêtes/min, limite de caractères optionnelle)"
    echo "  keys remove <clé>             Supprime une clé API"
    echo "  tunnel                        État du tunnel Cloudflare"
    echo "  tunnel update                 Vérifie / installe maintenant la dernière version de cloudflared"
    echo "  tunnel restart                Redémarre le tunnel"
    echo "  stop                          Arrête le serveur"
}

handle_command() {
    local -a w
    read -r -a w <<< "$1"
    [[ ${#w[@]} -eq 0 ]] && return
    case "${w[0],,}" in
        help|aide|\?) print_help ;;
        keys|key|cles|clés)
            case "${w[1]:-}" in
                "") ltmanage ;;
                add)
                    if [[ ! "${w[2]:-}" =~ ^[0-9]+$ ]]; then
                        warn "Usage : keys add <requêtes/min> [limite de caractères]"; return
                    fi
                    if [[ -n "${w[3]:-}" ]]; then
                        [[ "${w[3]}" =~ ^[0-9]+$ ]] || { warn "La limite de caractères doit être un nombre."; return; }
                        ltmanage add "${w[2]}" --char-limit "${w[3]}"
                    else
                        ltmanage add "${w[2]}"
                    fi
                    ;;
                remove|rm|del|delete)
                    [[ -n "${w[2]:-}" ]] || { warn "Usage : keys remove <clé>"; return; }
                    ltmanage remove "${w[2]}"
                    ;;
                *) warn "Sous-commande inconnue. Tapez « help »." ;;
            esac
            ;;
        tunnel)
            case "${w[1]:-}" in
                "")
                    echo "  Mode        : ${CF_TUNNEL_MODE}"
                    echo "  Auto-update : ${CF_AUTOUPDATE} (toutes les ${CF_UPDATE_INTERVAL} h)"
                    if [[ -x "$CF_BIN" ]]; then
                        echo "  Version     : $(cf_version_of "$CF_BIN")"
                    fi
                    if [[ -n "$CF_SUP_PID" ]] && kill -0 "$CF_SUP_PID" 2>/dev/null; then
                        echo -e "  État        : ${GRN}actif${R}"
                    else
                        echo -e "  État        : ${DIM}inactif${R}"
                    fi
                    ;;
                update)  tunnel_signal USR1 && log "Vérification de mise à jour demandée (résultat sous ~15 s)." ;;
                restart) tunnel_signal USR2 && log "Redémarrage du tunnel demandé (sous ~15 s)." ;;
                *) warn "Sous-commande inconnue. Tapez « help »." ;;
            esac
            ;;
        stop|exit|quit) shutdown ;;
        *) warn "Commande inconnue « ${w[0]} ». Tapez « help »." ;;
    esac
}

# --- Boucle principale -------------------------------------------------------
# Tant que LibreTranslate tourne : lecture de la console (timeout 1 s pour
# surveiller l'état du processus). Si stdin est fermé, on se contente
# d'attendre.
STDIN_OPEN=1
while kill -0 "$LT_PID" 2>/dev/null; do
    if (( STDIN_OPEN && ! STOPPING )); then
        if IFS= read -r -t 1 LINE; then
            handle_command "${LINE%$'\r'}"
        elif (( $? <= 128 )); then
            STDIN_OPEN=0   # EOF (pas un timeout)
        fi
    else
        sleep 1 & wait $!
    fi
done

wait "$LT_PID" 2>/dev/null; LT_RC=$?
if (( ! STOPPING )); then
    err "LibreTranslate s'est arrêté de façon inattendue (code ${LT_RC})."
fi

# Arrêt du tunnel s'il tourne encore.
if [[ -n "$CF_SUP_PID" ]]; then
    kill -TERM "$CF_SUP_PID" 2>/dev/null
    wait "$CF_SUP_PID" 2>/dev/null
fi

if (( STOPPING )); then
    log "Serveur arrêté."
    exit 0
fi
exit "$LT_RC"
