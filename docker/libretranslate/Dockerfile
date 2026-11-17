# =============================================================================
# NeoHeberg · Egg LibreTranslate — image runtime
# -----------------------------------------------------------------------------
# - LibreTranslate (API de traduction libre, https://libretranslate.com)
#   installé depuis PyPI dans un venv figé dans l'image (/opt/libretranslate).
#   Depuis la 1.9.x, LibreTranslate n'utilise plus torch (ctranslate2 +
#   onnxruntime) : l'image reste raisonnable (~ 600 Mo).
# - cloudflared (Cloudflare Tunnel) : une copie de secours est embarquée dans
#   l'image (/usr/local/bin/cloudflared). Au démarrage, elle est copiée dans
#   le volume persistant puis mise à jour automatiquement depuis GitHub
#   (le rootfs du conteneur Pterodactyl est en lecture seule).
#
# Les modèles de langue ne sont PAS dans l'image : ils sont téléchargés au
# premier démarrage dans le volume (/home/container/.local/share/argos-translate)
# par models.py, selon les langues source / cible choisies dans le panel.
# =============================================================================

# -----------------------------------------------------------------------------
# Étape 1 : build du venv (compilateurs nécessaires pour certaines dépendances)
# -----------------------------------------------------------------------------
FROM python:3.11-slim-bookworm AS builder

ARG LT_VERSION=1.9.6
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends pkg-config gcc g++ \
    && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/libretranslate/venv \
    && /opt/libretranslate/venv/bin/pip install --upgrade pip \
    && /opt/libretranslate/venv/bin/pip install "libretranslate==${LT_VERSION}" \
    && /opt/libretranslate/venv/bin/libretranslate --help >/dev/null

# -----------------------------------------------------------------------------
# Étape 2 : image runtime
# -----------------------------------------------------------------------------
FROM python:3.11-slim-bookworm

ARG LT_VERSION=1.9.6
ARG CLOUDFLARED_VERSION=2026.11.0
ARG TARGETARCH=amd64

LABEL org.opencontainers.image.source="https://github.com/NeoHeberg/Eggs-Pterodactyl"
LABEL org.opencontainers.image.description="Runtime LibreTranslate NeoHeberg + Cloudflare Tunnel (cloudflared auto-mis a jour)"
LABEL fr.neoheberg.libretranslate.version="${LT_VERSION}"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    ARGOS_CHUNK_TYPE=MINISBD

# Dépendances runtime :
#   bash            -> entrypoint / scripts
#   curl            -> téléchargement / mise à jour de cloudflared
#   ca-certificates -> HTTPS
#   jq              -> lecture de l'API GitHub (empreinte SHA-256 des releases)
#   libgomp1        -> OpenMP (ctranslate2 / onnxruntime)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        curl \
        ca-certificates \
        jq \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Utilisateur « container » (UID du conteneur Pterodactyl).
# Sans entrée /etc/passwd pour l'UID du conteneur, Path.home() (Python)
# peut résoudre vers / (rootfs en lecture seule) → erreurs.
# L'UID doit correspondre à celui utilisé par Wings : `id pterodactyl` sur
# l'hôte (valeur par défaut de Wings si non configuré : 988).
ARG PTERO_UID=988
RUN useradd -d /home/container -m -u ${PTERO_UID} container

# venv LibreTranslate
COPY --from=builder /opt/libretranslate /opt/libretranslate

# cloudflared — copie de secours (la version à jour vit dans le volume).
RUN curl -fsSL "https://github.com/cloudflare/cloudflared/releases/download/${CLOUDFLARED_VERSION}/cloudflared-linux-${TARGETARCH}" \
        -o /usr/local/bin/cloudflared \
    && chmod +x /usr/local/bin/cloudflared \
    && cloudflared --version

# Scripts NeoHeberg
RUN mkdir -p /usr/local/share/neoheberg/libretranslate
COPY start.sh tunnel.sh models.py /usr/local/share/neoheberg/libretranslate/
RUN chmod +x /usr/local/share/neoheberg/libretranslate/*.sh

# ENTRYPOINT : exécute la commande de démarrage fournie par Pterodactyl via
# la variable d'environnement STARTUP (mécanisme des images officielles yolks).
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Pas de `USER` ici : Wings impose lui-même l'UID au démarrage du serveur, et
# le script d'installation doit pouvoir s'exécuter en root (comme l'egg Node.js).
ENV HOME=/home/container
WORKDIR /home/container
