-- Sweep S6 (core): tables/views of the retired v1 backend (rooms/matches/game_state/clubs/cups/tournaments/messages ...)
-- are not used by the app (all game/tournament data lives on the games project, chats in nx_*), but stayed readable —
-- several with USING (true): game_state, matches, inventory, admins, clubs, ... — and some writable. Data is kept;
-- clients simply lose all table privileges on them (SECURITY DEFINER functions and service_role are unaffected).
revoke all on table public.admin_applications,public.admin_audit,public.admin_bank_ledger,public.admin_banks,public.admins,public.arena_stakes,public.arena_tiers,public.challenge_defs,public.club_challenges,public.club_list,public.club_members,public.club_requests,public.clubs,public.conversation_members,public.conversations,public.cup_games,public.cup_ledger,public.cup_lineups,public.cup_matches,public.cup_payouts,public.cup_players,public.cup_rankings,public.cups,public.device_tokens,public.disc_packs,public.discs,public.friends,public.game_leaderboard,public.game_moves,public.game_private,public.game_ratings,public.game_room_list,public.game_secret,public.game_state,public.gm_quiz_bank,public.inbox,public.inventory,public.leaderboard,public.leagues,public.matches,public.messages,public.mm_tickets,public.notifications,public.profile_stats,public.public_conversations,public.room_list,public.room_players,public.rooms,public.season_claims,public.season_rewards,public.seasons,public.standings,public.tournament_codes,public.tournament_entries,public.tournament_matches,public.tournament_prizes,public.tournaments,public.user_challenges,public.xp_events from anon, authenticated;

-- core copy of nx_matches (the app uses the games project's): same players-only rule as games (#6)
drop policy if exists nx_matches_read on public.nx_matches;
create policy nx_matches_read on public.nx_matches for select to authenticated using (auth.uid() = any(players));
revoke insert, update, delete, truncate on table public.nx_matches from anon, authenticated;
revoke all on table public.nx_matches from anon;
