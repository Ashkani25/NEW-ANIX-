-- P0 #7c: report kinds, core project (eisstodgncimypdawisy).
-- The client's report flow (lib/core/safety/safety_actions.dart, reportContent) files reports of kind profile, comment,
-- story and community too; the original check only allowed user/message/post/room/match/other, so those reports were
-- refused by the constraint. Widen the allowed list (no rows change).
alter table public.nx_user_reports drop constraint if exists nx_user_reports_kind_check;
alter table public.nx_user_reports add constraint nx_user_reports_kind_check
  check (kind = any (array['user', 'profile', 'message', 'post', 'comment', 'story', 'community', 'room', 'match', 'other']));
