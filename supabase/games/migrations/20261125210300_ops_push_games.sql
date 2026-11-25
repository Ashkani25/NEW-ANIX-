-- Ops · push notifications (games project eyzafhrefnqlwcjpcdyg). Rollback: supabase/maintenance/rollback_ops_push_games.sql
-- Tournament / match notifications (nx_t_notifications) and game invites (nx_invites) are relayed, one REST call per
-- statement, to core public.nx_push_notify_batch (service role; Vault nx_social_url + nx_social_service_key, the same
-- channel nx_wallet_push uses). Core drops users without a registered device and calls the push-send Edge Function.
-- In-app delivery (Realtime on these tables) is untouched.

create or replace function public._nx_push_relay(p_items jsonb)
returns void
language plpgsql security definer set search_path = public, extensions
as $$
declare url text := _nx_secret('nx_social_url'); key text := _nx_secret('nx_social_service_key');
begin
  if url is null or key is null or p_items is null or jsonb_array_length(p_items) = 0 then return; end if;
  perform net.http_post(url := url || '/rest/v1/rpc/nx_push_notify_batch',
    headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', key, 'Authorization', 'Bearer ' || key),
    body := jsonb_build_object('p_items', p_items), timeout_milliseconds := 8000);
exception when others then
  raise warning '_nx_push_relay: %', sqlerrm;  -- push must never break the insert
end $$;

create or replace function public._nx_push_on_t_notif()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare items jsonb;
begin
  select jsonb_agg(jsonb_build_object('user_id', n.user_id, 'kind', n.kind,
           'data', coalesce(n.data, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object('tournament', n.tournament_id,
                     'tmatch', n.tmatch, 'notification', n.id,
                     'route', case when n.tournament_id is null then '/tournaments' else '/tournaments/' || n.tournament_id end))))
    into items
    from (select * from new_rows limit 500) n
   where n.user_id is not null
     -- informational kinds the app only lists in-app; everything time-critical or outcome-related is pushed
     and n.kind not in ('registered', 'waitlisted', 'bye', 'no_checkin', 'result_corrected', 'refund');
  perform _nx_push_relay(items);
  return null;
exception when others then return null;
end $$;

create or replace function public._nx_push_on_invite()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare items jsonb;
begin
  select jsonb_agg(jsonb_build_object('user_id', i.to_user, 'kind', 'invite', 'data', jsonb_strip_nulls(jsonb_build_object(
           'invite', i.id, 'actor', i.from_user, 'actor_name', coalesce(nullif(i.payload ->> 'from_name', ''), p.username),
           'room', i.room_id, 'game', coalesce(i.payload ->> 'game', i.kind),
           'route', case when coalesce(i.payload ->> 'game', '') <> '' and coalesce(i.payload ->> 'code', '') <> ''
                         then '/online/' || (i.payload ->> 'game') || '?code=' || (i.payload ->> 'code') else '/hub' end))))
    into items
    from (select * from new_rows limit 200) i
    left join profiles p on p.id = i.from_user
   where i.to_user is not null and coalesce(i.status, 'pending') = 'pending'
     and not exists (select 1 from user_blocks b where b.blocker = i.to_user and b.blocked = i.from_user);
  perform _nx_push_relay(items);
  return null;
exception when others then return null;
end $$;

revoke all on function public._nx_push_relay(jsonb) from public, anon, authenticated;
revoke all on function public._nx_push_on_t_notif() from public, anon, authenticated;
revoke all on function public._nx_push_on_invite() from public, anon, authenticated;

drop trigger if exists nx_push_t_notif on public.nx_t_notifications;
create trigger nx_push_t_notif after insert on public.nx_t_notifications
  referencing new table as new_rows for each statement execute function public._nx_push_on_t_notif();
drop trigger if exists nx_push_invite on public.nx_invites;
create trigger nx_push_invite after insert on public.nx_invites
  referencing new table as new_rows for each statement execute function public._nx_push_on_invite();
