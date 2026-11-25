-- Rollback for migrations/20261125210000_p0_07c_report_kinds.sql (core).
-- Reports filed with the new kinds would violate the old check: map them to 'other' first (keeps every report).
update public.nx_user_reports set kind = 'other' where kind in ('profile', 'comment', 'story', 'community');
alter table public.nx_user_reports drop constraint if exists nx_user_reports_kind_check;
alter table public.nx_user_reports add constraint nx_user_reports_kind_check
  check (kind = any (array['user'::text, 'message'::text, 'post'::text, 'room'::text, 'match'::text, 'other'::text]));
