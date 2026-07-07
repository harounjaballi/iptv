import 'dart:ui';

/// Langues prises en charge par l'application.
enum AppLanguage {
  fr('Français', Locale('fr')),
  en('English', Locale('en')),
  ar('العربية', Locale('ar'));

  final String label;
  final Locale locale;
  const AppLanguage(this.label, this.locale);

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
        (l) => l.locale.languageCode == code,
        orElse: () => AppLanguage.fr,
      );
}

/// Chaînes traduites — navigation, réglages et écrans transverses.
/// (Les onglets de contenu migrent progressivement vers ce système.)
class L10n {
  final String tabLive;
  final String tabMovies;
  final String tabSeries;
  final String tabSearch;
  final String tabSettings;

  final String settings;
  final String account;
  final String appearance;
  final String themeSystem;
  final String themeLight;
  final String themeDark;
  final String amoled;
  final String amoledSubtitle;
  final String accentColor;
  final String language;
  final String profiles;
  final String activeProfile;
  final String manageProfiles;
  final String addProfile;
  final String editProfile;
  final String deleteProfile;
  final String profileName;
  final String kidsProfile;
  final String kidsProfileSubtitle;
  final String parentalControl;
  final String pinCode;
  final String setPin;
  final String changePin;
  final String removePin;
  final String enterPin;
  final String confirmPin;
  final String wrongPin;
  final String pinMismatch;
  final String hiddenCategories;
  final String hiddenCategoriesSubtitle;
  final String statistics;
  final String watchTime;
  final String today;
  final String last7Days;
  final String totalPlays;
  final String inProgress;
  final String completed;
  final String favorites;
  final String cache;
  final String clearCatalogs;
  final String clearImages;
  final String clearAll;
  final String cacheCleared;
  final String backupSync;
  final String exportBackup;
  final String importMerge;
  final String importMergeSubtitle;
  final String restoreBackup;
  final String restoreBackupSubtitle;
  final String includeAccounts;
  final String backupDone;
  final String importDone;
  final String myAccounts;
  final String logout;
  final String search;
  final String searchHint;
  final String searchEmpty;
  final String searchNoResults;
  final String channels;
  final String movies;
  final String series;
  final String cancel;
  final String save;
  final String delete;
  final String confirm;
  final String offline;

  const L10n({
    required this.tabLive,
    required this.tabMovies,
    required this.tabSeries,
    required this.tabSearch,
    required this.tabSettings,
    required this.settings,
    required this.account,
    required this.appearance,
    required this.themeSystem,
    required this.themeLight,
    required this.themeDark,
    required this.amoled,
    required this.amoledSubtitle,
    required this.accentColor,
    required this.language,
    required this.profiles,
    required this.activeProfile,
    required this.manageProfiles,
    required this.addProfile,
    required this.editProfile,
    required this.deleteProfile,
    required this.profileName,
    required this.kidsProfile,
    required this.kidsProfileSubtitle,
    required this.parentalControl,
    required this.pinCode,
    required this.setPin,
    required this.changePin,
    required this.removePin,
    required this.enterPin,
    required this.confirmPin,
    required this.wrongPin,
    required this.pinMismatch,
    required this.hiddenCategories,
    required this.hiddenCategoriesSubtitle,
    required this.statistics,
    required this.watchTime,
    required this.today,
    required this.last7Days,
    required this.totalPlays,
    required this.inProgress,
    required this.completed,
    required this.favorites,
    required this.cache,
    required this.clearCatalogs,
    required this.clearImages,
    required this.clearAll,
    required this.cacheCleared,
    required this.backupSync,
    required this.exportBackup,
    required this.importMerge,
    required this.importMergeSubtitle,
    required this.restoreBackup,
    required this.restoreBackupSubtitle,
    required this.includeAccounts,
    required this.backupDone,
    required this.importDone,
    required this.myAccounts,
    required this.logout,
    required this.search,
    required this.searchHint,
    required this.searchEmpty,
    required this.searchNoResults,
    required this.channels,
    required this.movies,
    required this.series,
    required this.cancel,
    required this.save,
    required this.delete,
    required this.confirm,
    required this.offline,
  });

