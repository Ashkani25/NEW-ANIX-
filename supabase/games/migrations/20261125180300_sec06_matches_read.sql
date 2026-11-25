-- #6 (games): nx_matches was readable by every signed-in user (USING true): seeds, players, settings and results of
-- every match. Only the match's players (and staff with the 'rooms' permission) can read a match row now. The app
-- only opens a match it plays in (OnlineMatchPage refuses non-players), talk-room listeners use nx_rooms.match_id.
drop policy if exists nx_matches_read on public.nx_matches;
create policy nx_matches_read on public.nx_matches for select to authenticated
  using (auth.uid() = any(players) or public.nx_has_perm('rooms', auth.uid()));
revoke insert, update, delete, truncate on table public.nx_matches from anon, authenticated;
revoke all on table public.nx_matches from anon;
