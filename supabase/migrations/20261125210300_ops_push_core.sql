-- Ops · push notifications (core project eisstodgncimypdawisy). Rollback: supabase/maintenance/rollback_ops_push_core.sql
--
-- Delivery path: event -> nx_push_notify(_batch) -> pg_net -> Edge Function push-send (x-push-secret = Vault
-- push_webhook_secret) -> FCM HTTP v1. push-send answers {skipped:"fcm_not_configured"} until the function secret
-- FCM_SERVICE_ACCOUNT (Firebase service-account JSON) is set, and every step returns early for users without a
-- registered device, so nothing here costs anything until the app build with FCM_ENABLED registers tokens.
--
-- Sources wired here (core): chat messages (nx_messages) and incoming calls (nx_calls).
-- Sources on the games project (tournament / match notifications, game invites) call nx_push_notify_batch over REST
-- with the service key (migration supabase/games/... ops_push_games).

-- 1) device registration (the app calls these; device_tokens itself stays closed to clients since sweep S6)
create or replace function public.nx_push_register(p_token text, p_platform text default 'android', p_locale text default null)
returns boolean
language plpgsql security definer set search_path = public
as $$
declare uid uuid := auth.uid();
begin
  if uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then return false; end if;
  if p_token is null or length(p_token) not between 20 and 4096 or p_token !~ '^[A-Za-z0-9_:\-.]+$' then return false; end if;
  insert into device_tokens(token, user_id, platform, locale, updated_at)
  values (p_token, uid, left(coalesce(nullif(p_platform, ''), 'android'), 16), left(p_locale, 8), now())
  on conflict (token) do update set user_id = uid, platform = excluded.platform, locale = excluded.locale, updated_at = now();
  -- at most 5 devices per account (oldest go first): bounds the fan-out of one notification
  delete from device_tokens d where d.user_id = uid and d.token in (
    select token from device_tokens where user_id = uid order by updated_at desc offset 5);
  return true;
end $$;

create or replace function public.nx_push_unregister(p_token text)
returns void
language sql security definer set search_path = public
as $$ delete from device_tokens where token = p_token and user_id = auth.uid() $$;

revoke all on function public.nx_push_register(text, text, text) from public, anon;
revoke all on function public.nx_push_unregister(text) from public, anon;
grant execute on function public.nx_push_register(text, text, text) to authenticated;
grant execute on function public.nx_push_unregister(text) to authenticated;

-- 2) texts (fa / en by the device's locale); unknown kinds fall back to a generic line
create or replace function public._nx_push_text(p_kind text, p_data jsonb, p_fa boolean)
returns text[]  -- {title, body}
language plpgsql immutable set search_path = public
as $$
declare who text := coalesce(nullif(p_data ->> 'actor_name', ''), case when p_fa then 'یک نفر' else 'Someone' end);
        game text := coalesce(nullif(p_data ->> 'game', ''), '');
        t text := 'ANIX'; b text;
begin
  b := case p_kind
    when 'message'         then case when p_fa then who || ': ' || coalesce(p_data ->> 'preview', 'پیام تازه') else who || ': ' || coalesce(p_data ->> 'preview', 'New message') end
    when 'call'            then case when p_fa then who || ' تماس می‌گیرد' else who || ' is calling' end
    when 'invite'          then case when p_fa then who || ' تو را به بازی ' || game || ' دعوت کرد' else who || ' invited you to play ' || game end
    when 'match_ready'     then case when p_fa then 'بازی‌ات آماده است — «آماده‌ام» را بزن' else 'Your match is ready — tap Ready' end
    when 'match_soon'      then case when p_fa then 'بازی‌ات ۱۰ دقیقه‌ی دیگر شروع می‌شود' else 'Your match starts in 10 minutes' end
    when 'starting_soon'   then case when p_fa then 'تورنمنت ۱۰ دقیقه‌ی دیگر شروع می‌شود' else 'The tournament starts in 10 minutes' end
    when 'checkin_open'    then case when p_fa then '۱۰ دقیقه تا شروع — همین الان اعلام حضور کن' else '10 minutes to the start — check in now' end
    when 'approved'        then case when p_fa then 'ثبت‌نامت تأیید شد' else 'Registration approved' end
    when 'promoted'        then case when p_fa then 'از لیست انتظار وارد شدی' else 'You are in from the waitlist' end
    when 'rejected'        then case when p_fa then 'ثبت‌نامت رد شد' else 'Registration declined' end
    when 'drawn'           then case when p_fa then 'قرعه‌کشی انجام شد' else 'The draw is done' end
    when 'started'         then case when p_fa then 'تورنمنت شروع شد' else 'The tournament started' end
    when 'advanced'        then case when p_fa then 'به دور بعد رفتی' else 'You advanced' end
    when 'eliminated'      then case when p_fa then 'حذف شدی' else 'You were eliminated' end
    when 'prize'           then case when p_fa then 'جایزه‌ات واریز شد' else 'Your prize was paid' end
    when 'time_changed'    then case when p_fa then 'زمان تورنمنت تغییر کرد' else 'The schedule changed' end
    when 'cancelled'       then case when p_fa then 'تورنمنت لغو شد؛ ورودیه برگشت' else 'Tournament cancelled — fee refunded' end
    when 'walkover'        then case when p_fa then 'بازی واگذار شد' else 'Walkover' end
    when 'dispute'         then case when p_fa then 'اختلاف در نتیجه' else 'Result disputed' end
    when 'finished'        then case when p_fa then 'تورنمنت تمام شد' else 'Tournament finished' end
    when 'approval_needed' then case when p_fa then 'ثبت‌نام جدید منتظر تأیید' else 'New registration to approve' end
    when 'result'          then case when (p_data ->> 'draw') = 'true' then case when p_fa then 'مساوی' else 'Draw' end
                                     when (p_data ->> 'won') = 'true' then case when p_fa then 'بردی!' else 'You won!' end
                                     else case when p_fa then 'باختی' else 'You lost' end end
    else null end;
  if p_kind in ('message', 'call', 'invite') then t := case when p_fa then 'آنیکس' else 'ANIX' end;
  elsif b is not null then t := case when p_fa then 'تورنمنت' else 'Tournament' end; end if;
  return array[t, coalesce(b, case when p_fa then 'اعلان تازه' else 'New notification' end)];
end $$;

-- 3) fan-out: one pg_net call per (user with a device). Items: [{user_id, kind, data}]; service role / triggers only.
create or replace function public.nx_push_notify_batch(p_items jsonb)
returns integer
language plpgsql security definer set search_path = public, extensions
as $$
declare sec text; it record; txt text[]; n int := 0;
begin
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then return 0; end if;
  for it in
    select (e ->> 'user_id')::uuid uid, left(coalesce(e ->> 'kind', ''), 40) kind, coalesce(e -> 'data', '{}'::jsonb) data,
           (select d.locale from device_tokens d where d.user_id = (e ->> 'user_id')::uuid order by d.updated_at desc limit 1) loc
      from jsonb_array_elements(p_items) e
     where (e ->> 'user_id') ~ '^[0-9a-f-]{36}$'
       and exists (select 1 from device_tokens d where d.user_id = (e ->> 'user_id')::uuid)
     limit 500
  loop
    if sec is null then sec := coalesce(_nx_vault('push_webhook_secret'), ''); end if;
    txt := _nx_push_text(it.kind, it.data, coalesce(it.loc, 'fa') not like 'en%');
    perform net.http_post(
      url := 'https://eisstodgncimypdawisy.supabase.co/functions/v1/push-send',
      body := jsonb_build_object('user_id', it.uid, 'kind', it.kind, 'title', txt[1], 'body', txt[2], 'data', it.data),
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', sec),
      timeout_milliseconds := 5000);
    n := n + 1;
  end loop;
  return n;
