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
  - Le choix des langues chargées (`en,fr` par défaut) : seuls les modèles nécessaires sont téléchargés au premier démarrage, dans le volume persistant.
  - Les limites de caractères / requêtes, l'interface web activable, et des **clés API gérables depuis la console** du panel (`keys`, `keys add 60`, `keys remove <clé>` ; tapez `help`).
  - Un **Cloudflare Tunnel** intégré, au choix :
    - `token` : tunnel géré depuis le dashboard Cloudflare Zero Trust (service public à pointer vers `http://localhost:<port du serveur>`) ;
    - `quick` : tunnel rapide `trycloudflare.com` sans compte (URL aléatoire, pour les tests).
  - La **mise à jour automatique de cloudflared** : le binaire vit dans le volume (`.neoheberg/bin/cloudflared`), une vérification a lieu au démarrage puis toutes les N heures (24 h par défaut). Chaque nouvelle version est vérifiée (empreinte SHA-256 publiée par GitHub + `cloudflared --version`) avant d'être installée, puis seul le tunnel redémarre : LibreTranslate n'est pas interrompu. Commandes console : `tunnel`, `tunnel update`, `tunnel restart`.
- **Ressources conseillées** : ~1 à 2 Go de RAM et ~1 Go de disque pour quelques langues ; charger toutes les langues demande plusieurs Go.
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
