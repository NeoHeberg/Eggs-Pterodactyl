## 📦 Eggs disponibles

| Nom | Auteur | Description | Licence |
|-----|--------|-------------|---------|
| **Minecraft Vanilla** | [Pterodactyl](https://github.com/pterodactyl) | Egg officiel pour serveur Minecraft Vanilla (version standard). | [MIT](https://github.com/pterodactyl/panel/blob/develop/LICENSE) (Pterodactyl) |
| **Python** | [parkervcp](https://github.com/parkervcp) | Egg pour exécuter des applications Python. | [MIT](https://github.com/parkervcp/eggs/blob/master/LICENSE) (parkervcp) |
| **Node.js NeoHeberg** | Axel Lalaut & Slownover | Egg optimisé pour NeoHeberg avec support Node.js 12 à 24, installation automatique des dépendances et affichage personnalisé. | **Propriétaire NeoHeberg** – Toute copie ou réutilisation sans autorisation est interdite. |

---

## 🧩 Détails des eggs

### Minecraft Vanilla
- **Source** : Egg officiel du projet Pterodactyl.
- **Utilisation chez NeoHeberg** : Aucune modification n’a été apportée, il est utilisé tel quel.
- **Licence** : Distribué sous licence MIT par Pterodactyl.

### Python
- **Source** : Egg créé par parkervcp, maintenu dans le dépôt [parkervcp/eggs](https://github.com/parkervcp/eggs).
- **Utilisation chez NeoHeberg** : Utilisé sans modification.
- **Licence** : Également sous licence MIT (voir [LICENSE](https://github.com/parkervcp/eggs/blob/master/LICENSE)).

### Node.js NeoHeberg
- **Auteurs** : Axel Lalaut & Slownover (équipe NeoHeberg).
- **Description** : Cet egg a été conçu spécialement pour l’hébergement d’applications Node.js sur NeoHeberg. Il intègre :
  - Support des versions Node.js de 12 à 24.
  - Installation automatique des dépendances npm à chaque démarrage (via `package.json` ou variables d’environnement).
  - Fichiers par défaut (`index.js`, `package.json`) générés avec un message d’accueil personnalisé incluant le copyright NeoHeberg.
  - Récupération automatique du port alloué par Pterodactyl (`SERVER_PORT`).
- **Licence** : **Propriétaire**. Cet egg est la propriété exclusive de NeoHeberg. Toute reproduction, modification ou redistribution sans accord écrit préalable est interdite. Il est fourni uniquement pour les besoins de l’infrastructure NeoHeberg.

---

## ⚖️ Respect des licences

Nous tenons à remercier les auteurs des eggs communautaires pour leur travail.  
Si vous utilisez ces eggs en dehors de NeoHeberg, merci de vous référer aux licences respectives :

- **Pterodactyl** : [MIT](https://github.com/pterodactyl/panel/blob/develop/LICENSE)
- **parkervcp/eggs** : [MIT](https://github.com/parkervcp/eggs/blob/master/LICENSE)

Pour toute question concernant l’egg **Node.js NeoHeberg**, veuillez contacter l’équipe NeoHeberg.

> **Attention** : L’egg Node.js NeoHeberg a été créer par NeoHeberg pour NeoHeberg. Son utilisation sur une autre infrastructure n’est pas autorisée sans l’accord de NeoHeberg.