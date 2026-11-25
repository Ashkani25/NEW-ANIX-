-- Sweep S5 (games realtime): the match channel `nxm:<match id>` was a PUBLIC Realtime channel and the app applied
-- broadcast 'mv' payloads as if they were server rows, so anyone on the channel could inject moves for any seat and
-- bypass every nx_push_move check. The app now treats 'mv' only as a "fetch" hint and joins the channel as private;
-- these Realtime Authorization policies admit only the match's players.
drop policy if exists nx_match_channel_read on realtime.messages;
create policy nx_match_channel_read on realtime.messages for select to authenticated
  using (realtime.topic() ~ '^nxm:[0-9a-fA-F-]{36}$' and public.nx_in_match(substr(realtime.topic(), 5)::uuid));
drop policy if exists nx_match_channel_write on realtime.messages;
create policy nx_match_channel_write on realtime.messages for insert to authenticated
  with check (realtime.topic() ~ '^nxm:[0-9a-fA-F-]{36}$' and public.nx_in_match(substr(realtime.topic(), 5)::uuid));
