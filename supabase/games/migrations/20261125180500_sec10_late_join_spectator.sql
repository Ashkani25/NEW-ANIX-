-- #10 (games): a stranger with a private room's code joined a running match's room as a seated speaker.
-- Late joiners (room status 'playing') now enter as spectators (listeners) with no seat; re-joins of existing members
-- keep their role.

CREATE OR REPLACE FUNCTION public.nx_room_join(p_room uuid, p_role text DEFAULT 'speaker'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); r public.nx_rooms; role_to_use text; speakers int; spectators int; seat_no int; game_limit int;
begin
  if me is null then raise exception 'not signed in'; end if;
  insert into public.profiles(id, username) values (me, coalesce(auth.jwt() -> 'user_metadata' ->> 'username', 'Pilot'))
    on conflict (id) do nothing;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if r.status = 'closed' then raise exception 'room closed'; end if;
  if exists(select 1 from public.nx_room_members where room_id = p_room and user_id = me) then
    update public.nx_room_members set last_seen = now() where room_id = p_room and user_id = me;
    return jsonb_build_object('room_id', p_room, 'role', public.nx_room_member_role(p_room), 'rejoined', true,
                              'status', r.status, 'match_id', r.match_id);
  end if;
  if coalesce(r.join_locked, false) then raise exception 'room locked'; end if;
  if coalesce(p_role, 'speaker') not in ('speaker', 'spectator') then raise exception 'bad role'; end if;
  select count(*) filter (where role in ('manager','speaker')), count(*) filter (where role = 'spectator')
    into speakers, spectators from public.nx_room_members where room_id = p_room;
  -- #10: while a match is running nobody new gets a seat or the mic: late joiners are listeners (spectators)
  if r.status = 'playing' then
    if r.spectator_capacity is not null and spectators >= r.spectator_capacity then raise exception 'room full'; end if;
    role_to_use := 'spectator';
  elsif p_role = 'spectator' and (r.spectator_capacity is null or spectators < r.spectator_capacity) then role_to_use := 'spectator';
  elsif r.speaker_capacity is null or speakers < r.speaker_capacity then role_to_use := 'speaker';
  elsif r.spectator_capacity is null or spectators < r.spectator_capacity then role_to_use := 'spectator';
  else raise exception 'room full'; end if;
  insert into public.nx_room_members(room_id, user_id, role) values (p_room, me, role_to_use);
  if r.kind <> 'talk' and role_to_use = 'speaker' then
    game_limit := least(coalesce(r.seats, 6), public._nx_room_seat_limit(coalesce(r.selected_game, r.game)));
    select min(g) into seat_no from generate_series(0, game_limit - 1) g
     where not exists(select 1 from public.nx_room_game_players where room_id = p_room and seat = g)
       and not exists(select 1 from public.nx_room_players where room_id = p_room and seat = g);
    if seat_no is not null then
      insert into public.nx_room_game_players(room_id, user_id, seat, team) values (p_room, me, seat_no, seat_no % 2);
    end if;
  end if;
  update public.nx_rooms set updated_at = now() where id = p_room;
  return jsonb_build_object('room_id', p_room, 'role', role_to_use, 'seat', seat_no, 'status', r.status, 'match_id', r.match_id);
end $function$;

CREATE OR REPLACE FUNCTION public.nx_join_room(p_code text DEFAULT NULL::text, p_room uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare me uuid:=auth.uid(); rid uuid; r nx_rooms; joined jsonb; seat_no int; begin if me is null then raise exception 'not signed in'; end if; if p_room is not null then rid:=p_room; else select id into rid from nx_rooms where code=upper(trim(p_code)); end if; if rid is null then raise exception 'room not found'; end if; select * into r from nx_rooms where id=rid for update; joined:=nx_room_join(rid,'speaker'); seat_no:=nullif(joined->>'seat','')::int; if seat_no is not null and r.status = 'lobby' and not exists(select 1 from nx_room_players where room_id=rid and user_id=me) then insert into nx_room_players(room_id,user_id,seat,ready) values(rid,me,seat_no,false) on conflict(room_id,user_id) do update set last_seen=now(); end if; update nx_room_members set last_seen=now() where room_id=rid and user_id=me; return jsonb_build_object('room_id',rid,'code',r.code,'seat',seat_no,'role',joined->>'role','status',r.status,'match_id',r.match_id,'rejoined',coalesce((joined->>'rejoined')::boolean,false)); end $function$;
