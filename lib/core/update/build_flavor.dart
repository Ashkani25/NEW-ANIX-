/// Build flavour injected by CI (`--dart-define=STORE=bazaar` for the Cafe Bazaar build, empty for sideload builds).
///
/// Store builds never update themselves from GitHub (stores forbid self-updating and the manifest has no
/// REQUEST_INSTALL_PACKAGES); a forced update sends the user to the store page instead.
class BuildFlavor {
  const BuildFlavor._();

  static const String store = String.fromEnvironment('STORE');
  static const bool isStoreBuild = store != '';

  /// Store page used when the server config has no `store_url`.
  static String get defaultStoreUrl {
    switch (store) {
      case 'bazaar':
        return 'bazaar://details?id=com.nexora.nexora';
      default:
        return '';
    }
  }

  /// Web fallback when the store app is not installed.
  static String get storeWebUrl {
    switch (store) {
      case 'bazaar':
        return 'https://cafebazaar.ir/app/com.nexora.nexora';
      default:
        return '';
    }
  }
}
