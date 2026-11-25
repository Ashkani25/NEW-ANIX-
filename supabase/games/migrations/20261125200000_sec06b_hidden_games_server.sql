-- #6 (part 2): server-authoritative hidden-information games (mafia, spy_mafia, uno).
--
-- Before: every phone built the same engine from nx_matches.seed (readable by every player), so a modified client
-- could compute every role (mafia), the location and the spies (spy_mafia) and every hand plus the whole draw pile
-- (uno). Night actions and the mafia-only chat travelled through the public move log / match broadcast.
--
-- Now:
--   * the full state lives in nx_hg_state (no client grants, RLS on, no policies) and is dealt with
--     gen_random_uuid() randomness when the match row is inserted (trigger, every start path incl. tournaments);
--   * each player reads ONLY their own view: nx_match_secrets slot 'view' (RLS user_id = auth.uid()), rebuilt by
--     the server after every change (_nx_hg_publish). Public changes also append a hint row
--     (nx_match_moves kind 'srv', seat -1, by_user = nil uuid) so phones refresh at once; private changes (night actions,
--     mafia-only chat, a drawn card) update only the affected views and add no public row;
--   * every input goes through nx_hg_act(match, action): validated against the state, phases / votes / night /
--     turns resolved and the winner decided on the server, which finishes the match itself (nx.server_result);
--   * timeouts: nx_hg_act(match, {a:'tick'}) by any player after the deadline, plus a 15 s cron sweep;
--   * leaving (forfeit rows from nx_forfeit / nx_idle_forfeit) is applied to the state by a trigger;
--   * clients can no longer post ordinary move rows for these games, report their own result, or write secrets
--     (nx_put_secret retired: it let seat 0 write any player's secret).

-- ---------------------------------------------------------------- helpers
create or replace function public._nx_rand(p_n int) returns int
language sql volatile set search_path = public as $$
  select case when coalesce(p_n, 0) <= 0 then 0
              else (('x' || substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 8))::bit(32)::bigint % p_n)::int end
$$;

create or replace function public._nx_shuffle(p_a int[]) returns int[]
language sql volatile set search_path = public as $$
  select coalesce(array_agg(x order by gen_random_uuid()), '{}'::int[]) from unnest(p_a) x
$$;

create or replace function public._nx_ja_int(p jsonb) returns int[]
language sql immutable set search_path = public as $$
  select coalesce(array_agg((x)::int order by o), '{}'::int[])
    from jsonb_array_elements_text(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) with ordinality t(x, o)
$$;

create or replace function public._nx_ja_bool(p jsonb) returns boolean[]
language sql immutable set search_path = public as $$
  select coalesce(array_agg((x)::boolean order by o), '{}'::boolean[])
    from jsonb_array_elements_text(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) with ordinality t(x, o)
$$;

create or replace function public._nx_ja_text(p jsonb) returns text[]
language sql immutable set search_path = public as $$
  select coalesce(array_agg(x order by o), '{}'::text[])
    from jsonb_array_elements_text(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) with ordinality t(x, o)
$$;

