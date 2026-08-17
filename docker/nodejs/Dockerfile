# =============================================================================
# NeoHeberg · Egg Node.js — image runtime
# -----------------------------------------------------------------------------
# Base Debian bookworm-slim (glibc).
#
# Pourquoi PAS Alpine ? Les binaires Node.js officiels distribués sur
# nodejs.org/dist sont compilés en glibc (il n'existe pas de build musl
# officiel pour linux-x64), et fnm ne fournit lui aussi qu'un binaire glibc.
# Alpine (musl) ne peut donc pas les exécuter. Debian slim reste léger tout en
# étant compatible avec toutes les versions Node officielles (12.x → 24.x).
#
# La version de Node n'est PAS figée dans l'image : elle est installée à la
# demande via fnm dans le volume persistant (/home/container/.fnm).
# =============================================================================

FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/NeoHeberg/Eggs-Pterodactyl"
LABEL org.opencontainers.image.description="Runtime Node.js NeoHeberg - versions a la demande via fnm"

ENV FNM_DIR=/home/container/.fnm \
    FNM_VERSION_FILE_STRATEGY=local \
    DEBIAN_FRONTEND=noninteractive

# Dépendances runtime :
#   bash          -> entrypoint / scripts
#   curl          -> téléchargement fnm + Node
#   ca-certificates -> HTTPS
#   git           -> dépendances npm depuis git
#   unzip         -> extraction du binaire fnm
#   xz-utils      -> extraction des tarballs Node (.tar.xz)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        curl \
        ca-certificates \
        git \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# fnm (Fast Node Manager) — binaire glibc x64, version épinglée.
ARG FNM_VERSION=1.39.0
RUN curl -fsSL "https://github.com/Schniz/fnm/releases/download/v${FNM_VERSION}/fnm-linux.zip" \
        -o /tmp/fnm.zip \
    && unzip -o /tmp/fnm.zip fnm -d /usr/local/bin \
    && chmod +x /usr/local/bin/fnm \
    && rm -f /tmp/fnm.zip \
    && fnm --version

# Scripts NeoHeberg
RUN mkdir -p /usr/local/share/neoheberg
COPY versions.txt /usr/local/share/neoheberg/versions.txt
COPY setup.sh /usr/local/share/neoheberg/setup.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/share/neoheberg/setup.sh /entrypoint.sh

# Optionnel : décommenter pour supporter les modules npm natifs (node-gyp).
# Attention : cela alourdit nettement l'image (python3 + make + g++).
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends python3 make g++ \
#     && rm -rf /var/lib/apt/lists/*

WORKDIR /home/container
