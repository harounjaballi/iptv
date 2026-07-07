# Système de connexion multi-sources

## Sources supportées

| Mode | Saisie | Validation avant connexion |
|---|---|---|
| **Xtream Codes** | serveur, utilisateur, mot de passe | Appel `player_api.php` : compte actif exigé |
| **URL M3U** | URL http(s) | Téléchargement + parsing (en-tête `#EXTM3U`, ≥ 1 entrée) |
| **Fichier M3U** | sélecteur de fichier (.m3u / .m3u8 / .txt) | Copie dans l'app + parsing |
| **Adresse MAC** | serveur d'activation | Interrogation du portail + validation de la source attribuée |

## Multi-comptes

- Les comptes sont chiffrés dans `flutter_secure_storage` (clé `iptv_accounts`, liste JSON).
- Le compte actif est mémorisé (`iptv_active_account_id`).
- Écran **Mes comptes IPTV** (`/accounts`) : changement, suppression, ajout.
- « Déconnexion » quitte la session mais **conserve** les comptes.
- Les anciens identifiants v1 (compte Xtream unique) sont **migrés automatiquement**.

## Reconnexion automatique

1. **Couche réseau** : intercepteur Dio — 2 nouvelles tentatives (1 s puis 2 s) sur les erreurs transitoires des requêtes GET.
2. **Couche session** : à la connexion / restauration, 3 tentatives avec délai progressif (2 s, 4 s) et état `AuthReconnecting` affiché.
3. **Repli hors ligne** (comptes M3U) : la dernière playlist téléchargée est conservée dans Hive (`m3u_raw_<accountId>`) et sert de secours sans réseau (badge « Hors ligne » dans les réglages).

## Mode MAC — contrat du portail d'activation

L'app génère et persiste :
- une **adresse MAC virtuelle** `00:1A:79:XX:XX:XX` (convention MAG — la vraie MAC est inaccessible depuis Android 6) ;
- un **Device ID** hexadécimal de 12 caractères.

L'écran d'activation les affiche (copie en un clic) et interroge le portail toutes les 5 s :

```
GET {portail}/activation?mac=00:1A:79:XX:XX:XX&device_id=XXXXXXXXXXXX
```

Réponses JSON attendues (côté serveur à implémenter, ex. panel SmarTech) :

```json
{ "status": "active", "type": "xtream",
  "host": "http://srv:8080", "username": "u", "password": "p" }

{ "status": "active", "type": "m3u", "url": "http://.../liste.m3u" }

{ "status": "pending" }

{ "status": "not_found", "message": "Appareil inconnu" }
```

La source attribuée (`xtream` ou `m3u`) est ensuite validée puis enregistrée
dans le compte : le contenu passe par les canaux habituels.

## Contenu M3U

Le parseur classe automatiquement chaque entrée :
- **Épisode de série** : nom contenant `SxxExx` (ou « Saison x Épisode y »), URL `/series/`, ou groupe « Séries » ;
- **Film** : URL `/movie/` ou extension vidéo (mp4, mkv, avi…) ;
- **Chaîne live** : le reste.

Les catégories proviennent de `group-title`. Les modèles portent une
`directUrl` : le lecteur l'utilise en priorité, sinon l'URL Xtream est
construite depuis les identifiants.

## Nouvelle dépendance

`file_picker: ^8.1.2` — lancer `flutter pub get` après mise à jour.