create or replace function public._nx_jint(p jsonb) returns int
language sql immutable set search_path = public as $$
  select case when jsonb_typeof(p) = 'number' then (p #>> '{}')::numeric::int else null end
$$;

-- ---------------------------------------------------------------- state
create table if not exists public.nx_hg_state (
  match_id uuid primary key references public.nx_matches(id) on delete cascade,
  game text not null,
  st jsonb not null,
  ver int not null default 0,
  deadline timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.nx_hg_state enable row level security;
revoke all on public.nx_hg_state from public, anon, authenticated;
create index if not exists nx_hg_state_deadline on public.nx_hg_state (deadline);

create or replace function public._nx_hg_games() returns text[]
language sql immutable as $$ select array['mafia', 'spy_mafia', 'uno']::text[] $$;

-- ================================================================= MAFIA
create or replace function public._nx_mafia_is_m(r text) returns boolean
language sql immutable as $$ select r in ('godfather', 'mafia') $$;

create or replace function public._nx_mafia_label(r text, fa boolean) returns text
language sql immutable as $$
  select case r
    when 'godfather' then case when fa then 'پدرخوانده' else 'Godfather' end
    when 'mafia' then case when fa then 'مافیا' else 'Mafia' end
    when 'doctor' then case when fa then 'دکتر' else 'Doctor' end
    when 'detective' then case when fa then 'کارآگاه' else 'Detective' end
    when 'sniper' then case when fa then 'تک‌تیرانداز' else 'Sniper' end
    else case when fa then 'شهروند' else 'Citizen' end end
$$;

-- Same distribution as MafiaEngine.distributeRoles (6..12 players, sniper from 7), shuffled server-side.
create or replace function public._nx_mafia_init(p_n int) returns jsonb
language plpgsql volatile set search_path = public as $$
declare n int := greatest(6, least(12, p_n)); r text[] := array['godfather']; i int;
begin
  for i in 2 .. (case when n >= 9 then 3 else 2 end) loop r := r || 'mafia'::text; end loop;
  r := r || 'doctor'::text || 'detective'::text;
  if n >= 7 then r := r || 'sniper'::text; end if;
  while coalesce(array_length(r, 1), 0) < n loop r := r || 'citizen'::text; end loop;
  select array_agg(x order by gen_random_uuid()) into r from unnest(r) x;
  return jsonb_build_object(
    'n', n, 'roles', to_jsonb(r),
    'alive', to_jsonb(array_fill(true, array[n])), 'revealed', to_jsonb(array_fill(false, array[n])),
    'out', '[]'::jsonb, 'ready', '[]'::jsonb, 'defs', '[]'::jsonb,
    'stage', 'intro', 'day', 1, 'acts', '{}'::jsonb,
    'last_doc', null, 'doc_self', false, 'bullets', 1, 'det', '{}'::jsonb,
    'winner', null, 'log', '[]'::jsonb, 'chat', '[]'::jsonb, 'last', null,
    'dl', extract(epoch from now() + interval '60 seconds'));
end $$;

-- Night actors: Mafia lead (alive Godfather, else the lowest alive Mafia), Doctor, Detective, Sniper with a bullet.
create or replace function public._nx_mafia_actors(p_st jsonb) returns int[]
language plpgsql immutable set search_path = public as $$
declare n int := (p_st->>'n')::int; roles text[] := _nx_ja_text(p_st->'roles'); alive boolean[] := _nx_ja_bool(p_st->'alive');
        lead int; doc int; dtc int; snp int;
begin
  select min(g) into lead from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'godfather';
  if lead is null then
    select min(g) into lead from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'mafia';
  end if;
  select min(g) into doc from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'doctor';
  select min(g) into dtc from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'detective';
  if coalesce((p_st->>'bullets')::int, 0) > 0 then
    select min(g) into snp from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'sniper';
  end if;
  return array_remove(array[lead, doc, dtc, snp], null);
end $$;

-- Legal targets for [p_seat]'s pending action in the current stage; null = nothing to do now.
create or replace function public._nx_mafia_legal(p_st jsonb, p_seat int) returns int[]
language plpgsql immutable set search_path = public as $$
declare n int := (p_st->>'n')::int; roles text[] := _nx_ja_text(p_st->'roles'); alive boolean[] := _nx_ja_bool(p_st->'alive');
        stage text := p_st->>'stage'; acts jsonb := coalesce(p_st->'acts', '{}'::jsonb); r text; out int[];
        last_doc int := _nx_jint(p_st->'last_doc'); doc_self boolean := coalesce((p_st->>'doc_self')::boolean, false);
begin
  if p_seat is null or p_seat < 0 or p_seat >= n or not alive[p_seat + 1] or p_st->>'winner' is not null then return null; end if;
  if acts ? p_seat::text then return null; end if;
  if stage = 'night' then
    if not (p_seat = any(_nx_mafia_actors(p_st))) then return null; end if;
    r := roles[p_seat + 1];
    if _nx_mafia_is_m(r) then
      select coalesce(array_agg(g order by g), '{}') into out from generate_series(0, n - 1) g
       where alive[g + 1] and not _nx_mafia_is_m(roles[g + 1]);
    elsif r = 'doctor' then
      select coalesce(array_agg(g order by g), '{}') into out from generate_series(0, n - 1) g
       where alive[g + 1] and g is distinct from last_doc and not (g = p_seat and doc_self);
    else
      select coalesce(array_agg(g order by g), '{}') into out from generate_series(0, n - 1) g
       where alive[g + 1] and g <> p_seat;
    end if;
    return out;
  elsif stage = 'nominate' then
    select coalesce(array_agg(g order by g), '{}') into out from generate_series(0, n - 1) g where alive[g + 1] and g <> p_seat;
    return out;
  elsif stage = 'final' then
    select coalesce(array_agg(d order by d), '{}') into out from unnest(_nx_ja_int(p_st->'defs')) d where d <> p_seat;
    return out;
  end if;
  return null;
end $$;

create or replace function public._nx_mafia_step(p_st jsonb, p_seat int, p_act jsonb, p_names text[])
returns jsonb language plpgsql volatile set search_path = public as $$
declare
  n int := (p_st->>'n')::int;
  roles text[] := _nx_ja_text(p_st->'roles');
  alive boolean[] := _nx_ja_bool(p_st->'alive');
  revealed boolean[] := _nx_ja_bool(p_st->'revealed');
  outs int[] := _nx_ja_int(p_st->'out');
  ready int[] := _nx_ja_int(p_st->'ready');
  defs int[] := _nx_ja_int(p_st->'defs');
  stage text := p_st->>'stage';
  dday int := (p_st->>'day')::int;
  acts jsonb := coalesce(p_st->'acts', '{}'::jsonb);
  last_doc int := _nx_jint(p_st->'last_doc');
  doc_self boolean := coalesce((p_st->>'doc_self')::boolean, false);
  bullets int := coalesce((p_st->>'bullets')::int, 1);
  det jsonb := coalesce(p_st->'det', '{}'::jsonb);
  winner text := p_st->>'winner';
  lg jsonb := coalesce(p_st->'log', '[]'::jsonb);
  chat jsonb := coalesce(p_st->'chat', '[]'::jsonb);
  lastv jsonb := p_st->'last';
  dl double precision := (p_st->>'dl')::double precision;
  a text := coalesce(p_act->>'a', '');
  t int := _nx_jint(p_act->'t');
  fill boolean := false;
  priv_seats int[] := null;
  ev jsonb := jsonb_build_object('t', 'u');
  legal int[]; actors int[]; voters int[]; cur jsonb;
  gi int; k text; v jsonb; changed boolean; guard int := 0;
  lead int; doc int; dtc int; snp int; mt int; ds int; dc int; sn int;
  deaths int[]; causes text[]; saved boolean; tally jsonb; top int; spares int; leaders int[]; outp int; thr int;
  mafia_alive int; town_alive int; nm text; rl text; txt text; won int[] := null; mafia_chat boolean;
begin
  for gi in 1 .. n loop p_names[gi] := coalesce(nullif(p_names[gi], ''), 'Pilot ' || gi); end loop;
  if winner is not null or stage = 'over' then return jsonb_build_object('err', 'over'); end if;

  if a = 'leave' then
    if not (p_seat = any(outs)) then outs := outs || p_seat; end if;
    if alive[p_seat + 1] then
      alive[p_seat + 1] := false; revealed[p_seat + 1] := true;
      lg := lg || jsonb_build_object('d', dday, 'n', stage = 'night', 'k', 'death', 'to', null,
        'fa', p_names[p_seat + 1] || ' (' || _nx_mafia_label(roles[p_seat + 1], true) || ') بازی را ترک کرد.',
        'en', p_names[p_seat + 1] || ' (' || _nx_mafia_label(roles[p_seat + 1], false) || ') left the game.');
    end if;
    acts := acts - p_seat::text;
    ev := jsonb_build_object('t', 'leave', 's', p_seat);
  elsif a = 'timeout' then
    fill := true;
    ev := jsonb_build_object('t', 'timeout');
  elsif a = 'ready' then
    if stage <> 'intro' then return jsonb_build_object('err', 'stage'); end if;
    if not alive[p_seat + 1] then return jsonb_build_object('err', 'out'); end if;
    if p_seat = any(ready) then return jsonb_build_object('err', 'done'); end if;
    ready := ready || p_seat;
    ev := jsonb_build_object('t', 'ready', 's', p_seat);
  elsif a in ('night', 'nom', 'final') then
    if (a = 'night' and stage <> 'night') or (a = 'nom' and stage <> 'nominate') or (a = 'final' and stage <> 'final') then
      return jsonb_build_object('err', 'stage');
    end if;
    if p_act ? 'd' and _nx_jint(p_act->'d') is distinct from dday then return jsonb_build_object('err', 'stale'); end if;
    legal := _nx_mafia_legal(p_st, p_seat);
    if legal is null then return jsonb_build_object('err', 'not_yours'); end if;
    if t is not null and not (t = any(legal)) then return jsonb_build_object('err', 'illegal'); end if;
    acts := acts || jsonb_build_object(p_seat::text, t);
    if a = 'night' then
      priv_seats := array[p_seat];   -- nobody else learns that a night role acted
    else
      ev := jsonb_build_object('t', 'voted', 's', p_seat);
    end if;
  elsif a = 'chat' then
    txt := left(btrim(regexp_replace(coalesce(p_act->>'t', ''), '[[:cntrl:]]', ' ', 'g')), 240);
    if txt = '' then return jsonb_build_object('err', 'empty'); end if;
    if not alive[p_seat + 1] then return jsonb_build_object('err', 'out'); end if;
    mafia_chat := stage = 'night';
    if mafia_chat and not _nx_mafia_is_m(roles[p_seat + 1]) then return jsonb_build_object('err', 'night'); end if;
    chat := chat || jsonb_build_object('s', p_seat, 't', txt, 'm', mafia_chat, 'd', dday);
    if jsonb_array_length(chat) > 60 then
      select jsonb_agg(e order by o) into chat
        from jsonb_array_elements(chat) with ordinality x(e, o) where o > jsonb_array_length(chat) - 60;
    end if;
    if mafia_chat then
      select array_agg(g) into priv_seats from generate_series(0, n - 1) g where _nx_mafia_is_m(roles[g + 1]);
    else
      ev := jsonb_build_object('t', 'chat');
    end if;
  else
    return jsonb_build_object('err', 'bad_action');
  end if;

  -- advance until nothing changes
  loop
    guard := guard + 1;
    exit when guard > 12;
    changed := false;
    select count(*) filter (where alive[g + 1] and _nx_mafia_is_m(roles[g + 1])),
           count(*) filter (where alive[g + 1] and not _nx_mafia_is_m(roles[g + 1]))
      into mafia_alive, town_alive from generate_series(0, n - 1) g;
    if winner is null and (mafia_alive = 0 or mafia_alive >= town_alive) then
      winner := case when mafia_alive = 0 then 'town' else 'mafia' end;
      lg := lg || jsonb_build_object('d', dday, 'n', stage = 'night', 'k', 'phase', 'to', null,
        'fa', case when winner = 'town' then 'شهروندان پیروز شدند! همه‌ی مافیا حذف شدند.' else 'مافیا ایستگاه را تسخیر کرد!' end,
        'en', case when winner = 'town' then 'The Town wins! Every Mafia is gone.' else 'The Mafia has taken the station!' end);
    end if;
    if winner is not null then
      stage := 'over'; acts := '{}'::jsonb; dl := null; priv_seats := null;
      select coalesce(array_agg(g order by g), '{}') into won from generate_series(0, n - 1) g
       where _nx_mafia_is_m(roles[g + 1]) = (winner = 'mafia') and not (g = any(outs));
      ev := jsonb_build_object('t', 'over', 'winner', winner);
      exit;
    end if;
    cur := jsonb_build_object('n', n, 'roles', to_jsonb(roles), 'alive', to_jsonb(alive), 'bullets', bullets);

    if stage = 'intro' then
      if fill then
        select coalesce(array_agg(g), '{}') into ready from generate_series(0, n - 1) g where alive[g + 1];
      end if;
      if not exists (select 1 from generate_series(0, n - 1) g where alive[g + 1] and not (g = any(ready))) then
        stage := 'night'; acts := '{}'::jsonb; dl := extract(epoch from now() + interval '75 seconds'); changed := true;
      end if;

    elsif stage = 'night' then
      actors := _nx_mafia_actors(cur);
      if fill then
        foreach gi in array actors loop
          if not (acts ? gi::text) then acts := acts || jsonb_build_object(gi::text, null); end if;
        end loop;
      end if;
      if not exists (select 1 from unnest(actors) x where not (acts ? x::text)) then
        select min(g) into lead from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'godfather';
        if lead is null then select min(g) into lead from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'mafia'; end if;
        select min(g) into doc from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'doctor';
        select min(g) into dtc from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'detective';
        select min(g) into snp from generate_series(0, n - 1) g where alive[g + 1] and roles[g + 1] = 'sniper';
        mt := case when lead is not null then _nx_jint(acts->lead::text) end;
        if mt is not null and not (mt >= 0 and mt < n and alive[mt + 1] and not _nx_mafia_is_m(roles[mt + 1])) then mt := null; end if;
        ds := case when doc is not null then _nx_jint(acts->doc::text) end;
        if ds is not null and not (ds >= 0 and ds < n and alive[ds + 1] and ds is distinct from last_doc and not (ds = doc and doc_self)) then ds := null; end if;
        dc := case when dtc is not null then _nx_jint(acts->dtc::text) end;
        if dc is not null and not (dc >= 0 and dc < n and alive[dc + 1] and dc <> dtc) then dc := null; end if;
        sn := case when snp is not null and bullets > 0 then _nx_jint(acts->snp::text) end;
        if sn is not null and not (sn >= 0 and sn < n and alive[sn + 1] and sn <> snp) then sn := null; end if;
        deaths := '{}'; causes := '{}'; saved := false;
        if mt is not null then
          if ds = mt then saved := true; else deaths := deaths || mt; causes := causes || 'night'::text; end if;
        end if;
        if sn is not null then
          bullets := bullets - 1;
          if _nx_mafia_is_m(roles[sn + 1]) then
            if ds = sn then saved := true;
            elsif not (sn = any(deaths)) then deaths := deaths || sn; causes := causes || 'sniper'::text; end if;
          elsif not (snp = any(deaths)) then
            deaths := deaths || snp; causes := causes || 'backfire'::text;
          end if;
        end if;
        if dc is not null then
          det := det || jsonb_build_object(dc::text, roles[dc + 1] = 'mafia');
          lg := lg || jsonb_build_object('d', dday, 'n', true, 'k', 'check', 'to', jsonb_build_array(dtc),
            'fa', 'استعلام ' || p_names[dc + 1] || ': ' || case when roles[dc + 1] = 'mafia' then 'مافیا' else 'بی‌گناه' end,
            'en', 'Investigation of ' || p_names[dc + 1] || ': ' || case when roles[dc + 1] = 'mafia' then 'MAFIA' else 'innocent' end);
        end if;
        if doc is not null then
          last_doc := ds;
          if ds is not null and ds = doc then doc_self := true; end if;
          if ds is not null then
            lg := lg || jsonb_build_object('d', dday, 'n', true, 'k', 'save', 'to', jsonb_build_array(doc),
              'fa', 'محافظت از ' || p_names[ds + 1] || case when saved and ds in (mt, sn) then ' — حمله دفع شد!' else '' end,
              'en', 'Protected ' || p_names[ds + 1] || case when saved and ds in (mt, sn) then ' — attack prevented!' else '' end);
          end if;
        end if;
        for gi in 1 .. coalesce(array_length(deaths, 1), 0) loop
          outp := deaths[gi];
          if alive[outp + 1] then
            alive[outp + 1] := false; revealed[outp + 1] := true;
            nm := p_names[outp + 1];
            lg := lg || jsonb_build_object('d', dday, 'n', true, 'k', 'death', 'to', null,
              'fa', nm || ' (' || _nx_mafia_label(roles[outp + 1], true) || ') ' || case causes[gi]
                      when 'night' then 'در شب کشته شد.' when 'sniper' then 'با شلیک تک‌تیرانداز از پا درآمد.'
                      else 'به یک بی‌گناه شلیک کرد و از بازی خارج شد.' end,
              'en', nm || ' (' || _nx_mafia_label(roles[outp + 1], false) || ') ' || case causes[gi]
                      when 'night' then 'was killed in the night.' when 'sniper' then 'was taken down by the Sniper.'
                      else 'shot an innocent and left the game.' end);
          end if;
        end loop;
        if coalesce(array_length(deaths, 1), 0) = 0 then
          lg := lg || jsonb_build_object('d', dday, 'n', true, 'k', 'info', 'to', null,
            'fa', 'شب ' || dday || ' بدون قربانی گذشت.', 'en', 'Night ' || dday || ' passed with no victim.');
        end if;
        if saved then
          lg := lg || jsonb_build_object('d', dday, 'n', true, 'k', 'save', 'to', null,
            'fa', 'دکتر دیشب جان یک نفر را نجات داد.', 'en', 'The Doctor saved someone last night.');
        end if;
        stage := 'nominate'; acts := '{}'::jsonb; dl := extract(epoch from now() + interval '180 seconds');
        changed := true; priv_seats := null; ev := jsonb_build_object('t', 'dawn', 'day', dday);
      end if;

    elsif stage in ('nominate', 'final') then
      select coalesce(array_agg(g), '{}') into voters from generate_series(0, n - 1) g where alive[g + 1];
      if fill then
        foreach gi in array voters loop
          if not (acts ? gi::text) then acts := acts || jsonb_build_object(gi::text, null); end if;
        end loop;
      end if;
      if not exists (select 1 from unnest(voters) x where not (acts ? x::text)) then
        tally := '{}'::jsonb; spares := 0;
        if stage = 'final' then
          foreach gi in array defs loop tally := tally || jsonb_build_object(gi::text, 0); end loop;
        end if;
        for k, v in select * from jsonb_each(acts) loop
          gi := k::int;
          if not alive[gi + 1] then continue; end if;
          outp := _nx_jint(v);
          if outp is null or outp = gi or outp < 0 or outp >= n or not alive[outp + 1]
             or (stage = 'final' and not (outp = any(defs))) then
            spares := spares + 1; continue;
          end if;
          tally := tally || jsonb_build_object(outp::text, coalesce((tally->>outp::text)::int, 0) + 1);
        end loop;
        select coalesce(max(value::int), 0) into top from jsonb_each_text(tally);
        if stage = 'nominate' then
          thr := case when coalesce(array_length(voters, 1), 0) <= 4 then 1 else 2 end;
          defs := '{}';
          if top >= thr then
            select coalesce(array_agg(key::int order by key::int), '{}') into defs from jsonb_each_text(tally) where value::int = top;
            if array_length(defs, 1) > 3 then defs := '{}'; end if;
          end if;
          lg := lg || jsonb_build_object('d', dday, 'n', false, 'k', 'vote', 'to', null,
            'fa', case when coalesce(array_length(defs, 1), 0) = 0 then 'رأی‌گیری اول: کسی به دفاع نرفت.'
                       else 'به دفاع رفتند: ' || (select string_agg(p_names[d + 1], '، ' order by d) from unnest(defs) d) end,
            'en', case when coalesce(array_length(defs, 1), 0) = 0 then 'First vote: nobody was put on trial.'
                       else 'On trial: ' || (select string_agg(p_names[d + 1], ', ' order by d) from unnest(defs) d) end);
          lastv := jsonb_build_object('k', 'nom', 'day', dday, 'votes', acts, 'tally', tally);
          if coalesce(array_length(defs, 1), 0) > 0 then
            stage := 'final'; acts := '{}'::jsonb; dl := extract(epoch from now() + interval '60 seconds');
            ev := jsonb_build_object('t', 'trial');
          else
            dday := dday + 1; stage := 'night'; acts := '{}'::jsonb; dl := extract(epoch from now() + interval '75 seconds');
            lg := lg || jsonb_build_object('d', dday, 'n', true, 'k', 'phase', 'to', null,
              'fa', 'شب ' || dday || ' فرا رسید.', 'en', 'Night ' || dday || ' falls.');
            ev := jsonb_build_object('t', 'night', 'day', dday);
          end if;
        else
          select coalesce(array_agg(key::int), '{}') into leaders from jsonb_each_text(tally) where value::int = top;
          outp := null;
          if top > 0 and array_length(leaders, 1) = 1 and top > spares then outp := leaders[1]; end if;
          lastv := jsonb_build_object('k', 'final', 'day', dday, 'votes', acts, 'tally', tally, 'spares', spares);
          if outp is not null then
            alive[outp + 1] := false; revealed[outp + 1] := true;
            lg := lg || jsonb_build_object('d', dday, 'n', false, 'k', 'death', 'to', null,
              'fa', p_names[outp + 1] || ' (' || _nx_mafia_label(roles[outp + 1], true) || ') با رأی شهر حذف شد.',
              'en', p_names[outp + 1] || ' (' || _nx_mafia_label(roles[outp + 1], false) || ') was voted out by the town.');
          else
            lg := lg || jsonb_build_object('d', dday, 'n', false, 'k', 'vote', 'to', null,
              'fa', 'رأی نهایی کافی نبود؛ کسی حذف نشد.', 'en', 'The final vote fell short; nobody was eliminated.');
          end if;
          defs := '{}';
          -- the next night starts unless the vote ended the game (checked at the top of the loop)
          select count(*) filter (where alive[g + 1] and _nx_mafia_is_m(roles[g + 1])),
                 count(*) filter (where alive[g + 1] and not _nx_mafia_is_m(roles[g + 1]))
            into mafia_alive, town_alive from generate_series(0, n - 1) g;
          if not (mafia_alive = 0 or mafia_alive >= town_alive) then
            dday := dday + 1;
            lg := lg || jsonb_build_object('d', dday, 'n', true, 'k', 'phase', 'to', null,
              'fa', 'شب ' || dday || ' فرا رسید.', 'en', 'Night ' || dday || ' falls.');
          end if;
          stage := 'night'; acts := '{}'::jsonb; dl := extract(epoch from now() + interval '75 seconds');
          ev := jsonb_build_object('t', 'night', 'day', dday);
        end if;
        changed := true; priv_seats := null;
      end if;
    end if;
    fill := false;
    exit when not changed;
  end loop;

  if jsonb_array_length(lg) > 120 then
    select jsonb_agg(e order by o) into lg from jsonb_array_elements(lg) with ordinality x(e, o) where o > jsonb_array_length(lg) - 120;
  end if;
  return jsonb_build_object(
    'st', p_st || jsonb_build_object(
      'alive', to_jsonb(alive), 'revealed', to_jsonb(revealed), 'out', to_jsonb(outs), 'ready', to_jsonb(ready),
      'defs', to_jsonb(defs), 'stage', stage, 'day', dday, 'acts', acts, 'last_doc', last_doc, 'doc_self', doc_self,
      'bullets', bullets, 'det', det, 'winner', winner, 'log', lg, 'chat', chat, 'last', lastv, 'dl', dl),
    'ev', ev, 'priv', to_jsonb(priv_seats), 'win', to_jsonb(won));
end $$;

create or replace function public._nx_mafia_view(p_st jsonb, p_seat int, p_names text[]) returns jsonb
language plpgsql stable set search_path = public as $$
declare n int := (p_st->>'n')::int; roles text[] := _nx_ja_text(p_st->'roles'); alive boolean[] := _nx_ja_bool(p_st->'alive');
        revealed boolean[] := _nx_ja_bool(p_st->'revealed'); outs int[] := _nx_ja_int(p_st->'out');
        stage text := p_st->>'stage'; over boolean := p_st->>'winner' is not null; acts jsonb := coalesce(p_st->'acts', '{}'::jsonb);
        me_m boolean := _nx_mafia_is_m(roles[p_seat + 1]); my text := roles[p_seat + 1];
        players jsonb; waiting jsonb; logv jsonb; chatv jsonb; actors int[]; lead int;
begin
  select jsonb_agg(jsonb_build_object('s', g, 'name', coalesce(p_names[g + 1], 'Pilot ' || (g + 1)), 'alive', alive[g + 1],
           'out', g = any(outs),
           'role', case when g = p_seat or over or revealed[g + 1] or (me_m and _nx_mafia_is_m(roles[g + 1])) then roles[g + 1] end)
         order by g) into players from generate_series(0, n - 1) g;
  if stage = 'intro' then
    select coalesce(jsonb_agg(g order by g), '[]') into waiting from generate_series(0, n - 1) g
     where alive[g + 1] and not (g = any(_nx_ja_int(p_st->'ready')));
  elsif stage in ('nominate', 'final') then
    select coalesce(jsonb_agg(g order by g), '[]') into waiting from generate_series(0, n - 1) g
     where alive[g + 1] and not (acts ? g::text);
  else
    waiting := '[]'::jsonb;   -- night: who still has to act would reveal the role holders
  end if;
  select coalesce(jsonb_agg(e order by o), '[]') into logv from jsonb_array_elements(coalesce(p_st->'log', '[]')) with ordinality x(e, o)
   where jsonb_typeof(e->'to') <> 'array' or (e->'to') @> to_jsonb(p_seat) or over;
  select coalesce(jsonb_agg(e order by o), '[]') into chatv from jsonb_array_elements(coalesce(p_st->'chat', '[]')) with ordinality x(e, o)
   where not coalesce((e->>'m')::boolean, false) or me_m or over;
  if me_m then
    actors := _nx_mafia_actors(p_st);
    select min(x) into lead from unnest(actors) x where _nx_mafia_is_m(roles[x + 1]);
  end if;
  return jsonb_build_object(
    'g', 'mafia', 'n', n, 'stage', case when over then 'over' else stage end, 'day', (p_st->>'day')::int,
    'role', my, 'alive', alive[p_seat + 1], 'players', players,
    'partners', case when me_m then (select coalesce(jsonb_agg(g order by g), '[]') from generate_series(0, n - 1) g
                                       where g <> p_seat and _nx_mafia_is_m(roles[g + 1])) else '[]'::jsonb end,
    'lead', lead,
    'legal', to_jsonb(_nx_mafia_legal(p_st, p_seat)),
    'acted', acts ? p_seat::text or (stage = 'intro' and p_seat = any(_nx_ja_int(p_st->'ready'))),
    'my', acts->p_seat::text,
    'waiting', waiting,
    'defs', coalesce(p_st->'defs', '[]'),
    'last', p_st->'last',
    'det', case when my = 'detective' or over then coalesce(p_st->'det', '{}'::jsonb) else '{}'::jsonb end,
    'bullets', case when my = 'sniper' then (p_st->>'bullets')::int end,
    'winner', p_st->>'winner',
    'log', logv, 'chat', chatv);
end $$;

-- ================================================================= SPY & MAFIA
-- 12 locations x 6 clue words (kSpyLocations in lib/games/spy_mafia/core/spy_core.dart); word ref = loc * 6 + word.
create or replace function public._nx_spy_opts(p_st jsonb, p_seat int) returns jsonb
language plpgsql volatile set search_path = public as $$
declare loc int := (p_st->>'loc')::int; used int[] := _nx_ja_int(p_st->'clues'->p_seat); r int[]; o int[];
begin
  if p_seat = any(_nx_ja_int(p_st->'spies')) then
    select array_agg(l * 6 + _nx_rand(6)) into r
      from (select l from generate_series(0, 11) l where l <> loc order by gen_random_uuid() limit 3) z;
    return to_jsonb(r);
  end if;
  select array_agg(x) into o from (select loc * 6 + w x from generate_series(0, 5) w order by gen_random_uuid()) z
   where not (x = any(used));
  if coalesce(array_length(o, 1), 0) = 0 then
    select array_agg(x) into o from (select loc * 6 + w x from generate_series(0, 5) w order by gen_random_uuid()) z;
  end if;
  return to_jsonb(o[1:3]);
end $$;

create or replace function public._nx_spy_init(p_n int) returns jsonb
language plpgsql volatile set search_path = public as $$
declare n int := greatest(4, least(8, p_n)); seats int[] := _nx_shuffle(array(select generate_series(0, n - 1)));
        st jsonb; starter int := _nx_rand(n);
begin
  st := jsonb_build_object('n', n, 'loc', _nx_rand(12), 'spies', to_jsonb(seats[1:(case when n >= 7 then 2 else 1 end)]),
    'starter', starter, 'turn', starter, 'round', 0, 'rounds', 2, 'phase', 'clues',
    'clues', (select jsonb_agg('[]'::jsonb) from generate_series(1, n)), 'votes', '{}'::jsonb, 'out', '[]'::jsonb,
    'accused', null, 'guess_opts', null, 'guessed', null, 'spies_win', null,
    'dl', extract(epoch from now() + interval '40 seconds'));
  return st || jsonb_build_object('opts', _nx_spy_opts(st, starter));
end $$;

create or replace function public._nx_spy_step(p_st jsonb, p_seat int, p_act jsonb)
returns jsonb language plpgsql volatile set search_path = public as $$
declare st jsonb := p_st; n int := (p_st->>'n')::int; a text := coalesce(p_act->>'a', ''); v int := _nx_jint(p_act->'v');
        phase text := p_st->>'phase'; outs int[] := _nx_ja_int(p_st->'out'); spies int[] := _nx_ja_int(p_st->'spies');
        turn int; k int; s int; o int[]; best int; best_n int; tie boolean; won int[] := null; ev jsonb;
        votes jsonb; acc int; nextturn boolean := false; tally_now boolean := false; prev_turn int := _nx_jint(p_st->'turn');
begin
  if phase = 'over' then return jsonb_build_object('err', 'over'); end if;
  ev := jsonb_build_object('t', a);
  if a = 'leave' then
    if p_seat = any(outs) then return jsonb_build_object('err', 'done'); end if;
    outs := outs || p_seat; st := st || jsonb_build_object('out', to_jsonb(outs));
    ev := jsonb_build_object('t', 'leave', 's', p_seat);
    if p_seat = any(spies) and not exists (select 1 from unnest(spies) x where not (x = any(outs))) then
      st := st || jsonb_build_object('spies_win', false, 'phase', 'over');
    elsif phase = 'clues' and prev_turn = p_seat then nextturn := true;
    elsif phase = 'vote' then tally_now := true;
    elsif phase = 'guess' and _nx_jint(st->'accused') = p_seat then
      st := st || jsonb_build_object('spies_win', false, 'phase', 'over');
    end if;
  elsif a = 'timeout' then
    if phase = 'clues' then
      st := jsonb_set(st, array['clues', prev_turn::text], (st->'clues'->prev_turn) || jsonb_build_array((st->'opts'->>0)::int));
      nextturn := true;
    elsif phase = 'vote' then
      votes := coalesce(st->'votes', '{}');
      for s in 0 .. n - 1 loop
        if not (s = any(outs)) and not (votes ? s::text) then votes := votes || jsonb_build_object(s::text, -1); end if;
      end loop;
      st := st || jsonb_build_object('votes', votes); tally_now := true;
    elsif phase = 'guess' then
      st := st || jsonb_build_object('guessed', -1, 'spies_win', false, 'phase', 'over');
    end if;
  elsif a = 'clue' then
    if phase <> 'clues' then return jsonb_build_object('err', 'phase'); end if;
    if p_seat <> prev_turn then return jsonb_build_object('err', 'turn'); end if;
    o := _nx_ja_int(st->'opts');
    if coalesce(array_length(o, 1), 0) = 0 then return jsonb_build_object('err', 'no_options'); end if;
    k := greatest(0, least(coalesce(v, 0), array_length(o, 1) - 1));
    st := jsonb_set(st, array['clues', p_seat::text], (st->'clues'->p_seat) || jsonb_build_array(o[k + 1]));
    nextturn := true;
  elsif a = 'vote' then
    if phase <> 'vote' then return jsonb_build_object('err', 'phase'); end if;
    if p_seat = any(outs) or (st->'votes') ? p_seat::text then return jsonb_build_object('err', 'done'); end if;
    if v is null or v = p_seat or v < -1 or v >= n then return jsonb_build_object('err', 'illegal'); end if;
    st := st || jsonb_build_object('votes', coalesce(st->'votes', '{}') || jsonb_build_object(p_seat::text, v));
    ev := jsonb_build_object('t', 'vote', 's', p_seat);
    tally_now := true;
  elsif a = 'guess' then
    if phase <> 'guess' then return jsonb_build_object('err', 'phase'); end if;
    if p_seat is distinct from _nx_jint(st->'accused') then return jsonb_build_object('err', 'turn'); end if;
    if v is null or not (v = any(_nx_ja_int(st->'guess_opts'))) then return jsonb_build_object('err', 'illegal'); end if;
    st := st || jsonb_build_object('guessed', v, 'spies_win', v = (st->>'loc')::int, 'phase', 'over');
  else
    return jsonb_build_object('err', 'bad_action');
  end if;

  if nextturn and st->>'phase' = 'clues' then
    turn := prev_turn;
    for k in 1 .. n loop
      s := (turn + k) % n;
      if s = (st->>'starter')::int then
        st := st || jsonb_build_object('round', (st->>'round')::int + 1);
        if (st->>'round')::int >= (st->>'rounds')::int then
          st := st || jsonb_build_object('phase', 'vote', 'opts', null, 'dl', extract(epoch from now() + interval '45 seconds'));
          exit;
        end if;
      end if;
      if not (s = any(outs)) then
        st := st || jsonb_build_object('turn', s, 'dl', extract(epoch from now() + interval '40 seconds'));
        st := st || jsonb_build_object('opts', _nx_spy_opts(st, s));
        exit;
      end if;
    end loop;
  end if;

  if tally_now and st->>'phase' = 'vote'
     and not exists (select 1 from generate_series(0, n - 1) g where not (g = any(outs)) and not ((st->'votes') ? g::text)) then
    best := -1; best_n := 0; tie := false;
    for s, k in select x::int, count(*)::int from jsonb_each_text(st->'votes') e(key, x) where x::int >= 0 group by x::int loop
      if k > best_n then best := s; best_n := k; tie := false; elsif k = best_n then tie := true; end if;
    end loop;
    acc := case when tie or best < 0 then null else best end;
    st := st || jsonb_build_object('accused', acc);
    if acc is not null and acc = any(spies) and not (acc = any(outs)) then
      select jsonb_agg(x order by gen_random_uuid()) into votes
        from (select (st->>'loc')::int x union all
              (select l from generate_series(0, 11) l where l <> (st->>'loc')::int order by gen_random_uuid() limit 5)) z;
      st := st || jsonb_build_object('phase', 'guess', 'guess_opts', votes, 'dl', extract(epoch from now() + interval '30 seconds'));
    else
      st := st || jsonb_build_object('spies_win', true, 'phase', 'over');
    end if;
  end if;

  if st->>'phase' = 'over' then
    st := st || jsonb_build_object('dl', null, 'opts', null);
    select coalesce(array_agg(g order by g), '{}') into won from generate_series(0, n - 1) g
     where (g = any(spies)) = (st->>'spies_win')::boolean and not (g = any(outs));
    ev := jsonb_build_object('t', 'over');
  end if;
  return jsonb_build_object('st', st, 'ev', ev, 'priv', null, 'win', to_jsonb(won));
end $$;

create or replace function public._nx_spy_view(p_st jsonb, p_seat int) returns jsonb
language plpgsql stable set search_path = public as $$
declare spies int[] := _nx_ja_int(p_st->'spies'); spy boolean := p_seat = any(spies); over boolean := p_st->>'phase' = 'over';
begin
  return jsonb_build_object(
    'g', 'spy_mafia', 'n', (p_st->>'n')::int, 'phase', p_st->>'phase', 'turn', _nx_jint(p_st->'turn'),
    'round', (p_st->>'round')::int, 'rounds', (p_st->>'rounds')::int, 'starter', (p_st->>'starter')::int,
    'clues', p_st->'clues', 'votes', coalesce(p_st->'votes', '{}'), 'out', coalesce(p_st->'out', '[]'),
    'accused', p_st->'accused', 'spy', spy, 'spy_count', coalesce(array_length(spies, 1), 0),
    'loc', case when not spy or over then (p_st->>'loc')::int else -1 end,
    'spies', case when over then to_jsonb(spies) when spy then jsonb_build_array(p_seat) else '[]'::jsonb end,
    'opts', case when p_st->>'phase' = 'clues' and _nx_jint(p_st->'turn') = p_seat then p_st->'opts' end,
    'guess_opts', case when (p_st->>'phase' = 'guess' and _nx_jint(p_st->'accused') = p_seat) or over then p_st->'guess_opts' end,
    'guessed', p_st->'guessed', 'spies_win', case when over then p_st->'spies_win' end);
end $$;

-- ================================================================= UNO (NX Cards)
-- Card ids as buildUnoDeck(): per colour c (0..3) base c*25: +0 number 0, +1..+18 numbers 1..9 (two each),
-- +19/+22 skip, +20/+23 reverse, +21/+24 draw two; 100..103 wild; 104..107 wild draw four.
create or replace function public._nx_uno_kind(c int) returns text
language sql immutable as $$
  select case when c >= 104 then 'wd4' when c >= 100 then 'wild'
              when c % 25 <= 18 then 'num' when c % 25 in (19, 22) then 'skip' when c % 25 in (20, 23) then 'rev' else 'd2' end
$$;
create or replace function public._nx_uno_color(c int) returns int
language sql immutable as $$ select case when c < 100 then c / 25 end $$;
create or replace function public._nx_uno_num(c int) returns int
language sql immutable as $$ select case when c < 100 and c % 25 = 0 then 0 when c < 100 and c % 25 <= 18 then (c % 25 - 1) / 2 + 1 else -1 end $$;
create or replace function public._nx_uno_points(c int) returns int
language sql immutable as $$
  select case _nx_uno_kind(c) when 'num' then _nx_uno_num(c) when 'wild' then 50 when 'wd4' then 50 else 20 end
$$;

create or replace function public._nx_uno_init(p_n int) returns jsonb
language plpgsql volatile set search_path = public as $$
declare n int := greatest(2, least(4, p_n)); deck int[] := _nx_shuffle(array(select generate_series(0, 107)));
        hands jsonb := '[]'::jsonb; h int[]; p int; r int; first int; guard int := 0;
begin
  for p in 0 .. n - 1 loop
    h := '{}';
    for r in 0 .. 6 loop h := h || deck[array_length(deck, 1) - (r * n + p)]; end loop;
    hands := hands || jsonb_build_array(to_jsonb(h));
  end loop;
  deck := deck[1:array_length(deck, 1) - 7 * n];
  first := deck[array_length(deck, 1)]; deck := deck[1:array_length(deck, 1) - 1];
  while _nx_uno_kind(first) <> 'num' and guard < 200 loop
    deck := first || deck; first := deck[array_length(deck, 1)]; deck := deck[1:array_length(deck, 1) - 1]; guard := guard + 1;
  end loop;
  return jsonb_build_object('n', n, 'hands', hands, 'draw', to_jsonb(deck), 'disc', jsonb_build_array(first),
    'color', _nx_uno_color(first), 'cur', 0, 'dir', 1, 'drawn', null, 'vul', null,
    'called', to_jsonb(array_fill(false, array[n])), 'winner', null, 'out', '[]'::jsonb,
    'ev', jsonb_build_array(jsonb_build_object('i', 1, 't', 'deal')), 'evi', 1,
    'dl', extract(epoch from now() + interval '35 seconds'));
end $$;

create or replace function public._nx_uno_step(p_st jsonb, p_seat int, p_act jsonb)
returns jsonb language plpgsql volatile set search_path = public as $$
declare
  n int := (p_st->>'n')::int;
  hand_j jsonb := p_st->'hands';
  drawp int[] := _nx_ja_int(p_st->'draw');
  disc int[] := _nx_ja_int(p_st->'disc');
  color int := _nx_jint(p_st->'color');
  cur int := (p_st->>'cur')::int;
  dir int := (p_st->>'dir')::int;
  drawn int := _nx_jint(p_st->'drawn');
  vul int := _nx_jint(p_st->'vul');
  called boolean[] := _nx_ja_bool(p_st->'called');
  winner int := _nx_jint(p_st->'winner');
  outs int[] := _nx_ja_int(p_st->'out');
  evs jsonb := coalesce(p_st->'ev', '[]'::jsonb);
  evi int := coalesce((p_st->>'evi')::int, 0);
  a text := coalesce(p_act->>'a', '');
  c int := _nx_jint(p_act->'c');
  col int := _nx_jint(p_act->'col');
  h int[]; top int; ok boolean; k int; vic int; got int; left_n int; won boolean; active int;
  cur0 int; drawn0 int; priv_seats int[] := null; i int; pts int; scores int[];
  -- in-function helpers are unrolled below: hand(p) = _nx_ja_int(hand_j->p)
begin
  if winner is not null then return jsonb_build_object('err', 'over'); end if;
  cur0 := cur; drawn0 := drawn;
  select count(*) into active from generate_series(0, n - 1) g where not (g = any(outs));

  if a in ('play', 'draw', 'pass') and p_seat <> cur then return jsonb_build_object('err', 'turn'); end if;

  if a = 'leave' then
    if p_seat = any(outs) then return jsonb_build_object('err', 'done'); end if;
    outs := outs || p_seat; active := active - 1;
    if vul = p_seat then vul := null; end if;
    evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'leave', 'p', p_seat);
    if active <= 1 then
      select min(g) into winner from generate_series(0, n - 1) g where not (g = any(outs));
    elsif cur = p_seat then
      drawn := null;
      k := cur;
      for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
      cur := k;
    end if;
  elsif a = 'timeout' then
    -- the player on turn ran out of time: keep a playable drawn card / draw one, then pass
    if p_seat <> -1 then return jsonb_build_object('err', 'bad_action'); end if;
    p_seat := cur;
    if drawn is null then
      h := _nx_ja_int(hand_j->p_seat);
      if coalesce(array_length(drawp, 1), 0) = 0 and coalesce(array_length(disc, 1), 0) > 1 then
        top := disc[array_length(disc, 1)];
        drawp := _nx_shuffle(disc[1:array_length(disc, 1) - 1]) || drawp; disc := array[top];
        evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'reshuffle', 'n', array_length(drawp, 1));
      end if;
      if coalesce(array_length(drawp, 1), 0) > 0 then
        h := h || drawp[array_length(drawp, 1)]; drawp := drawp[1:array_length(drawp, 1) - 1];
        hand_j := jsonb_set(hand_j, array[p_seat::text], to_jsonb(h));
        evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'draw', 'p', p_seat, 'n', 1);
        if array_length(h, 1) > 1 then called[p_seat + 1] := false; if vul = p_seat then vul := null; end if; end if;
      end if;
    end if;
    if vul is not null and vul <> p_seat then vul := null; end if;
    drawn := null;
    evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'pass', 'p', p_seat, 'timeout', true);
    k := cur;
    for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
    cur := k;
  elsif a = 'play' then
    h := _nx_ja_int(hand_j->p_seat);
    if c is null or not (c = any(h)) then return jsonb_build_object('err', 'card'); end if;
    if drawn is not null and drawn <> c then return jsonb_build_object('err', 'drawn_only'); end if;
    -- legality
    top := disc[array_length(disc, 1)];
    if _nx_uno_kind(c) in ('wild', 'wd4') then
      ok := true;
      if _nx_uno_kind(c) = 'wd4' and exists (select 1 from unnest(h) x where x <> c and x < 100 and _nx_uno_color(x) = color) then ok := false; end if;
      if col is null or col < 0 or col > 3 then return jsonb_build_object('err', 'color'); end if;
    elsif _nx_uno_color(c) = color then ok := true;
    elsif top >= 100 then ok := false;
    else ok := _nx_uno_kind(c) = _nx_uno_kind(top) and (_nx_uno_kind(c) <> 'num' or _nx_uno_num(c) = _nx_uno_num(top));
    end if;
    if not ok then return jsonb_build_object('err', 'illegal'); end if;
    if vul is not null and vul <> p_seat then vul := null; end if;
    h := array_remove(h, c);
    hand_j := jsonb_set(hand_j, array[p_seat::text], to_jsonb(h));
    disc := disc || c; drawn := null;
    evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'play', 'p', p_seat, 'c', c);
    if c >= 100 then
      color := col;
      evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'color', 'p', p_seat, 'col', col);
    else
      color := _nx_uno_color(c);
    end if;
    left_n := coalesce(array_length(h, 1), 0);
    if left_n = 1 then
      if not called[p_seat + 1] then vul := p_seat; end if;
    elsif left_n > 1 then called[p_seat + 1] := false;
    end if;
    won := left_n = 0;
    -- effects (out seats are skipped)
    k := p_seat;
    for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
    vic := k;   -- next active seat
    if _nx_uno_kind(c) = 'rev' then
      dir := -dir;
      evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'reverse', 'p', p_seat);
      if active = 2 then
        evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'skip', 'p', vic);
        cur := p_seat;
      else
        k := p_seat;
        for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
        cur := k;
      end if;
    elsif _nx_uno_kind(c) in ('skip', 'd2', 'wd4') then
      if _nx_uno_kind(c) in ('d2', 'wd4') then
        h := _nx_ja_int(hand_j->vic); got := 0;
        for i in 1 .. case when _nx_uno_kind(c) = 'd2' then 2 else 4 end loop
          if coalesce(array_length(drawp, 1), 0) = 0 and coalesce(array_length(disc, 1), 0) > 1 then
            top := disc[array_length(disc, 1)];
            drawp := _nx_shuffle(disc[1:array_length(disc, 1) - 1]) || drawp; disc := array[top];
            evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'reshuffle', 'n', array_length(drawp, 1));
          end if;
          exit when coalesce(array_length(drawp, 1), 0) = 0;
          h := h || drawp[array_length(drawp, 1)]; drawp := drawp[1:array_length(drawp, 1) - 1]; got := got + 1;
        end loop;
        hand_j := jsonb_set(hand_j, array[vic::text], to_jsonb(h));
        if got > 0 then
          evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'draw', 'p', vic, 'n', got);
          if array_length(h, 1) > 1 then called[vic + 1] := false; if vul = vic then vul := null; end if; end if;
        end if;
      end if;
      evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'skip', 'p', vic);
      k := vic;
      for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
      cur := k;
    else
      cur := vic;
    end if;
    if won then
      winner := p_seat; vul := null; cur := p_seat;
    end if;
  elsif a = 'draw' then
    if drawn is not null then return jsonb_build_object('err', 'drawn'); end if;
    if vul is not null and vul <> p_seat then vul := null; end if;
    h := _nx_ja_int(hand_j->p_seat);
    if coalesce(array_length(drawp, 1), 0) = 0 and coalesce(array_length(disc, 1), 0) > 1 then
      top := disc[array_length(disc, 1)];
      drawp := _nx_shuffle(disc[1:array_length(disc, 1) - 1]) || drawp; disc := array[top];
      evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'reshuffle', 'n', array_length(drawp, 1));
    end if;
    if coalesce(array_length(drawp, 1), 0) = 0 then
      evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'pass', 'p', p_seat);
      k := cur;
      for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
      cur := k;
    else
      c := drawp[array_length(drawp, 1)]; drawp := drawp[1:array_length(drawp, 1) - 1];
      h := h || c;
      hand_j := jsonb_set(hand_j, array[p_seat::text], to_jsonb(h));
      evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'draw', 'p', p_seat, 'n', 1);
      if array_length(h, 1) > 1 then called[p_seat + 1] := false; if vul = p_seat then vul := null; end if; end if;
      top := disc[array_length(disc, 1)];
      if c >= 104 then ok := not exists (select 1 from unnest(h) x where x <> c and x < 100 and _nx_uno_color(x) = color);
      elsif c >= 100 then ok := true;
      elsif _nx_uno_color(c) = color then ok := true;
      elsif top >= 100 then ok := false;
      else ok := _nx_uno_kind(c) = _nx_uno_kind(top) and (_nx_uno_kind(c) <> 'num' or _nx_uno_num(c) = _nx_uno_num(top));
      end if;
      if ok then
        drawn := c;
      else
        evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'pass', 'p', p_seat);
        k := cur;
        for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
        cur := k;
      end if;
    end if;
  elsif a = 'pass' then
    if drawn is null then return jsonb_build_object('err', 'not_drawn'); end if;
    drawn := null;
    evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'pass', 'p', p_seat);
    k := cur;
    for i in 1 .. n loop k := ((k + dir) % n + n) % n; exit when not (k = any(outs)); end loop;
    cur := k;
  elsif a = 'nx' then
    h := _nx_ja_int(hand_j->p_seat);
    if coalesce(array_length(h, 1), 0) = 1 and vul = p_seat then
      vul := null; called[p_seat + 1] := true;
    elsif coalesce(array_length(h, 1), 0) = 2 and cur = p_seat and not called[p_seat + 1] then
      called[p_seat + 1] := true;
    else
      return jsonb_build_object('err', 'illegal');
    end if;
    evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'nx', 'p', p_seat);
  elsif a = 'catch' then
    if vul is null or vul = p_seat then return jsonb_build_object('err', 'illegal'); end if;
    vic := vul; vul := null;
    h := _nx_ja_int(hand_j->vic); got := 0;
    for i in 1 .. 2 loop
      if coalesce(array_length(drawp, 1), 0) = 0 and coalesce(array_length(disc, 1), 0) > 1 then
        top := disc[array_length(disc, 1)];
        drawp := _nx_shuffle(disc[1:array_length(disc, 1) - 1]) || drawp; disc := array[top];
        evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'reshuffle', 'n', array_length(drawp, 1));
      end if;
      exit when coalesce(array_length(drawp, 1), 0) = 0;
      h := h || drawp[array_length(drawp, 1)]; drawp := drawp[1:array_length(drawp, 1) - 1]; got := got + 1;
    end loop;
    hand_j := jsonb_set(hand_j, array[vic::text], to_jsonb(h));
    if got > 0 and array_length(h, 1) > 1 then called[vic + 1] := false; end if;
    evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'caught', 'p', vic, 'n', got, 'by', p_seat);
  else
    return jsonb_build_object('err', 'bad_action');
  end if;

  if winner is not null then
    pts := 0;
    for i in 0 .. n - 1 loop
      if i <> winner then pts := pts + coalesce((select sum(_nx_uno_points(x)) from unnest(_nx_ja_int(hand_j->i)) x), 0); end if;
    end loop;
    evi := evi + 1; evs := evs || jsonb_build_object('i', evi, 't', 'win', 'p', winner, 'n', pts);
    scores := array_fill(0, array[n]); scores[winner + 1] := pts;
  end if;
  if jsonb_array_length(evs) > 40 then
    select jsonb_agg(e order by o) into evs from jsonb_array_elements(evs) with ordinality x(e, o) where o > jsonb_array_length(evs) - 40;
  end if;
  return jsonb_build_object(
    'st', p_st || jsonb_build_object('hands', hand_j, 'draw', to_jsonb(drawp), 'disc', to_jsonb(disc), 'color', color,
       'cur', cur, 'dir', dir, 'drawn', drawn, 'vul', vul, 'called', to_jsonb(called), 'winner', winner, 'out', to_jsonb(outs),
       'ev', evs, 'evi', evi,
       'dl', case when winner is not null then null
                  when cur is distinct from cur0 or drawn is distinct from drawn0 or a = 'timeout'
                    then extract(epoch from now() + interval '35 seconds')
                  else (p_st->>'dl')::double precision end),
    'ev', jsonb_build_object('t', a),
    'priv', to_jsonb(priv_seats),
    'win', case when winner is not null then jsonb_build_array(winner) end,
    'scores', to_jsonb(scores));
