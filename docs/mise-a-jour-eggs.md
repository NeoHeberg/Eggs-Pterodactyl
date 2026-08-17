# Mise à jour des eggs et des images Docker

Ce document explique ce qui se passe quand on corrige un egg (ou son image
Docker) **après** que des utilisateurs ont déjà installé des serveurs à partir
de celui-ci.

## Réponse courte

- Les corrections d'un egg ou de son image Docker **ne s'appliquent pas**
  automatiquement aux serveurs déjà installés.
- Seuls les **nouveaux** serveurs (ou une réinstallation) utilisent la
  dernière version.
- Pour mettre à jour un serveur existant, il faut le **réinstaller**, ce qui
  **efface ses données**.

## Pourquoi il y a deux couches

Un egg Pterodactyl comporte deux éléments versionnés séparément :

1. **L'egg lui-même** : commande de démarrage, script d'installation,
   variables, fichiers de configuration.
2. **L'image Docker** référencée par l'egg (ici
   `registry.axel-l.fr/neoheberg_egg/nodejs:<tag>`).

Ces deux éléments ont le même comportement : ils sont **figés** au moment de
l'installation du serveur.

## Ce qui se passe concrètement

### 1. L'egg

Quand un utilisateur installe un serveur, Pterodactyl **copie** toute la
définition de l'egg dans le serveur. Chaque serveur garde ensuite **sa propre
copie**, indépendante de l'egg d'origine.

→ Modifier l'egg ensuite ne change rien aux serveurs existants.

### 2. L'image Docker

L'egg référence un tag (par ex. `:latest`). Au moment de l'installation, la
machine Wings **tire** cette image et la garde en cache local.

→ Pousser un nouveau `:latest` sur Harbor ne force pas la mise à jour des
serveurs existants : ils continuent d'utiliser l'image déjà téléchargée.

## Récapitulatif par situation

- **Correction de l'egg** : les nouveaux serveurs reçoivent la version
  corrigée ; les serveurs existants gardent l'ancienne version.
- **Nouvelle image Docker (`:latest`)** : les nouveaux serveurs tirent la
  nouvelle image ; les serveurs existants gardent l'ancienne image en cache.
- **Correctif critique de sécurité** : les nouveaux serveurs sont protégés ;
  les serveurs existants doivent être réinstallés manuellement.

## Comment mettre à jour un serveur existant

1. **Réinstaller le serveur** (bouton « Réinstaller » du panel) :
   - re-tire l'image et re-exécute le setup ;
   - ⚠️ **efface toutes les données** du serveur (le volume est remis à zéro).
2. **Purge manuelle de l'image sur l'hôte Wings** (uniquement pour un
   correctif qui ne touche que l'image runtime, pas le script) : le prochain
   démarrage re-tire `:latest`. C'est une opération d'administration, à faire
   avec précaution.

## Bonnes pratiques

- **Tester avant de publier** : il n'y a pas de filet de sécurité après coup.
- **Garder la rétrocompatibilité** : un nouveau script / une nouvelle image ne
  doit pas casser les serveurs qui ne sont pas encore mis à jour.
- **Tagger par sha** : chaque build pousse `:latest` + `:<sha>` pour pouvoir
  revenir en arrière.
- **Rétention Harbor** : purger les anciens tags pour ne pas remplir le quota.
