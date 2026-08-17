#!/usr/bin/env bash
set -e

# =============================================================================
#  NeoHeberg · Egg Node.js — ENTRYPOINT de l'image (runtime)
#  ---------------------------------------------------------------------------
#  Pterodactyl ne passe PAS la commande de démarrage en tant que CMD/Entrypoint
#  du conteneur : il la fournit via la variable d'environnement STARTUP.
#  C'est l'ENTRYPOINT de l'image qui est responsable de l'exécuter (mécanisme
#  standard des images officielles "yolks").
# =============================================================================

cd /home/container 2>/dev/null || true

if [[ -n "${STARTUP:-}" ]]; then
    exec bash -c "$STARTUP"
fi

# Fallback (ne devrait jamais arriver) : shell interactif.
exec bash
