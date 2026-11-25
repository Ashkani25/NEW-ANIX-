-- rollback #6 (games): previous nx_matches read policy + grants
drop policy if exists nx_matches_read on public.nx_matches;
create policy nx_matches_read on public.nx_matches as permissive for select to authenticated using (true);
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public.nx_matches to anon;
grant INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER on public.nx_matches to authenticated;
