-- Sweep S2 (core storage)
-- * Public buckets had a `SELECT to public` policy, which lets anyone (even without a session) LIST every object:
--   all users' photo/story/avatar file names, including private accounts'. Public-URL downloads do not need that
--   policy, so SELECT is now limited to the uploader's own folder (needed for upsert of avatars / crests).
-- * Legacy buckets (avatars, chat, nexora-avatars) no longer accept uploads/changes; their files stay readable by URL.
-- * UPDATE (move/rename) on nx-media / nx-chat-media must stay inside the caller's own folder.
drop policy if exists "nx_media_read" on storage.objects;
create policy "nx_media_read" on storage.objects for select to authenticated
  using (bucket_id = 'nx-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars read" on storage.objects;
drop policy if exists "chat read" on storage.objects;
drop policy if exists "avatars write own" on storage.objects;
drop policy if exists "avatars update own" on storage.objects;
drop policy if exists "avatars delete own" on storage.objects;
drop policy if exists "chat write own" on storage.objects;
drop policy if exists "Explorer avatar upload" on storage.objects;
drop policy if exists "Explorer avatar update" on storage.objects;
drop policy if exists "Explorer avatar delete" on storage.objects;
drop policy if exists "nx_media_update" on storage.objects;
create policy "nx_media_update" on storage.objects for update to authenticated
  using (bucket_id = 'nx-media' and owner = auth.uid())
  with check (bucket_id = 'nx-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "nx_chat_media_update" on storage.objects;
create policy "nx_chat_media_update" on storage.objects for update to authenticated
  using (bucket_id = 'nx-chat-media' and owner = auth.uid() and public.nx_can_read_chat_media(name))
  with check (bucket_id = 'nx-chat-media' and (storage.foldername(name))[1] = auth.uid()::text
              and (storage.foldername(name))[2] = 'chat'
              and public.nx_is_chat_member(((storage.foldername(name))[3])::uuid));
