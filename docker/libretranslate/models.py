"""
NeoHeberg · Egg LibreTranslate — installation des modèles de langue
--------------------------------------------------------------------
Exécuté par start.sh AVANT LibreTranslate, avec le Python du venv :

    python models.py <sources> <cibles> <update:true|false>

    <sources> : codes séparés par des virgules, ou « all »
    <cibles>  : codes séparés par des virgules (ex : fr)

Pourquoi ne pas utiliser --load-only de LibreTranslate ?
  --load-only installe toutes les paires entre les langues listées, dans les
  DEUX sens. Or presque tous les modèles Argos passent par l'anglais
  (X -> en, en -> X) : pour traduire « n'importe quelle langue -> français »,
  il suffit de X -> en (pour chaque source) + en -> fr. Ce script n'installe
  que les modèles utiles dans le bon sens (~2x moins de disque), LibreTranslate
  fait ensuite le pivot X -> en -> fr tout seul.

LibreTranslate ne réinstalle rien au démarrage tant qu'au moins 2 modèles sont
présents (sans --update-models) : il utilise donc exactement ce qui est
installé ici.

Le résultat est mémorisé dans ~/.neoheberg/models.conf : tant que la
configuration ne change pas (et sans mise à jour demandée), le script ne
contacte pas le réseau, ce qui garde un démarrage rapide.
"""

import os
import sys
from pathlib import Path

from argostranslate import package
from packaging import version

from libretranslate.language import iso2model

PIVOT = "en"
STATE_FILE = Path.home() / ".neoheberg" / "models.conf"


def log(msg):
    print(f"\x1b[35m[modèles]\x1b[0m {msg}", flush=True)


def parse_codes(value):
    codes = [c.strip() for c in value.split(",") if c.strip()]
    return [iso2model(c) for c in codes]


def wanted(pack, sources, targets):
    """Le modèle sert-il à traduire une source vers une cible ?"""
    src_ok = sources is None or pack.from_code in sources
    if pack.to_code in targets and (src_ok or pack.from_code == PIVOT):
        return True  # direct (source -> cible), ou en -> cible (pivot)
    if pack.to_code == PIVOT and src_ok and pack.from_code not in targets:
        return True  # source -> en (pivot)
    return False


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2

    sources_arg = sys.argv[1].strip().lower()
    targets = set(parse_codes(sys.argv[2]))
    update = sys.argv[3].strip().lower() == "true"

    if not targets:
        log("Aucune langue cible définie — rien à installer.")
        return 1

    sources = None if sources_arg in ("", "all", "*", "toutes") else set(parse_codes(sources_arg))
    config = f"sources={'all' if sources is None else ','.join(sorted(sources))};targets={','.join(sorted(targets))}"

    installed = package.get_installed_packages()
    previous = STATE_FILE.read_text().strip() if STATE_FILE.exists() else ""
    if previous == config and not update and len(installed) >= 2:
        log(f"{len(installed)} modèles installés, configuration inchangée.")
        return 0

    log("Récupération de l'index des modèles...")
    package.update_package_index()
    available = package.get_available_packages()

    known = {p.from_code for p in available} | {p.to_code for p in available}
    for label, codes in (("source", sources or set()), ("cible", targets)):
        unknown = sorted(codes - known)
        if unknown:
            log(f"\x1b[33mLangue(s) {label} inconnue(s), ignorée(s) : {', '.join(unknown)}\x1b[0m")

    selected = [p for p in available if wanted(p, sources, targets)]
    if not selected:
        log("\x1b[31mAucun modèle ne correspond à la configuration.\x1b[0m")
        return 1

    # Si une source n'a aucun chemin vers une cible (ni direct, ni via en),
    # on le signale.
    has_pivot_to = {t for t in targets if any(p.from_code == PIVOT and p.to_code == t for p in selected)}
    for src in sorted(sources or []):
        if src in targets or src not in known:
            continue
        direct = any(p.from_code == src and p.to_code in targets for p in selected)
        via_en = src == PIVOT or (any(p.from_code == src and p.to_code == PIVOT for p in selected) and has_pivot_to)
        if not (direct or via_en):
            log(f"\x1b[33mAucun chemin de traduction pour « {src} » vers {', '.join(sorted(targets))}.\x1b[0m")

    log(f"{len(selected)} modèle(s) nécessaire(s) "
        f"(sources : {'toutes' if sources is None else ', '.join(sorted(sources))} -> cibles : {', '.join(sorted(targets))}).")

    by_pair = {(p.from_code, p.to_code): p for p in installed}
    selected_pairs = {(p.from_code, p.to_code) for p in selected}

    # Suppression des modèles devenus inutiles (libère du disque).
    for pair, pack in by_pair.items():
        if pair not in selected_pairs:
            log(f"Suppression de {pair[0]} -> {pair[1]} (plus nécessaire)")
            package.uninstall(pack)

    failures = 0
    for i, pack in enumerate(selected, 1):
        pair = (pack.from_code, pack.to_code)
        prefix = f"[{i}/{len(selected)}] {pack.from_name} -> {pack.to_name}"
        current = by_pair.get(pair)
        try:
            if current is None:
                log(f"{prefix} : téléchargement ({pack.package_version})...")
                pack.install()
            elif version.parse(current.package_version) < version.parse(pack.package_version):
                log(f"{prefix} : mise à jour {current.package_version} -> {pack.package_version}...")
                package.uninstall(current)
                pack.install()
        except Exception as e:  # réseau, disque plein...
            failures += 1
            log(f"\x1b[31m{prefix} : échec ({e})\x1b[0m")

    # Modèles de découpage en phrases (MiniSBD) des langues concernées.
    try:
        from minisbd import download_models
        codes = {c for p in selected for c in (p.from_code, p.to_code)}
        log("Téléchargement des modèles de découpage de phrases (MiniSBD)...")
        download_models(sorted(codes), lambda m: None)
    except Exception as e:
        log(f"\x1b[33mMiniSBD : {e}\x1b[0m")

    if failures == 0:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(config + "\n")
        log(f"Terminé : {len(package.get_installed_packages())} modèles installés.")
    else:
        log(f"\x1b[33m{failures} modèle(s) en échec — nouvel essai au prochain démarrage.\x1b[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
