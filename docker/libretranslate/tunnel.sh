#!/usr/bin/env bash
# =============================================================================
#  NeoHeberg · Egg LibreTranslate — Cloudflare Tunnel (cloudflared)
#  ---------------------------------------------------------------------------
#  Fichier SOURCÉ par start.sh (ne pas exécuter directement).
#
#  - Le binaire cloudflared vit dans le volume persistant
#    ($HOME/.neoheberg/bin/cloudflared) : le rootfs du conteneur est en
#    lecture seule, c'est le seul endroit où il peut être remplacé.
#    Au premier démarrage, il est initialisé depuis la copie de l'image.
#
#  - Mise à jour automatique : au démarrage du tunnel puis toutes les
#    CF_UPDATE_INTERVAL heures, la dernière release GitHub est comparée à la
#    version installée. Si elle diffère :
#      1. téléchargement dans un fichier temporaire ;
#      2. vérification de l'empreinte SHA-256 publiée par GitHub (obligatoire :
#         sans empreinte, la mise à jour est reportée) ;
#      3. vérification de `cloudflared --version` ;
#      4. remplacement atomique (mv) puis redémarrage du tunnel SEUL
#         (LibreTranslate n'est pas interrompu).
#
#    L'auto-update intégré de cloudflared n'est pas utilisé (--no-autoupdate) :
#    il est désactivé quand cloudflared tourne dans un TTY, ce qui est le cas
#    sous Pterodactyl.
#
#  - Signaux reçus par le superviseur (envoyés par les commandes console) :
#      USR1 -> vérifier / appliquer une mise à jour maintenant
#      USR2 -> redémarrer le tunnel
#      TERM -> arrêter le tunnel et quitter
# =============================================================================

CF_REPO="cloudflare/cloudflared"
CF_BIN_DIR="${HOME}/.neoheberg/bin"
CF_BIN="${CF_BIN_DIR}/cloudflared"
CF_IMAGE_BIN="/usr/local/bin/cloudflared"

cf_log()  { echo -e "\e[36m[tunnel]\e[0m $*"; }
cf_warn() { echo -e "\e[33m[tunnel]\e[0m $*"; }
cf_err()  { echo -e "\e[31m[tunnel]\e[0m $*"; }

# Nom de l'asset GitHub correspondant à l'architecture.
cf_asset_name() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "cloudflared-linux-amd64" ;;
        aarch64|arm64) echo "cloudflared-linux-arm64" ;;
        armv7l|armv7)  echo "cloudflared-linux-arm" ;;
        i386|i686)     echo "cloudflared-linux-386" ;;
        *) return 1 ;;
    esac
}

# "cloudflared version 2026.11.0 (built ...)" -> "2026.11.0"
cf_version_of() {
    "$1" --version 2>/dev/null | awk '{print $3}'
}

# Dernière version publiée. On lit la redirection de /releases/latest plutôt
# que l'API GitHub : pas de limite de requêtes (60/h par IP sur l'API).
cf_latest_version() {
    local url ver
    url="$(curl -fsSI --max-time 20 -o /dev/null -w '%{redirect_url}' \
        "https://github.com/${CF_REPO}/releases/latest" 2>/dev/null)" || return 1
    ver="${url##*/tag/}"
    [[ "$ver" =~ ^[0-9]{4}\.[0-9]+\.[0-9]+$ ]] || return 1
    echo "$ver"
}

# Installe le binaire de l'image dans le volume s'il n'y est pas encore.
cf_ensure_binary() {
    mkdir -p "$CF_BIN_DIR"
    if [[ ! -x "$CF_BIN" ]]; then
        if [[ ! -x "$CF_IMAGE_BIN" ]]; then
            cf_err "cloudflared introuvable dans l'image ($CF_IMAGE_BIN)."
            return 1
        fi
        cp "$CF_IMAGE_BIN" "$CF_BIN" && chmod +x "$CF_BIN" || return 1
        cf_log "cloudflared $(cf_version_of "$CF_BIN") initialisé depuis l'image."
    fi
}

# Télécharge, vérifie puis installe la version $1.
cf_install_version() {
    local ver="$1" asset tmp expected actual got
    asset="$(cf_asset_name)" || { cf_err "Architecture non supportée : $(uname -m)"; return 1; }

    tmp="$(mktemp "${CF_BIN}.new.XXXXXX")" || return 1
    cf_log "Téléchargement de cloudflared ${ver} (${asset})..."
    if ! curl -fsSL --max-time 300 \
            "https://github.com/${CF_REPO}/releases/download/${ver}/${asset}" -o "$tmp"; then
        cf_err "Échec du téléchargement — nouvel essai au prochain contrôle."
        rm -f "$tmp"; return 1
    fi

    # Empreinte SHA-256 publiée par GitHub pour l'asset (champ `digest`).
    expected="$(curl -fsS --max-time 20 -H 'Accept: application/vnd.github+json' \
            "https://api.github.com/repos/${CF_REPO}/releases/tags/${ver}" 2>/dev/null \
        | jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .digest // empty' 2>/dev/null)"
    if [[ "$expected" != sha256:* ]]; then
        cf_warn "Empreinte SHA-256 indisponible (limite de l'API GitHub ?) — mise à jour reportée."
        rm -f "$tmp"; return 1
    fi
    actual="sha256:$(sha256sum "$tmp" | cut -d' ' -f1)"
    if [[ "$actual" != "$expected" ]]; then
        cf_err "Empreinte SHA-256 invalide (attendu ${expected}, obtenu ${actual}) — mise à jour annulée."
        rm -f "$tmp"; return 1
    fi

    chmod +x "$tmp"
    got="$(cf_version_of "$tmp")"
    if [[ "$got" != "$ver" ]]; then
        cf_err "Le binaire téléchargé annonce la version « ${got} » au lieu de ${ver} — mise à jour annulée."
        rm -f "$tmp"; return 1
    fi

    # mv sur le même système de fichiers = remplacement atomique (le processus
    # en cours garde l'ancien inode jusqu'à son redémarrage).
    mv -f "$tmp" "$CF_BIN"
    cf_log "cloudflared mis à jour en ${ver}."
}