  static const fr = L10n(
    tabLive: 'TV',
    tabMovies: 'Films',
    tabSeries: 'Séries',
    tabSearch: 'Recherche',
    tabSettings: 'Réglages',
    settings: 'Réglages',
    account: 'Compte',
    appearance: 'Apparence',
    themeSystem: 'Système',
    themeLight: 'Clair',
    themeDark: 'Sombre',
    amoled: 'Noir AMOLED',
    amoledSubtitle: 'Fond noir pur en mode sombre (économie d\'énergie OLED)',
    accentColor: 'Couleur d\'accent',
    language: 'Langue',
    profiles: 'Profils',
    activeProfile: 'Profil actif',
    manageProfiles: 'Gérer les profils',
    addProfile: 'Ajouter un profil',
    editProfile: 'Modifier le profil',
    deleteProfile: 'Supprimer le profil',
    profileName: 'Nom du profil',
    kidsProfile: 'Profil enfant',
    kidsProfileSubtitle: 'Catégories cachées appliquées, réglages protégés',
    parentalControl: 'Contrôle parental',
    pinCode: 'Code PIN',
    setPin: 'Définir un code PIN',
    changePin: 'Changer le code PIN',
    removePin: 'Supprimer le code PIN',
    enterPin: 'Saisissez le code PIN',
    confirmPin: 'Confirmez le code PIN',
    wrongPin: 'Code PIN incorrect',
    pinMismatch: 'Les codes ne correspondent pas',
    hiddenCategories: 'Catégories cachées',
    hiddenCategoriesSubtitle:
        'Masquées dans toute l\'application (TV, Films, Séries, recherche)',
    statistics: 'Statistiques',
    watchTime: 'Temps de visionnage',
    today: 'Aujourd\'hui',
    last7Days: '7 derniers jours',
    totalPlays: 'Lectures',
    inProgress: 'En cours',
    completed: 'Terminés',
    favorites: 'Favoris',
    cache: 'Cache',
    clearCatalogs: 'Vider les catalogues (chaînes, films, séries)',
    clearImages: 'Vider le cache des images',
    clearAll: 'Tout vider',
    cacheCleared: 'Cache vidé',
    backupSync: 'Sauvegarde & synchronisation',
    exportBackup: 'Exporter une sauvegarde',
    importMerge: 'Synchroniser depuis un fichier',
    importMergeSubtitle:
        'Fusionne favoris, progression et historique (le plus récent gagne)',
    restoreBackup: 'Restaurer une sauvegarde',
    restoreBackupSubtitle: 'Remplace les données locales par la sauvegarde',
    includeAccounts: 'Inclure les comptes IPTV',
    backupDone: 'Sauvegarde exportée',
    importDone: 'Données importées',
    myAccounts: 'Mes comptes IPTV',
    logout: 'Déconnexion',
    search: 'Recherche',
    searchHint: 'Chaînes, films, séries...',
    searchEmpty: 'Recherchez dans tout votre contenu',
    searchNoResults: 'Aucun résultat',
    channels: 'Chaînes TV',
    movies: 'Films',
    series: 'Séries',
    cancel: 'Annuler',
    save: 'Enregistrer',
    delete: 'Supprimer',
    confirm: 'Confirmer',
    offline: 'Hors ligne',
  );

  static const en = L10n(
    tabLive: 'Live',
    tabMovies: 'Movies',
    tabSeries: 'Series',
    tabSearch: 'Search',
    tabSettings: 'Settings',
    settings: 'Settings',
    account: 'Account',
    appearance: 'Appearance',
    themeSystem: 'System',
    themeLight: 'Light',
    themeDark: 'Dark',
    amoled: 'AMOLED black',
    amoledSubtitle: 'Pure black background in dark mode (OLED power saving)',
    accentColor: 'Accent color',
    language: 'Language',
    profiles: 'Profiles',
    activeProfile: 'Active profile',
    manageProfiles: 'Manage profiles',
    addProfile: 'Add profile',
    editProfile: 'Edit profile',
    deleteProfile: 'Delete profile',
    profileName: 'Profile name',
    kidsProfile: 'Kids profile',
    kidsProfileSubtitle: 'Hidden categories applied, protected settings',
    parentalControl: 'Parental control',
    pinCode: 'PIN code',
    setPin: 'Set a PIN code',
    changePin: 'Change PIN code',
    removePin: 'Remove PIN code',
    enterPin: 'Enter PIN code',
    confirmPin: 'Confirm PIN code',
    wrongPin: 'Wrong PIN code',
    pinMismatch: 'PIN codes don\'t match',
    hiddenCategories: 'Hidden categories',
    hiddenCategoriesSubtitle:
        'Hidden everywhere in the app (Live, Movies, Series, search)',
    statistics: 'Statistics',
    watchTime: 'Watch time',
    today: 'Today',
    last7Days: 'Last 7 days',
    totalPlays: 'Plays',
    inProgress: 'In progress',
    completed: 'Completed',
    favorites: 'Favorites',
    cache: 'Cache',
    clearCatalogs: 'Clear catalogs (channels, movies, series)',
    clearImages: 'Clear image cache',
    clearAll: 'Clear everything',
    cacheCleared: 'Cache cleared',
    backupSync: 'Backup & sync',
    exportBackup: 'Export a backup',
    importMerge: 'Sync from a file',
    importMergeSubtitle:
        'Merges favorites, progress and history (most recent wins)',
    restoreBackup: 'Restore a backup',
    restoreBackupSubtitle: 'Replaces local data with the backup',
    includeAccounts: 'Include IPTV accounts',
    backupDone: 'Backup exported',
    importDone: 'Data imported',
    myAccounts: 'My IPTV accounts',
    logout: 'Log out',
    search: 'Search',
    searchHint: 'Channels, movies, series...',
    searchEmpty: 'Search across all your content',
    searchNoResults: 'No results',
    channels: 'Live channels',
    movies: 'Movies',
    series: 'Series',
    cancel: 'Cancel',
    save: 'Save',
    delete: 'Delete',
    confirm: 'Confirm',
    offline: 'Offline',
  );

