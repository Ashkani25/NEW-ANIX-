# Store (Cafe Bazaar) build and release signing

## Store flavour
Run **Actions → ANIX PRO Android Build → Run workflow** with `store = bazaar` (leave `release_tag` empty).
The build passes `--dart-define=STORE=bazaar`, which:
- disables the GitHub in-app updater (`AppUpdater.sideloadEnabled == false`, no update banner, no APK download/install);
- leaves `REQUEST_INSTALL_PACKAGES` and the updater FileProvider out of the manifest (CI fails the build if the permission is still there);
- sends the force-update screen (`nx_app_config.min_version_code`) to `nx_app_config.store_url`, falling back to
  `bazaar://details?id=com.nexora.nexora` and `https://cafebazaar.ir/app/com.nexora.nexora`.
Store builds are uploaded as workflow artifacts (`ANIX-apks-bazaar`, `ANIX-arm64-v8a-apk-bazaar`) and are never published as a GitHub Release.

## Release keystore (required before the first store upload)
CI signs with a real release key when these repository secrets all exist, otherwise it keeps the permanent CI install key:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Create it once on a trusted machine, e.g.
`keytool -genkeypair -v -keystore release.jks -alias anix -keyalg RSA -keysize 4096 -validity 10000`,
and keep two offline backups: if this key is lost, store updates of the app become impossible.
Switching from the CI install key to the release key changes the signature, so a release-signed APK will not install over a CI-signed one (uninstall first; the app is not released yet).
The SHA-256 certificate fingerprint is printed in the "Verify installable release outputs" step.

## Force update / maintenance
Owner only: `select nx_admin_set_app_config('{"min_version_code": 350, "store_url": "bazaar://details?id=com.nexora.nexora"}')`
(or `{"maintenance": true, "message_fa": "...", "message_en": "..."}`). Version codes are `300 + workflow run number`.
