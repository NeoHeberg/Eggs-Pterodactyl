"""
NeoHeberg · Egg LibreTranslate — installation des modèles de langue
--------------------------------------------------------------------
Exécuté par start.sh AVANT LibreTranslate, avec le Python du venv :

    python models.py <sources> <cibles> <réponses> <update:true|false>

    <sources>  : codes séparés par des virgules, ou « all »
    <cibles>   : codes séparés par des virgules (ex : fr)
    <réponses> : codes séparés par des virgules, « all », ou vide (aucune) :
                 langues vers lesquelles on traduit DEPUIS les cibles (ex : la
                 réponse du support, écrite en français, vers la langue du
                 client)

Deux directions sont donc installées : sources -> cibles, et cibles -> réponses.

Pourquoi ne pas utiliser --load-only de LibreTranslate ?
  --load-only installe toutes les paires entre les langues listées, dans les
  DEUX sens. Or presque tous les modèles Argos passent par l'anglais
  (X -> en, en -> X) : pour traduire « n'importe quelle langue -> français »,
  il suffit de X -> en (pour chaque source) + en -> fr. Ce script n'installe
  que les modèles utiles dans le bon sens, LibreTranslate fait ensuite le
  pivot X -> en -> fr tout seul. Sans langue de réponse, c'est ~2x moins de
  disque ; avec « all » en réponse, on retombe sur ~tous les modèles.

LibreTranslate est lancé via lt_run.py, qui désactive son installation
automatique des modèles : il utilise exactement ce qui est installé ici.

Le résultat (configuration + liste des modèles) est mémorisé dans
~/.neoheberg/models.conf : tant que rien ne change (et sans mise à jour
demandée), le script ne contacte pas le réseau, ce qui garde un démarrage
rapide. Les modèles en trop sont supprimés à la synchronisation suivante.
"""

import json
import sys
from pathlib import Path

from argostranslate import package
from packaging import version

from libretranslate.language import iso2model

PIVOT = "en"
STATE_FILE = Path.home() / ".neoheberg" / "models.conf"
ALL_WORDS = ("all", "*", "toutes")
NONE_WORDS = ("", "none", "aucune", "off", "false")


def log(msg):
    print(f"\x1b[35m[modèles]\x1b[0m {msg}", flush=True)


