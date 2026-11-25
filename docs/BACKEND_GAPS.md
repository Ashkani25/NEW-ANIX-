# NEXORA — BACKEND-DEPENDENT CAPABILITIES (UNIMPLEMENTED / SERVER-GATED)
_Deliverable §9. Honest list of capabilities that are not yet real. The app never simulates them — it shows disabled states, `OnlineOnlyNotice`, or truthful "needs server" explanations. No fake data, no fake success._

## 1. Not implemented at all (no client path, no backend)
| Capability | Current UI treatment |
|---|---|
| **Voice/video calls (LiveKit)** | Call screen exists (`/call/:chatId`) and requests tokens through the trusted `nx-call-token` Edge Function — but with no LiveKit server connected, calls do not connect. The UI shows honest connecting/denied/unavailable states; no call is simulated. |
| **Real-user messaging** | Orbit Network conversation UI is fully built; sending to real users requires the server. Offline builds show `OnlineOnlyNotice`. |
| **Public Nova Gallery sharing** | Posts/stories compose and save locally; public publishing to other users requires the server. |
| **Online matchmaking / real opponents** | Online lobby, match link and host-authoritative settlement are built against the games project; with no server they stay offline (bots / pass-and-play). |
| **Global leaderboards / tournament settlement** | Leaderboard and tournament pages are built; authoritative rankings/brackets require the server. Local stats always shown in Personal Orbit. |

## 2. Implemented client-side, gated on server availability
| Capability | Gate |
|---|---|
| Sign-in / sign-up (username/email + password) | `OnlineService` — `not_configured` state when no Supabase config |
| Cloud profile sync | `CloudProfileSync` — runs after sign-in; offline = local-only |
| Rooms (talk + game lobbies), capacity rules | `room_capacity.dart` mirrors server `nx_room_capacity`; local fallback when RPC absent |
| Tournaments (create/manage/brackets/inbox/join codes) | Tournament repository + watcher; needs games project |
| Exchange purchases | `ProfileService.purchase` — offline = local wallet; online = server-confirmed (server refuses insufficient balance; client undoes local spend) |
| Oracle AI | On-device knowledge base; `nx-oracle` Edge Function exists for server mode but the client answers offline and says so |
| Admin panel / Oracle persona config | `AdminApi` server-checked; client role labels are never trusted |
| Updates | `AppUpdater` reads GitHub releases (`anix-*` tags, `ANIX-universal.apk` asset) |

## 3. Two-Supabase split (preserved, not collapsed)
- **Core project** (auth project): auth, profiles, social (follows/friend requests), Nova, chat, Oracle, admin, tournaments API.
- **Games project**: rooms, matchmaking, matches, leaderboards, tournament engine — no own auth; receives the auth project's access token.
- JWT, RLS and Edge Function boundaries preserved (`supabase/functions/nx-login`, `nx-call-token`, `nx-oracle`; games functions under `supabase/games/`). No service-role credentials or secrets in the client.

## 4. Account deletion (implemented, P0 #1)
Settings → Account & data → **Delete account permanently** (`lib/worlds/settings/delete_account.dart`).
1. **Core** `nx_delete_account(p_confirm 'DELETE', p_password, p_dry_run)` (`supabase/migrations/20261125200000_p0_01_account_deletion.sql`), self only, security definer:
   password re-check (bcrypt against `auth.users`, rate-limited 5 / 15 min) for accounts that have one; the platform owner cannot delete itself.
   Group chats / communities pass ownership to the next member (empty ones are removed), direct chats stay for the other person;
   messages in other people's chats are anonymised (`author` → null, name `[deleted]`, media blanked); tournaments pass to the platform owner;
   everything else is deleted (profile, wallet, posts, comments, likes, follows, memberships, device tokens, reports filed, error logs,
   storage objects) and finally the `auth.users` row (cascades).
2. **Games project** `nx_bridge_forget_user(p_user)` (service_role only, `supabase/games/migrations/20261125200000_p0_01_account_deletion.sql`),
   called by core over the pg_net bridge: hosted rooms pass to another member, tournaments to the platform owner, mirror profile + game rows deleted.
   The immutable tournament ledger/audit keep the bare uuid for accounting.
