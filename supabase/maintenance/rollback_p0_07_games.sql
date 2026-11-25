-- Rollback for games/migrations/20261125200600_p0_07_social_safety.sql
do $$ declare t text; begin
  foreach t in array array['nx_rooms','nx_room_members','nx_room_players','nx_room_game_players','nx_match_moves','nx_room_messages','nx_t_entries','nx_invites'] loop
    if to_regclass('public.'||t) is not null then execute format('drop trigger if exists nx_ban_guard on public.%I', t); end if;
  end loop; end $$;
drop trigger if exists nx_invites_block on public.nx_invites;
drop trigger if exists nx_rooms_safety on public.nx_rooms;
drop trigger if exists nx_room_messages_safety on public.nx_room_messages;
drop trigger if exists nx_tournaments_safety on public.nx_tournaments;
drop function if exists public.nx_g_my_ban(), public._nx_g_tournament_safety(), public._nx_g_room_messages_safety(),
  public._nx_g_rooms_safety(), public._nx_g_invites_block(), public._nx_g_ban_guard(), public._nx_g_blocked(uuid, uuid),
  public._nx_g_banned(uuid), public.nx_bridge_blocks_put(jsonb), public.nx_bridge_bans_put(jsonb);
drop table if exists public.user_blocks;  -- mirror only (source of truth: core user_blocks)
drop table if exists public.nx_bans;      -- mirror only (source of truth: core nx_account_flags)
drop function if exists public.nx_profanity_add(text, boolean, text), public.nx_profanity_mask(text), public.nx_profanity_check(text),
  public._nx_username_bad(text), public._nx_username_reserved(text), public._nx_name_rules_bypass(), public._nx_bad_token(text),
  public._nx_token_key(text, int), public._nx_text_norm(text);
drop table if exists public.nx_profanity_words;
