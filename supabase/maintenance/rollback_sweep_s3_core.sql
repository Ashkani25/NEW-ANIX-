-- rollback snapshot taken 2026-11-25T17:17:58Z from project eisstodgncimypdawisy (state BEFORE the fix)
CREATE OR REPLACE FUNCTION public.nx_award(p_event text, p_xp integer, p_coins integer, p_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  ev text := left(coalesce(p_event, ''), 120);
  day0 timestamptz := date_trunc('day', now());
  rl nx_reward_rules;
  today_xp int; today_coins int; n int; streak int := 0;
  gx int; gc int;
  r record;
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_key is null or length(p_key) < 4 then raise exception 'bad key'; end if;
  perform set_config('nx.trusted', '1', true);
  select p.xp, p.coins into r from profiles p where p.id = me;
  if exists (select 1 from nx_xp_events x where x.user_id = me and x.idem_key = p_key) then
    return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', true,
                              'granted', 0, 'reason', 'duplicate');
  end if;
  if nx_is_banned(me) then
    return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                              'granted', 0, 'reason', 'banned');
  end if;
  if ev !~ '^[A-Za-z0-9_.:-]{1,120}$' then
    rl := null;
  else
    select * into rl from nx_reward_rules
     where coalesce(nx_reward_rules.active, true)
       and ((not nx_reward_rules.is_pattern and nx_reward_rules.event = ev)
            or (nx_reward_rules.is_pattern and ev like nx_reward_rules.event))
     order by nx_reward_rules.is_pattern, length(nx_reward_rules.event) desc
     limit 1;
  end if;
  if rl.event is null then
    return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                              'granted', 0, 'reason', 'unknown_event');
  end if;

  -- per-rule caps
  if rl.daily_cap is not null then
    select count(*) into n from nx_xp_events x where x.user_id = me and x.rule = rl.event and x.created_at >= day0;
    if n >= rl.daily_cap then
      return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                                'granted', 0, 'reason', 'rule_daily_cap');
    end if;
  end if;
  if rl.weekly_cap is not null then
    select count(*) into n from nx_xp_events x where x.user_id = me and x.rule = rl.event
       and x.created_at >= date_trunc('week', now());
    if n >= rl.weekly_cap then
      return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                                'granted', 0, 'reason', 'rule_weekly_cap');
    end if;
  end if;
  if rl.lifetime_cap is not null then
    select count(*) into n from nx_xp_events x where x.user_id = me and x.rule = rl.event;
    if n >= rl.lifetime_cap then
      return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', 0, 'granted_coins', 0, 'dup', false,
                                'granted', 0, 'reason', 'rule_lifetime_cap');
    end if;
  end if;

  gx := greatest(0, rl.xp);
  gc := greatest(0, rl.coins);
  -- daily reward: streak bonus computed from the server's own history (+10 per consecutive day, max 7)
  if rl.event = 'daily' then
    streak := 1;
    while streak < 7 and exists (
      select 1 from nx_xp_events x
       where x.user_id = me and x.rule = 'daily'
         and x.created_at >= day0 - make_interval(days => streak)
         and x.created_at <  day0 - make_interval(days => streak - 1)) loop
      streak := streak + 1;
    end loop;
    gc := gc + least(streak, 7) * 10;
  end if;

  -- global daily caps (3000 XP, 1500 coins), achievements excluded
  if rl.counts_to_cap then
    select coalesce(sum(e.xp), 0), coalesce(sum(e.coins), 0) into today_xp, today_coins
      from nx_xp_events e
      left join nx_reward_rules rr on rr.event = e.rule
     where e.user_id = me and e.created_at >= day0 and coalesce(rr.counts_to_cap, true);
    gx := greatest(0, least(gx, 3000 - today_xp));
    gc := greatest(0, least(gc, 1500 - today_coins));
  end if;

  insert into nx_xp_events(user_id, idem_key, event, xp, coins, rule) values (me, p_key, ev, gx, gc, rl.event);
  if gx > 0 or gc > 0 then
    update profiles set xp = xp + gx, coins = coins + gc, level = level_for_xp(xp + gx) where id = me
      returning xp, coins into r;
  end if;
  if gx > 0 then insert into xp_events(user_id, amount, reason) values (me, gx, 'nexora:' || left(ev, 100)); end if;
  return jsonb_build_object('xp', r.xp, 'coins', r.coins, 'granted_xp', gx, 'granted_coins', gc, 'dup', false,
                            'granted', gx + gc, 'reason', case when gx + gc > 0 then 'ok' else 'daily_cap' end);
end $function$
;
revoke all on function nx_award(text,integer,integer,text) from public, anon, authenticated; grant execute on function nx_award(text,integer,integer,text) to authenticated;
