# Optimisations v8 — Premium IPTV Player

Passe d'optimisation globale visant une qualité professionnelle (Bob Player / IBO Player / HOT IPTV) et la conformité Play Store 2026.

## Nouveautés v8 (par rapport à la v7)

### 1. Navigation entre onglets : IndexedStack paresseux (`home_screen.dart`)
L'ancien `AnimatedSwitcher` **détruisait puis reconstruisait** chaque onglet à chaque changement : perte du scroll, refiltrage des catalogues, redécodage des affiches. Désormais :
- un onglet jamais visité n'est **pas construit** (lazy loading des onglets) ;
- un onglet visité reste vivant hors écran : scroll, recherche et filtres **préservés**, changement d'onglet **instantané** (comportement Netflix/TiviMate).

### 2. Mode performance TV (`core/perf/perf_mode.dart`, nouveau)
Détecté une fois au démarrage (`main.dart`) via le canal natif `FEATURE_LEANBACK` / `amazon.hardware.fire_tv` :
- sur Android TV / Google TV / **Fire TV**, les animations *décoratives* sont coupées, le GPU reste disponible pour le décodage vidéo ;
- respecte aussi la préférence d'accessibilité « réduire les animations » (`MediaQuery.disableAnimationsOf`) ;
- les animations *fonctionnelles* (focus D-pad, transitions) restent actives.

### 3. Fond premium sans repaint permanent (`premium_background.dart`)
Les deux orbes animés tournaient **en boucle infinie à 60 fps** (CPU/batterie, jank garanti sur Fire TV Stick) :
- chaque orbe est isolé dans un `RepaintBoundary` (son animation ne repeint plus le contenu) ;
- orbes **statiques** en mode TV / économie — zéro frame d'animation superflue.
La bannière héro suit la même règle (fondu d'apparition ignoré sur TV).

### 4. Recherche globale débouncée (`global_search_tab.dart`)
Chaque frappe refiltrait immédiatement les 3 catalogues complets (chaînes + films + séries, souvent 20 000+ éléments). Ajout du `Debouncer` 300 ms (déjà utilisé sur Films/Séries/Live) : saisie parfaitement fluide, y compris au clavier virtuel TV.

### 5. Accueil Netflix : regroupement par catégorie mémoïsé (`media_providers.dart`)
`moviesByCategoryProvider` / `seriesByCategoryProvider` : le regroupement O(N) n'est exécuté qu'au (re)chargement du catalogue. Avant : 10 rangées × `where()` sur tout le catalogue **à chaque rebuild** (≈200 000 itérations par frame lors d'une mise à jour de progression ou d'un favori).

### 6. Modernisation couleur : `withOpacity` → `withValues(alpha:)`
50 occurrences migrées (API dépréciée, perte de précision en wide-gamut). SDK Dart minimal relevé à `>=3.6.0`.

### 7. Conformité Play Store 2026 (`android/`)
- `compileSdk = 35`, `targetSdk = 35` (**exigence Google Play** pour toute publication/mise à jour depuis fin août 2025 ; prévoir API 36 vers fin août 2026) ;
- AGP `8.3.2 → 8.7.3`, Kotlin `1.9.24 → 2.1.0`, Java 8 → **Java 11** ;
- déjà en place : R8 full mode (minify + shrinkResources + obfuscation), signature via `key.properties`, `allowBackup=false`, `networkSecurityConfig`.

## Rappel du socle déjà présent (v7)

- **Réseau** : pool de connexions keep-alive (6/hôte), gzip, retry exponentiel + jitter, **déduplication des GET en vol**, timeouts bornés, logs en debug uniquement.
- **Parsing** : catalogues > 800 éléments mappés dans un **isolate** (aucun jank au premier chargement).
- **Cache** : Hive avec TTL 6 h + compactage auto + récupération de corruption ; repli hors-ligne M3U ; cache disque images LRU borné (1200 objets / 14 jours).
- **Images** : `OptimizedImage` — décodage à la taille d'affichage (`memCacheWidth`), compression disque (`maxWidthDiskCache`), cache RAM plafonné à 80 Mo ; `ImagePrefetcher` (préchargement héro + premières rangées, 4 téléchargements max en parallèle).
- **Listes** : `PagedGrid` (pagination de rendu par pages de 60, compatible D-pad), `itemExtent` fixe sur les listes de chaînes, `cacheExtent` et `RepaintBoundary` sur les rangées.
- **Sécurité** : identifiants dans `flutter_secure_storage`, migration v1 automatique, `allowBackup=false`, R8.
- **Erreurs** : handlers globaux (`FlutterError.onError`, `PlatformDispatcher.onError`) — aucune exception non interceptée ne crashe l'app ; `ErrorView` avec réessai partout.
- **Lecteur** : 6 timers tous annulés au `dispose`, garde `mounted` systématique, reprise intelligente, PiP, Chromecast.

## Checklist publication Play Store

1. Créer le keystore : `keytool -genkey -v -keystore keystore/premium_iptv.jks -keyalg RSA -keysize 2048 -validity 10000 -alias premium_iptv`
2. Renseigner `android/key.properties` (jamais commité).
3. `flutter build appbundle --release` (AAB obligatoire).
4. Fiche Play Console : politique de confidentialité obligatoire (l'app stocke des identifiants) + déclaration « sécurité des données ».
5. Tester l'AAB obfusqué (R8) sur un vrai appareil **et** sur Android TV avant soumission.
6. Pour l'Amazon Appstore (Fire TV) : APK classique, la déclaration `amazon.hardware.fire_tv` est déjà dans le manifest.