end $$;

create or replace function public._nx_uno_view(p_st jsonb, p_seat int) returns jsonb
language plpgsql stable set search_path = public as $$
declare n int := (p_st->>'n')::int; over boolean := p_st->>'winner' is not null;
begin
  return jsonb_build_object(
    'g', 'uno', 'n', n, 'hand', p_st->'hands'->p_seat,
    'counts', (select jsonb_agg(jsonb_array_length(p_st->'hands'->g) order by g) from generate_series(0, n - 1) g),
    'hands', case when over then p_st->'hands' end,
    'disc', p_st->'disc', 'draw_n', jsonb_array_length(coalesce(p_st->'draw', '[]')),
    'color', p_st->'color', 'cur', p_st->'cur', 'dir', p_st->'dir',
    'drawn', case when (p_st->>'cur')::int = p_seat then p_st->'drawn' end,
    'drawing', p_st->'drawn' is not null and jsonb_typeof(p_st->'drawn') = 'number',
    'vul', p_st->'vul', 'called', p_st->'called', 'winner', p_st->'winner', 'out', p_st->'out', 'ev', p_st->'ev');
end $$;

-- ================================================================= engine plumbing
create or replace function public._nx_hg_step(p_game text, p_st jsonb, p_seat int, p_act jsonb, p_names text[]) returns jsonb
language plpgsql volatile set search_path = public as $$
begin
  return case p_game
    when 'mafia' then _nx_mafia_step(p_st, p_seat, p_act, p_names)
    when 'spy_mafia' then _nx_spy_step(p_st, p_seat, p_act)
    when 'uno' then _nx_uno_step(p_st, p_seat, p_act)
    else jsonb_build_object('err', 'game') end;
