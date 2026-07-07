# Optimisations — Premium IPTV Player (v8)

Passe d'optimisation complète visant un niveau professionnel (Bob Player,
IBO Player, HOT IPTV) et la préparation à la publication Play Store.

---

## 1. Performances

| Optimisation | Fichier | Effet |
|---|---|---|
| **Parsing en isolate** : les catalogues > 800 éléments (souvent 10 000–50 000 en IPTV) sont mappés hors du thread UI via `Isolate.run` | `xtream_api_service.dart` | Zéro frame perdue au premier chargement |
| **Grille paginée (lazy loading)** : rendu incrémental par pages de 60 + déclenchement à 600 px du bas + loader de pied | `widgets/paged_grid.dart`, onglets Films/Séries | Grille instantanée même sur 50 000 films |
| **`RepaintBoundary`** par poster (grilles + rangées) | `paged_grid.dart`, `media_row.dart` | Repaints isolés (focus TV, progression) |
| **`cacheExtent`** sur les rangées horizontales (3 posters hors écran) | `media_row.dart` | Défilement horizontal fluide |
| **Debounce 300 ms** sur les 3 recherches (Live / Films / Séries) | `core/utils/debouncer.dart` + onglets | Saisie fluide, plus de refiltrage par frappe |
| **Animation par carte supprimée** (`animate().fadeIn` sur chaque poster = jank en grille) — remplacée par le fade-in de l'image seule (180 ms) | `poster_card.dart` | Scroll de grille sans à-coups |

## 2. Mémoire

- **Compression mémoire des images** : tout est décodé à la taille
  d'affichage réelle (`memCacheWidth = largeur logique × DPR`, plafonné) via
  `OptimizedImage`. Un poster 2000 px affiché en 122 dp ≈ **25× moins de RAM**.
- **Cache RAM borné** : `imageCache` limité à **80 Mo / 300 images**
  (`main.dart`) — laisse la mémoire au décodage vidéo (critique sur Fire TV
  Stick, ~1 Go utilisable).
- **Backdrops plafonnés à 1280 px** (détails film/série) au lieu de la
  taille d'origine.
- `android:largeHeap="true"` : marge sur les appareils TV à faible RAM.

## 3. Réseau (`core/network/dio_client.dart`)

- **Pool de connexions** : keep-alive 30 s, max 6 connexions/hôte —
  plus de handshake TCP/TLS à chaque appel `player_api.php`.
- **Compression gzip** (`Accept-Encoding: gzip` + `autoUncompress`) : les
  catalogues JSON de plusieurs Mo descendent à ~10 % de leur taille.
- **Déduplication des GET en vol** : quand Home + héro + rangées réveillent
  les mêmes providers, une seule requête part réellement.
- **Retry avec backoff + jitter** : 2 tentatives (1 s, 2 s + aléa 0–400 ms),
  GET uniquement, erreurs transitoires uniquement.
- **Logs uniquement en debug** : aucun identifiant IPTV dans les logs release.

## 4. Cache

- **Cache disque images dédié** (`core/cache/app_cache_manager.dart`) :
  LRU **1200 objets / 14 jours** (vs 200/30 j par défaut), dimensionné pour
  un catalogue IPTV sans empreinte disque illimitée.
- **Hive résilient** : boîte corrompue (coupure de courant sur box TV) →
  suppression + recréation au lieu d'un blocage au démarrage ; **compactage
  automatique** dès 50 entrées mortes + action `compact()` manuelle.
- Écran Réglages > Cache : vide désormais aussi le nouveau cache disque
  **et** le cache RAM (`imageCache.clear()`).

## 5. Sécurité

- `android:allowBackup="false"` : les identifiants IPTV ne sont plus
  extractibles via `adb backup` / sauvegarde cloud.
- **`network_security_config.xml`** explicite (HTTP clair déclaré et
  auditable — obligatoire en IPTV, propre pour la revue Play Store).
- **R8 minify + obfuscation** activés en release + règles ProGuard
  (Flutter, Media3/ExoPlayer, secure storage).
- **Signature de production** via `key.properties` (jamais commité),
  fallback debug en local.
- Identifiants toujours dans `flutter_secure_storage` (Keystore).

## 6. Erreurs

- **Gestion globale** : `FlutterError.onError` + `PlatformDispatcher.onError`
  dans `main.dart` — aucune exception non interceptée ne crash l'app
  (le taux de crash impacte le classement Play Store).
- Préchargement d'images à erreurs silencieuses (un poster mort ne casse rien).
- Ouverture Hive à récupération automatique (voir §4).

## 7. Animations & UX

- Fade-in image court (180 ms) au lieu d'animations par widget.
- **Pull-to-refresh** sur les accueils Films et Séries (invalide le catalogue).
- **Préchargement** (`core/perf/image_prefetcher.dart`) : bannière héro +
  8 premières affiches de chaque rangée, par lots de 4 max (ne vole pas la
  bande passante du flux vidéo), dédupliqué.
- Loader discret en pied de grille pendant le lazy loading.
- Recherche : bouton effacer instantané (`runNow`), résultats debouncés.

## 8. Android TV / Google TV / Fire TV

- `scrollBehavior` multi-pointeurs (tactile, souris, trackpad, stylet).
- La grille paginée fonctionne aussi au **D-pad** : la navigation au focus
  fait défiler → déclenche le chargement des pages suivantes.
- Manifest : `amazon.hardware.fire_tv` et `android.hardware.gamepad`
  déclarés non requis (compatibilité documentée, installable partout).
- `LEANBACK_LAUNCHER`, bannière TV, écran tactile non requis : déjà en place.
- Décodage d'images plafonné à 1080 px : sur TV 4K, le GPU upscale — inutile
  de décoder plus grand pour un poster.

## 9. Publication Play Store — reste à faire

1. Créer le keystore : `keytool -genkey -v -keystore keystore/premium_iptv.jks -alias premium_iptv -keyalg RSA -keysize 2048 -validity 10000`
2. Créer `android/key.properties` (voir commentaire dans `build.gradle`).
3. `flutter build appbundle --release` (l'AAB gère les splits ABI).
4. Tester la release : `flutter build apk --release` + installation sur
   mobile, Android TV et Fire TV (`adb install`).
5. Fiche Play Store : captures mobile **et** TV (obligatoires pour la
   distribution Android TV), déclaration de la politique de confidentialité.

## Notes de comportement

- Le TTL du cache catalogue reste à 6 h (`AppConstants.cacheTtl`).
- `PagedGrid` repart à la page 1 à chaque changement de liste
  (catégorie / recherche) et remonte en haut.
- `ImagePrefetcher.reset()` à appeler au changement de compte si l'on veut
  re-précharger (facultatif : le cache disque fait déjà le travail).
