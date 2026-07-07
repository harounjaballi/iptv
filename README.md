# Premium IPTV Player

Lecteur IPTV professionnel en **Flutter** (Xtream Codes) pour **Android Mobile, Android TV, Google TV et Fire TV**.

## Stack technique

| Domaine | Choix |
|---|---|
| Architecture | Clean Architecture (domain / data / presentation) |
| State management | Riverpod 2 (`Notifier`, `FutureProvider.family`) |
| Navigation | GoRouter |
| Réseau | Dio |
| Cache local | Hive (TTL 6h sur les catégories) |
| Identifiants | flutter_secure_storage (chiffré) |
| Lecteur vidéo | better_player_plus (fork maintenu de Better Player / ExoPlayer) |
| UI | Material 3, cached_network_image, shimmer, flutter_animate |
| i18n / formats | intl (locale `fr`) |

## Structure du projet

```
lib/
├── core/            # constantes, exceptions typées, client Dio
├── data/            # implémentations des repositories (API + cache)
├── domain/          # contrats abstraits des repositories
├── models/          # modèles Xtream (chaînes, films, séries, épisodes, compte)
├── presentation/    # écrans (splash, login, home, player, détails…)
├── providers/       # providers Riverpod (auth, thème, contenu, infra)
├── repositories/    # (voir domain/repositories + data/repositories)
├── routes/          # configuration GoRouter
├── services/        # API Xtream, cache Hive, secure storage, détection TV
├── themes/          # thèmes Material 3 clair & sombre + palette
├── utils/           # responsive, formatters (intl)
└── widgets/         # composants réutilisables (cartes focusables D-Pad, shimmer…)
```


## Design Premium (v2)

Interface inspirée des lecteurs IPTV commerciaux (Bob Player, IBO Player, Tivimate, HOT IPTV) :

- **Glassmorphism** : `GlassContainer` (BackdropFilter + voile translucide + bordure lumineuse) — carte de login, bottom navigation flottante.
- **Dégradés** : palette violet→fuchsia (`AppColors.brandGradient`), fond profond animé avec orbes lumineux (`PremiumBackground`), titres en ShaderMask.
- **Boutons animés** : `GradientButton` (rebond au clic, halo au focus D-Pad/souris, état de chargement).
- **Skeleton Loading** : `SkeletonGrid` / `SkeletonBox` (shimmer sur placeholders arrondis).
- **Transitions** : pages GoRouter (fondu + glissement + zoom subtil), changement d'onglet via AnimatedSwitcher.
- **Navigation** : Drawer M3 avec en-tête compte en dégradé + Bottom Navigation "verre" flottante (mobile) / NavigationRail avec marges overscan (TV).
- **Cartes** : coins 18-20 px, ombres douces au repos, zoom + halo au focus TV.


## Module Live TV (v4)

Expérience TiviMate : **une seule requête** charge toutes les chaînes (cache Hive avec TTL),
puis catégories / recherche / tri se font **en mémoire** → navigation instantanée.

- **Catégories** : panneau latéral (TV/desktop) ou chips (mobile), avec pseudo-catégories **Favoris** et **Récents**.
- **Recherche** en temps réel + **tri** (numéro, A→Z, Z→A).
- **Favoris** persistés par compte (étoile sur chaque tuile et dans le lecteur).
- **Chaînes récentes** (15 max) + **reprise de lecture** (bannière « Reprendre » sur la dernière chaîne vue).
- **EPG** (`get_short_epg`, titres Base64 décodés, cache 10 min) : programme **actuel** avec barre de progression + **suivant**, en ligne dans chaque tuile et en détail dans l'aperçu et le lecteur.
- **Aperçu de chaîne** : sur écran large / TV, le focus D-Pad ou un tap joue la chaîne dans le panneau de droite ; second appui → plein écran.
- **Zapping ultra rapide** : lecteur unique réutilisé (`setupDataSource`), **debounce 300 ms** (l'UI suit chaque appui, le flux démarre après la rafale), buffers de démarrage réduits (~900 ms). ▲/▼ ou boutons CH de la télécommande, glissement vertical sur mobile, ◀ ouvre la liste des chaînes en superposition.
- **Lecteur intégré** plein écran sans contrôles natifs : bandeau glassmorphism (logo, numéro, nom, EPG) auto-masqué après 4 s.

> EPG disponible pour les comptes Xtream (et MAC résolus en Xtream) ; les comptes M3U affichent la liste sans guide, sans erreur.

## Compilation

```bash
flutter pub get
flutter run                # appareil connecté
flutter build apk --release
```

> Ouvrez le dossier dans Android Studio : `local.properties` (chemins SDK/Flutter)
> sera généré automatiquement au premier `flutter pub get` / build.

## Support TV (Android TV / Google TV / Fire TV)

- Intent-filter `LEANBACK_LAUNCHER` + `android:banner` déclarés dans le Manifest.
- `touchscreen` et `portrait` déclarés non requis (exigence Play Store TV).
- Détection TV native via MethodChannel (`FEATURE_LEANBACK` + `amazon.hardware.fire_tv`)
  → l'UI bascule automatiquement en `NavigationRail` + marges overscan.
- Navigation D-Pad : `FocusableCard` (zoom + bordure au focus), lecteur pilotable
  à la télécommande (OK = play/pause, ◀/▶ = -10s/+10s en VOD).

## À faire avant publication

- Remplacer `res/drawable/tv_banner.xml` par une vraie bannière **320×180 px** (PNG).
- Ajouter des icônes `mipmap/ic_launcher` (via `flutter_launcher_icons` par ex.).
- Configurer une **signature release** dans `android/app/build.gradle`.
- `usesCleartextTraffic="true"` est activé car beaucoup de serveurs Xtream sont en HTTP ;
  à restreindre via `network_security_config` si vos serveurs sont en HTTPS.

## Évolutions prévues par l'architecture

- Favoris (boîte Hive `favorites` + `CacheService.toggleFavorite` déjà en place).
- EPG (ajouter `get_short_epg` dans `XtreamApiService`).
- Recherche globale, profils multiples, contrôle parental.
