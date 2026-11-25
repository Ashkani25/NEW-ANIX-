-- Rollback for migrations/20261125200000_p0_01_account_deletion.sql (core). Run only if no NULL owners exist yet.
drop function if exists public.nx_delete_account(text, text, boolean);
drop function if exists public.nx_my_storage_objects();
CREATE OR REPLACE FUNCTION public.nx_chats_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.id := old.id; new.kind := old.kind; new.owner := old.owner; new.dm_key := old.dm_key; new.created_at := old.created_at;
  return new;
end $function$;
alter table public.nx_chats drop constraint nx_chats_owner_fkey,
  add constraint nx_chats_owner_fkey foreign key (owner) references auth.users(id) on delete cascade;
alter table public.nx_chats alter column owner set not null;
alter table public.nx_communities drop constraint nx_communities_owner_fkey,
  add constraint nx_communities_owner_fkey foreign key (owner) references auth.users(id) on delete cascade;
alter table public.nx_communities alter column owner set not null;
