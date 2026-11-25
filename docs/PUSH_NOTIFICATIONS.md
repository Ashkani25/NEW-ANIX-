# Push notifications (FCM) — status and how to switch them on

## Why push did not work

* The app had **no remote push client** at all: only `flutter_local_notifications` (in-app Realtime banners while the
  app runs, plus locally scheduled 10-minute tournament reminders). No device ever registered a token —
  `core.device_tokens` has 0 rows, and `register_device` was no longer executable by clients (sweep lockdowns).
* The only server trigger (`core.notifications` → `_push_dispatch` → `push-send`) hangs off the **legacy v1
  notifications table**, which nothing writes anymore. Tournaments/invites live on the games project, chats in `nx_*`.
* The Edge Function `push-send` has no `FCM_SERVICE_ACCOUNT` secret, so it answers `{skipped:"fcm_not_configured"}`.

## What is in place now (deployed / applied 2026-11-25)

| Layer | What |
|---|---|
| Client | `lib/core/push/push_service.dart` — `firebase_core` + `firebase_messaging`, initialised from `--dart-define` options (no `google-services.json`, no Gradle plugin). **Off unless `FCM_ENABLED=true` and all four options are set.** Registers the token via `nx_push_register` for signed-in non-guest accounts, deletes it on sign-out, creates the Android channels, opens `data.route` on tap. Foreground messages are ignored (in-app watchers already show them); the tournament watcher skips its own background tray notification once push is active. |
| Core DB | `nx_push_register` / `nx_push_unregister` (authenticated; max 5 devices per account), `nx_push_notify_batch` (service role), fa/en texts in `_nx_push_text`, triggers on `nx_messages` (chat members, not muted, not blocking the author) and `nx_calls`. Migration `supabase/migrations/20261125210300_ops_push_core.sql`. |
| Games DB | statement-level triggers on `nx_t_notifications` (tournament / match events) and `nx_invites` (game invites) relay one REST call per statement to core `nx_push_notify_batch` (Vault `nx_social_url` + `nx_social_service_key`). Migration `supabase/games/migrations/20261125210300_ops_push_games.sql`. |
| Edge | `push-send` (now in the repo, `supabase/functions/push-send`) — channels for message/call/invite/match kinds, tag collapses per chat / match. |

Every step returns early for users without a registered device, so this costs nothing until a push-enabled build
ships. Rollbacks: `supabase/maintenance/rollback_ops_push_core.sql`, `rollback_ops_push_games.sql`.

## What the owner has to do

1. Firebase console → create (or pick) a project → add an **Android app** with package `com.nexora.nexora`.
2. From the Android app's config (the values inside `google-services.json`) set **repo Variables**
   (Settings → Secrets and variables → Actions → Variables):
   `FCM_ENABLED=true`, `FCM_API_KEY` (`current_key`), `FCM_APP_ID` (`mobilesdk_app_id`),
   `FCM_SENDER_ID` (`project_number`), `FCM_PROJECT_ID` (`project_id`). These are public client values.
3. Firebase console → Project settings → Service accounts → **Generate new private key**, then set it as the
   push-send secret (core project):
   `supabase secrets set --project-ref eisstodgncimypdawisy FCM_SERVICE_ACCOUNT="$(cat service-account.json)"`
4. Build a new APK. Check: sign in on a phone → `select count(*) from device_tokens;` on core > 0 → send a chat
   message from another account with the app in the background.

Note: FCM needs Google Play services on the phone. Many devices in Iran (and some Cafe Bazaar users) lack them or
cannot reach FCM reliably; on those phones the in-app banners and local reminders keep working as before.