end $$;

-- Rebuild the views (all seats, or only p_seats for a private change) and, for a public change, append a hint row.
create or replace function public._nx_hg_publish(p_match uuid, p_ev jsonb, p_seats int[] default null)
returns void language plpgsql security definer set search_path = public as $$
declare m nx_matches; s nx_hg_state; i int; v jsonb; q int; n int;
begin
  select * into m from nx_matches where id = p_match;
  select * into s from nx_hg_state where match_id = p_match;
  if m.id is null or s.match_id is null then return; end if;
  n := coalesce(array_length(m.players, 1), 0);
  for i in 0 .. n - 1 loop
    if p_seats is not null and not (i = any(p_seats)) then continue; end if;
    v := case s.game when 'mafia' then _nx_mafia_view(s.st, i, m.names)
                     when 'spy_mafia' then _nx_spy_view(s.st, i)
                     else _nx_uno_view(s.st, i) end;
    v := v || jsonb_build_object('ver', s.ver, 'seat', i, 'match', p_match,
                                 'deadline', s.deadline, 'server_now', now());
    insert into nx_match_secrets(match_id, user_id, slot, data) values (p_match, m.players[i + 1], 'view', v)
    on conflict (match_id, user_id, slot) do update set data = excluded.data, created_at = now();
  end loop;
  if p_seats is null then
    select greatest(coalesce(max(seq), 0), m.last_seq) + 1 into q from nx_match_moves where match_id = p_match;
    insert into nx_match_moves(match_id, seq, seat, by_user, kind, move)
    values (p_match, q, -1, '00000000-0000-0000-0000-000000000000'::uuid, 'srv', coalesce(p_ev, '{}'::jsonb) || jsonb_build_object('ver', s.ver));
    update nx_matches set last_seq = greatest(last_seq, q) where id = p_match;
  end if;