def read_state():
    """État de la dernière synchronisation ({} si absent ou ancien format)."""
    try:
        data = json.loads(STATE_FILE.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def parse_codes(value):
    codes = [c.strip() for c in value.split(",") if c.strip()]
    return [iso2model(c) for c in codes]


def parse_set(value, empty_is_all):
    """None = toutes les langues, set() = aucune, sinon l'ensemble des codes."""
    value = value.strip().lower()
    if value in ALL_WORDS or (empty_is_all and value == ""):
        return None
    if value in NONE_WORDS:
        return set()
    return set(parse_codes(value))


def label(codes):
    return "toutes" if codes is None else ", ".join(sorted(codes))


def config_part(codes):
    return "all" if codes is None else ",".join(sorted(codes))


def contains(codes, code):
    return codes is None or code in codes


def other_than(codes, excluded):
    """Reste-t-il une langue dans `codes` en dehors de `excluded` ?"""
    return codes is None or bool(codes - excluded)


def wanted_for(pack, froms, tos):
    """Le modèle sert-il à traduire une langue de `froms` vers une de `tos` ?"""
    src, dst = pack.from_code, pack.to_code
    if src != dst and contains(froms, src) and contains(tos, dst):
        return True  # direct
    if dst == PIVOT and src != PIVOT and contains(froms, src) and other_than(tos, {src, PIVOT}):
        return True  # source -> en (pivot)
    if src == PIVOT and contains(tos, dst) and other_than(froms, {dst, PIVOT}):
        return True  # en -> cible (pivot)
    return False


def wanted(pack, directions):
    return any(wanted_for(pack, froms, tos) for froms, tos in directions)


def has_path(src, dst, pairs):
    """Chemin de traduction src -> dst (direct, ou via l'anglais) ?"""
    if (src, dst) in pairs:
        return True
    to_pivot = src == PIVOT or (src, PIVOT) in pairs
    from_pivot = dst == PIVOT or (PIVOT, dst) in pairs
    return to_pivot and from_pivot


def main():
    if len(sys.argv) != 5:
        print(__doc__)
        return 2

    sources = parse_set(sys.argv[1], empty_is_all=True)
    targets = set(parse_codes(sys.argv[2].strip().lower()))
    replies = parse_set(sys.argv[3], empty_is_all=False)
    update = sys.argv[4].strip().lower() == "true"

    if not targets:
        log("Aucune langue cible définie — rien à installer.")
        return 1

    directions = [(sources, targets)]
    if replies is None or replies:
        directions.append((targets, replies))

    config = (f"sources={config_part(sources)};targets={config_part(targets)}"
              f";replies={config_part(replies)}")

    installed = package.get_installed_packages()
    installed_pairs = sorted(f"{p.from_code}>{p.to_code}" for p in installed)
    state = read_state()
    # Sans réseau tant que la configuration ET la liste des modèles installés
    # correspondent à la dernière synchronisation. Un écart (modèles ajoutés
    # par une autre source, supprimés à la main...) déclenche une resynchro.
    if (not update and installed
            and state.get("config") == config
            and state.get("pairs") == installed_pairs):
        log(f"{len(installed)} modèle(s) installé(s), configuration inchangée.")
        return 0
    if state.get("config") == config and state.get("pairs") != installed_pairs:
        log("Les modèles installés ne correspondent pas à la configuration : resynchronisation.")

    log("Récupération de l'index des modèles...")
    package.update_package_index()
    available = package.get_available_packages()

    known = {p.from_code for p in available} | {p.to_code for p in available}
    for kind, codes in (("source", sources), ("cible", targets), ("de réponse", replies)):
        unknown = sorted((codes or set()) - known)
        if unknown:
            log(f"\x1b[33mLangue(s) {kind} inconnue(s), ignorée(s) : {', '.join(unknown)}\x1b[0m")

    selected = [p for p in available if wanted(p, directions)]
    if not selected:
        log("\x1b[31mAucun modèle ne correspond à la configuration.\x1b[0m")
        return 1

    # Une langue explicitement demandée sans aucun chemin de traduction (ni
    # direct, ni via en) est signalée.
    pairs = {(p.from_code, p.to_code) for p in selected}
    for froms, tos in directions:
        if froms is None or tos is None:
            continue
        for src in sorted(froms & known):
            for dst in sorted((tos & known) - {src}):
                if not has_path(src, dst, pairs):
                    log(f"\x1b[33mAucun chemin de traduction pour « {src} » vers « {dst} ».\x1b[0m")

    log(f"{len(selected)} modèle(s) nécessaire(s) "
        f"(sources : {label(sources)} -> cibles : {label(targets)}"
        + (f" ; réponses : {label(targets)} -> {label(replies)}" if len(directions) > 1 else "")
        + ").")

    by_pair = {(p.from_code, p.to_code): p for p in installed}
    selected_pairs = pairs

    # Archives laissées par un téléchargement interrompu (arrêt du serveur
    # pendant l'installation) : Argos les supprime normalement après usage.
    try:
        from argostranslate import settings
        for leftover in Path(settings.downloads_dir).glob("*.argosmodel"):
            leftover.unlink(missing_ok=True)
    except Exception:
        pass

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
        final = package.get_installed_packages()
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(json.dumps({
            "config": config,
            "pairs": sorted(f"{p.from_code}>{p.to_code}" for p in final),
        }) + "\n")
        log(f"Terminé : {len(final)} modèle(s) installé(s).")
    else:
        log(f"\x1b[33m{failures} modèle(s) en échec — nouvel essai au prochain démarrage.\x1b[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
