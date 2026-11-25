-- Rollback for migrations/20261125200600_p0_07_social_safety.sql
drop trigger if exists nx_profiles_safety on public.profiles;
drop trigger if exists nx_chats_safety on public.nx_chats;
drop trigger if exists nx_communities_safety on public.nx_communities;
drop trigger if exists nx_posts_safety on public.nx_posts;
drop trigger if exists nx_post_comments_safety on public.nx_post_comments;
drop trigger if exists nx_messages_safety on public.nx_messages;
drop trigger if exists nx_chat_members_block on public.nx_chat_members;
drop trigger if exists nx_calls_block on public.nx_calls;
drop trigger if exists nx_blocks_to_games on public.user_blocks;
drop trigger if exists nx_bans_to_games on public.nx_account_flags;
CREATE OR REPLACE FUNCTION public.nx_username_available(p_username text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select lower(btrim(coalesce(p_username, ''))) ~ '^[a-z0-9_.]{3,20}$'
     and not exists(select 1 from public.profiles where lower(username) = lower(btrim(p_username))) $function$;
drop function if exists public.nx_block_user(uuid), public.nx_unblock_user(uuid), public.nx_my_blocks(), public.nx_block_state(uuid),
  public._nx_blocks_to_games(), public._nx_bans_to_games(), public._nx_games_post(text, jsonb), public._nx_calls_block(),
  public._nx_chat_members_block(), public._nx_messages_safety(), public._nx_dm_peer(uuid, uuid), public._nx_text_mask_trg(),
  public._nx_names_safety(), public._nx_profiles_safety(),
  public.nx_profanity_add(text, boolean, text), public.nx_profanity_mask(text), public.nx_profanity_check(text),
  public._nx_username_bad(text), public._nx_username_reserved(text), public._nx_name_rules_bypass(), public._nx_bad_token(text),
  public._nx_token_key(text, int), public._nx_text_norm(text);
drop table if exists public.nx_profanity_words;
