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
3. **Storage**: the client lists its files (`nx_my_storage_objects`) and removes them through the Storage API after a dry-run check; the RPC
   then clears any leftover object rows (legacy `avatars`/`chat` buckets have no client delete policy, so their blobs may stay orphaned in the
   bucket store until a service-side cleanup runs).
4. Client flow: confirm dialog (type DELETE / «حذف» + password if any) → dry run → storage cleanup → delete → local wipe → local sign-out → `/auth`.
   Guests (local-only) still get "Erase all data on this phone".
