#!/usr/bin/env bash
set -e

# =============================================================================
#  NeoHeberg · Egg Node.js — ENTRYPOINT de l'image (installation + démarrage)
#  ---------------------------------------------------------------------------
#  Pterodactyl appelle cet ENTRYPOINT de deux façons :
#
#  1. INSTALLATION : il passe la commande d'installation en arguments
#     (ex: "bash /mnt/install/install.sh"). On les exécute donc tels quels.
#
#  2. DÉMARRAGE : aucun argument ; la commande de démarrage est fournie via la
#     variable d'environnement STARTUP. On l'exécute.
#
#  C'est le mécanisme standard des images officielles "yolks".
# =============================================================================

# Cas installation : des arguments sont passés.
if [[ $# -gt 0 ]]; then
    exec "$@"
fi

# Cas démarrage : exécuter la commande STARTUP.
cd /home/container 2>/dev/null || true
if [[ -n "${STARTUP:-}" ]]; then
    exec bash -c "$STARTUP"
fi

# Fallback (ne devrait jamais arriver).
exec bash