  static const ar = L10n(
    tabLive: 'البث',
    tabMovies: 'أفلام',
    tabSeries: 'مسلسلات',
    tabSearch: 'بحث',
    tabSettings: 'الإعدادات',
    settings: 'الإعدادات',
    account: 'الحساب',
    appearance: 'المظهر',
    themeSystem: 'النظام',
    themeLight: 'فاتح',
    themeDark: 'داكن',
    amoled: 'أسود AMOLED',
    amoledSubtitle: 'خلفية سوداء نقية في الوضع الداكن (توفير طاقة OLED)',
    accentColor: 'لون التمييز',
    language: 'اللغة',
    profiles: 'الملفات الشخصية',
    activeProfile: 'الملف النشط',
    manageProfiles: 'إدارة الملفات الشخصية',
    addProfile: 'إضافة ملف شخصي',
    editProfile: 'تعديل الملف الشخصي',
    deleteProfile: 'حذف الملف الشخصي',
    profileName: 'اسم الملف الشخصي',
    kidsProfile: 'ملف الأطفال',
    kidsProfileSubtitle: 'الفئات المخفية مطبقة، الإعدادات محمية',
    parentalControl: 'الرقابة الأبوية',
    pinCode: 'رمز PIN',
    setPin: 'تعيين رمز PIN',
    changePin: 'تغيير رمز PIN',
    removePin: 'إزالة رمز PIN',
    enterPin: 'أدخل رمز PIN',
    confirmPin: 'تأكيد رمز PIN',
    wrongPin: 'رمز PIN غير صحيح',
    pinMismatch: 'الرمزان غير متطابقين',
    hiddenCategories: 'الفئات المخفية',
    hiddenCategoriesSubtitle:
        'مخفية في كل التطبيق (البث، الأفلام، المسلسلات، البحث)',
    statistics: 'الإحصائيات',
    watchTime: 'وقت المشاهدة',
    today: 'اليوم',
    last7Days: 'آخر ٧ أيام',
    totalPlays: 'مرات التشغيل',
    inProgress: 'قيد المشاهدة',
    completed: 'مكتملة',
    favorites: 'المفضلة',
    cache: 'ذاكرة التخزين',
    clearCatalogs: 'مسح الفهارس (قنوات، أفلام، مسلسلات)',
    clearImages: 'مسح ذاكرة الصور',
    clearAll: 'مسح الكل',
    cacheCleared: 'تم مسح ذاكرة التخزين',
    backupSync: 'النسخ الاحتياطي والمزامنة',
    exportBackup: 'تصدير نسخة احتياطية',
    importMerge: 'مزامنة من ملف',
    importMergeSubtitle:
        'دمج المفضلة والتقدم والسجل (الأحدث يفوز)',
    restoreBackup: 'استعادة نسخة احتياطية',
    restoreBackupSubtitle: 'استبدال البيانات المحلية بالنسخة الاحتياطية',
    includeAccounts: 'تضمين حسابات IPTV',
    backupDone: 'تم تصدير النسخة الاحتياطية',
    importDone: 'تم استيراد البيانات',
    myAccounts: 'حسابات IPTV الخاصة بي',
    logout: 'تسجيل الخروج',
    search: 'بحث',
    searchHint: 'قنوات، أفلام، مسلسلات...',
    searchEmpty: 'ابحث في كل المحتوى الخاص بك',
    searchNoResults: 'لا توجد نتائج',
    channels: 'القنوات',
    movies: 'أفلام',
    series: 'مسلسلات',
    cancel: 'إلغاء',
    save: 'حفظ',
    delete: 'حذف',
    confirm: 'تأكيد',
    offline: 'غير متصل',
  );

  static L10n of(AppLanguage language) => switch (language) {
        AppLanguage.fr => fr,
        AppLanguage.en => en,
        AppLanguage.ar => ar,
      };
}