# Retourne 0 si une NOUVELLE version a été installée (=> redémarrage requis).
cf_update_check() {
    local latest current
    current="$(cf_version_of "$CF_BIN")"
    if ! latest="$(cf_latest_version)"; then
        cf_warn "Impossible de récupérer la dernière version de cloudflared — nouvel essai plus tard."
        return 1
    fi
    if [[ "$latest" == "$current" ]]; then
        cf_log "cloudflared ${current} est à jour."
        return 1
    fi
    cf_log "Nouvelle version disponible : ${current:-?} -> ${latest}"
    cf_install_version "$latest"
}

# Lance cloudflared en arrière-plan ; écrit son PID dans CF_PID.
cf_launch() {
    local target="http://127.0.0.1:${SERVER_PORT}"
    local -a args=(tunnel --no-autoupdate --grace-period 10s)

    case "$CF_TUNNEL_MODE" in
        token)
            # Le token passe par l'environnement (TUNNEL_TOKEN) et non par la
            # ligne de commande, pour ne pas apparaître dans `ps`.
            args+=(run)
            TUNNEL_TOKEN="$CF_TUNNEL_TOKEN" "$CF_BIN" "${args[@]}" \
                > >(sed -u 's/^/\x1b[36m[tunnel]\x1b[0m /') 2>&1 &
            ;;
        quick)
            args+=(--url "$target")
            "$CF_BIN" "${args[@]}" \
                > >(sed -u 's/^/\x1b[36m[tunnel]\x1b[0m /') 2>&1 &
            ;;
    esac
    CF_PID=$!
    cf_log "Tunnel démarré (mode ${CF_TUNNEL_MODE}, cloudflared $(cf_version_of "$CF_BIN"), cible ${target})."
}

# Attend la fin du processus $1 même si `wait` est interrompu par un signal.
cf_wait_pid() {
    local pid="$1" rc=0
    while kill -0 "$pid" 2>/dev/null; do
        wait "$pid"; rc=$?
    done
    return "$rc"
}

# Boucle de supervision (lancée en arrière-plan par start.sh).
cf_supervisor() {
    local stopping=0 force_check=0 restart=0 planned=0
    local now next_check=0 started_at rc backoff=10
    local interval=$(( ${CF_UPDATE_INTERVAL:-24} * 3600 ))
    (( interval < 3600 )) && interval=3600
    CF_PID=""

    trap 'stopping=1; [[ -n "$CF_PID" ]] && kill -TERM "$CF_PID" 2>/dev/null' TERM
    trap 'force_check=1' USR1
    trap 'restart=1' USR2

    while (( ! stopping )); do
        # Contrôle de mise à jour AVANT le lancement : le premier démarrage
        # utilise directement la dernière version.
        now="$(date +%s)"
        if [[ "$CF_AUTOUPDATE" == "true" ]] && (( now >= next_check )); then
            cf_update_check
            next_check=$(( now + interval ))
        fi

        cf_launch
        started_at="$(date +%s)"
        planned=0

        while kill -0 "$CF_PID" 2>/dev/null; do
            sleep 15 & wait $!
            (( stopping )) && break

            if (( restart )); then
                restart=0; planned=1
                cf_log "Redémarrage du tunnel demandé."
                kill -TERM "$CF_PID" 2>/dev/null
                break
            fi

            now="$(date +%s)"
            if (( force_check )) || { [[ "$CF_AUTOUPDATE" == "true" ]] && (( now >= next_check )); }; then
                force_check=0
                next_check=$(( now + interval ))
                if cf_update_check; then
                    planned=1
                    cf_log "Redémarrage du tunnel sur la nouvelle version..."
                    kill -TERM "$CF_PID" 2>/dev/null
                    break
                fi
            fi
        done

        cf_wait_pid "$CF_PID"; rc=$?
        CF_PID=""
        (( stopping )) && break
        (( planned )) && { backoff=10; continue; }

        # Arrêt inattendu : relance avec un délai croissant (10 s -> 5 min)
        # pour éviter de spammer la console (ex : token invalide).
        (( $(date +%s) - started_at > 120 )) && backoff=10
        cf_warn "cloudflared s'est arrêté (code ${rc}). Nouvelle tentative dans ${backoff} s."
        sleep "$backoff" & wait $!
        backoff=$(( backoff * 2 )); (( backoff > 300 )) && backoff=300
    done

    [[ -n "$CF_PID" ]] && cf_wait_pid "$CF_PID"
    cf_log "Tunnel arrêté."
    exit 0
}