exception when others then
  raise warning 'nx_push_notify_batch: %', sqlerrm;  -- push must never break the caller
  return n;
end $$;

revoke all on function public.nx_push_notify_batch(jsonb) from public, anon, authenticated;
grant execute on function public.nx_push_notify_batch(jsonb) to service_role;
revoke all on function public._nx_push_text(text, jsonb, boolean) from public, anon, authenticated;

-- 4) core sources: chat messages and calls (members of the chat except the author, not muted, not blocking the author)
create or replace function public._nx_push_on_message()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare items jsonb;
begin
  if new.author is null or coalesce(new.deleted, false) then return new; end if;
  select coalesce(jsonb_agg(jsonb_build_object('user_id', cm.user_id, 'kind', 'message', 'data', jsonb_build_object(
           'chat', new.chat_id, 'message', new.id, 'actor', new.author,
           'actor_name', coalesce(nullif(new.author_name, ''), nullif(p.display_name, ''), p.username),
           'preview', case when new.kind = 'text' then left(coalesce(new.text, ''), 80) else null end,
           'route', '/social'))), '[]'::jsonb)
    into items
    from nx_chat_members cm
    left join profiles p on p.id = new.author
   where cm.chat_id = new.chat_id and cm.user_id <> new.author and not coalesce(cm.muted, false)
     and exists (select 1 from device_tokens d where d.user_id = cm.user_id)
     and not exists (select 1 from user_blocks b where b.blocker = cm.user_id and b.blocked = new.author);
  if jsonb_array_length(items) > 0 then perform nx_push_notify_batch(items); end if;
  return new;
exception when others then return new;
end $$;

create or replace function public._nx_push_on_call()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare items jsonb;
begin
  if new.caller is null or new.ended_at is not null then return new; end if;
  select coalesce(jsonb_agg(jsonb_build_object('user_id', cm.user_id, 'kind', 'call', 'data', jsonb_build_object(
           'chat', new.chat_id, 'call', new.id, 'actor', new.caller, 'video', new.video,
           'actor_name', coalesce(nullif(p.display_name, ''), p.username), 'route', '/social'))), '[]'::jsonb)
    into items
    from nx_chat_members cm
    left join profiles p on p.id = new.caller
   where cm.chat_id = new.chat_id and cm.user_id <> new.caller
     and exists (select 1 from device_tokens d where d.user_id = cm.user_id)
     and not exists (select 1 from user_blocks b where b.blocker = cm.user_id and b.blocked = new.caller);
  if jsonb_array_length(items) > 0 then perform nx_push_notify_batch(items); end if;
  return new;
exception when others then return new;
end $$;

revoke all on function public._nx_push_on_message() from public, anon, authenticated;
revoke all on function public._nx_push_on_call() from public, anon, authenticated;

drop trigger if exists nx_push_message on public.nx_messages;
create trigger nx_push_message after insert on public.nx_messages for each row execute function public._nx_push_on_message();
drop trigger if exists nx_push_call on public.nx_calls;
create trigger nx_push_call after insert on public.nx_calls for each row execute function public._nx_push_on_call();
