"""
NeoHeberg · Egg LibreTranslate — lanceur de LibreTranslate
-----------------------------------------------------------
Lance LibreTranslate exactement comme la commande `libretranslate`, mais en
désactivant son installation automatique des modèles.

Pourquoi ? Au démarrage, LibreTranslate télécharge TOUS les modèles (~100,
plus de 10 Go) dès qu'il en trouve moins de 2 installés, ou toutes les paires
dans les deux sens avec --load-only. Les modèles sont gérés uniquement par
models.py (installation par direction : sources -> en -> cibles) : un seul
modèle installé (ex : en -> fr) doit rester une configuration valide.

Usage : python lt_run.py <arguments libretranslate...>
"""

import sys

import libretranslate.init as lt_init


def _no_model_install(*args, **kwargs):
    print("[modèles] Installation automatique de LibreTranslate désactivée (gérée par models.py).", flush=True)


# boot() résout check_and_install_models dans les globales du module au
# moment de l'appel : le remplacement suffit.
lt_init.check_and_install_models = _no_model_install

from libretranslate.main import main  # noqa: E402

if __name__ == "__main__":
    sys.argv[0] = "libretranslate"
    sys.exit(main())