end $$;

create or replace function public._nx_hg_finish(p_match uuid, p_winners int[], p_scores int[])
returns void language plpgsql security definer set search_path = public as $$
declare m nx_matches;
begin
  perform set_config('nx.server_result', '1', true);
  update nx_matches set status = 'finished', winner_seats = coalesce(p_winners, '{}'), scores = p_scores,
         reason = 'finished', ended_at = now()
   where id = p_match and status = 'playing' returning * into m;
  if m.id is not null then
    perform _nx_apply_result(m, coalesce(p_winners, '{}'), p_scores);
    perform _nx_room_after_match(m.room_id, m.id);
  end if;
  perform set_config('nx.server_result', '', true);
end $$;

create or replace function public._nx_hg_commit(p_match uuid, p_res jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_st jsonb := p_res->'st'; priv int[];
begin
  update nx_hg_state set st = v_st, ver = ver + 1,
         deadline = case when jsonb_typeof(v_st->'dl') = 'number' then to_timestamp((v_st->>'dl')::double precision) end,
         updated_at = now()
   where match_id = p_match;
  if jsonb_typeof(p_res->'priv') = 'array' then priv := _nx_ja_int(p_res->'priv'); end if;
  perform _nx_hg_publish(p_match, coalesce(p_res->'ev', '{}'::jsonb), priv);
  if jsonb_typeof(p_res->'win') = 'array' then
    perform _nx_hg_finish(p_match, _nx_ja_int(p_res->'win'),
                          case when jsonb_typeof(p_res->'scores') = 'array' then _nx_ja_int(p_res->'scores') end);
  end if;
end $$;

-- The only way to play a hidden-information game. p_act: {a: 'ready'|'night'|'nom'|'final'|'chat'|'clue'|'vote'|
-- 'guess'|'play'|'draw'|'pass'|'nx'|'catch'|'tick', ...}. 'tick' applies the timeout once the deadline passed.
create or replace function public.nx_hg_act(p_match uuid, p_act jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); m nx_matches; s nx_hg_state; seat int; a text; r jsonb; now_ms bigint; last_ms bigint;
begin
  if me is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if p_act is null or jsonb_typeof(p_act) <> 'object' or pg_column_size(p_act) > 2000 then
    return jsonb_build_object('ok', false, 'reason', 'bad_action');
  end if;
  a := coalesce(p_act->>'a', '');
  if a in ('leave', 'timeout', '') then return jsonb_build_object('ok', false, 'reason', 'bad_action'); end if;
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then raise exception 'match not found'; end if;
  seat := array_position(m.players, me) - 1;
  if seat is null then raise exception 'not a player' using errcode = '42501'; end if;
  if m.status <> 'playing' then return jsonb_build_object('ok', false, 'reason', 'over'); end if;
  select * into s from nx_hg_state where match_id = p_match for update;
  if s.match_id is null then return jsonb_build_object('ok', false, 'reason', 'not_server_game'); end if;
  if seat = any(_nx_forfeited_seats(p_match)) then return jsonb_build_object('ok', false, 'reason', 'forfeited'); end if;
  now_ms := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  last_ms := coalesce((s.st->'lt'->>seat::text)::bigint, 0);
  if now_ms - last_ms < (case when a = 'chat' then 800 else 150 end) then
    return jsonb_build_object('ok', false, 'reason', 'rate');
  end if;
  if a = 'tick' then
    if s.deadline is null or clock_timestamp() < s.deadline then
      return jsonb_build_object('ok', false, 'reason', 'too_early', 'deadline', s.deadline, 'ver', s.ver);
    end if;
    r := _nx_hg_step(s.game, s.st, -1, jsonb_build_object('a', 'timeout'), m.names);
  else
    r := _nx_hg_step(s.game, s.st, seat, p_act, m.names);
  end if;
  if r ? 'err' then return jsonb_build_object('ok', false, 'reason', r->>'err', 'ver', s.ver); end if;
  r := jsonb_set(r, '{st,lt}', coalesce(r->'st'->'lt', '{}'::jsonb) || jsonb_build_object(seat::text, now_ms));
  perform _nx_hg_commit(p_match, r);
  return jsonb_build_object('ok', true, 'ver', s.ver + 1);
end $$;

-- Cron: apply expired timeouts of matches where somebody is still around.
create or replace function public._nx_hg_sweep() returns int
language plpgsql security definer set search_path = public as $$
declare h record; m nx_matches; hs nx_hg_state; r jsonb; k int := 0;
begin
  for h in select hs.match_id from nx_hg_state hs join nx_matches mm on mm.id = hs.match_id
            where mm.status = 'playing' and hs.deadline < now() - interval '3 seconds'
              and exists (select 1 from nx_match_presence p where p.match_id = hs.match_id and p.last_seen > now() - interval '10 minutes')
            order by hs.deadline limit 50 loop
    begin
      select * into m from nx_matches where id = h.match_id and status = 'playing' for update skip locked;
      continue when m.id is null;
      select * into hs from nx_hg_state where match_id = m.id for update;
      r := _nx_hg_step(hs.game, hs.st, -1, '{"a":"timeout"}', m.names);
      if not (r ? 'err') then perform _nx_hg_commit(m.id, r); k := k + 1; end if;
    exception when others then
      raise warning '_nx_hg_sweep %: %', h.match_id, sqlerrm;
    end;
  end loop;
  return k;
end $$;

-- Deal on insert (every start path: rooms, quick play, tournaments).
create or replace function public._nx_hg_on_match() returns trigger
language plpgsql security definer set search_path = public as $$
declare st jsonb; n int := coalesce(array_length(new.players, 1), 0);
begin
  if new.game = any(_nx_hg_games()) and new.status = 'playing' and n > 0 then
    st := case new.game when 'mafia' then _nx_mafia_init(n) when 'spy_mafia' then _nx_spy_init(n) else _nx_uno_init(n) end;
    -- the engines need exactly the match's seat count
    if (st->>'n')::int = n then
      insert into nx_hg_state(match_id, game, st, ver, deadline)
      values (new.id, new.game, st, 1, case when jsonb_typeof(st->'dl') = 'number' then to_timestamp((st->>'dl')::double precision) end)
      on conflict (match_id) do nothing;
      perform _nx_hg_publish(new.id, jsonb_build_object('t', 'start'));
    end if;
  end if;
  return null;
end $$;
drop trigger if exists nx_matches_hidden_deal on public.nx_matches;
create trigger nx_matches_hidden_deal after insert on public.nx_matches
  for each row execute function public._nx_hg_on_match();

-- last_seq only grows (the server appends hint rows inside callers that later write last_seq from a stale copy).
create or replace function public._nx_last_seq_monotonic() returns trigger
language plpgsql as $$
begin
  if new.last_seq < old.last_seq then new.last_seq := old.last_seq; end if;
  return new;
end $$;
drop trigger if exists nx_matches_last_seq_monotonic on public.nx_matches;
create trigger nx_matches_last_seq_monotonic before update of last_seq on public.nx_matches
  for each row execute function public._nx_last_seq_monotonic();

-- Move log guard: 'srv' rows only from the server; hidden games take no client rows except forfeits.
create or replace function public._nx_hg_moves_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'srv' and new.by_user is distinct from '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'server rows only' using errcode = '42501';
  end if;
  if new.kind not in ('srv', 'forfeit') and exists (select 1 from nx_hg_state h where h.match_id = new.match_id) then
    raise exception 'this game is played through nx_hg_act' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists nx_match_moves_hidden_guard on public.nx_match_moves;
create trigger nx_match_moves_hidden_guard before insert on public.nx_match_moves
  for each row execute function public._nx_hg_moves_guard();

-- A forfeit row (nx_forfeit / nx_idle_forfeit / own-seat push) takes the player out of the hidden game.
create or replace function public._nx_hg_on_forfeit() returns trigger
language plpgsql security definer set search_path = public as $$
declare s nx_hg_state; m nx_matches; r jsonb; seat int;
begin
  select * into s from nx_hg_state where match_id = new.match_id for update;
  if s.match_id is null then return null; end if;
  select * into m from nx_matches where id = new.match_id;
  if m.status <> 'playing' then return null; end if;
  seat := coalesce(_nx_jint(new.move->'seat'), new.seat);
  r := _nx_hg_step(s.game, s.st, seat, jsonb_build_object('a', 'leave'), m.names);
  if not (r ? 'err') then perform _nx_hg_commit(new.match_id, r); end if;
  return null;
end $$;
drop trigger if exists nx_match_moves_hidden_forfeit on public.nx_match_moves;
create trigger nx_match_moves_hidden_forfeit after insert on public.nx_match_moves
  for each row when (new.kind = 'forfeit') execute function public._nx_hg_on_forfeit();

-- Results of server games come from the server only (a lone survivor after forfeits stays allowed).
create or replace function public._nx_server_result_guard()
returns trigger language plpgsql as $$
begin
  if new.game = 'quiz'
     and old.status = 'playing' and new.status = 'finished'
     and coalesce(new.reason, 'finished') not like 'forfeit%'
     and exists (select 1 from public.nx_quiz_games q where q.match_id = new.id and q.phase <> 'pick')
     and coalesce(current_setting('nx.server_result', true), '') <> '1' then
    raise exception 'the server decides % results', new.game;
  end if;
  if new.game = any(public._nx_hg_games())
     and old.status = 'playing' and new.status in ('finished', 'disputed')
     and coalesce(new.reason, 'finished') not like 'forfeit%'
     and exists (select 1 from public.nx_hg_state h where h.match_id = new.id)
     and coalesce(current_setting('nx.server_result', true), '') <> '1' then
    raise exception 'the server decides % results', new.game;
  end if;
  return new;
end $$;

-- nx_finish_match: a hidden game is never settled by client reports (patched into the live definition so concurrent
-- changes to the rest of the function are kept).
do $patch$
declare d text;
begin
  d := pg_get_functiondef('public.nx_finish_match(uuid, integer[], integer[], text, text)'::regprocedure);
  if position('nx_hg_state' in d) = 0 then
    d := replace(d,
      E'  n := coalesce(array_length(m.players, 1), 0);\n',
      E'  -- server-authoritative hidden games (mafia, spy_mafia, uno) finish themselves\n'
      || E'  if exists (select 1 from nx_hg_state h where h.match_id = p_match) then\n'
      || E'    return jsonb_build_object(''ok'', true, ''pending'', true, ''server'', true);\n'
      || E'  end if;\n'
      || E'  n := coalesce(array_length(m.players, 1), 0);\n');
    if position('nx_hg_state' in d) = 0 then raise exception 'nx_finish_match patch point not found'; end if;
    execute d;
  end if;
end $patch$;

-- Retired: the match authority could write ANY player's secret slots (incl. forged views).
create or replace function public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  raise exception 'secrets are written by the server only' using errcode = '42501';
end $$;
revoke all on function public.nx_put_secret(uuid, uuid, text, jsonb) from public, anon, authenticated;

-- secrets / move log: clients read through RLS only
revoke insert, update, delete, truncate, references, trigger on public.nx_match_secrets from anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.nx_match_moves from anon, authenticated;
revoke all on public.nx_match_secrets from anon;

-- grants
do $g$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
            where ns.nspname = 'public' and (p.proname like '\_nx\_hg\_%' or p.proname like '\_nx\_mafia\_%'
                  or p.proname like '\_nx\_spy\_%' or p.proname like '\_nx\_uno\_%'
                  or p.proname in ('_nx_rand', '_nx_shuffle', '_nx_ja_int', '_nx_ja_bool', '_nx_ja_text', '_nx_jint',
                                   '_nx_last_seq_monotonic')) loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
end $g$;
grant execute on function public._nx_hg_games() to authenticated;
revoke all on function public.nx_hg_act(uuid, jsonb) from public, anon;
grant execute on function public.nx_hg_act(uuid, jsonb) to authenticated;

-- timeouts even when every phone is asleep
do $c$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'nx_hg_sweep') then
      perform cron.unschedule('nx_hg_sweep');
    end if;
    perform cron.schedule('nx_hg_sweep', '15 seconds', 'select public._nx_hg_sweep()');
  end if;
end $c$;
