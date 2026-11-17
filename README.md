## 📦 Eggs disponibles

| Nom                   | Auteur                                        | Description                                                                                                                   | Licence                                                                               |
| --------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Minecraft Vanilla** | [Pterodactyl](https://github.com/pterodactyl) | Egg officiel pour serveur Minecraft Vanilla (version standard).                                                               | [MIT](https://github.com/pterodactyl/panel/blob/1.0-develop/LICENSE.md) (Pterodactyl) |
| **Python**            | [YajTPG](https://github.com/YajTPG)           | Egg python créé par YajTPG                                                                                                    | [MIT](https://github.com/YajTPG/pterodactyl-eggs/blob/universal/LICENSE)              |
| **Node.js NeoHeberg** | Axel Lalaut & Slownover                       | Egg Node.js avec setup interactif au premier démarrage (type de service + version 12 à 24), versions installées via fnm, image runtime légère sur le registry Harbor. | **Utilisation libre, modification interdite sans accord – Propriété NeoHeberg**       |
| **LibreTranslate NeoHeberg** | Axel Lalaut & Slownover | Egg [LibreTranslate](https://libretranslate.com) (API de traduction auto-hébergée) avec Cloudflare Tunnel intégré et mise à jour automatique de cloudflared, image runtime sur le registry Harbor. | **Utilisation libre, modification interdite sans accord – Propriété NeoHeberg**       |

---

## 🧩 Détails des eggs

### Minecraft Vanilla

- **Source** : Egg officiel du projet Pterodactyl.
- **Utilisation chez NeoHeberg** : Aucune modification n’a été apportée, il est utilisé tel quel.
- **Licence** : Distribué sous licence MIT par Pterodactyl.

### Python

- **Source** : Egg créé par YajTPG, maintenu dans le dépôt [YajTPG/pterodactyl-eggs](https://github.com/YajTPG/pterodactyl-eggs).
- **Utilisation chez NeoHeberg** : Utilisé sans modification.
- **Licence** : Également sous licence MIT (voir [LICENSE](https://github.com/YajTPG/pterodactyl-eggs/blob/universal/LICENSE)).

### Node.js NeoHeberg

- **Auteurs** : Axel Lalaut & Slownover (équipe NeoHeberg).
- **Description** : Cet egg a été conçu spécialement pour l’hébergement d’applications Node.js sur NeoHeberg. Il intègre :
  - Un setup interactif au premier démarrage (confirmation d’installation, choix du type de service : Web / Bot Discord / API / Autre, puis choix de la version Node.js).
  - Une liste de versions Node.js **curatée** (12.x à 24.x), installées via `fnm` dans le volume persistant (aucune saisie de version arbitraire).
  - Une image runtime légère (Debian slim) construite par GitHub Actions et poussée sur le registry Harbor NeoHeberg (`registry.axel-l.fr/neoheberg_egg/nodejs`).
  - La génération de fichiers par défaut (`package.json`, `index.js`) selon le type de service choisi.
  - La récupération automatique du port alloué par Pterodactyl (`SERVER_PORT`).
- **Mise à jour** : les corrections de l’egg ou de son image Docker ne s’appliquent qu’aux **nouvelles** installations (voir [docs/mise-a-jour-eggs.md](docs/mise-a-jour-eggs.md)).
- **Licence** : Utilisation autorisée (téléchargement et exécution), mais toute modification, adaptation ou redistribution de versions modifiées est interdite sans accord écrit préalable de NeoHeberg. Cet egg reste la propriété exclusive de NeoHeberg.


### LibreTranslate NeoHeberg

- **Auteurs** : Axel Lalaut & Slownover (équipe NeoHeberg).
- **Description** : Egg pour héberger [LibreTranslate](https://libretranslate.com), une API de traduction libre et auto-hébergée. Il intègre :
  - Une image runtime (Python slim + LibreTranslate installé depuis PyPI) construite par GitHub Actions et poussée sur le registry Harbor NeoHeberg (`registry.axel-l.fr/neoheberg_egg/libretranslate`). La version de LibreTranslate est fixée par `ARG LT_VERSION` dans le [Dockerfile](docker/libretranslate/Dockerfile) (ou choisie au lancement manuel du workflow).
  - Traduction de **n'importe quelle langue vers le français** par défaut (langues source `all`, cible `fr`, détection automatique de la langue d'origine). Les modèles sont installés **par direction** (source → anglais, puis anglais → cible) dans le volume persistant : ~50 modèles au lieu de ~100 avec `--load-only`. Les langues source peuvent être restreintes pour économiser du disque (ex : `en,ru,ms,es,de`).
  - Traduction **retour du français vers la langue de l'interlocuteur** (variable « Langues de réponse », `all` par défaut) : modèles français → anglais → X, pour que le support réponde au client dans sa langue. Vide pour la désactiver et diviser le disque par deux.
  - Un **port d'écoute** au choix (variable « Port d'écoute », vide = port principal du serveur). Un autre port n'est joignable de l'extérieur que s'il fait partie des allocations du serveur ; le tunnel, lui, suit automatiquement ce port.
  - Les limites de caractères / requêtes, l'interface web activable, et des **clés API gérables depuis la console** du panel (`keys`, `keys add 60`, `keys remove <clé>` ; tapez `help`).
  - Un **Cloudflare Tunnel** intégré, au choix :
    - `token` : tunnel géré depuis le dashboard Cloudflare Zero Trust (service public à pointer vers `http://localhost:<port d'écoute>`) ;
    - `quick` : tunnel rapide `trycloudflare.com` sans compte (URL aléatoire, pour les tests).
  - **Accès par nom de domaine** : LibreTranslate parle HTTP simple, sans TLS. Un sous-domaine d'un domaine en HSTS `includeSubDomains` (cas de `neoheberg.fr`) est forcé en HTTPS par le navigateur, et un domaine proxifié par Cloudflare (nuage orange) ne relaie que quelques ports (80, 443, 8080, 8443…) : `http://sous-domaine:port` échoue alors que `http://IP:port` fonctionne. Passer par le tunnel en mode `token` (nom d'hôte public → `http://localhost:<port d'écoute>`) et utiliser `https://sous-domaine`, sans port.
  - La **mise à jour automatique de cloudflared** : le binaire vit dans le volume (`.neoheberg/bin/cloudflared`), une vérification a lieu au démarrage puis toutes les N heures (24 h par défaut). Chaque nouvelle version est vérifiée (empreinte SHA-256 publiée par GitHub + `cloudflared --version`) avant d'être installée, puis seul le tunnel redémarre : LibreTranslate n'est pas interrompu. Commandes console : `tunnel`, `tunnel update`, `tunnel restart`.
- **Ressources conseillées** : ~15 Go de disque avec toutes les langues source et de réponse (~8 Go sans langue de réponse, ~1 Go pour 5 langues dans un seul sens) ; 2 à 4 Go de RAM (les modèles sont chargés en mémoire au fur et à mesure des langues réellement traduites).
- **Mise à jour** : cloudflared se met à jour tout seul ; LibreTranslate lui-même suit l'image Docker (voir [docs/mise-a-jour-eggs.md](docs/mise-a-jour-eggs.md)).
- **Licence** : mêmes conditions que l'egg Node.js NeoHeberg. LibreTranslate est distribué sous licence [AGPL-3.0](https://github.com/LibreTranslate/LibreTranslate/blob/main/LICENSE) et cloudflared sous licence [Apache-2.0](https://github.com/cloudflare/cloudflared/blob/master/LICENSE).

---

## ⚖️ Respect des licences

Nous tenons à remercier les auteurs des eggs communautaires pour leur travail.  
Si vous utilisez ces eggs en dehors de NeoHeberg, merci de vous référer aux licences respectives :

- **Pterodactyl** : [MIT](https://github.com/pterodactyl/panel/blob/develop/LICENSE)
- **YajTPG/pterodactyl-eggs** : [MIT](https://github.com/YajTPG/pterodactyl-eggs/blob/universal/LICENSE)

Pour toute question concernant l’egg **Node.js NeoHeberg**, veuillez contacter l’équipe NeoHeberg.

> **Attention** : L’egg Node.js NeoHeberg a été créer par NeoHeberg pour NeoHeberg. Son utilisation sur une autre infrastructure n’est pas autorisée sans l’accord de NeoHeberg.