3. **Storage**: the client lists its files (`nx_my_storage_objects`) and removes them through the Storage API after a dry-run check.
   Leftovers (legacy `avatars`/`chat` buckets have no client delete policy) are queued by the RPC in `nx_storage_purge_queue`
   (`supabase/migrations/20261125210100_p0_01b_storage_purge.sql`, P0 #1b) and removed — blob and row — by the Edge Function
   `supabase/functions/nx-storage-purge` (kicked after the deletion and by pg_cron every 15 min).
   **Not deployed yet**: until the deploy steps in `supabase/functions/nx-storage-purge/README.md` are done, the queue only fills up.
4. Client flow: confirm dialog (type DELETE / «حذف» + password if any) → dry run → storage cleanup → delete → local wipe → local sign-out → `/auth`.
   Guests (local-only) still get "Erase all data on this phone".

## 5. Ban evasion hold (implemented, P0 #7c)
`supabase/migrations/20261125210200_p0_07c_ban_hold.sql`. When a **banned** account is deleted (self-service or by staff; trigger on
`auth.users`), `nx_ban_holds` keeps keyed HMAC-SHA256 hashes (pepper in Vault `nx_ban_hold_pepper`) of the normalised username, e-mail
and the app's random install id (`lib/core/safety/install_id.dart`, sent with sign-up / sign-in / delete). Expiry = the ban
(`banned_until` when finite, otherwise until staff clear it with `nx_owner_ban_hold_clear`; list with `nx_owner_ban_holds`).
Checked on sign-up and e-mail change (auth.users trigger, error `banned`), username claim (profiles trigger -> `username_reserved`,
`nx_username_available` false) and sign-in (client calls `nx_install_held` and signs out; the `nx-login` Edge Function refuses with
`user_banned` once redeployed). Described in the privacy policy (fa + en).
Reports: kinds `comment`, `story`, `profile` and `community` are accepted (`20261125210000_p0_07c_report_kinds.sql`); report buttons on
comments, stories and the online match result (report an opponent).
## 5. Game integrity: server match sweep, move rate limit, resume (games project)
Migration `supabase/games/migrations/20261126100000_gi_match_sweep_rate.sql` (applied live 2026-11-25; rollback
`supabase/maintenance/rollback_gi_01_games.sql`; probe `supabase/tests/security/games_gi_01_probe.sql`).
- **`_nx_match_sweep()`**, pg_cron job `nx_match_sweep` every 20 s, next to `_nx_hg_sweep` (15 s, mafia/spy/uno turn clocks).
  The server never invents a game move; it applies the authority phone's own rules later, as a safety net:
  - a seat with no sign of life (match ping, move row, room heartbeat) for 120 s (tournaments: `grace_sec` + 30 s, ≥ 60 s),
    or 60 s while its server turn clock (`nx_match_turn_state`) has run out, and no result report → server `forfeit` row
    (`by_user` = all-zero uuid, `move = {seat, idle: true, srv: true}`); one seat left → `nx_finish_match_as` (survivor wins,
    rewards/Elo) unless the survivor already reported, then the reports decide;
  - everybody gone → settled from the reports filed (same consensus as `nx_finish_match`), else `abandoned` (no rewards);
  - nothing happened for 20 min (realtime arcade games 45 min) or the match is older than 3 h → reports, else `abandoned`;
  - tournament games: absent seats are forfeited the same way, but an all-gone / stalled game is left to `nx_t_tick`
    (organizer dispute) and its row is closed only once the tournament accepted that game.
  - every action is logged in `nx_match_sweep_log` (RLS, no client access).
- **Rate limit** in `nx_push_move` / `nx_g_push`: per player per match at most 12 rows / 3 s and 90 rows / 60 s
  (`{ok:false, reason:'rate'}`; forfeits always pass). `nx_hg_act` keeps its 150 ms per-seat limit, quiz answers are one per round.
- **Resume after the app was killed** (`lib/core/online/match_resume.dart`): the match page stores the live match
  (`online.active_match.v1`: match, game, account, tournament match) and clears it when the match ends or the player
  leaves; on start-up / sign-in `MatchResumeWatcher` asks `nx_my_active_match` and offers "Return to game", which opens
  route `/match/:id?game=…&t=…` (the page rebuilds the game from the move log).
