-- Games project (eyzafhrefnqlwcjpcdyg) baseline, generated read-only from the live catalog on 2026-11-25
-- (pg_get_functiondef / pg_get_constraintdef / pg_policies / grants). Reproduces the public schema as it was before
-- the fix/backend-security migrations. Apply only to an EMPTY project.

-- [0] pg_cron
create extension if not exists pg_cron with schema pg_catalog;

-- [0] pg_net
create extension if not exists pg_net with schema public;

-- [0] pg_stat_statements
create extension if not exists pg_stat_statements with schema extensions;

-- [0] pgcrypto
create extension if not exists pgcrypto with schema extensions;

-- [0] supabase_vault
create extension if not exists supabase_vault with schema vault;

-- [0] uuid-ossp
create extension if not exists "uuid-ossp" with schema extensions;

-- [2] nx_admin_audit_id_seq
create sequence if not exists public.nx_admin_audit_id_seq;

-- [2] nx_arcade_runs_id_seq
create sequence if not exists public.nx_arcade_runs_id_seq;

-- [2] nx_invites_id_seq
create sequence if not exists public.nx_invites_id_seq;

-- [2] nx_t_audit_id_seq
create sequence if not exists public.nx_t_audit_id_seq;

-- [2] nx_t_code_attempts_id_seq
create sequence if not exists public.nx_t_code_attempts_id_seq;

-- [2] nx_t_jobs_id_seq
create sequence if not exists public.nx_t_jobs_id_seq;

-- [2] nx_t_ledger_id_seq
create sequence if not exists public.nx_t_ledger_id_seq;

-- [2] nx_t_notifications_id_seq
create sequence if not exists public.nx_t_notifications_id_seq;

-- [2] nx_wallet_tx_id_seq
create sequence if not exists public.nx_wallet_tx_id_seq;

-- [2] nx_xp_events_id_seq
create sequence if not exists public.nx_xp_events_id_seq;

-- [3] nx_admin_audit
create table if not exists public.nx_admin_audit (
  id bigint default nextval('nx_admin_audit_id_seq'::regclass) not null,
  actor uuid,
  action text not null,
  target text,
  data jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_arcade_best
create table if not exists public.nx_arcade_best (
  user_id uuid not null,
  game text not null,
  best integer default 0 not null,
  best_at timestamp with time zone default now() not null,
  daily_day date,
  daily_best integer default 0 not null,
  plays integer default 0 not null,
  last_submit timestamp with time zone
);

-- [3] nx_arcade_runs
create table if not exists public.nx_arcade_runs (
  id bigint default nextval('nx_arcade_runs_id_seq'::regclass) not null,
  user_id uuid not null,
  game text not null,
  score integer not null,
  duration_ms integer not null,
  daily boolean default false not null,
  accepted boolean not null,
  reason text,
  meta jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_cosmetic_equipped
create table if not exists public.nx_cosmetic_equipped (
  user_id uuid not null,
  game text not null,
  kind text not null,
  item_id text not null,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_cosmetic_owned
create table if not exists public.nx_cosmetic_owned (
  user_id uuid not null,
  item_id text not null,
  price_paid integer default 0 not null,
  acquired_at timestamp with time zone default now() not null
);

-- [3] nx_cosmetics
create table if not exists public.nx_cosmetics (
  item_id text not null,
  game text not null,
  kind text not null,
  name text not null,
  name_fa text,
  price_coins integer default 0 not null,
  active boolean default true not null,
  sort integer default 0 not null,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_game_stats
create table if not exists public.nx_game_stats (
  user_id uuid not null,
  game text not null,
  played integer default 0 not null,
  won integer default 0 not null,
  lost integer default 0 not null,
  draw integer default 0 not null,
  rating integer default 1000 not null,
  best integer default 0 not null,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_invites
create table if not exists public.nx_invites (
  id bigint default nextval('nx_invites_id_seq'::regclass) not null,
  from_user uuid not null,
  to_user uuid not null,
  kind text default 'game'::text not null,
  room_id uuid,
  payload jsonb default '{}'::jsonb not null,
  status text default 'pending'::text not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_match_moves
create table if not exists public.nx_match_moves (
  match_id uuid not null,
  seq integer not null,
  seat integer not null,
  by_user uuid not null,
  kind text default 'move'::text not null,
  move jsonb not null,
  hash text,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_match_presence
create table if not exists public.nx_match_presence (
  match_id uuid not null,
  user_id uuid not null,
  last_seen timestamp with time zone default now() not null
);

-- [3] nx_match_reports
create table if not exists public.nx_match_reports (
  match_id uuid not null,
  user_id uuid not null,
  winners integer[] default '{}'::integer[] not null,
  scores integer[],
  state_hash text,
  reason text,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_match_results
create table if not exists public.nx_match_results (
  match_id uuid not null,
  user_id uuid not null,
  game text not null,
  seat integer not null,
  outcome text not null,
  score integer default 0 not null,
  rating_delta integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_match_secrets
create table if not exists public.nx_match_secrets (
  match_id uuid not null,
  user_id uuid not null,
  slot text default 'role'::text not null,
  data jsonb not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_match_turn_state
create table if not exists public.nx_match_turn_state (
  match_id uuid not null,
  authority_user uuid not null,
  epoch bigint default 0 not null,
  seat integer not null,
  deadline timestamp with time zone not null,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_matches
create table if not exists public.nx_matches (
  id uuid default gen_random_uuid() not null,
  room_id uuid,
  game text not null,
  players uuid[] not null,
  names text[] default '{}'::text[] not null,
  seed bigint not null,
  settings jsonb default '{}'::jsonb not null,
  status text default 'playing'::text not null,
  winner_seats integer[],
  scores integer[],
  reason text,
  last_seq integer default 0 not null,
  state_hash text,
  started_at timestamp with time zone default now() not null,
  ended_at timestamp with time zone,
  turn_seat integer default 0 not null,
  turn_deadline timestamp with time zone default (now() + '00:00:10'::interval) not null,
  physics_version text default 'physics-2026-11-18-v1'::text not null,
  physics_contract jsonb default '{}'::jsonb not null
);

-- [3] nx_physics_contracts
create table if not exists public.nx_physics_contracts (
  game text not null,
  version text not null,
  contract jsonb not null,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_quiz_answers
create table if not exists public.nx_quiz_answers (
  match_id uuid not null,
  round integer not null,
  seat integer not null,
  user_id uuid not null,
  choice smallint,
  elapsed_ms integer not null,
  correct boolean not null,
  points integer not null,
  answered_at timestamp with time zone default now() not null
);

-- [3] nx_quiz_games
create table if not exists public.nx_quiz_games (
  match_id uuid not null,
  category text,
  rounds integer default 10 not null,
  round_idx integer default '-1'::integer not null,
  phase text default 'pick'::text not null,
  qids text[] default '{}'::text[] not null,
  phase_started timestamp with time zone default now() not null,
  phase_ends timestamp with time zone,
  winners integer[],
  created_at timestamp with time zone default now() not null
);

-- [3] nx_quiz_questions
create table if not exists public.nx_quiz_questions (
  id text not null,
  category text not null,
  difficulty smallint default 1 not null,
  fa text not null,
  en text not null,
  options_fa jsonb not null,
  options_en jsonb not null,
  correct smallint not null,
  active boolean default true not null
);

-- [3] nx_quiz_seen
create table if not exists public.nx_quiz_seen (
  user_id uuid not null,
  question_id text not null,
  seen_at timestamp with time zone default now() not null
);

-- [3] nx_room_game_players
create table if not exists public.nx_room_game_players (
  room_id uuid not null,
  user_id uuid not null,
  seat integer not null,
  team integer default 0 not null,
  ready boolean default false not null,
  selected_at timestamp with time zone default now() not null,
  prefs jsonb default '{}'::jsonb not null
);

-- [3] nx_room_members
create table if not exists public.nx_room_members (
  room_id uuid not null,
  user_id uuid not null,
  role text not null,
  joined_at timestamp with time zone default now() not null,
  last_seen timestamp with time zone default now() not null,
  muted boolean default false not null
);

-- [3] nx_room_messages
create table if not exists public.nx_room_messages (
  id uuid default gen_random_uuid() not null,
  room_id uuid not null,
  author uuid not null,
  text text not null,
  created_at timestamp with time zone default now() not null,
  edited_at timestamp with time zone,
  deleted boolean default false not null
);

-- [3] nx_room_players
create table if not exists public.nx_room_players (
  room_id uuid not null,
  user_id uuid not null,
  seat integer not null,
  ready boolean default false not null,
  joined_at timestamp with time zone default now() not null,
  last_seen timestamp with time zone default now() not null
);

-- [3] nx_rooms
create table if not exists public.nx_rooms (
  id uuid default gen_random_uuid() not null,
  code text not null,
  game text not null,
  host uuid not null,
  seats integer default 2 not null,
  status text default 'lobby'::text not null,
  is_private boolean default false not null,
  quick boolean default false not null,
  settings jsonb default '{}'::jsonb not null,
  match_id uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  speaker_capacity integer default 30,
  spectator_capacity integer default 30,
  selected_game text,
  selected_seats integer[] default '{}'::integer[] not null,
  title text,
  kind text default 'game'::text not null,
  join_locked boolean default false not null
);

-- [3] nx_staff
create table if not exists public.nx_staff (
  user_id uuid not null,
  role text,
  perms text[] default '{}'::text[] not null,
  unlimited boolean default false not null,
  gem_budget integer,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_t_audit
create table if not exists public.nx_t_audit (
  id bigint default nextval('nx_t_audit_id_seq'::regclass) not null,
  tournament_id uuid,
  actor uuid,
  action text not null,
  data jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_code_attempts
create table if not exists public.nx_t_code_attempts (
  id bigint default nextval('nx_t_code_attempts_id_seq'::regclass) not null,
  user_id uuid not null,
  code text not null,
  ok boolean not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_codes
create table if not exists public.nx_t_codes (
  id uuid default gen_random_uuid() not null,
  tournament_id uuid not null,
  code text not null,
  max_uses integer default 1 not null,
  uses integer default 0 not null,
  expires_at timestamp with time zone,
  revoked boolean default false not null,
  requires_approval boolean default false not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_entries
create table if not exists public.nx_t_entries (
  tournament_id uuid not null,
  user_id uuid not null,
  status text not null,
  seed integer,
  group_no integer,
  rating integer default 1000 not null,
  paid_coins integer default 0 not null,
  paid_gems integer default 0 not null,
  fee_ref bigint,
  code_id uuid,
  note text,
  place integer,
  decided_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  checked_in_at timestamp with time zone
);

-- [3] nx_t_games
create table if not exists public.nx_t_games (
  game_match uuid not null,
  tmatch uuid not null,
  n integer not null,
  home uuid not null,
  away uuid not null,
  golden boolean default false not null,
  ended_at timestamp with time zone,
  srv_winner uuid,
  srv_s_home integer,
  srv_s_away integer,
  accepted boolean default false not null,
  disputed boolean default false not null,
  winner uuid,
  s_home integer,
  s_away integer,
  source text,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_jobs
create table if not exists public.nx_t_jobs (
  id bigint default nextval('nx_t_jobs_id_seq'::regclass) not null,
  kind text not null,
  tournament_id uuid,
  ref uuid,
  run_at timestamp with time zone not null,
  done_at timestamp with time zone,
  attempts integer default 0 not null,
  last_error text,
  idem_key text not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_ledger
create table if not exists public.nx_t_ledger (
  id bigint default nextval('nx_t_ledger_id_seq'::regclass) not null,
  tournament_id uuid not null,
  user_id uuid,
  kind text not null,
  currency text not null,
  amount integer not null,
  place integer,
  idem_key text not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_matches
create table if not exists public.nx_t_matches (
  id uuid default gen_random_uuid() not null,
  tournament_id uuid not null,
  stage text default 'main'::text not null,
  bracket text not null,
  round integer not null,
  idx integer default 0 not null,
  tslot integer default 1 not null,
  group_no integer,
  label text,
  p1 uuid,
  p2 uuid,
  p1_set boolean default false not null,
  p2_set boolean default false not null,
  win_to uuid,
  win_slot smallint,
  lose_to uuid,
  lose_slot smallint,
  best_of smallint default 1 not null,
  aggregate boolean default false not null,
  status text default 'pending'::text not null,
  scheduled_at timestamp with time zone,
  ready_deadline timestamp with time zone,
  p1_ready boolean default false not null,
  p2_ready boolean default false not null,
  games integer default 0 not null,
  w1 integer default 0 not null,
  w2 integer default 0 not null,
  g1 integer default 0 not null,
  g2 integer default 0 not null,
  winner uuid,
  loser uuid,
  is_draw boolean default false not null,
  game_match uuid,
  result_note text,
  finished_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_t_notifications
create table if not exists public.nx_t_notifications (
  id bigint default nextval('nx_t_notifications_id_seq'::regclass) not null,
  user_id uuid not null,
  tournament_id uuid,
  tmatch uuid,
  kind text not null,
  data jsonb default '{}'::jsonb not null,
  read boolean default false not null,
  dedup text,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_reports
create table if not exists public.nx_t_reports (
  game_match uuid not null,
  user_id uuid not null,
  winner uuid,
  s_home integer not null,
  s_away integer not null,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_t_staff
create table if not exists public.nx_t_staff (
  tournament_id uuid not null,
  user_id uuid not null,
  added_by uuid,
  created_at timestamp with time zone default now() not null
);

-- [3] nx_tournaments
create table if not exists public.nx_tournaments (
  id uuid default gen_random_uuid() not null,
  title text not null,
  description text default ''::text not null,
  rules text default ''::text not null,
  game text default 'finger_soccer'::text not null,
  created_by uuid not null,
  status text default 'draft'::text not null,
  paused boolean default false not null,
  format text not null,
  capacity integer not null,
  min_players integer default 2 not null,
  config jsonb default '{}'::jsonb not null,
  reg_mode text default 'open'::text not null,
  min_level integer default 0 not null,
  min_xp integer default 0 not null,
  min_rating integer default 0 not null,
  fee_coins integer default 0 not null,
  fee_gems integer default 0 not null,
  prize jsonb default '{}'::jsonb not null,
  reg_open_at timestamp with time zone not null,
  reg_close_at timestamp with time zone not null,
  draw_at timestamp with time zone not null,
  start_at timestamp with time zone not null,
  seeding text default 'random'::text not null,
  seed bigint,
  stage text default 'main'::text not null,
  escrow_coins integer default 0 not null,
  escrow_gems integer default 0 not null,
  paid_out boolean default false not null,
  cancel_reason text,
  winner uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  published_at timestamp with time zone,
  drawn_at timestamp with time zone,
  started_at timestamp with time zone,
  finished_at timestamp with time zone
);

-- [3] nx_user_mutes
create table if not exists public.nx_user_mutes (
  user_id uuid not null,
  muted_until timestamp with time zone,
  reason text,
  by uuid,
  updated_at timestamp with time zone default now() not null
);

-- [3] nx_wallet_tx
create table if not exists public.nx_wallet_tx (
  id bigint default nextval('nx_wallet_tx_id_seq'::regclass) not null,
  user_id uuid not null,
  xp integer default 0 not null,
  coins integer default 0 not null,
  gems integer default 0 not null,
  reason text,
  created_at timestamp with time zone default now() not null,
  sent_at timestamp with time zone,
  request_id bigint,
  acked_at timestamp with time zone,
  tries integer default 0 not null
);

-- [3] nx_xp_events
create table if not exists public.nx_xp_events (
  id bigint default nextval('nx_xp_events_id_seq'::regclass) not null,
  user_id uuid not null,
  idem_key text not null,
  event text not null,
  xp integer default 0 not null,
  coins integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

-- [3] profiles
create table if not exists public.profiles (
  id uuid not null,
  username text,
  avatar text,
  xp integer default 0 not null,
  level integer default 1 not null,
  coins integer default 0 not null,
  gems integer default 0 not null,
  role text,
  synced_at timestamp with time zone,
  updated_at timestamp with time zone default now() not null
);

-- [4] nx_admin_audit_pkey
alter table public.nx_admin_audit add constraint nx_admin_audit_pkey PRIMARY KEY (id);

-- [4] nx_arcade_best_pkey
alter table public.nx_arcade_best add constraint nx_arcade_best_pkey PRIMARY KEY (user_id, game);

-- [4] nx_arcade_runs_pkey
alter table public.nx_arcade_runs add constraint nx_arcade_runs_pkey PRIMARY KEY (id);

-- [4] nx_cosmetic_equipped_pkey
alter table public.nx_cosmetic_equipped add constraint nx_cosmetic_equipped_pkey PRIMARY KEY (user_id, game, kind);

-- [4] nx_cosmetic_owned_pkey
alter table public.nx_cosmetic_owned add constraint nx_cosmetic_owned_pkey PRIMARY KEY (user_id, item_id);

-- [4] nx_cosmetics_item_id_check
alter table public.nx_cosmetics add constraint nx_cosmetics_item_id_check CHECK ((item_id ~ '^[a-z0-9_]+:[a-z0-9_]{1,48}$'::text));

-- [4] nx_cosmetics_pkey
alter table public.nx_cosmetics add constraint nx_cosmetics_pkey PRIMARY KEY (item_id);

-- [4] nx_cosmetics_price_coins_check
alter table public.nx_cosmetics add constraint nx_cosmetics_price_coins_check CHECK (((price_coins >= 0) AND (price_coins <= 100000)));

-- [4] nx_game_stats_pkey
alter table public.nx_game_stats add constraint nx_game_stats_pkey PRIMARY KEY (user_id, game);

-- [4] nx_invites_pkey
alter table public.nx_invites add constraint nx_invites_pkey PRIMARY KEY (id);

-- [4] nx_invites_status_check
alter table public.nx_invites add constraint nx_invites_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'expired'::text])));

-- [4] nx_match_moves_pkey
alter table public.nx_match_moves add constraint nx_match_moves_pkey PRIMARY KEY (match_id, seq);

-- [4] nx_match_presence_pkey
alter table public.nx_match_presence add constraint nx_match_presence_pkey PRIMARY KEY (match_id, user_id);

-- [4] nx_match_reports_pkey
alter table public.nx_match_reports add constraint nx_match_reports_pkey PRIMARY KEY (match_id, user_id);

-- [4] nx_match_results_outcome_check
alter table public.nx_match_results add constraint nx_match_results_outcome_check CHECK ((outcome = ANY (ARRAY['win'::text, 'loss'::text, 'draw'::text])));

-- [4] nx_match_results_pkey
alter table public.nx_match_results add constraint nx_match_results_pkey PRIMARY KEY (match_id, user_id);

-- [4] nx_match_secrets_pkey
alter table public.nx_match_secrets add constraint nx_match_secrets_pkey PRIMARY KEY (match_id, user_id, slot);

-- [4] nx_match_turn_state_pkey
alter table public.nx_match_turn_state add constraint nx_match_turn_state_pkey PRIMARY KEY (match_id);

-- [4] nx_matches_pkey
alter table public.nx_matches add constraint nx_matches_pkey PRIMARY KEY (id);

-- [4] nx_matches_status_check
alter table public.nx_matches add constraint nx_matches_status_check CHECK ((status = ANY (ARRAY['playing'::text, 'finished'::text, 'abandoned'::text, 'disputed'::text])));

-- [4] nx_physics_contracts_pkey
alter table public.nx_physics_contracts add constraint nx_physics_contracts_pkey PRIMARY KEY (game);

-- [4] nx_quiz_answers_pkey
alter table public.nx_quiz_answers add constraint nx_quiz_answers_pkey PRIMARY KEY (match_id, round, seat);

-- [4] nx_quiz_games_phase_check
alter table public.nx_quiz_games add constraint nx_quiz_games_phase_check CHECK ((phase = ANY (ARRAY['pick'::text, 'question'::text, 'reveal'::text, 'done'::text])));

-- [4] nx_quiz_games_pkey
alter table public.nx_quiz_games add constraint nx_quiz_games_pkey PRIMARY KEY (match_id);

-- [4] nx_quiz_questions_correct_check
alter table public.nx_quiz_questions add constraint nx_quiz_questions_correct_check CHECK (((correct >= 0) AND (correct <= 3)));

-- [4] nx_quiz_questions_pkey
alter table public.nx_quiz_questions add constraint nx_quiz_questions_pkey PRIMARY KEY (id);

-- [4] nx_quiz_seen_pkey
alter table public.nx_quiz_seen add constraint nx_quiz_seen_pkey PRIMARY KEY (user_id, question_id);

-- [4] nx_room_game_players_pkey
alter table public.nx_room_game_players add constraint nx_room_game_players_pkey PRIMARY KEY (room_id, user_id);

-- [4] nx_room_game_players_room_id_seat_key
alter table public.nx_room_game_players add constraint nx_room_game_players_room_id_seat_key UNIQUE (room_id, seat);

-- [4] nx_room_game_players_seat_check
alter table public.nx_room_game_players add constraint nx_room_game_players_seat_check CHECK (((seat >= 0) AND (seat <= 20)));

-- [4] nx_room_game_players_team_check
alter table public.nx_room_game_players add constraint nx_room_game_players_team_check CHECK (((team >= 0) AND (team <= 2)));

-- [4] nx_room_members_pkey
alter table public.nx_room_members add constraint nx_room_members_pkey PRIMARY KEY (room_id, user_id);

-- [4] nx_room_members_role_check
alter table public.nx_room_members add constraint nx_room_members_role_check CHECK ((role = ANY (ARRAY['manager'::text, 'speaker'::text, 'spectator'::text])));

-- [4] nx_room_messages_pkey
alter table public.nx_room_messages add constraint nx_room_messages_pkey PRIMARY KEY (id);

-- [4] nx_room_messages_text_check
alter table public.nx_room_messages add constraint nx_room_messages_text_check CHECK (((char_length(btrim(text)) >= 1) AND (char_length(btrim(text)) <= 4000)));

-- [4] nx_room_players_pkey
alter table public.nx_room_players add constraint nx_room_players_pkey PRIMARY KEY (room_id, user_id);

-- [4] nx_room_players_room_id_seat_key
alter table public.nx_room_players add constraint nx_room_players_room_id_seat_key UNIQUE (room_id, seat);

-- [4] nx_rooms_code_key
alter table public.nx_rooms add constraint nx_rooms_code_key UNIQUE (code);

-- [4] nx_rooms_pkey
alter table public.nx_rooms add constraint nx_rooms_pkey PRIMARY KEY (id);

-- [4] nx_rooms_seats_check
alter table public.nx_rooms add constraint nx_rooms_seats_check CHECK (((seats >= 2) AND (seats <= 32)));

-- [4] nx_rooms_status_check
alter table public.nx_rooms add constraint nx_rooms_status_check CHECK ((status = ANY (ARRAY['lobby'::text, 'playing'::text, 'closed'::text])));

-- [4] nx_staff_pkey
alter table public.nx_staff add constraint nx_staff_pkey PRIMARY KEY (user_id);

-- [4] nx_t_audit_pkey
alter table public.nx_t_audit add constraint nx_t_audit_pkey PRIMARY KEY (id);

-- [4] nx_t_code_attempts_pkey
alter table public.nx_t_code_attempts add constraint nx_t_code_attempts_pkey PRIMARY KEY (id);

-- [4] nx_t_codes_code_check
alter table public.nx_t_codes add constraint nx_t_codes_code_check CHECK ((code ~ '^[A-HJ-NP-Z2-9]{8}$'::text));

-- [4] nx_t_codes_code_key
alter table public.nx_t_codes add constraint nx_t_codes_code_key UNIQUE (code);

-- [4] nx_t_codes_max_uses_check
alter table public.nx_t_codes add constraint nx_t_codes_max_uses_check CHECK (((max_uses >= 1) AND (max_uses <= 1000)));

-- [4] nx_t_codes_pkey
alter table public.nx_t_codes add constraint nx_t_codes_pkey PRIMARY KEY (id);

-- [4] nx_t_entries_pkey
alter table public.nx_t_entries add constraint nx_t_entries_pkey PRIMARY KEY (tournament_id, user_id);

-- [4] nx_t_entries_status_check
alter table public.nx_t_entries add constraint nx_t_entries_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'waitlist'::text, 'withdrawn'::text, 'removed'::text, 'no_checkin'::text])));

-- [4] nx_t_games_pkey
alter table public.nx_t_games add constraint nx_t_games_pkey PRIMARY KEY (game_match);

-- [4] nx_t_jobs_idem_key_key
alter table public.nx_t_jobs add constraint nx_t_jobs_idem_key_key UNIQUE (idem_key);

-- [4] nx_t_jobs_pkey
alter table public.nx_t_jobs add constraint nx_t_jobs_pkey PRIMARY KEY (id);

-- [4] nx_t_ledger_currency_check
alter table public.nx_t_ledger add constraint nx_t_ledger_currency_check CHECK ((currency = ANY (ARRAY['coins'::text, 'gems'::text])));

-- [4] nx_t_ledger_idem_key_key
alter table public.nx_t_ledger add constraint nx_t_ledger_idem_key_key UNIQUE (idem_key);

-- [4] nx_t_ledger_kind_check
alter table public.nx_t_ledger add constraint nx_t_ledger_kind_check CHECK ((kind = ANY (ARRAY['entry_fee'::text, 'refund'::text, 'payout'::text, 'house_fee'::text, 'entry_fee_unlimited'::text, 'refund_unlimited'::text])));

-- [4] nx_t_ledger_pkey
alter table public.nx_t_ledger add constraint nx_t_ledger_pkey PRIMARY KEY (id);

-- [4] nx_t_matches_best_of_check
alter table public.nx_t_matches add constraint nx_t_matches_best_of_check CHECK (((best_of >= 1) AND (best_of <= 15)));

-- [4] nx_t_matches_bracket_check
alter table public.nx_t_matches add constraint nx_t_matches_bracket_check CHECK ((bracket = ANY (ARRAY['W'::text, 'L'::text, 'GF'::text, 'GF2'::text, 'P3'::text, 'RR'::text, 'G'::text, 'SW'::text, 'C'::text])));

-- [4] nx_t_matches_pkey
alter table public.nx_t_matches add constraint nx_t_matches_pkey PRIMARY KEY (id);

-- [4] nx_t_matches_status_check
alter table public.nx_t_matches add constraint nx_t_matches_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'scheduled'::text, 'ready_check'::text, 'playing'::text, 'done'::text, 'walkover'::text, 'bye'::text, 'disputed'::text, 'void'::text, 'skipped'::text])));

-- [4] nx_t_notifications_pkey
alter table public.nx_t_notifications add constraint nx_t_notifications_pkey PRIMARY KEY (id);

-- [4] nx_t_notifications_user_id_dedup_key
alter table public.nx_t_notifications add constraint nx_t_notifications_user_id_dedup_key UNIQUE (user_id, dedup);

-- [4] nx_t_reports_pkey
alter table public.nx_t_reports add constraint nx_t_reports_pkey PRIMARY KEY (game_match, user_id);

-- [4] nx_t_staff_pkey
alter table public.nx_t_staff add constraint nx_t_staff_pkey PRIMARY KEY (tournament_id, user_id);

-- [4] nx_t_times
alter table public.nx_tournaments add constraint nx_t_times CHECK (((reg_open_at < reg_close_at) AND (reg_close_at <= draw_at) AND (draw_at <= start_at)));

-- [4] nx_tournaments_capacity_check
alter table public.nx_tournaments add constraint nx_tournaments_capacity_check CHECK (((capacity >= 2) AND (capacity <= 64)));

-- [4] nx_tournaments_escrow_coins_check
alter table public.nx_tournaments add constraint nx_tournaments_escrow_coins_check CHECK ((escrow_coins >= 0));

-- [4] nx_tournaments_escrow_gems_check
alter table public.nx_tournaments add constraint nx_tournaments_escrow_gems_check CHECK ((escrow_gems >= 0));

-- [4] nx_tournaments_fee_coins_check
alter table public.nx_tournaments add constraint nx_tournaments_fee_coins_check CHECK (((fee_coins >= 0) AND (fee_coins <= 1000000)));

-- [4] nx_tournaments_fee_gems_check
alter table public.nx_tournaments add constraint nx_tournaments_fee_gems_check CHECK (((fee_gems >= 0) AND (fee_gems <= 100000)));

-- [4] nx_tournaments_format_check
alter table public.nx_tournaments add constraint nx_tournaments_format_check CHECK ((format = ANY (ARRAY['single_elim'::text, 'double_elim'::text, 'two_legs'::text, 'round_robin'::text, 'groups_ko'::text, 'swiss'::text, 'custom'::text])));

-- [4] nx_tournaments_min_players_check
alter table public.nx_tournaments add constraint nx_tournaments_min_players_check CHECK ((min_players >= 2));

-- [4] nx_tournaments_pkey
alter table public.nx_tournaments add constraint nx_tournaments_pkey PRIMARY KEY (id);

-- [4] nx_tournaments_reg_mode_check
alter table public.nx_tournaments add constraint nx_tournaments_reg_mode_check CHECK ((reg_mode = ANY (ARRAY['open'::text, 'approval'::text, 'code'::text, 'code_approval'::text])));

-- [4] nx_tournaments_seeding_check
alter table public.nx_tournaments add constraint nx_tournaments_seeding_check CHECK ((seeding = ANY (ARRAY['random'::text, 'rating'::text, 'manual'::text])));

-- [4] nx_tournaments_stage_check
alter table public.nx_tournaments add constraint nx_tournaments_stage_check CHECK ((stage = ANY (ARRAY['main'::text, 'groups'::text, 'ko'::text])));

-- [4] nx_tournaments_status_check
alter table public.nx_tournaments add constraint nx_tournaments_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'scheduled'::text, 'registering'::text, 'closed'::text, 'drawn'::text, 'live'::text, 'finished'::text, 'cancelled'::text])));

-- [4] nx_tournaments_title_check
alter table public.nx_tournaments add constraint nx_tournaments_title_check CHECK (((char_length(title) >= 3) AND (char_length(title) <= 80)));

-- [4] nx_user_mutes_pkey
alter table public.nx_user_mutes add constraint nx_user_mutes_pkey PRIMARY KEY (user_id);

-- [4] nx_wallet_tx_pkey
alter table public.nx_wallet_tx add constraint nx_wallet_tx_pkey PRIMARY KEY (id);

-- [4] nx_xp_events_pkey
alter table public.nx_xp_events add constraint nx_xp_events_pkey PRIMARY KEY (id);

-- [4] nx_xp_events_user_id_idem_key_key
alter table public.nx_xp_events add constraint nx_xp_events_user_id_idem_key_key UNIQUE (user_id, idem_key);

-- [4] profiles_pkey
alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);

-- [5] nx_arcade_best_user_id_fkey
alter table public.nx_arcade_best add constraint nx_arcade_best_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_arcade_runs_user_id_fkey
alter table public.nx_arcade_runs add constraint nx_arcade_runs_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_cosmetic_equipped_item_id_fkey
alter table public.nx_cosmetic_equipped add constraint nx_cosmetic_equipped_item_id_fkey FOREIGN KEY (item_id) REFERENCES nx_cosmetics(item_id) ON UPDATE CASCADE;

-- [5] nx_cosmetic_owned_item_id_fkey
alter table public.nx_cosmetic_owned add constraint nx_cosmetic_owned_item_id_fkey FOREIGN KEY (item_id) REFERENCES nx_cosmetics(item_id) ON UPDATE CASCADE;

-- [5] nx_game_stats_profile_fk
alter table public.nx_game_stats add constraint nx_game_stats_profile_fk FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_invites_room_id_fkey
alter table public.nx_invites add constraint nx_invites_room_id_fkey FOREIGN KEY (room_id) REFERENCES nx_rooms(id) ON DELETE CASCADE;

-- [5] nx_match_moves_match_id_fkey
alter table public.nx_match_moves add constraint nx_match_moves_match_id_fkey FOREIGN KEY (match_id) REFERENCES nx_matches(id) ON DELETE CASCADE;

-- [5] nx_match_results_match_id_fkey
alter table public.nx_match_results add constraint nx_match_results_match_id_fkey FOREIGN KEY (match_id) REFERENCES nx_matches(id) ON DELETE CASCADE;

-- [5] nx_match_results_profile_fk
alter table public.nx_match_results add constraint nx_match_results_profile_fk FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_match_secrets_match_id_fkey
alter table public.nx_match_secrets add constraint nx_match_secrets_match_id_fkey FOREIGN KEY (match_id) REFERENCES nx_matches(id) ON DELETE CASCADE;

-- [5] nx_match_turn_state_match_id_fkey
alter table public.nx_match_turn_state add constraint nx_match_turn_state_match_id_fkey FOREIGN KEY (match_id) REFERENCES nx_matches(id) ON DELETE CASCADE;

-- [5] nx_matches_room_id_fkey
alter table public.nx_matches add constraint nx_matches_room_id_fkey FOREIGN KEY (room_id) REFERENCES nx_rooms(id) ON DELETE SET NULL;

-- [5] nx_quiz_answers_match_id_fkey
alter table public.nx_quiz_answers add constraint nx_quiz_answers_match_id_fkey FOREIGN KEY (match_id) REFERENCES nx_matches(id) ON DELETE CASCADE;

-- [5] nx_quiz_games_match_id_fkey
alter table public.nx_quiz_games add constraint nx_quiz_games_match_id_fkey FOREIGN KEY (match_id) REFERENCES nx_matches(id) ON DELETE CASCADE;

-- [5] nx_room_game_players_room_id_fkey
alter table public.nx_room_game_players add constraint nx_room_game_players_room_id_fkey FOREIGN KEY (room_id) REFERENCES nx_rooms(id) ON DELETE CASCADE;

-- [5] nx_room_game_players_user_id_fkey
alter table public.nx_room_game_players add constraint nx_room_game_players_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_room_members_room_id_fkey
alter table public.nx_room_members add constraint nx_room_members_room_id_fkey FOREIGN KEY (room_id) REFERENCES nx_rooms(id) ON DELETE CASCADE;

-- [5] nx_room_members_user_id_fkey
alter table public.nx_room_members add constraint nx_room_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_room_messages_author_fkey
alter table public.nx_room_messages add constraint nx_room_messages_author_fkey FOREIGN KEY (author) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_room_messages_room_id_fkey
alter table public.nx_room_messages add constraint nx_room_messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES nx_rooms(id) ON DELETE CASCADE;

-- [5] nx_room_players_profile_fk
alter table public.nx_room_players add constraint nx_room_players_profile_fk FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_room_players_room_id_fkey
alter table public.nx_room_players add constraint nx_room_players_room_id_fkey FOREIGN KEY (room_id) REFERENCES nx_rooms(id) ON DELETE CASCADE;

-- [5] nx_rooms_host_fkey
alter table public.nx_rooms add constraint nx_rooms_host_fkey FOREIGN KEY (host) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_t_codes_tournament_id_fkey
alter table public.nx_t_codes add constraint nx_t_codes_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES nx_tournaments(id) ON DELETE CASCADE;

-- [5] nx_t_entries_tournament_id_fkey
alter table public.nx_t_entries add constraint nx_t_entries_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES nx_tournaments(id) ON DELETE CASCADE;

-- [5] nx_t_entries_user_id_fkey
alter table public.nx_t_entries add constraint nx_t_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_t_games_game_match_fkey
alter table public.nx_t_games add constraint nx_t_games_game_match_fkey FOREIGN KEY (game_match) REFERENCES nx_matches(id) ON DELETE CASCADE;

-- [5] nx_t_games_tmatch_fkey
alter table public.nx_t_games add constraint nx_t_games_tmatch_fkey FOREIGN KEY (tmatch) REFERENCES nx_t_matches(id) ON DELETE CASCADE;

-- [5] nx_t_jobs_tournament_id_fkey
alter table public.nx_t_jobs add constraint nx_t_jobs_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES nx_tournaments(id) ON DELETE CASCADE;

-- [5] nx_t_ledger_tournament_id_fkey
alter table public.nx_t_ledger add constraint nx_t_ledger_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES nx_tournaments(id) ON DELETE RESTRICT;

-- [5] nx_t_matches_lose_to_fkey
alter table public.nx_t_matches add constraint nx_t_matches_lose_to_fkey FOREIGN KEY (lose_to) REFERENCES nx_t_matches(id) ON DELETE SET NULL;

-- [5] nx_t_matches_p1_fkey
alter table public.nx_t_matches add constraint nx_t_matches_p1_fkey FOREIGN KEY (p1) REFERENCES profiles(id) ON DELETE SET NULL;

-- [5] nx_t_matches_p2_fkey
alter table public.nx_t_matches add constraint nx_t_matches_p2_fkey FOREIGN KEY (p2) REFERENCES profiles(id) ON DELETE SET NULL;

-- [5] nx_t_matches_tournament_id_fkey
alter table public.nx_t_matches add constraint nx_t_matches_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES nx_tournaments(id) ON DELETE CASCADE;

-- [5] nx_t_matches_win_to_fkey
alter table public.nx_t_matches add constraint nx_t_matches_win_to_fkey FOREIGN KEY (win_to) REFERENCES nx_t_matches(id) ON DELETE SET NULL;

-- [5] nx_t_notifications_tournament_id_fkey
alter table public.nx_t_notifications add constraint nx_t_notifications_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES nx_tournaments(id) ON DELETE CASCADE;

-- [5] nx_t_notifications_user_id_fkey
alter table public.nx_t_notifications add constraint nx_t_notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_t_reports_game_match_fkey
alter table public.nx_t_reports add constraint nx_t_reports_game_match_fkey FOREIGN KEY (game_match) REFERENCES nx_t_games(game_match) ON DELETE CASCADE;

-- [5] nx_t_staff_tournament_id_fkey
alter table public.nx_t_staff add constraint nx_t_staff_tournament_id_fkey FOREIGN KEY (tournament_id) REFERENCES nx_tournaments(id) ON DELETE CASCADE;

-- [5] nx_t_staff_user_id_fkey
alter table public.nx_t_staff add constraint nx_t_staff_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_tournaments_created_by_fkey
alter table public.nx_tournaments add constraint nx_tournaments_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE CASCADE;

-- [5] nx_xp_events_user_id_fkey
alter table public.nx_xp_events add constraint nx_xp_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- [6] nx_arcade_best_daily_idx
CREATE INDEX nx_arcade_best_daily_idx ON public.nx_arcade_best USING btree (game, daily_day, daily_best DESC);

-- [6] nx_arcade_best_game_idx
CREATE INDEX nx_arcade_best_game_idx ON public.nx_arcade_best USING btree (game, best DESC);

-- [6] nx_arcade_runs_user_idx
CREATE INDEX nx_arcade_runs_user_idx ON public.nx_arcade_runs USING btree (user_id, created_at DESC);

-- [6] nx_invites_to
CREATE INDEX nx_invites_to ON public.nx_invites USING btree (to_user, status, created_at DESC);

-- [6] nx_match_reports_created
CREATE INDEX nx_match_reports_created ON public.nx_match_reports USING btree (created_at);

-- [6] nx_matches_room
CREATE INDEX nx_matches_room ON public.nx_matches USING btree (room_id, started_at DESC);

-- [6] nx_room_game_players_room
CREATE INDEX nx_room_game_players_room ON public.nx_room_game_players USING btree (room_id, seat);

-- [6] nx_room_members_room_role
CREATE INDEX nx_room_members_room_role ON public.nx_room_members USING btree (room_id, role, joined_at);

-- [6] nx_room_members_user
CREATE INDEX nx_room_members_user ON public.nx_room_members USING btree (user_id, last_seen DESC);

-- [6] nx_room_messages_room_time
CREATE INDEX nx_room_messages_room_time ON public.nx_room_messages USING btree (room_id, created_at DESC);

-- [6] nx_rooms_kind_status_idx
CREATE INDEX nx_rooms_kind_status_idx ON public.nx_rooms USING btree (kind, status, updated_at DESC);

-- [6] nx_rooms_open
CREATE INDEX nx_rooms_open ON public.nx_rooms USING btree (game, status, quick, created_at);

-- [6] nx_t_audit_t
CREATE INDEX nx_t_audit_t ON public.nx_t_audit USING btree (tournament_id, created_at DESC);

-- [6] nx_t_code_attempts_user
CREATE INDEX nx_t_code_attempts_user ON public.nx_t_code_attempts USING btree (user_id, created_at DESC);

-- [6] nx_t_codes_t
CREATE INDEX nx_t_codes_t ON public.nx_t_codes USING btree (tournament_id);

-- [6] nx_t_entries_user
CREATE INDEX nx_t_entries_user ON public.nx_t_entries USING btree (user_id, created_at DESC);

-- [6] nx_t_games_tm
CREATE INDEX nx_t_games_tm ON public.nx_t_games USING btree (tmatch, n);

-- [6] nx_t_jobs_due
CREATE INDEX nx_t_jobs_due ON public.nx_t_jobs USING btree (run_at) WHERE (done_at IS NULL);

-- [6] nx_t_ledger_t
CREATE INDEX nx_t_ledger_t ON public.nx_t_ledger USING btree (tournament_id, created_at);

-- [6] nx_t_ledger_user
CREATE INDEX nx_t_ledger_user ON public.nx_t_ledger USING btree (user_id, created_at DESC);

-- [6] nx_t_matches_due
CREATE INDEX nx_t_matches_due ON public.nx_t_matches USING btree (status, scheduled_at);

-- [6] nx_t_matches_p1
CREATE INDEX nx_t_matches_p1 ON public.nx_t_matches USING btree (p1);

-- [6] nx_t_matches_p2
CREATE INDEX nx_t_matches_p2 ON public.nx_t_matches USING btree (p2);

-- [6] nx_t_matches_t
CREATE INDEX nx_t_matches_t ON public.nx_t_matches USING btree (tournament_id, bracket, round, idx);

-- [6] nx_t_notifications_user
CREATE INDEX nx_t_notifications_user ON public.nx_t_notifications USING btree (user_id, created_at DESC);

-- [6] nx_tournaments_status
CREATE INDEX nx_tournaments_status ON public.nx_tournaments USING btree (status, start_at);

-- [6] nx_wallet_tx_pending
CREATE INDEX nx_wallet_tx_pending ON public.nx_wallet_tx USING btree (acked_at, created_at) WHERE (acked_at IS NULL);

-- [6] nx_xp_events_user_day
CREATE INDEX nx_xp_events_user_day ON public.nx_xp_events USING btree (user_id, created_at);

-- [7] _nx_apply_result(m nx_matches, p_winners integer[], p_scores in
CREATE OR REPLACE FUNCTION public._nx_apply_result(m nx_matches, p_winners integer[], p_scores integer[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i int; j int; uid uuid; oc text; sc int; v_xp int; v_co int; rd int; n int := array_length(m.players, 1);
        ratings int[] := '{}'; opp_sum numeric; opp_avg numeric; expected numeric; actual numeric;
begin
  -- ratings before this match (default 1000)
  for i in 1..n loop
    ratings := ratings || coalesce((select s.rating from nx_game_stats s where s.user_id = m.players[i] and s.game = m.game), 1000);
  end loop;
  for i in 1..n loop
    uid := m.players[i];
    if p_winners is null or array_length(p_winners, 1) is null then oc := 'draw';
    elsif (i - 1) = any(p_winners) then oc := case when array_length(p_winners, 1) = n then 'draw' else 'win' end;
    else oc := 'loss'; end if;
    sc := coalesce(p_scores[i], 0);
    -- Elo, K = 32, vs the average opponent rating
    if n > 1 then
      opp_sum := 0;
      for j in 1..n loop
        if j <> i then opp_sum := opp_sum + ratings[j]; end if;
      end loop;
      opp_avg := opp_sum / (n - 1);
      expected := 1.0 / (1.0 + power(10.0, (opp_avg - ratings[i]) / 400.0));
      actual := case oc when 'win' then 1.0 when 'loss' then 0.0 else 0.5 end;
      rd := round(32 * (actual - expected))::int;
    else
      rd := 0;
    end if;
    insert into nx_match_results(match_id, user_id, game, seat, outcome, score, rating_delta)
    values (m.id, uid, m.game, i - 1, oc, sc, rd) on conflict do nothing;
    if found then
      insert into nx_game_stats(user_id, game, played, won, lost, draw, rating, best)
      values (uid, m.game, 1, (oc = 'win')::int, (oc = 'loss')::int, (oc = 'draw')::int, greatest(0, 1000 + rd), sc)
      on conflict (user_id, game) do update set
        played = nx_game_stats.played + 1,
        won = nx_game_stats.won + (excluded.won),
        lost = nx_game_stats.lost + (excluded.lost),
        draw = nx_game_stats.draw + (excluded.draw),
        rating = greatest(0, nx_game_stats.rating + rd),
        best = greatest(nx_game_stats.best, excluded.best),
        updated_at = now();
      v_xp := case oc when 'win' then 80 when 'draw' then 40 else 20 end;
      v_co := case oc when 'win' then 50 when 'draw' then 20 else 8 end;
      insert into nx_xp_events(user_id, idem_key, event, xp, coins)
      values (uid, 'match:' || m.id::text, 'online.' || m.game || '.' || oc, v_xp, v_co) on conflict do nothing;
      if found then
        update profiles p set xp = p.xp + v_xp, coins = p.coins + v_co, level = level_for_xp(p.xp + v_xp) where p.id = uid;
      end if;
    end if;
  end loop;
end $function$
;

-- [7] _nx_forfeited_seats(p_match uuid)
CREATE OR REPLACE FUNCTION public._nx_forfeited_seats(p_match uuid)
 RETURNS integer[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(array_agg(distinct coalesce((mv.move ->> 'seat')::int, mv.seat)), '{}'::int[])
    from public.nx_match_moves mv where mv.match_id = p_match and mv.kind = 'forfeit'
$function$
;

-- [7] _nx_g_turn_times(p_game text, OUT aim_s integer, OUT sim_s inte
CREATE OR REPLACE FUNCTION public._nx_g_turn_times(p_game text, OUT aim_s integer, OUT sim_s integer)
 RETURNS record
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p_game when 'billiards' then 30 when 'carrom' then 15 else 10 end,
         case p_game when 'billiards' then 25 when 'carrom' then 12 else 5 end
$function$
;

-- [7] _nx_leave_all(me uuid)
CREATE OR REPLACE FUNCTION public._nx_leave_all(me uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  for r in select rp.room_id from nx_room_players rp join nx_rooms x on x.id = rp.room_id
            where rp.user_id = me and x.status = 'lobby' loop
    -- re-check under the row lock: a room that started meanwhile is left alone (never forfeit as a side effect)
    perform 1 from nx_rooms where id = r.room_id and status = 'lobby' for update;
    if found then
      perform nx_leave_room(r.room_id);
    end if;
  end loop;
end $function$
;

-- [7] _nx_match_authority(p_match uuid)
CREATE OR REPLACE FUNCTION public._nx_match_authority(p_match uuid)
 RETURNS integer
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m public.nx_matches; gone int[]; a int;
begin
  select * into m from public.nx_matches where id = p_match;
  if m.id is null then return null; end if;
  gone := public._nx_forfeited_seats(p_match);
  select min(g) into a
    from generate_series(0, coalesce(array_length(m.players, 1), 0) - 1) g
   where not (g = any(gone))
     and public._nx_player_active(p_match, m.players[g + 1], 25, 30);
  if a is null then
    select min(g) into a
      from generate_series(0, coalesce(array_length(m.players, 1), 0) - 1) g
     where not (g = any(gone));
  end if;
  return a;
end $function$
;

-- [7] _nx_owner_guard()
CREATE OR REPLACE FUNCTION public._nx_owner_guard()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when auth.uid() is null then 'not_signed_in' when not nx_t_is_admin(auth.uid()) then 'forbidden' else null end
$function$
;

-- [7] _nx_player_active(p_match uuid, p_user uuid, p_ping_sec integer
CREATE OR REPLACE FUNCTION public._nx_player_active(p_match uuid, p_user uuid, p_ping_sec integer DEFAULT 25, p_move_sec integer DEFAULT 30)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from public.nx_match_presence p
                  where p.match_id = p_match and p.user_id = p_user
                    and p.last_seen > now() - make_interval(secs => p_ping_sec))
      or exists (select 1 from public.nx_match_moves mv
                  where mv.match_id = p_match and mv.by_user = p_user
                    and mv.created_at > now() - make_interval(secs => p_move_sec))
$function$
;

-- [7] _nx_profiles_delta()
CREATE OR REPLACE FUNCTION public._nx_profiles_delta()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(current_setting('nx.sync', true), '') = '1' then return new; end if;
  if tg_op = 'UPDATE' and (new.xp <> old.xp or new.coins <> old.coins or new.gems <> old.gems) then
    insert into nx_wallet_tx(user_id, xp, coins, gems, reason)
    values (new.id, new.xp - old.xp, new.coins - old.coins, new.gems - old.gems,
            left(coalesce(current_setting('nx.reason', true), 'games'), 80));
    new.level := level_for_xp(new.xp);
    new.updated_at := now();
  end if;
  return new;
end $function$
;

-- [7] _nx_quick_lock(p_game text, p_seats integer)
CREATE OR REPLACE FUNCTION public._nx_quick_lock(p_game text, p_seats integer)
 RETURNS void
 LANGUAGE sql
AS $function$
  select pg_advisory_xact_lock(hashtext('nx_quick:' || coalesce(p_game, '') || ':' || coalesce(p_seats, 0)))
$function$
;

-- [7] _nx_quick_seats(p_game text, p_seats integer)
CREATE OR REPLACE FUNCTION public._nx_quick_seats(p_game text, p_seats integer)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare b record; s int;
begin
  select * into b from public.nx_game_bounds(p_game);
  s := greatest(b.min_seats, least(coalesce(p_seats, b.min_seats), b.max_seats));
  if p_game = 'finger_soccer' and s % 2 <> 0 then
    s := case when s + 1 <= b.max_seats then s + 1 else s - 1 end;
  end if;
  return s;
end $function$
;

-- [7] _nx_quiz_const(OUT q_ms integer, OUT grace_ms integer, OUT reve
CREATE OR REPLACE FUNCTION public._nx_quiz_const(OUT q_ms integer, OUT grace_ms integer, OUT reveal_ms integer, OUT lead_ms integer, OUT pick_s integer)
 RETURNS record
 LANGUAGE sql
 IMMUTABLE
AS $function$ select 15000, 1500, 4500, 2500, 20 $function$
;

-- [7] _nx_quiz_tick(p_match uuid)
CREATE OR REPLACE FUNCTION public._nx_quiz_tick(p_match uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  g nx_quiz_games; m nx_matches; c record; active int[]; n_ans int; i int := 0;
  sc int[]; cc int[]; best int; bestc int; w int[]; s int;
begin
  select * into c from _nx_quiz_const();
  select * into m from nx_matches where id = p_match;
  select * into g from nx_quiz_games where match_id = p_match for update;
  if g.match_id is null then return; end if;
  if m.status <> 'playing' and g.phase <> 'done' then
    update nx_quiz_games set phase = 'done', phase_ends = null where match_id = p_match;
    return;
  end if;
  active := array(select x from generate_series(0, array_length(m.players, 1) - 1) x
                  where not (x = any(_nx_forfeited_seats(p_match))));
  while i < 4 loop
    i := i + 1;
    if g.phase = 'question' then
      select count(*) into n_ans from nx_quiz_answers a where a.match_id = p_match and a.round = g.round_idx
         and a.seat = any(active);
      exit when now() < g.phase_ends and n_ans < coalesce(array_length(active, 1), 0);
      update nx_quiz_games set phase = 'reveal', phase_started = now(),
             phase_ends = now() + make_interval(secs => c.reveal_ms / 1000.0)
       where match_id = p_match returning * into g;
    elsif g.phase = 'reveal' then
      exit when now() < g.phase_ends;
      if g.round_idx >= coalesce(array_length(g.qids, 1), 0) - 1 then
        -- final result
        n_ans := array_length(m.players, 1);
        sc := array(select coalesce((select sum(points) from nx_quiz_answers a where a.match_id = p_match and a.seat = x), 0)::int
                      from generate_series(0, n_ans - 1) x order by x);
        cc := array(select (select count(*) from nx_quiz_answers a where a.match_id = p_match and a.seat = x and a.correct)::int
                      from generate_series(0, n_ans - 1) x order by x);
        best := -1; bestc := -1; w := '{}';
        foreach s in array active loop
          if sc[s + 1] > best or (sc[s + 1] = best and cc[s + 1] > bestc) then
            best := sc[s + 1]; bestc := cc[s + 1]; w := array[s];
          elsif sc[s + 1] = best and cc[s + 1] = bestc then
            w := w || s;
          end if;
        end loop;
        if best <= 0 or (coalesce(array_length(active, 1), 0) > 1 and coalesce(array_length(w, 1), 0) = coalesce(array_length(active, 1), 0)) then w := '{}'; end if; -- draw
        update nx_quiz_games set phase = 'done', phase_ends = null, winners = w where match_id = p_match returning * into g;
        perform set_config('nx.server_result', '1', true);
        perform nx_finish_match(p_match, w, sc, null, 'finished');
        perform set_config('nx.server_result', '', true);
        exit;
      end if;
      update nx_quiz_games set phase = 'question', round_idx = g.round_idx + 1,
             phase_started = now() + interval '600 milliseconds',
             phase_ends = now() + interval '600 milliseconds' + make_interval(secs => (c.q_ms + c.grace_ms) / 1000.0)
       where match_id = p_match returning * into g;
    else
      exit;
    end if;
  end loop;
end $function$
;

-- [7] _nx_room_after_match(p_room uuid, p_match uuid)
CREATE OR REPLACE FUNCTION public._nx_room_after_match(p_room uuid, p_match uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_room is null then return; end if;
  update nx_rooms set status = case when quick then 'closed' else 'lobby' end, updated_at = now()
   where id = p_room and match_id = p_match and status = 'playing';
  update nx_room_players set ready = false where room_id = p_room and seat > 0;
end $function$
;

-- [7] _nx_room_audience(p_room uuid)
CREATE OR REPLACE FUNCTION public._nx_room_audience(p_room uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select greatest(
    (select count(*)::int from public.nx_room_members where room_id = p_room),
    (select count(*)::int from public.nx_room_players where room_id = p_room))
$function$
;

-- [7] _nx_room_can_manage(p_room uuid)
CREATE OR REPLACE FUNCTION public._nx_room_can_manage(p_room uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    exists (select 1 from public.nx_rooms r where r.id = p_room and r.host = auth.uid())
    or public.nx_room_member_role(p_room) = 'manager', false)
$function$
;

-- [7] _nx_room_seat_limit(p_game text)
CREATE OR REPLACE FUNCTION public._nx_room_seat_limit(p_game text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ select (public.nx_game_bounds(p_game)).max_seats $function$
;

-- [7] _nx_room_selected(p_room uuid)
CREATE OR REPLACE FUNCTION public._nx_room_selected(p_room uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select greatest(
    (select count(*)::int from public.nx_room_game_players where room_id = p_room),
    (select count(*)::int from public.nx_room_players where room_id = p_room))
$function$
;

-- [7] _nx_secret(n text)
CREATE OR REPLACE FUNCTION public._nx_secret(n text)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'vault'
AS $function$
  select decrypted_secret from vault.decrypted_secrets where name = n limit 1
$function$
;

-- [7] _nx_server_result_guard()
CREATE OR REPLACE FUNCTION public._nx_server_result_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.game = 'quiz'
     and old.status = 'playing' and new.status = 'finished'
     and coalesce(new.reason, 'finished') not like 'forfeit%'
     and exists (select 1 from public.nx_quiz_games q where q.match_id = new.id and q.phase <> 'pick')
     and coalesce(current_setting('nx.server_result', true), '') <> '1' then
    raise exception 'the server decides % results', new.game;
  end if;
  return new;
end $function$
;

-- [7] _nx_t_audit(p_t uuid, p_actor uuid, p_action text, p_data jsonb
CREATE OR REPLACE FUNCTION public._nx_t_audit(p_t uuid, p_actor uuid, p_action text, p_data jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  insert into nx_t_audit(tournament_id, actor, action, data) values (p_t, p_actor, p_action, coalesce(p_data, '{}'::jsonb));
$function$
;

-- [7] _nx_t_better_seed(p_t uuid, a uuid, b uuid)
CREATE OR REPLACE FUNCTION public._nx_t_better_seed(p_t uuid, a uuid, b uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select user_id from nx_t_entries where tournament_id = p_t and user_id in (a, b) order by seed nulls last, user_id limit 1
$function$
;

-- [7] _nx_t_bo(t nx_tournaments, p_kind text)
CREATE OR REPLACE FUNCTION public._nx_t_bo(t nx_tournaments, p_kind text)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare v int;
begin
  if t.format = 'two_legs' then
    if p_kind = 'final' and _nx_t_cfg_bool(t.config, 'final_one_leg', false) then return 1; end if;
    return 2;
  end if;
  v := _nx_t_cfg_int(t.config, 'bo_' || p_kind, _nx_t_cfg_int(t.config, 'bo_early', 1));
  if v not between 1 and 15 then v := 1; end if;
  return v;
end $function$
;

-- [7] _nx_t_cancel(p_t uuid, p_reason text, p_actor uuid)
CREATE OR REPLACE FUNCTION public._nx_t_cancel(p_t uuid, p_reason text, p_actor uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; r record; gm record;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null or t.status in ('finished', 'cancelled') then return; end if;
  for r in select user_id from nx_t_entries where tournament_id = p_t and (paid_coins > 0 or paid_gems > 0) loop
    perform _nx_t_refund(p_t, r.user_id, 'cancelled');
  end loop;
  -- games still being played end now; marking them accepted first keeps them out of the engine
  for gm in select g.game_match from nx_t_games g join nx_t_matches m on m.id = g.tmatch
             where m.tournament_id = p_t and not g.accepted loop
    update nx_t_games set accepted = true, source = 'cancelled' where game_match = gm.game_match;
    update nx_matches set status = 'abandoned', reason = 'tournament_cancelled', ended_at = now()
     where id = gm.game_match and status = 'playing';
  end loop;
  update nx_t_matches set status = 'void', result_note = 'cancelled', updated_at = now()
   where tournament_id = p_t and status not in ('done', 'walkover', 'bye', 'void', 'skipped');
  update nx_tournaments set status = 'cancelled', cancel_reason = left(p_reason, 200), finished_at = now(), updated_at = now()
   where id = p_t;
  update nx_t_jobs set done_at = now(), last_error = 'cancelled' where tournament_id = p_t and done_at is null;
  perform _nx_t_notify_all(p_t, 'cancelled', jsonb_build_object('reason', p_reason), 'cancelled:' || p_t,
                           array['approved', 'pending', 'waitlist']);
  perform _nx_t_audit(p_t, p_actor, 'cancelled', jsonb_build_object('reason', p_reason));
end $function$
;

-- [7] _nx_t_cfg_bool(c jsonb, k text, d boolean)
CREATE OR REPLACE FUNCTION public._nx_t_cfg_bool(c jsonb, k text, d boolean)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when jsonb_typeof(c -> k) = 'boolean' then (c ->> k)::boolean else d end
$function$
;

-- [7] _nx_t_cfg_int(c jsonb, k text, d integer)
CREATE OR REPLACE FUNCTION public._nx_t_cfg_int(c jsonb, k text, d integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when jsonb_typeof(c -> k) = 'number' then (c ->> k)::numeric::int
              when jsonb_typeof(c -> k) = 'string' and (c ->> k) ~ '^-?[0-9]+$' then (c ->> k)::int
              else d end
$function$
;

-- [7] _nx_t_charge(p_t uuid, p_user uuid, p_coins integer, p_gems int
CREATE OR REPLACE FUNCTION public._nx_t_charge(p_t uuid, p_user uuid, p_coins integer, p_gems integer)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare lid bigint; ok uuid; unl boolean := nx_unlimited(p_user);
        k text := case when unl then 'ufee:' else 'fee:' end || p_t || ':' || p_user || ':'
                  || floor(extract(epoch from clock_timestamp()) * 1000)::bigint;
        kd text := case when unl then 'entry_fee_unlimited' else 'entry_fee' end;
begin
  if coalesce(p_coins, 0) = 0 and coalesce(p_gems, 0) = 0 then return 0; end if;
  if not unl then
    perform set_config('nx.reason', 'tournament_entry_fee', true);
    update profiles set coins = coins - p_coins, gems = coalesce(gems, 0) - p_gems
     where id = p_user and coins >= p_coins and coalesce(gems, 0) >= p_gems returning id into ok;
    if ok is null then return null; end if;
  end if;
  if p_coins > 0 then
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, idem_key)
    values (p_t, p_user, kd, 'coins', -p_coins, k || ':c') returning id into lid;
  end if;
  if p_gems > 0 then
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, idem_key)
    values (p_t, p_user, kd, 'gems', -p_gems, k || ':g') returning id into lid;
  end if;
  -- only real money goes into the escrow (an unlimited account pays nothing, so nothing may be paid out for it)
  if not unl then
    update nx_tournaments set escrow_coins = escrow_coins + p_coins, escrow_gems = escrow_gems + p_gems where id = p_t;
  end if;
  return lid;
end $function$
;

-- [7] _nx_t_check(p_m uuid)
CREATE OR REPLACE FUNCTION public._nx_t_check(p_m uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_t_matches; t nx_tournaments; at timestamptz; d1 boolean; d2 boolean;
begin
  select * into m from nx_t_matches where id = p_m for update;
  if m.id is null or m.status <> 'pending' or not (m.p1_set and m.p2_set) then return; end if;
  if m.p1 is null or m.p2 is null then
    -- a disqualified player does not advance through a bye either (nobody advances; the next opponent gets a bye)
    if not _nx_t_gen_on() and exists (select 1 from nx_t_entries where tournament_id = m.tournament_id
                                       and user_id = coalesce(m.p1, m.p2) and status = 'removed') then
      perform _nx_t_complete(m.id, null, null, false, 'bye', 'disqualified');
    else
      perform _nx_t_complete(m.id, coalesce(m.p1, m.p2), null, false, 'bye', 'bye');
    end if;
    return;
  end if;
  -- a disqualified (removed after the draw) player loses every match they are seated in by walkover
  if not _nx_t_gen_on() then
    d1 := exists (select 1 from nx_t_entries where tournament_id = m.tournament_id and user_id = m.p1 and status = 'removed');
    d2 := exists (select 1 from nx_t_entries where tournament_id = m.tournament_id and user_id = m.p2 and status = 'removed');
    if d1 and d2 then
      perform _nx_t_complete(m.id, null, null, false,
                             case when m.bracket in ('W', 'L', 'GF', 'GF2', 'P3') then 'walkover' else 'void' end, 'disqualified');
      return;
    elsif d1 then
      perform _nx_t_complete(m.id, m.p2, m.p1, false, 'walkover', 'disqualified');
      return;
    elsif d2 then
      perform _nx_t_complete(m.id, m.p1, m.p2, false, 'walkover', 'disqualified');
      return;
    end if;
  end if;
  select * into t from nx_tournaments where id = m.tournament_id;
  at := greatest(_nx_t_planned(t, m.tslot), now());
  update nx_t_matches set status = 'scheduled', scheduled_at = at, updated_at = now() where id = m.id;
  if at - interval '10 minutes' > now() + interval '1 minute' then
    perform _nx_t_job('remind_match', t.id, m.id, at - interval '10 minutes', 'remind_match:' || m.id);
  end if;
end $function$
;

-- [7] _nx_t_check_code(p_user uuid, p_t uuid, p_code text)
CREATE OR REPLACE FUNCTION public._nx_t_check_code(p_user uuid, p_t uuid, p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c nx_t_codes; norm text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); bad int; err text;
begin
  select count(*) into bad from nx_t_code_attempts where user_id = p_user and not ok and created_at > now() - interval '15 minutes';
  if bad >= 5 then return jsonb_build_object('ok', false, 'error', 'too_many_attempts'); end if;
  select * into c from nx_t_codes where code = norm and (p_t is null or tournament_id = p_t);
  if c.id is null then err := 'bad_code';
  elsif c.revoked then err := 'code_revoked';
  elsif c.expires_at is not null and c.expires_at < now() then err := 'code_expired';
  elsif c.uses >= c.max_uses then err := 'code_used_up';
  end if;
  insert into nx_t_code_attempts(user_id, code, ok) values (p_user, left(norm, 16), err is null);
  if err is not null then return jsonb_build_object('ok', false, 'error', err); end if;
  return jsonb_build_object('ok', true, 'code_id', c.id, 'tournament_id', c.tournament_id, 'requires_approval', c.requires_approval);
end $function$
;

-- [7] _nx_t_complete(p_m uuid, p_winner uuid, p_loser uuid, p_draw bo
CREATE OR REPLACE FUNCTION public._nx_t_complete(p_m uuid, p_winner uuid, p_loser uuid, p_draw boolean, p_status text, p_note text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_t_matches; elim boolean;
begin
  update nx_t_matches set winner = p_winner, loser = p_loser, is_draw = coalesce(p_draw, false), status = p_status,
         result_note = coalesce(p_note, result_note), finished_at = now(), game_match = null, ready_deadline = null,
         updated_at = now()
   where id = p_m and status not in ('done', 'walkover', 'bye', 'void', 'skipped')
  returning * into m;
  if m.id is null then return; end if;
  if not _nx_t_gen_on() and p_status <> 'bye' then
    elim := m.bracket in ('W', 'L', 'GF', 'GF2', 'P3');
    perform _nx_t_notify(m.p1, m.tournament_id, m.id, 'result',
      jsonb_build_object('won', p_winner = m.p1, 'draw', coalesce(p_draw, false), 'w1', m.w1, 'w2', m.w2, 'g1', m.g1, 'g2', m.g2,
                         'note', p_note), 'result:' || m.id);
    perform _nx_t_notify(m.p2, m.tournament_id, m.id, 'result',
      jsonb_build_object('won', p_winner = m.p2, 'draw', coalesce(p_draw, false), 'w1', m.w1, 'w2', m.w2, 'g1', m.g1, 'g2', m.g2,
                         'note', p_note), 'result:' || m.id);
    if elim then
      if p_winner is not null and (m.win_to is not null or m.bracket = 'GF' and p_winner <> m.p1) then
        perform _nx_t_notify(p_winner, m.tournament_id, m.id, 'advanced', '{}'::jsonb, 'adv:' || m.id);
      end if;
      if p_loser is not null and m.lose_to is null and not (m.bracket = 'GF' and p_loser = m.p1) then
        perform _nx_t_notify(p_loser, m.tournament_id, m.id, 'eliminated', '{}'::jsonb, 'elim:' || m.id);
      end if;
    end if;
  elsif p_status = 'bye' and not _nx_t_gen_on() and p_winner is not null then
    perform _nx_t_notify(p_winner, m.tournament_id, m.id, 'bye', '{}'::jsonb, 'bye:' || m.id);
  end if;
  perform _nx_t_audit(m.tournament_id, null, 'match_' || p_status,
                      jsonb_build_object('match', m.id, 'winner', p_winner, 'loser', p_loser, 'draw', p_draw, 'note', p_note));
  perform _nx_t_propagate(m.id);
  perform _nx_t_progress(m.tournament_id);
end $function$
;

-- [7] _nx_t_dispute(p_m uuid, p_actor uuid, p_reason text)
CREATE OR REPLACE FUNCTION public._nx_t_dispute(p_m uuid, p_actor uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_t_matches;
begin
  select * into m from nx_t_matches where id = p_m for update;
  if m.id is null or m.status in ('done', 'walkover', 'bye', 'void', 'skipped', 'disputed') then return; end if;
  update nx_t_matches set status = 'disputed', result_note = left(p_reason, 120), updated_at = now() where id = p_m;
  if m.game_match is not null then update nx_t_games set disputed = true where game_match = m.game_match; end if;
  perform _nx_t_notify_managers(m.tournament_id, m.id, 'dispute', jsonb_build_object('reason', p_reason), 'dispute:' || m.id);
  perform _nx_t_notify(m.p1, m.tournament_id, m.id, 'dispute', jsonb_build_object('reason', p_reason), 'disputep:' || m.id);
  perform _nx_t_notify(m.p2, m.tournament_id, m.id, 'dispute', jsonb_build_object('reason', p_reason), 'disputep:' || m.id);
  perform _nx_t_audit(m.tournament_id, p_actor, 'dispute', jsonb_build_object('match', m.id, 'reason', p_reason));
end $function$
;

-- [7] _nx_t_downstream_free(p_m uuid)
CREATE OR REPLACE FUNCTION public._nx_t_downstream_free(p_m uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select not exists (
    select 1 from nx_t_matches d, nx_t_matches m
     where m.id = p_m and (d.id = m.win_to or d.id = m.lose_to
                           or (m.bracket = 'GF' and d.tournament_id = m.tournament_id and d.bracket = 'GF2'))
       and (d.games > 0 or d.status in ('playing', 'done', 'walkover', 'disputed')))
$function$
;

-- [7] _nx_t_draw(p_t uuid, p_actor uuid)
CREATE OR REPLACE FUNCTION public._nx_t_draw(p_t uuid, p_actor uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; n int; players uuid[]; g int; a int; i int; grp int; r record; maxr int := 0; rr int;
        win text; purge boolean := false;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null or t.status not in ('registering', 'closed') then return; end if;
  -- check-in: approved players who did not check in are left out (fee refunded) - but only once the check-in
  -- window (10 minutes before the start) has opened. An organizer's early "draw now" / "start now" sets
  -- nx.t_checkin_window = 'closed' and everybody registered plays.
  if _nx_t_cfg_bool(t.config, 'checkin', false) then
    win := coalesce(current_setting('nx.t_checkin_window', true), '');
    purge := case win when 'open' then true when 'closed' then false
                      else now() >= t.start_at - interval '10 minutes' end;
  end if;
  if purge then
    for r in select user_id from nx_t_entries where tournament_id = p_t and status = 'approved' and checked_in_at is null loop
      perform _nx_t_refund(p_t, r.user_id, 'no_checkin');
      update nx_t_entries set status = 'no_checkin', note = 'no_checkin', updated_at = now()
       where tournament_id = p_t and user_id = r.user_id;
      perform _nx_t_notify(r.user_id, p_t, null, 'no_checkin', '{}'::jsonb, 'nocheckin:' || p_t);
    end loop;
    -- places freed that way go to waitlisted players who checked in, first come first served
    select count(*) into n from nx_t_entries where tournament_id = p_t and status = 'approved';
    for r in select user_id from nx_t_entries where tournament_id = p_t and status = 'waitlist' and checked_in_at is not null
              order by created_at loop
      exit when n >= t.capacity;
      update nx_t_entries set status = 'approved', updated_at = now() where tournament_id = p_t and user_id = r.user_id;
      perform _nx_t_notify(r.user_id, p_t, null, 'promoted', '{}'::jsonb, 'promo:' || p_t || ':' || r.user_id);
      n := n + 1;
    end loop;
  end if;
  select count(*) into n from nx_t_entries where tournament_id = p_t and status = 'approved';
  if n < greatest(2, t.min_players) then
    perform _nx_t_cancel(p_t, 'not_enough_players', p_actor);
    return;
  end if;
  -- whoever did not make it (pending approval / waitlist) gets the fee back
  for r in select user_id from nx_t_entries where tournament_id = p_t and status in ('pending', 'waitlist') loop
    perform _nx_t_refund(p_t, r.user_id, 'not_drawn');
    update nx_t_entries set status = 'rejected', note = 'not_drawn', updated_at = now()
     where tournament_id = p_t and user_id = r.user_id;
    perform _nx_t_notify(r.user_id, p_t, null, 'rejected', jsonb_build_object('reason', 'not_drawn'), 'notdrawn:' || p_t);
  end loop;
  if t.seed is null then
    t.seed := floor(random() * 2147483646)::bigint + 1;
    update nx_tournaments set seed = t.seed where id = p_t;
  end if;
  select array_agg(user_id order by
           case when t.seeding = 'manual' then coalesce(seed, 100000) else 0 end,
           case when t.seeding = 'rating' then -rating else 0 end,
           md5(t.seed::text || user_id::text))
    into players from nx_t_entries where tournament_id = p_t and status = 'approved';
  for i in 1..n loop
    update nx_t_entries set seed = i, group_no = null where tournament_id = p_t and user_id = players[i];
  end loop;
  delete from nx_t_matches where tournament_id = p_t;
  if t.format in ('single_elim', 'two_legs') then
    perform _nx_t_gen_se(p_t, players, 'main', 0, 0);
  elsif t.format = 'double_elim' then
    perform _nx_t_gen_de(p_t, players);
  elsif t.format = 'round_robin' then
    perform _nx_t_gen_rr(p_t, players, null, _nx_t_cfg_bool(t.config, 'rr_double', false), 0, 0, 'RR', 'main');
  elsif t.format = 'groups_ko' then
    g := greatest(1, least(_nx_t_cfg_int(t.config, 'groups', 2), n / 2));
    for i in 1..n loop
      -- snake: 1..g, g..1, ...
      grp := case when ((i - 1) / g) % 2 = 0 then ((i - 1) % g) + 1 else g - ((i - 1) % g) end;
      update nx_t_entries set group_no = grp where tournament_id = p_t and user_id = players[i];
    end loop;
    for grp in 1..g loop
      rr := _nx_t_gen_rr(p_t, (select array_agg(user_id order by seed) from nx_t_entries
                                where tournament_id = p_t and status = 'approved' and group_no = grp),
                         grp, _nx_t_cfg_bool(t.config, 'rr_double', false), 0, 0, 'G', 'groups');
    end loop;
    update nx_tournaments set stage = 'groups' where id = p_t;
  elsif t.format = 'swiss' then
    perform _nx_t_swiss_round(p_t, 1);
  end if;
  update nx_tournaments set status = 'drawn', drawn_at = now(), updated_at = now() where id = p_t;
  perform _nx_t_notify_all(p_t, 'drawn', '{}'::jsonb, 'drawn:' || p_t);
  perform _nx_t_audit(p_t, p_actor, 'drawn', jsonb_build_object('seed', t.seed, 'players', n, 'seeding', t.seeding));
end $function$
;

-- [7] _nx_t_fill_from_waitlist(p_t uuid)
CREATE OR REPLACE FUNCTION public._nx_t_fill_from_waitlist(p_t uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; n int; r record;
begin
  select * into t from nx_tournaments where id = p_t;
  select count(*) into n from nx_t_entries where tournament_id = p_t and status = 'approved';
  for r in select user_id from nx_t_entries where tournament_id = p_t and status = 'waitlist' order by created_at loop
    exit when n >= t.capacity;
    update nx_t_entries set status = 'approved', updated_at = now() where tournament_id = p_t and user_id = r.user_id;
    perform _nx_t_notify(r.user_id, p_t, null, 'promoted', '{}'::jsonb, 'promo:' || p_t || ':' || r.user_id);
    n := n + 1;
  end loop;
end $function$
;

-- [7] _nx_t_finish(p_t uuid)
CREATE OR REPLACE FUNCTION public._nx_t_finish(p_t uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; placed int; r record; i int := 0; champ uuid;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null or t.status in ('finished', 'cancelled') then return; end if;
  update nx_t_entries set place = null where tournament_id = p_t;
  if t.format in ('single_elim', 'two_legs', 'double_elim') then
    placed := _nx_t_place_elim(p_t, 'main');
  elsif t.format = 'groups_ko' then
    placed := _nx_t_place_elim(p_t, 'ko');
    update nx_t_entries set place = placed + 1 where tournament_id = p_t and status = 'approved' and place is null;
  else
    for r in select x.user_id from _nx_t_table(p_t, 'main', null) x
              order by x.pts desc, (x.gf - x.ga) desc, x.gf desc, x.won desc, x.seed loop
      i := i + 1;
      update nx_t_entries set place = i where tournament_id = p_t and user_id = r.user_id;
    end loop;
  end if;
  select user_id into champ from nx_t_entries where tournament_id = p_t and place = 1 order by seed limit 1;
  update nx_tournaments set status = 'finished', finished_at = now(), winner = champ, updated_at = now() where id = p_t;
  perform _nx_t_payout(p_t);
  perform _nx_t_notify_all(p_t, 'finished', jsonb_build_object('winner', champ,
            'winner_name', (select username from profiles where id = champ)), 'finished:' || p_t);
  perform _nx_t_audit(p_t, null, 'finished', jsonb_build_object('winner', champ));
end $function$
;

-- [7] _nx_t_game_result(p_gm uuid, p_winner uuid, p_s_home integer, p
CREATE OR REPLACE FUNCTION public._nx_t_game_result(p_gm uuid, p_winner uuid, p_s_home integer, p_s_away integer, p_source text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g nx_t_games; m nx_t_matches; s1 int; s2 int; need int; elim boolean; w uuid; l uuid; draw boolean := false;
        decided boolean := false;
begin
  select * into g from nx_t_games where game_match = p_gm for update;
  if g.game_match is null or g.accepted then return; end if;
  update nx_t_games set accepted = true, disputed = false, winner = p_winner, s_home = p_s_home, s_away = p_s_away,
         source = p_source where game_match = p_gm;
  select * into m from nx_t_matches where id = g.tmatch for update;
  if m.status in ('done', 'walkover', 'bye', 'void', 'skipped') then return; end if;
  if g.home = m.p1 then s1 := coalesce(p_s_home, 0); s2 := coalesce(p_s_away, 0);
  else s1 := coalesce(p_s_away, 0); s2 := coalesce(p_s_home, 0); end if;
  update nx_t_matches set games = games + 1, g1 = g1 + s1, g2 = g2 + s2,
         w1 = w1 + coalesce(p_winner = p1, false)::int, w2 = w2 + coalesce(p_winner = p2, false)::int, game_match = null, updated_at = now()
   where id = m.id returning * into m;
  elim := m.bracket in ('W', 'L', 'GF', 'GF2', 'P3');
  need := m.best_of / 2 + 1;
  if m.aggregate then
    if m.games >= 2 then
      if m.games > 2 and p_winner is not null then w := p_winner; decided := true;
      elsif m.g1 > m.g2 then w := m.p1; decided := true;
      elsif m.g2 > m.g1 then w := m.p2; decided := true;
      elsif not elim then draw := true; decided := true;
      end if;
    end if;
  else
    if m.best_of <> 2 and m.w1 >= need then w := m.p1; decided := true;
    elsif m.best_of <> 2 and m.w2 >= need then w := m.p2; decided := true;
    elsif m.games >= m.best_of then
      if m.w1 > m.w2 then w := m.p1; decided := true;
      elsif m.w2 > m.w1 then w := m.p2; decided := true;
      elsif not elim then draw := true; decided := true;
      end if; -- knockout tie → golden-goal decider game
    end if;
  end if;
  if not decided and m.games >= m.best_of + 4 then
    w := _nx_t_better_seed(m.tournament_id, m.p1, m.p2); decided := true;
  end if;
  perform _nx_t_audit(m.tournament_id, null, 'game_accepted',
    jsonb_build_object('match', m.id, 'game_match', p_gm, 'winner', p_winner, 's_home', p_s_home, 's_away', p_s_away, 'source', p_source));
  if decided then
    l := case when w = m.p1 then m.p2 when w = m.p2 then m.p1 end;
    perform _nx_t_complete(m.id, w, l, draw, 'done', p_source);
  else
    update nx_t_matches set status = 'scheduled', updated_at = now() where id = m.id;
    perform _nx_t_open_ready(m.id);
  end if;
end $function$
;

-- [7] _nx_t_gen_de(p_t uuid, players uuid[])
CREATE OR REPLACE FUNCTION public._nx_t_gen_de(p_t uuid, players uuid[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; n int := coalesce(array_length(players, 1), 0); k int := 0; p int; ord int[];
        r int; i int; m int; cnt int; mid uuid; gf uuid; gf2 uuid; lrounds int; kind text; a int; b int; j int;
begin
  select * into t from nx_tournaments where id = p_t;
  if n < 2 then return; end if;
  while (1 << k) < n loop k := k + 1; end loop;
  p := 1 << k;
  ord := _nx_t_seed_order(p);
  lrounds := 2 * (k - 1);
  perform set_config('nx.tgen', 'on', true);
  for r in 1..k loop
    kind := case when r = k then 'final' when r = k - 1 then 'semi' else 'early' end;
    for i in 0..(p >> r) - 1 loop
      perform _nx_t_new_match(t, 'main', 'W', r, i, r, null, _nx_t_bo(t, kind));
    end loop;
  end loop;
  for m in 1..lrounds loop
    cnt := _nx_t_lb_count(p, m);
    kind := case when m = lrounds then 'semi' else 'early' end;
    for i in 0..cnt - 1 loop
      perform _nx_t_new_match(t, 'main', 'L', m, i, m + 1, null, _nx_t_bo(t, kind));
    end loop;
  end loop;
  gf := _nx_t_new_match(t, 'main', 'GF', 1, 0, greatest(2 * k, lrounds + 2), null, _nx_t_bo(t, 'final'));
  gf2 := _nx_t_new_match(t, 'main', 'GF2', 1, 0, greatest(2 * k, lrounds + 2) + 1, null, _nx_t_bo(t, 'final'));
  -- winners bracket links
  for r in 1..k loop
    for i in 0..(p >> r) - 1 loop
      mid := _nx_t_mid(p_t, 'main', 'W', r, i);
      if r < k then
        update nx_t_matches set win_to = _nx_t_mid(p_t, 'main', 'W', r + 1, i / 2), win_slot = (i % 2) + 1 where id = mid;
      else
        update nx_t_matches set win_to = gf, win_slot = 1 where id = mid;
      end if;
      if k = 1 then
        update nx_t_matches set lose_to = gf, lose_slot = 2 where id = mid;
      elsif r = 1 then
        update nx_t_matches set lose_to = _nx_t_mid(p_t, 'main', 'L', 1, i / 2), lose_slot = (i % 2) + 1 where id = mid;
      else
        cnt := p >> r;
        j := case when r % 2 = 0 then cnt - 1 - i else i end;
        update nx_t_matches set lose_to = _nx_t_mid(p_t, 'main', 'L', 2 * (r - 1), j), lose_slot = 2 where id = mid;
      end if;
    end loop;
  end loop;
  -- losers bracket links
  for m in 1..lrounds loop
    cnt := _nx_t_lb_count(p, m);
    for i in 0..cnt - 1 loop
      mid := _nx_t_mid(p_t, 'main', 'L', m, i);
      if m = lrounds then
        update nx_t_matches set win_to = gf, win_slot = 2 where id = mid;
      elsif m % 2 = 1 then
        update nx_t_matches set win_to = _nx_t_mid(p_t, 'main', 'L', m + 1, i), win_slot = 1 where id = mid;
      else
        update nx_t_matches set win_to = _nx_t_mid(p_t, 'main', 'L', m + 1, i / 2), win_slot = (i % 2) + 1 where id = mid;
      end if;
    end loop;
  end loop;
  for i in 0..(p / 2) - 1 loop
    a := ord[2 * i + 1]; b := ord[2 * i + 2];
    mid := _nx_t_mid(p_t, 'main', 'W', 1, i);
    update nx_t_matches set p1 = case when a <= n then players[a] end, p1_set = true,
                            p2 = case when b <= n then players[b] end, p2_set = true where id = mid;
    perform _nx_t_check(mid);
  end loop;
  perform set_config('nx.tgen', 'off', true);
end $function$
;

-- [7] _nx_t_gen_on()
CREATE OR REPLACE FUNCTION public._nx_t_gen_on()
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  select coalesce(current_setting('nx.tgen', true), '') = 'on'
$function$
;

-- [7] _nx_t_gen_rr(p_t uuid, players uuid[], p_group integer, p_doubl
CREATE OR REPLACE FUNCTION public._nx_t_gen_rr(p_t uuid, players uuid[], p_group integer, p_double boolean, r_off integer, s_off integer, p_bracket text, p_stage text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; arr uuid[] := players; m int; rounds int; cyc int; r int; i int; a uuid; b uuid; tmp uuid;
        rr int; mid uuid; idx int;
begin
  select * into t from nx_tournaments where id = p_t;
  if coalesce(array_length(arr, 1), 0) < 2 then return 0; end if;
  if array_length(arr, 1) % 2 = 1 then arr := arr || null::uuid; end if;
  m := array_length(arr, 1);
  rounds := m - 1;
  perform set_config('nx.tgen', 'on', true);
  for cyc in 0..(case when p_double then 1 else 0 end) loop
    arr := players;
    if array_length(arr, 1) % 2 = 1 then arr := arr || null::uuid; end if;
    for r in 0..rounds - 1 loop
      rr := cyc * rounds + r + 1;
      idx := 0;
      for i in 0..(m / 2) - 1 loop
        a := arr[i + 1]; b := arr[m - i];
        if a is not null and b is not null then
          if (r % 2 = 1 and i = 0) <> (cyc = 1) then tmp := a; a := b; b := tmp; end if;
          mid := _nx_t_new_match(t, p_stage, p_bracket, r_off + rr, idx, s_off + rr, p_group, _nx_t_bo(t, 'early'));
          update nx_t_matches set p1 = a, p1_set = true, p2 = b, p2_set = true where id = mid;
          perform _nx_t_check(mid);
          idx := idx + 1;
        end if;
      end loop;
      -- rotate all but the first
      arr := array[arr[1], arr[m]] || arr[2:m - 1];
    end loop;
  end loop;
  perform set_config('nx.tgen', 'off', true);
  return rounds * (case when p_double then 2 else 1 end);
end $function$
;

-- [7] _nx_t_gen_se(p_t uuid, players uuid[], p_stage text, r_off inte
CREATE OR REPLACE FUNCTION public._nx_t_gen_se(p_t uuid, players uuid[], p_stage text, r_off integer, s_off integer)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; n int := coalesce(array_length(players, 1), 0); k int := 0; p int; ord int[];
        r int; i int; cnt int; mid uuid; final_id uuid; p3 uuid; kind text; a int; b int; nxt uuid;
begin
  select * into t from nx_tournaments where id = p_t;
  if n < 2 then return null; end if;
  while (1 << k) < n loop k := k + 1; end loop;
  p := 1 << k;
  ord := _nx_t_seed_order(p);
  perform set_config('nx.tgen', 'on', true);
  for r in 1..k loop
    cnt := p >> r;
    kind := case when r = k then 'final' when r = k - 1 then 'semi' else 'early' end;
    for i in 0..cnt - 1 loop
      mid := _nx_t_new_match(t, p_stage, 'W', r_off + r, i, s_off + r, null, _nx_t_bo(t, kind));
      if r = k then final_id := mid; end if;
    end loop;
  end loop;
  for r in 1..k - 1 loop
    for i in 0..(p >> r) - 1 loop
      nxt := _nx_t_mid(p_t, p_stage, 'W', r_off + r + 1, i / 2);
      update nx_t_matches set win_to = nxt, win_slot = (i % 2) + 1
       where id = _nx_t_mid(p_t, p_stage, 'W', r_off + r, i);
    end loop;
  end loop;
  if k >= 2 and _nx_t_cfg_bool(t.config, 'third_place', false) then
    p3 := _nx_t_new_match(t, p_stage, 'P3', r_off + k, 0, s_off + k, null, _nx_t_bo(t, 'final'));
    update nx_t_matches set lose_to = p3, lose_slot = 1 where id = _nx_t_mid(p_t, p_stage, 'W', r_off + k - 1, 0);
    update nx_t_matches set lose_to = p3, lose_slot = 2 where id = _nx_t_mid(p_t, p_stage, 'W', r_off + k - 1, 1);
  end if;
  for i in 0..(p / 2) - 1 loop
    a := ord[2 * i + 1]; b := ord[2 * i + 2];
    mid := _nx_t_mid(p_t, p_stage, 'W', r_off + 1, i);
    update nx_t_matches set p1 = case when a <= n then players[a] end, p1_set = true,
                            p2 = case when b <= n then players[b] end, p2_set = true where id = mid;
    perform _nx_t_check(mid);
  end loop;
  perform set_config('nx.tgen', 'off', true);
  return final_id;
end $function$
;

-- [7] _nx_t_job(p_kind text, p_t uuid, p_ref uuid, p_run timestamp wi
CREATE OR REPLACE FUNCTION public._nx_t_job(p_kind text, p_t uuid, p_ref uuid, p_run timestamp with time zone, p_key text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  insert into nx_t_jobs(kind, tournament_id, ref, run_at, idem_key) values (p_kind, p_t, p_ref, p_run, p_key)
  on conflict (idem_key) do update set run_at = excluded.run_at, last_error = null
   where nx_t_jobs.done_at is null;
$function$
;

-- [7] _nx_t_launch(p_m uuid)
CREATE OR REPLACE FUNCTION public._nx_t_launch(p_m uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_t_matches; t nx_tournaments; home uuid; away uuid; rid uuid; mid uuid; sd bigint; c text; golden boolean;
        st jsonb;
begin
  select * into m from nx_t_matches where id = p_m for update;
  if m.id is null or m.status <> 'ready_check' then return null; end if;
  select * into t from nx_tournaments where id = m.tournament_id;
  if m.games % 2 = 0 then home := m.p1; away := m.p2; else home := m.p2; away := m.p1; end if;
  golden := m.games >= m.best_of;
  st := jsonb_build_object('tmatch', m.id, 'tournament', t.id, 'game_no', m.games + 1, 'golden_goal', golden,
                           'grace_sec', 60, 'best_of', m.best_of, 'aggregate', m.aggregate,
                           'match_minutes', _nx_t_cfg_int(t.config, 'match_minutes', 0),
                           'goal_target', _nx_t_cfg_int(t.config, 'goal_target', 0),
                           'lineup', true);
  c := nx_gen_code();
  insert into nx_rooms(code, game, host, seats, status, is_private, quick, settings)
  values (c, t.game, home, 2, 'playing', true, false, st) returning id into rid;
  insert into nx_room_players(room_id, user_id, seat, ready) values (rid, home, 0, true), (rid, away, 1, true);
  sd := floor(random() * 2147483646)::bigint + 1;
  insert into nx_matches(room_id, game, players, names, seed, settings)
  values (rid, t.game, array[home, away],
          array[coalesce((select username from profiles where id = home), 'Pilot'),
                coalesce((select username from profiles where id = away), 'Pilot')], sd, st)
  returning id into mid;
  update nx_rooms set match_id = mid where id = rid;
  insert into nx_t_games(game_match, tmatch, n, home, away, golden) values (mid, m.id, m.games + 1, home, away, golden);
  update nx_t_matches set status = 'playing', game_match = mid, ready_deadline = null, updated_at = now() where id = m.id;
  perform _nx_t_audit(t.id, null, 'game_started', jsonb_build_object('match', m.id, 'game_match', mid, 'n', m.games + 1));
  return mid;
end $function$
;

-- [7] _nx_t_lb_count(p integer, m integer)
CREATE OR REPLACE FUNCTION public._nx_t_lb_count(p integer, m integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case when m = 1 then p >> 2 when m % 2 = 0 then p >> (m / 2 + 1) else p >> ((m - 1) / 2 + 2) end
$function$
;

-- [7] _nx_t_ledger_immutable()
CREATE OR REPLACE FUNCTION public._nx_t_ledger_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  raise exception '% is append-only', tg_table_name;
end $function$
;

-- [7] _nx_t_mid(p_t uuid, p_stage text, p_bracket text, p_round integ
CREATE OR REPLACE FUNCTION public._nx_t_mid(p_t uuid, p_stage text, p_bracket text, p_round integer, p_idx integer)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select id from nx_t_matches where tournament_id = p_t and stage = p_stage and bracket = p_bracket
     and round = p_round and idx = p_idx limit 1
$function$
;

-- [7] _nx_t_new_code()
CREATE OR REPLACE FUNCTION public._nx_t_new_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare c text; alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i int;
begin
  loop
    c := '';
    for i in 1..8 loop c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1); end loop;
    exit when not exists (select 1 from nx_t_codes where code = c);
  end loop;
  return c;
end $function$
;

-- [7] _nx_t_new_match(t nx_tournaments, p_stage text, p_bracket text,
CREATE OR REPLACE FUNCTION public._nx_t_new_match(t nx_tournaments, p_stage text, p_bracket text, p_round integer, p_idx integer, p_slot integer, p_group integer, p_bo integer, p_label text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare mid uuid;
begin
  insert into nx_t_matches(tournament_id, stage, bracket, round, idx, tslot, group_no, best_of, aggregate, label)
  values (t.id, p_stage, p_bracket, p_round, p_idx, p_slot, p_group, p_bo,
          t.format = 'two_legs' and p_bo = 2, p_label)
  returning id into mid;
  return mid;
end $function$
;

-- [7] _nx_t_no_show(p_m uuid)
CREATE OR REPLACE FUNCTION public._nx_t_no_show(p_m uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_t_matches; elim boolean; w uuid;
begin
  select * into m from nx_t_matches where id = p_m for update;
  if m.id is null or m.status <> 'ready_check' or m.ready_deadline > now() then return; end if;
  elim := m.bracket in ('W', 'L', 'GF', 'GF2', 'P3');
  if m.p1_ready and not m.p2_ready then
    perform _nx_t_complete(m.id, m.p1, m.p2, false, 'walkover', 'no_show');
    perform _nx_t_notify(m.p2, m.tournament_id, m.id, 'walkover', jsonb_build_object('lost', true), 'wo:' || m.id);
  elsif m.p2_ready and not m.p1_ready then
    perform _nx_t_complete(m.id, m.p2, m.p1, false, 'walkover', 'no_show');
    perform _nx_t_notify(m.p1, m.tournament_id, m.id, 'walkover', jsonb_build_object('lost', true), 'wo:' || m.id);
  elsif elim then
    -- nobody showed up: the better seed advances (a knockout needs a winner)
    w := _nx_t_better_seed(m.tournament_id, m.p1, m.p2);
    perform _nx_t_complete(m.id, w, case when w = m.p1 then m.p2 else m.p1 end, false, 'walkover', 'double_no_show');
  else
    perform _nx_t_complete(m.id, null, null, false, 'void', 'double_no_show');
  end if;
end $function$
;

-- [7] _nx_t_notif_guard()
CREATE OR REPLACE FUNCTION public._nx_t_notif_guard()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.user_id := old.user_id; new.tournament_id := old.tournament_id; new.tmatch := old.tmatch; new.kind := old.kind;
  new.data := old.data; new.dedup := old.dedup; new.created_at := old.created_at;
  return new;
end $function$
;

-- [7] _nx_t_notify(p_user uuid, p_t uuid, p_tm uuid, p_kind text, p_d
CREATE OR REPLACE FUNCTION public._nx_t_notify(p_user uuid, p_t uuid, p_tm uuid, p_kind text, p_data jsonb DEFAULT '{}'::jsonb, p_dedup text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare ttl text;
begin
  if p_user is null then return; end if;
  select title into ttl from nx_tournaments where id = p_t;
  insert into nx_t_notifications(user_id, tournament_id, tmatch, kind, data, dedup)
  values (p_user, p_t, p_tm, p_kind, coalesce(p_data, '{}'::jsonb) || jsonb_build_object('title', ttl), p_dedup)
  on conflict (user_id, dedup) do nothing;
end $function$
;

-- [7] _nx_t_notify_all(p_t uuid, p_kind text, p_data jsonb, p_dedup t
CREATE OR REPLACE FUNCTION public._nx_t_notify_all(p_t uuid, p_kind text, p_data jsonb, p_dedup text, p_statuses text[] DEFAULT ARRAY['approved'::text])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  for r in select user_id from nx_t_entries where tournament_id = p_t and status = any(p_statuses) loop
    perform _nx_t_notify(r.user_id, p_t, null, p_kind, p_data, case when p_dedup is null then null else p_dedup end);
  end loop;
end $function$
;

-- [7] _nx_t_notify_managers(p_t uuid, p_tm uuid, p_kind text, p_data 
CREATE OR REPLACE FUNCTION public._nx_t_notify_managers(p_t uuid, p_tm uuid, p_kind text, p_data jsonb, p_dedup text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare u uuid;
begin
  for u in
    select created_by from nx_tournaments where id = p_t
    union select user_id from nx_t_staff where tournament_id = p_t
    union select user_id from nx_staff where role = 'admin'
  loop
    perform _nx_t_notify(u, p_t, p_tm, p_kind, p_data, p_dedup);
  end loop;
end $function$
;

-- [7] _nx_t_on_match_end()
CREATE OR REPLACE FUNCTION public._nx_t_on_match_end()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare w uuid;
begin
  if not (new.settings ? 'tmatch') or old.status <> 'playing' or new.status = 'playing' then return new; end if;
  begin
    update nx_rooms set status = 'closed', updated_at = now() where id = new.room_id;
    if array_length(new.winner_seats, 1) = 1 then w := new.players[new.winner_seats[1] + 1]; end if;
    update nx_t_games set ended_at = now(), srv_winner = w, srv_s_home = coalesce(new.scores[1], 0),
           srv_s_away = coalesce(new.scores[2], 0) where game_match = new.id;
    if new.status = 'disputed' then
      -- the phones disagreed about this game: an organizer decides (never auto-accepted as a no-winner game)
      perform _nx_t_dispute((select g.tmatch from nx_t_games g where g.game_match = new.id and not g.accepted), null,
                            'game_reports_disagree');
    elsif coalesce(new.reason, '') like 'forfeit%' or new.status = 'abandoned' then
      perform _nx_t_game_result(new.id, w, coalesce(new.scores[1], 0), coalesce(new.scores[2], 0), 'forfeit');
    else
      perform _nx_t_try_accept(new.id, false);
    end if;
  exception when others then
    insert into nx_t_audit(tournament_id, action, data)
    values ((new.settings ->> 'tournament')::uuid, 'error_match_end', jsonb_build_object('match', new.id, 'error', sqlerrm));
  end;
  return new;
end $function$
;

-- [7] _nx_t_open_ready(p_m uuid)
CREATE OR REPLACE FUNCTION public._nx_t_open_ready(p_m uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_t_matches; t nx_tournaments; secs int;
begin
  select * into m from nx_t_matches where id = p_m for update;
  if m.id is null or m.status not in ('scheduled', 'playing') then return; end if;
  select * into t from nx_tournaments where id = m.tournament_id;
  secs := greatest(30, least(_nx_t_cfg_int(t.config, 'ready_seconds', 300), 3600));
  update nx_t_matches set status = 'ready_check', ready_deadline = now() + make_interval(secs => secs),
         p1_ready = false, p2_ready = false, game_match = null, updated_at = now() where id = p_m;
  perform _nx_t_notify(m.p1, m.tournament_id, m.id, 'match_ready', jsonb_build_object('game', m.games + 1, 'seconds', secs),
                       'ready:' || m.id || ':' || m.games);
  perform _nx_t_notify(m.p2, m.tournament_id, m.id, 'match_ready', jsonb_build_object('game', m.games + 1, 'seconds', secs),
                       'ready:' || m.id || ':' || m.games);
end $function$
;

-- [7] _nx_t_payout(p_t uuid)
CREATE OR REPLACE FUNCTION public._nx_t_payout(p_t uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; dist int[]; tc int; tg int; r record; pool int;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null or t.paid_out then return; end if;
  perform set_config('nx.reason', 'tournament_prize', true);
  select coalesce(array_agg(v::numeric::int order by o), array[60, 30, 10]) into dist
    from jsonb_array_elements_text(case when jsonb_typeof(t.prize -> 'dist') = 'array' then t.prize -> 'dist' else '[60,30,10]'::jsonb end)
         with ordinality as x(v, o);
  tc := _nx_t_prize_total(_nx_t_cfg_int(t.prize, 'fixed_coins', 0), t.escrow_coins, _nx_t_cfg_int(t.prize, 'pool_pct', 0),
                          _nx_t_cfg_int(t.prize, 'fee_pct', 0));
  tg := _nx_t_prize_total(_nx_t_cfg_int(t.prize, 'fixed_gems', 0), t.escrow_gems, _nx_t_cfg_int(t.prize, 'pool_pct', 0),
                          _nx_t_cfg_int(t.prize, 'fee_pct', 0));
  for r in select s.user_id, min(s.place) as place, sum(s.amount)::int as amount from _nx_t_split(p_t, tc, dist) s group by s.user_id loop
    continue when r.amount <= 0;
    if not exists (select 1 from profiles where id = r.user_id) then
      perform _nx_t_audit(p_t, null, 'payout_skipped_no_profile', jsonb_build_object('user', r.user_id, 'coins', r.amount));
      continue;
    end if;
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, place, idem_key)
    values (p_t, r.user_id, 'payout', 'coins', r.amount, r.place, 'payout:' || p_t || ':' || r.user_id || ':coins')
    on conflict (idem_key) do nothing;
    if found then
      update profiles set coins = coins + r.amount where id = r.user_id;
      perform _nx_t_notify(r.user_id, p_t, null, 'prize', jsonb_build_object('coins', r.amount, 'place', r.place),
                           'prize:coins:' || p_t);
    end if;
  end loop;
  for r in select s.user_id, min(s.place) as place, sum(s.amount)::int as amount from _nx_t_split(p_t, tg, dist) s group by s.user_id loop
    continue when r.amount <= 0;
    if not exists (select 1 from profiles where id = r.user_id) then
      perform _nx_t_audit(p_t, null, 'payout_skipped_no_profile', jsonb_build_object('user', r.user_id, 'gems', r.amount));
      continue;
    end if;
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, place, idem_key)
    values (p_t, r.user_id, 'payout', 'gems', r.amount, r.place, 'payout:' || p_t || ':' || r.user_id || ':gems')
    on conflict (idem_key) do nothing;
    if found then
      update profiles set gems = coalesce(gems, 0) + r.amount where id = r.user_id;
      perform _nx_t_notify(r.user_id, p_t, null, 'prize', jsonb_build_object('gems', r.amount, 'place', r.place),
                           'prize:gems:' || p_t);
    end if;
  end loop;
  -- the rest of the escrow (house fee + the part not in the pool) is released to the house in the ledger
  pool := t.escrow_coins;
  if pool > 0 and pool - least(pool, greatest(0, tc - _nx_t_cfg_int(t.prize, 'fixed_coins', 0))) > 0 then
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, idem_key)
    values (p_t, null, 'house_fee', 'coins', pool - least(pool, greatest(0, tc - _nx_t_cfg_int(t.prize, 'fixed_coins', 0))),
            'house:' || p_t || ':coins') on conflict (idem_key) do nothing;
  end if;
  if t.escrow_gems > 0
     and t.escrow_gems - least(t.escrow_gems, greatest(0, tg - _nx_t_cfg_int(t.prize, 'fixed_gems', 0))) > 0 then
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, idem_key)
    values (p_t, null, 'house_fee', 'gems',
            t.escrow_gems - least(t.escrow_gems, greatest(0, tg - _nx_t_cfg_int(t.prize, 'fixed_gems', 0))),
            'house:' || p_t || ':gems') on conflict (idem_key) do nothing;
  end if;
  update nx_tournaments set paid_out = true, escrow_coins = 0, escrow_gems = 0, updated_at = now() where id = p_t;
  perform _nx_t_audit(p_t, null, 'payout', jsonb_build_object('coins', tc, 'gems', tg, 'dist', to_jsonb(dist)));
end $function$
;

-- [7] _nx_t_place_elim(p_t uuid, p_stage text)
CREATE OR REPLACE FUNCTION public._nx_t_place_elim(p_t uuid, p_stage text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; minr int; maxr int; k int; m record; champ uuid; second uuid; lmax int; placed int := 0;
        r record; cnt int;
begin
  select * into t from nx_tournaments where id = p_t;
  if t.format = 'double_elim' then
    select * into m from nx_t_matches where tournament_id = p_t and bracket = 'GF2' and status in ('done', 'walkover');
    if m.id is null then
      select * into m from nx_t_matches where tournament_id = p_t and bracket = 'GF';
    end if;
    champ := m.winner; second := case when m.winner = m.p1 then m.p2 else m.p1 end;
    update nx_t_entries set place = 1 where tournament_id = p_t and user_id = champ;
    update nx_t_entries set place = 2 where tournament_id = p_t and user_id = second;
    placed := 2;
    select max(round) into lmax from nx_t_matches where tournament_id = p_t and bracket = 'L';
    for r in select round as rd, array_agg(loser) as us from nx_t_matches
              where tournament_id = p_t and bracket = 'L' and loser is not null group by round order by round desc loop
      update nx_t_entries set place = placed + 1 where tournament_id = p_t and user_id = any(r.us) and place is null;
      placed := placed + array_length(r.us, 1);
    end loop;
    return placed;
  end if;
  select min(round), max(round) into minr, maxr from nx_t_matches where tournament_id = p_t and stage = p_stage and bracket = 'W';
  if minr is null then return 0; end if;
  k := maxr - minr + 1;
  select * into m from nx_t_matches where tournament_id = p_t and stage = p_stage and bracket = 'W' and round = maxr;
  update nx_t_entries set place = 1 where tournament_id = p_t and user_id = m.winner;
  for r in select round as rd, loser from nx_t_matches
            where tournament_id = p_t and stage = p_stage and bracket = 'W' and loser is not null loop
    update nx_t_entries set place = (1 << (k - (r.rd - minr + 1))) + 1 where tournament_id = p_t and user_id = r.loser;
  end loop;
  select * into m from nx_t_matches where tournament_id = p_t and stage = p_stage and bracket = 'P3' and status in ('done', 'walkover', 'bye');
  if m.id is not null and m.winner is not null then
    update nx_t_entries set place = 3 where tournament_id = p_t and user_id = m.winner;
    if m.loser is not null then update nx_t_entries set place = 4 where tournament_id = p_t and user_id = m.loser; end if;
  end if;
  select count(*) into cnt from nx_t_entries where tournament_id = p_t and status = 'approved' and place is not null;
  return cnt;
end $function$
;

-- [7] _nx_t_planned(t nx_tournaments, p_slot integer)
CREATE OR REPLACE FUNCTION public._nx_t_planned(t nx_tournaments, p_slot integer)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 STABLE
AS $function$
declare a jsonb := t.config -> 'round_starts'; v text;
begin
  if jsonb_typeof(a) = 'array' and jsonb_array_length(a) >= p_slot and p_slot >= 1 then
    v := a ->> (p_slot - 1);
    if v is not null and v <> '' then
      begin return v::timestamptz; exception when others then null; end;
    end if;
  end if;
  return t.start_at + make_interval(mins => greatest(0, p_slot - 1) * greatest(1, _nx_t_cfg_int(t.config, 'round_minutes', 20)));
end $function$
;

-- [7] _nx_t_prize_total(p_fixed integer, p_escrow integer, p_pool_pct
CREATE OR REPLACE FUNCTION public._nx_t_prize_total(p_fixed integer, p_escrow integer, p_pool_pct integer, p_fee_pct integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select greatest(0, coalesce(p_fixed, 0))
       + (greatest(0, coalesce(p_escrow, 0)) * least(100, greatest(0, coalesce(p_pool_pct, 0))) / 100)
       - ((greatest(0, coalesce(p_escrow, 0)) * least(100, greatest(0, coalesce(p_pool_pct, 0))) / 100)
          * least(100, greatest(0, coalesce(p_fee_pct, 0))) / 100)
$function$
;

-- [7] _nx_t_progress(p_t uuid)
CREATE OR REPLACE FUNCTION public._nx_t_progress(p_t uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; open_n int; g int; a int; rk int; grp int; adv uuid[] := '{}'; r record; maxr int; maxs int;
        rounds int; pick uuid; k int;
begin
  if _nx_t_gen_on() then return; end if;
  select * into t from nx_tournaments where id = p_t;
  if t.id is null or t.status <> 'live' then return; end if;
  select count(*) into open_n from nx_t_matches
   where tournament_id = p_t and status not in ('done', 'walkover', 'bye', 'void', 'skipped');
  if open_n > 0 then return; end if;
  if t.format = 'groups_ko' and t.stage = 'groups' then
    g := coalesce((select max(group_no) from nx_t_entries where tournament_id = p_t and status = 'approved'), 1);
    a := greatest(1, least(_nx_t_cfg_int(t.config, 'advance', 2), 8));
    for rk in 1..a loop
      for grp in 1..g loop
        -- A1, B1, C1 ..., A2, B2 ...: the standard bracket order then pairs A1–(last group)2, B1–…, never two of one group
        pick := null;
        select y.user_id into pick from (
          select x.user_id, row_number() over (order by x.pts desc, (x.gf - x.ga) desc, x.gf desc, x.won desc, x.seed) as pos
            from _nx_t_table(p_t, 'groups', grp) x) y where y.pos = rk;
        if pick is not null then adv := adv || pick; end if;
      end loop;
    end loop;
    select max(round), max(tslot) into maxr, maxs from nx_t_matches where tournament_id = p_t;
    update nx_tournaments set stage = 'ko', updated_at = now() where id = p_t;
    for r in select user_id from nx_t_entries where tournament_id = p_t and status = 'approved' and not (user_id = any(adv)) loop
      perform _nx_t_notify(r.user_id, p_t, null, 'eliminated', jsonb_build_object('stage', 'groups'), 'elimg:' || p_t);
    end loop;
    if coalesce(array_length(adv, 1), 0) >= 2 then
      for r in select unnest(adv) as u loop
        perform _nx_t_notify(r.u, p_t, null, 'advanced', jsonb_build_object('stage', 'groups'), 'advg:' || p_t);
      end loop;
      perform _nx_t_gen_se(p_t, adv, 'ko', coalesce(maxr, 0), coalesce(maxs, 0));
      perform _nx_t_progress(p_t);
      return;
    end if;
  elsif t.format = 'swiss' then
    select max(round) into maxr from nx_t_matches where tournament_id = p_t and bracket = 'SW';
    select count(*) into rounds from nx_t_entries where tournament_id = p_t and status = 'approved';
    k := 0;
    while (1 << k) < rounds loop k := k + 1; end loop;
    rounds := least(greatest(1, _nx_t_cfg_int(t.config, 'swiss_rounds', greatest(k, 1))), greatest(1, rounds - 1));
    if coalesce(maxr, 0) < rounds then
      perform _nx_t_swiss_round(p_t, coalesce(maxr, 0) + 1);
      perform _nx_t_progress(p_t);
      return;
    end if;
  elsif t.format = 'custom' then
    return; -- custom brackets are finished by the organizer
  end if;
  perform _nx_t_finish(p_t);
end $function$
;

-- [7] _nx_t_propagate(p_m uuid)
CREATE OR REPLACE FUNCTION public._nx_t_propagate(p_m uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_t_matches; gf2 uuid;
begin
  select * into m from nx_t_matches where id = p_m;
  if m.bracket = 'GF' then
    select id into gf2 from nx_t_matches where tournament_id = m.tournament_id and bracket = 'GF2' and status = 'pending';
    if gf2 is null then return; end if;
    if m.winner is not distinct from m.p1 or m.p2 is null or m.p1 is null then
      update nx_t_matches set status = 'skipped', result_note = 'winners_bracket_champion', updated_at = now() where id = gf2;
    else
      perform _nx_t_put(gf2, 1, m.p1);
      perform _nx_t_put(gf2, 2, m.p2);
    end if;
    return;
  end if;
  if m.win_to is not null then perform _nx_t_put(m.win_to, m.win_slot, m.winner); end if;
  if m.lose_to is not null then perform _nx_t_put(m.lose_to, m.lose_slot, m.loser); end if;
end $function$
;

-- [7] _nx_t_put(p_m uuid, p_slot integer, p_player uuid)
CREATE OR REPLACE FUNCTION public._nx_t_put(p_m uuid, p_slot integer, p_player uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_m is null then return; end if;
  if p_slot = 1 then
    update nx_t_matches set p1 = p_player, p1_set = true, updated_at = now() where id = p_m;
  else
    update nx_t_matches set p2 = p_player, p2_set = true, updated_at = now() where id = p_m;
  end if;
  perform _nx_t_check(p_m);
end $function$
;

-- [7] _nx_t_refund(p_t uuid, p_user uuid, p_reason text)
CREATE OR REPLACE FUNCTION public._nx_t_refund(p_t uuid, p_user uuid, p_reason text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare e nx_t_entries; got boolean := false; unl boolean; kd text;
begin
  select * into e from nx_t_entries where tournament_id = p_t and user_id = p_user for update;
  if e.user_id is null or (e.paid_coins = 0 and e.paid_gems = 0) then return false; end if;
  unl := coalesce((select kind = 'entry_fee_unlimited' from nx_t_ledger where id = e.fee_ref), false);
  kd := case when unl then 'refund_unlimited' else 'refund' end;
  if e.paid_coins > 0 then
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, idem_key)
    values (p_t, p_user, kd, 'coins', e.paid_coins, 'refund:coins:' || coalesce(e.fee_ref::text, p_t || ':' || p_user))
    on conflict (idem_key) do nothing;
    if found then
      if not unl then
        perform set_config('nx.reason', 'tournament_refund', true);
        update profiles set coins = coins + e.paid_coins where id = p_user;
        update nx_tournaments set escrow_coins = greatest(0, escrow_coins - e.paid_coins) where id = p_t;
      end if;
      got := true;
    end if;
  end if;
  if e.paid_gems > 0 then
    insert into nx_t_ledger(tournament_id, user_id, kind, currency, amount, idem_key)
    values (p_t, p_user, kd, 'gems', e.paid_gems, 'refund:gems:' || coalesce(e.fee_ref::text, p_t || ':' || p_user))
    on conflict (idem_key) do nothing;
    if found then
      if not unl then
        perform set_config('nx.reason', 'tournament_refund', true);
        update profiles set gems = coalesce(gems, 0) + e.paid_gems where id = p_user;
        update nx_tournaments set escrow_gems = greatest(0, escrow_gems - e.paid_gems) where id = p_t;
      end if;
      got := true;
    end if;
  end if;
  update nx_t_entries set paid_coins = 0, paid_gems = 0, updated_at = now() where tournament_id = p_t and user_id = p_user;
  if got then
    perform _nx_t_notify(p_user, p_t, null, 'refund', jsonb_build_object('coins', e.paid_coins, 'gems', e.paid_gems,
                         'reason', p_reason, 'unlimited', unl), 'refund:' || coalesce(e.fee_ref::text, p_user::text));
  end if;
  return got;
end $function$
;

-- [7] _nx_t_reschedule(p_t uuid)
CREATE OR REPLACE FUNCTION public._nx_t_reschedule(p_t uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; r record; at timestamptz;
begin
  select * into t from nx_tournaments where id = p_t;
  for r in select id, tslot from nx_t_matches where tournament_id = p_t and status = 'scheduled' loop
    at := greatest(_nx_t_planned(t, r.tslot), now());
    update nx_t_matches set scheduled_at = at, updated_at = now() where id = r.id;
    if at - interval '10 minutes' > now() + interval '1 minute' then
      perform _nx_t_job('remind_match', p_t, r.id, at - interval '10 minutes', 'remind_match:' || r.id);
    end if;
  end loop;
end $function$
;

-- [7] _nx_t_run_job(j nx_t_jobs)
CREATE OR REPLACE FUNCTION public._nx_t_run_job(j nx_t_jobs)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; m nx_t_matches;
begin
  select * into t from nx_tournaments where id = j.tournament_id;
  if t.id is null or t.status in ('finished', 'cancelled', 'draft') then return; end if;
  case j.kind
    when 'open_reg' then
      update nx_tournaments set status = 'registering', updated_at = now() where id = t.id and status = 'scheduled';
    when 'close_reg' then
      update nx_tournaments set status = 'closed', updated_at = now() where id = t.id and status = 'registering';
    when 'checkin_open' then
      if t.status in ('registering', 'closed') then
        perform _nx_t_notify_all(t.id, 'checkin_open', jsonb_build_object('start_at', t.start_at), 'checkin:' || t.id,
                                 array['approved', 'waitlist']);
      end if;
    when 'draw' then
      if _nx_t_cfg_bool(t.config, 'checkin', false) then return; end if;
      if t.status = 'scheduled' then update nx_tournaments set status = 'closed' where id = t.id; end if;
      perform _nx_t_draw(t.id);
    when 'start' then
      if t.status = 'scheduled' then update nx_tournaments set status = 'closed' where id = t.id; end if;
      perform _nx_t_start(t.id);
    when 'remind_start' then
      if t.status in ('registering', 'closed', 'drawn') then
        perform _nx_t_notify_all(t.id, 'starting_soon', jsonb_build_object('start_at', t.start_at), 'soon:' || t.id);
      end if;
    when 'remind_match' then
      select * into m from nx_t_matches where id = j.ref;
      if m.id is not null and m.status = 'scheduled' and m.p1 is not null and m.p2 is not null then
        perform _nx_t_notify(m.p1, t.id, m.id, 'match_soon', jsonb_build_object('at', m.scheduled_at), 'msoon:' || m.id);
        perform _nx_t_notify(m.p2, t.id, m.id, 'match_soon', jsonb_build_object('at', m.scheduled_at), 'msoon:' || m.id);
      end if;
    else
      null;
  end case;
end $function$
;

-- [7] _nx_t_seed_order(p integer)
CREATE OR REPLACE FUNCTION public._nx_t_seed_order(p integer)
 RETURNS integer[]
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare a int[] := array[1]; b int[]; n int := 1; x int;
begin
  while n < p loop
    n := n * 2; b := '{}';
    foreach x in array a loop b := b || x || (n + 1 - x); end loop;
    a := b;
  end loop;
  return a;
end $function$
;

-- [7] _nx_t_split(p_t uuid, p_total integer, p_dist integer[])
CREATE OR REPLACE FUNCTION public._nx_t_split(p_t uuid, p_total integer, p_dist integer[])
 RETURNS TABLE(user_id uuid, place integer, amount integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; k int; share int; i int; paid int := 0; top uuid; dsum int := 0; first_place int;
begin
  if p_total <= 0 or p_dist is null then return; end if;
  for i in 1..coalesce(array_length(p_dist, 1), 0) loop dsum := dsum + greatest(0, p_dist[i]); end loop;
  select min(e.place) into first_place from nx_t_entries e where e.tournament_id = p_t and e.status = 'approved' and e.place is not null;
  for r in select e.place as pl, array_agg(e.user_id order by e.seed nulls last, e.user_id) as us
             from nx_t_entries e where e.tournament_id = p_t and e.status = 'approved' and e.place is not null
            group by e.place order by e.place loop
    k := array_length(r.us, 1);
    share := 0;
    for i in r.pl..r.pl + k - 1 loop
      if i <= coalesce(array_length(p_dist, 1), 0) then share := share + greatest(0, p_dist[i]); end if;
    end loop;
    if share > 0 then
      for i in 1..k loop
        user_id := r.us[i]; place := r.pl; amount := (p_total::bigint * share / 100 / k)::int;
        paid := paid + amount;
        if top is null and r.pl = first_place then top := r.us[i]; end if;
        return next;
      end loop;
    end if;
  end loop;
  if top is not null and (p_total::bigint * least(100, dsum) / 100)::int - paid > 0 then
    user_id := top; place := first_place; amount := (p_total::bigint * least(100, dsum) / 100)::int - paid;
    return next;
  end if;
end $function$
;

-- [7] _nx_t_start(p_t uuid, p_actor uuid)
CREATE OR REPLACE FUNCTION public._nx_t_start(p_t uuid, p_actor uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null then return; end if;
  if t.status in ('registering', 'closed') then
    perform _nx_t_draw(p_t, p_actor);
    select * into t from nx_tournaments where id = p_t;
  end if;
  if t.status <> 'drawn' then return; end if;
  update nx_tournaments set status = 'live', started_at = now(), updated_at = now() where id = p_t;
  perform _nx_t_notify_all(p_t, 'started', '{}'::jsonb, 'started:' || p_t);
  perform _nx_t_audit(p_t, p_actor, 'started', '{}'::jsonb);
  perform _nx_t_progress(p_t);
end $function$
;

-- [7] _nx_t_swiss_round(p_t uuid, p_r integer)
CREATE OR REPLACE FUNCTION public._nx_t_swiss_round(p_t uuid, p_r integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; ord uuid[]; n int; h int; i int; j int; used boolean[]; bye uuid; mid uuid; idx int := 0;
        partner int;
begin
  select * into t from nx_tournaments where id = p_t;
  if p_r = 1 then
    select array_agg(user_id order by seed) into ord from nx_t_entries where tournament_id = p_t and status = 'approved';
  else
    select array_agg(x.user_id order by x.pts desc, (x.gf - x.ga) desc, x.gf desc, x.seed) into ord
      from _nx_t_table(p_t, 'main', null) x;
  end if;
  n := coalesce(array_length(ord, 1), 0);
  if n < 2 then return; end if;
  perform set_config('nx.tgen', 'on', true);
  if n % 2 = 1 then
    for i in reverse n..1 loop
      if not exists (select 1 from nx_t_matches where tournament_id = p_t and bracket = 'SW' and status = 'bye'
                      and p1 = ord[i]) then
        bye := ord[i]; exit;
      end if;
    end loop;
    if bye is null then bye := ord[n]; end if;
    ord := array_remove(ord, bye);
    n := n - 1;
  end if;
  if p_r = 1 then
    h := n / 2;
    for i in 1..h loop
      mid := _nx_t_new_match(t, 'main', 'SW', p_r, idx, p_r, null, _nx_t_bo(t, 'early'));
      update nx_t_matches set p1 = ord[i], p1_set = true, p2 = ord[i + h], p2_set = true where id = mid;
      perform _nx_t_check(mid); idx := idx + 1;
    end loop;
  else
    used := array_fill(false, array[n]);
    for i in 1..n loop
      continue when used[i];
      partner := null;
      for j in i + 1..n loop
        continue when used[j];
        if not exists (select 1 from nx_t_matches where tournament_id = p_t and bracket = 'SW'
                        and ((p1 = ord[i] and p2 = ord[j]) or (p1 = ord[j] and p2 = ord[i]))) then
          partner := j; exit;
        end if;
      end loop;
      if partner is null then
        for j in i + 1..n loop
          if not used[j] then partner := j; exit; end if;
        end loop;
      end if;
      exit when partner is null;
      used[i] := true; used[partner] := true;
      mid := _nx_t_new_match(t, 'main', 'SW', p_r, idx, p_r, null, _nx_t_bo(t, 'early'));
      update nx_t_matches set p1 = ord[i], p1_set = true, p2 = ord[partner], p2_set = true where id = mid;
      perform _nx_t_check(mid); idx := idx + 1;
    end loop;
  end if;
  if bye is not null then
    mid := _nx_t_new_match(t, 'main', 'SW', p_r, idx, p_r, null, 1);
    update nx_t_matches set p1 = bye, p1_set = true, p2 = null, p2_set = true where id = mid;
    perform _nx_t_check(mid);
  end if;
  perform set_config('nx.tgen', 'off', true);
  update nx_tournaments set updated_at = now() where id = p_t;
end $function$
;

-- [7] _nx_t_sync_jobs(p_t uuid)
CREATE OR REPLACE FUNCTION public._nx_t_sync_jobs(p_t uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments;
begin
  select * into t from nx_tournaments where id = p_t;
  if t.id is null or t.status in ('draft', 'finished', 'cancelled') then return; end if;
  perform _nx_t_job('open_reg', t.id, null, t.reg_open_at, 'open_reg:' || t.id);
  perform _nx_t_job('close_reg', t.id, null, t.reg_close_at, 'close_reg:' || t.id);
  -- with check-in the draw happens at the start (after the check-in window)
  if not _nx_t_cfg_bool(t.config, 'checkin', false) then
    perform _nx_t_job('draw', t.id, null, t.draw_at, 'draw:' || t.id);
  end if;
  perform _nx_t_job('start', t.id, null, t.start_at, 'start:' || t.id);
  if t.start_at - interval '10 minutes' > now() then
    if _nx_t_cfg_bool(t.config, 'checkin', false) then
      delete from nx_t_jobs where idem_key = 'remind_start:' || t.id and done_at is null;
      perform _nx_t_job('checkin_open', t.id, null, t.start_at - interval '10 minutes', 'checkin_open:' || t.id);
    else
      delete from nx_t_jobs where idem_key = 'checkin_open:' || t.id and done_at is null;
      perform _nx_t_job('remind_start', t.id, null, t.start_at - interval '10 minutes', 'remind_start:' || t.id);
    end if;
  end if;
end $function$
;

-- [7] _nx_t_table(p_t uuid, p_stage text, p_group integer)
CREATE OR REPLACE FUNCTION public._nx_t_table(p_t uuid, p_stage text, p_group integer)
 RETURNS TABLE(user_id uuid, seed integer, played integer, won integer, drawn integer, lost integer, gf integer, ga integer, pts integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with t as (select * from nx_tournaments where id = p_t),
  rows as (
    select m.p1 as u, m.p2 as o, m.winner, m.is_draw, m.g1 as f, m.g2 as a, m.status from nx_t_matches m
     where m.tournament_id = p_t and m.stage = p_stage and m.bracket in ('RR', 'G', 'SW', 'C') and m.p1 is not null
       and (p_group is null or m.group_no = p_group) and m.status in ('done', 'walkover', 'bye')
    union all
    select m.p2, m.p1, m.winner, m.is_draw, m.g2, m.g1, m.status from nx_t_matches m
     where m.tournament_id = p_t and m.stage = p_stage and m.bracket in ('RR', 'G', 'SW', 'C') and m.p2 is not null
       and (p_group is null or m.group_no = p_group) and m.status in ('done', 'walkover', 'bye')
  )
  select e.user_id, e.seed,
         count(r.u)::int,
         count(r.u) filter (where r.winner = e.user_id)::int,
         count(r.u) filter (where r.is_draw)::int,
         count(r.u) filter (where r.winner is distinct from e.user_id and not r.is_draw)::int,
         coalesce(sum(r.f), 0)::int, coalesce(sum(r.a), 0)::int,
         (count(r.u) filter (where r.winner = e.user_id) * _nx_t_cfg_int((select config from t), 'points_win', 3)
          + count(r.u) filter (where r.is_draw) * _nx_t_cfg_int((select config from t), 'points_draw', 1))::int
    from nx_t_entries e left join rows r on r.u = e.user_id
   where e.tournament_id = p_t and e.status = 'approved' and (p_group is null or e.group_no = p_group)
   group by e.user_id, e.seed
$function$
;

-- [7] _nx_t_try_accept(p_gm uuid, p_from_tick boolean)
CREATE OR REPLACE FUNCTION public._nx_t_try_accept(p_gm uuid, p_from_tick boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g nx_t_games; rh nx_t_reports; ra nx_t_reports; one nx_t_reports; n int;
begin
  select * into g from nx_t_games where game_match = p_gm;
  if g.game_match is null or g.accepted or g.disputed then return; end if;
  select * into rh from nx_t_reports where game_match = p_gm and user_id = g.home;
  select * into ra from nx_t_reports where game_match = p_gm and user_id = g.away;
  if rh.user_id is not null and ra.user_id is not null then
    if rh.winner is not distinct from ra.winner and rh.s_home = ra.s_home and rh.s_away = ra.s_away then
      perform _nx_t_game_result(p_gm, rh.winner, rh.s_home, rh.s_away, 'both_reports');
    else
      perform _nx_t_dispute(g.tmatch, null, 'reports_disagree');
    end if;
    return;
  end if;
  one := coalesce(rh, ra);
  if one.user_id is not null then
    if g.ended_at is not null and (one.winner is distinct from g.srv_winner) then
      perform _nx_t_dispute(g.tmatch, null, 'report_vs_server');
      return;
    end if;
    if p_from_tick and g.ended_at is not null and greatest(g.ended_at, one.created_at) < now() - interval '90 seconds' then
      perform _nx_t_game_result(p_gm, one.winner, one.s_home, one.s_away, 'single_report');
    end if;
    return;
  end if;
  if p_from_tick and g.ended_at is not null and g.ended_at < now() - interval '3 minutes' then
    perform _nx_t_game_result(p_gm, g.srv_winner, coalesce(g.srv_s_home, 0), coalesce(g.srv_s_away, 0), 'server_only');
  end if;
end $function$
;

-- [7] _nx_t_validate_cfg(c jsonb)
CREATE OR REPLACE FUNCTION public._nx_t_validate_cfg(c jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
declare o jsonb := coalesce(c, '{}'::jsonb); k text;
begin
  foreach k in array array['bo_early', 'bo_semi', 'bo_final'] loop
    if _nx_t_cfg_int(o, k, 1) not between 1 and 15 then o := o || jsonb_build_object(k, 1); end if;
  end loop;
  -- online match length: 3 / 5 / 7 minutes, or first to N goals (0 = game default)
  if _nx_t_cfg_int(o, 'match_minutes', 0) not in (0, 3, 5, 7) then o := o || '{"match_minutes": 5}'::jsonb; end if;
  o := o || jsonb_build_object('goal_target', greatest(0, least(_nx_t_cfg_int(o, 'goal_target', 0), 20)),
                               'checkin', _nx_t_cfg_bool(o, 'checkin', true));
  if _nx_t_cfg_int(o, 'goal_target', 0) > 0 then o := o || '{"match_minutes": 0}'::jsonb; end if;
  o := o || jsonb_build_object(
    'groups', greatest(1, least(_nx_t_cfg_int(o, 'groups', 2), 16)),
    'advance', greatest(1, least(_nx_t_cfg_int(o, 'advance', 2), 8)),
    'swiss_rounds', greatest(0, least(_nx_t_cfg_int(o, 'swiss_rounds', 0), 12)),
    'points_win', greatest(0, least(_nx_t_cfg_int(o, 'points_win', 3), 10)),
    'points_draw', greatest(0, least(_nx_t_cfg_int(o, 'points_draw', 1), 10)),
    'ready_seconds', greatest(30, least(_nx_t_cfg_int(o, 'ready_seconds', 300), 3600)),
    'round_minutes', greatest(1, least(_nx_t_cfg_int(o, 'round_minutes', 20), 10080)),
    'max_game_minutes', greatest(5, least(_nx_t_cfg_int(o, 'max_game_minutes', 30), 240)));
  -- a game is only declared stuck ("game_timeout" dispute) well after its own clock could have run out:
  -- at least the match length + 10 minutes (lineup, 60 s reconnect grace, golden goal), or 15 minutes for "first to N goals"
  o := o || jsonb_build_object('max_game_minutes', greatest(_nx_t_cfg_int(o, 'max_game_minutes', 30),
    case when _nx_t_cfg_int(o, 'goal_target', 0) > 0 then 15
         else (case when _nx_t_cfg_int(o, 'match_minutes', 0) in (3, 5, 7) then _nx_t_cfg_int(o, 'match_minutes', 0) else 5 end) + 10 end));
  return o;
end $function$
;

-- [7] _nx_wallet_tx_kick()
CREATE OR REPLACE FUNCTION public._nx_wallet_tx_kick()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform nx_wallet_push();
  return null;
end $function$
;

-- [7] buy_cosmetic(p_item text)
CREATE OR REPLACE FUNCTION public.buy_cosmetic(p_item text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); it nx_cosmetics; bal integer;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select * into it from nx_cosmetics where item_id = p_item;
  if it.item_id is null or not it.active then
    select coins into bal from profiles where id = me;
    return jsonb_build_object('ok', false, 'error', 'not_for_sale', 'coins', bal);
  end if;
  if not exists (select 1 from profiles where id = me) then
    return jsonb_build_object('ok', false, 'error', 'no_profile');  -- client calls nx_g_hello first
  end if;
  -- serialise purchases of this player
  perform 1 from profiles where id = me for update;
  if exists (select 1 from nx_cosmetic_owned where user_id = me and item_id = p_item) then
    select coins into bal from profiles where id = me;
    return jsonb_build_object('ok', true, 'owned', true, 'coins', bal, 'item', p_item);
  end if;
  if it.price_coins > 0 then
    perform set_config('nx.reason', left('cosmetic:' || p_item, 80), true);
    update profiles set coins = coins - it.price_coins
     where id = me and coins >= it.price_coins returning coins into bal;
    if bal is null then
      select coins into bal from profiles where id = me;
      return jsonb_build_object('ok', false, 'error', 'insufficient_coins', 'coins', bal, 'price', it.price_coins);
    end if;
  else
    select coins into bal from profiles where id = me;
  end if;
  insert into nx_cosmetic_owned(user_id, item_id, price_paid) values (me, p_item, it.price_coins)
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'coins', bal, 'price', it.price_coins, 'item', p_item);
end $function$
;

-- [7] equip_cosmetic(p_item text)
CREATE OR REPLACE FUNCTION public.equip_cosmetic(p_item text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); it nx_cosmetics;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select * into it from nx_cosmetics where item_id = p_item;
  if it.item_id is null then return jsonb_build_object('ok', false, 'error', 'unknown_item'); end if;
  if it.price_coins > 0 and not exists (select 1 from nx_cosmetic_owned where user_id = me and item_id = p_item) then
    return jsonb_build_object('ok', false, 'error', 'not_owned');
  end if;
  insert into nx_cosmetic_equipped(user_id, game, kind, item_id) values (me, it.game, it.kind, p_item)
  on conflict (user_id, game, kind) do update set item_id = excluded.item_id, updated_at = now();
  return jsonb_build_object('ok', true, 'item', p_item, 'game', it.game, 'kind', it.kind);
end $function$
;

-- [7] is_admin(uid uuid)
CREATE OR REPLACE FUNCTION public.is_admin(uid uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select nx_t_is_admin(uid) $function$
;

-- [7] is_owner(uid uuid)
CREATE OR REPLACE FUNCTION public.is_owner(uid uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select (uid = auth.uid() and nx_perm('owner')) or exists (select 1 from profiles where id = uid and role = 'owner')
$function$
;

-- [7] level_for_xp(x integer)
CREATE OR REPLACE FUNCTION public.level_for_xp(x integer)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
AS $function$ select greatest(1, floor(sqrt(greatest(x,0)/100.0))::int + 1) $function$
;

-- [7] my_cosmetics()
CREATE OR REPLACE FUNCTION public.my_cosmetics()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'ok', auth.uid() is not null,
    'owned', coalesce((select jsonb_agg(item_id order by acquired_at) from nx_cosmetic_owned where user_id = auth.uid()), '[]'::jsonb),
    'equipped', coalesce((select jsonb_object_agg(game || '.' || kind, item_id) from nx_cosmetic_equipped where user_id = auth.uid()), '{}'::jsonb),
    'coins', (select coins from profiles where id = auth.uid()))
$function$
;

-- [7] nx_admin_close_room(p_room uuid, p_reason text)
CREATE OR REPLACE FUNCTION public.nx_admin_close_room(p_room uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r nx_rooms;
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  select * into r from nx_rooms where id = p_room for update;
  if r.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if r.match_id is not null and r.settings ? 'tmatch' then
    return jsonb_build_object('ok', false, 'error', 'tournament_room'); -- use the tournament match tools instead
  end if;
  if r.match_id is not null then
    update nx_matches set status = 'finished', reason = 'admin_closed', winner_seats = '{}', ended_at = now()
     where id = r.match_id and status = 'playing';
  end if;
  update nx_rooms set status = 'closed', updated_at = now() where id = p_room;
  delete from nx_room_players where room_id = p_room;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), 'close_room', p_room::text,
    jsonb_build_object('reason', p_reason, 'code', r.code, 'game', r.game));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_admin_end_match(p_match uuid, p_reason text)
CREATE OR REPLACE FUNCTION public.nx_admin_end_match(p_match uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_matches;
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if m.settings ? 'tmatch' then return jsonb_build_object('ok', false, 'error', 'tournament_room'); end if;
  if m.status <> 'playing' then return jsonb_build_object('ok', false, 'error', 'not_live'); end if;
  update nx_matches set status = 'finished', reason = 'admin_ended', winner_seats = '{}', ended_at = now() where id = p_match;
  if m.room_id is not null then
    update nx_rooms set status = case when status = 'playing' then 'lobby' else status end, updated_at = now() where id = m.room_id;
  end if;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), 'end_match', p_match::text,
    jsonb_build_object('reason', p_reason, 'game', m.game));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_admin_kick(p_room uuid, p_user uuid, p_reason text)
CREATE OR REPLACE FUNCTION public.nx_admin_kick(p_room uuid, p_user uuid, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if nx_is_owner(p_user) and not nx_is_owner(auth.uid()) then return jsonb_build_object('ok', false, 'error', 'cannot_ban_owner'); end if;
  delete from nx_room_members where room_id = p_room and user_id = p_user;
  delete from nx_room_players where room_id = p_room and user_id = p_user;
  delete from nx_room_game_players where room_id = p_room and user_id = p_user;
  update nx_rooms set updated_at = now() where id = p_room;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), 'kick', p_user::text,
    jsonb_build_object('room', p_room, 'reason', p_reason));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_admin_live_matches(p_limit integer)
CREATE OR REPLACE FUNCTION public.nx_admin_live_matches(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  return jsonb_build_object('ok', true, 'matches', coalesce((select jsonb_agg(x order by x.started_at desc) from (
    select id, room_id, game, names, scores, status, started_at, (settings ? 'tmatch') as tournament
      from nx_matches where status = 'playing'
     order by started_at desc limit greatest(1, least(coalesce(p_limit, 100), 300))) x), '[]'::jsonb));
end $function$
;

-- [7] nx_admin_mute(p_user uuid, p_minutes integer, p_reason text)
CREATE OR REPLACE FUNCTION public.nx_admin_mute(p_user uuid, p_minutes integer, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare until timestamptz;
begin
  if not nx_has_perm('users') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if p_user = auth.uid() then return jsonb_build_object('ok', false, 'error', 'cannot_change_self'); end if;
  if nx_is_owner(p_user) then return jsonb_build_object('ok', false, 'error', 'cannot_ban_owner'); end if;
  until := case when coalesce(p_minutes, 0) <= 0 then null else now() + make_interval(mins => least(p_minutes, 525600)) end;
  insert into nx_user_mutes(user_id, muted_until, reason, by) values (p_user, until, left(p_reason, 300), auth.uid())
  on conflict (user_id) do update set muted_until = excluded.muted_until, reason = excluded.reason, by = excluded.by, updated_at = now();
  -- muted players also lose the stage in every voice room
  if until is not null then
    update nx_room_members set muted = true where user_id = p_user;
  end if;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), case when until is null then 'unmute' else 'mute' end,
    p_user::text, jsonb_build_object('minutes', p_minutes, 'reason', p_reason));
  return jsonb_build_object('ok', true, 'muted_until', until);
end $function$
;

-- [7] nx_admin_room_clear_chat(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_admin_room_clear_chat(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n integer;
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  update nx_room_messages set deleted = true where room_id = p_room and not deleted;
  get diagnostics n = row_count;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), 'room_clear_chat', p_room::text, jsonb_build_object('messages', n));
  return jsonb_build_object('ok', true, 'messages', n);
end $function$
;

-- [7] nx_admin_room_members(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_admin_room_members(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  return jsonb_build_object('ok', true, 'members', coalesce((select jsonb_agg(x order by x.joined_at) from (
    select m.user_id, m.role, m.joined_at, m.last_seen, m.muted, p.username
      from nx_room_members m left join profiles p on p.id = m.user_id where m.room_id = p_room) x), '[]'::jsonb));
end $function$
;

-- [7] nx_admin_room_message(p_room uuid, p_text text)
CREATE OR REPLACE FUNCTION public.nx_admin_room_message(p_room uuid, p_text text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t text := btrim(coalesce(p_text, ''));
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if char_length(t) < 1 or char_length(t) > 500 then return jsonb_build_object('ok', false, 'error', 'bad_text'); end if;
  if not exists (select 1 from nx_rooms where id = p_room) then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  insert into nx_room_messages(room_id, author, text) values (p_room, auth.uid(), '📢 ' || t);
  update nx_rooms set updated_at = now() where id = p_room;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), 'room_message', p_room::text, jsonb_build_object('text', t));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_admin_room_update(p_room uuid, p_private boolean, p_seats in
CREATE OR REPLACE FUNCTION public.nx_admin_room_update(p_room uuid, p_private boolean DEFAULT NULL::boolean, p_seats integer DEFAULT NULL::integer, p_title text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r nx_rooms;
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  select * into r from nx_rooms where id = p_room for update;
  if r.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if p_seats is not null and (p_seats < 2 or p_seats > 21) then return jsonb_build_object('ok', false, 'error', 'bad_seats'); end if;
  update nx_rooms set is_private = coalesce(p_private, is_private), seats = coalesce(p_seats, seats),
         title = coalesce(nullif(left(btrim(coalesce(p_title, '')), 60), ''), title), updated_at = now()
   where id = p_room;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), 'room_update', p_room::text,
    jsonb_build_object('private', p_private, 'seats', p_seats, 'title', p_title));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_admin_rooms(p_limit integer)
CREATE OR REPLACE FUNCTION public.nx_admin_rooms(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not nx_has_perm('rooms') then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  return jsonb_build_object('ok', true, 'rooms', coalesce((select jsonb_agg(x order by x.updated_at desc) from (
    select r.id, r.code, r.game, r.status, r.is_private, r.quick, r.seats, r.settings, r.created_at, r.updated_at, r.host,
           p.username as host_name, (select count(*) from nx_room_players rp where rp.room_id = r.id) as players
      from nx_rooms r left join profiles p on p.id = r.host
     where r.status in ('lobby', 'playing')
     order by r.updated_at desc limit greatest(1, least(coalesce(p_limit, 100), 300))) x), '[]'::jsonb));
end $function$
;

-- [7] nx_admin_rooms_broadcast(p_text text)
CREATE OR REPLACE FUNCTION public.nx_admin_rooms_broadcast(p_text text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t text := btrim(coalesce(p_text, '')); n integer;
begin
  if not (nx_has_perm('rooms') or nx_has_perm('announcements')) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if char_length(t) < 1 or char_length(t) > 500 then return jsonb_build_object('ok', false, 'error', 'bad_text'); end if;
  insert into nx_room_messages(room_id, author, text)
  select id, auth.uid(), '📢 ' || t from nx_rooms where status in ('lobby', 'playing', 'open');
  get diagnostics n = row_count;
  insert into nx_admin_audit(actor, action, target, data) values (auth.uid(), 'rooms_broadcast', null, jsonb_build_object('text', t, 'rooms', n));
  return jsonb_build_object('ok', true, 'rooms', n);
end $function$
;

-- [7] nx_apply_physics_contract()
CREATE OR REPLACE FUNCTION public.nx_apply_physics_contract()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare c nx_physics_contracts;
begin select * into c from public.nx_physics_contracts where game = new.game; if found then new.physics_version := c.version; new.physics_contract := c.contract; end if; return new; end; $function$
;

-- [7] nx_arcade_limits(p_game text, OUT max_score integer, OUT max_ra
CREATE OR REPLACE FUNCTION public.nx_arcade_limits(p_game text, OUT max_score integer, OUT max_rate numeric, OUT min_ms integer)
 RETURNS record
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p_game
           when 'endless_runner' then 200000 when 'tetris_rush' then 9999999 when 'helix_jump' then 500000
           when 'fruit_ninja' then 20000 when 'geo_dash' then 100000 when 'traffic_racer' then 2000000
           when 'stack_tower' then 2000 when 'bubble_shooter' then 5000000 when 'knife_hit' then 50000
           when 'game_2048' then 4000000 else 0 end,
         case p_game
           when 'endless_runner' then 40 when 'tetris_rush' then 3000 when 'helix_jump' then 120
           when 'fruit_ninja' then 25 when 'geo_dash' then 30 when 'traffic_racer' then 400
           when 'stack_tower' then 4 when 'bubble_shooter' then 2500 when 'knife_hit' then 12
           when 'game_2048' then 1500 else 0 end,
         case p_game when 'stack_tower' then 800 else 1500 end
$function$
;

-- [7] nx_arcade_submit(p_game text, p_score integer, p_duration_ms in
CREATE OR REPLACE FUNCTION public.nx_arcade_submit(p_game text, p_score integer, p_duration_ms integer, p_daily boolean DEFAULT false, p_meta jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  l record;
  ok boolean := true;
  why text := null;
  today date := (now() at time zone 'utc')::date;
  b nx_arcade_best;
  r int;
  slack numeric;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into l from nx_arcade_limits(p_game);
  if l.max_score = 0 then raise exception 'unknown game'; end if;
  if not exists (select 1 from profiles where id = me) then raise exception 'call nx_g_hello first'; end if;
  select * into b from nx_arcade_best where user_id = me and game = p_game;
  -- rate limit: one submit per 3 s per game
  if b.last_submit is not null and b.last_submit > now() - interval '3 seconds' then
    ok := false; why := 'rate_limited';
  end if;
  slack := 1.0 + 15.0 * l.max_rate;  -- small bonus burst allowance
  if ok and (p_score is null or p_score < 0 or p_score > l.max_score) then ok := false; why := 'score_out_of_range'; end if;
  if ok and p_score > 0 and coalesce(p_duration_ms, 0) < l.min_ms then ok := false; why := 'too_short'; end if;
  if ok and p_score > slack + l.max_rate * greatest(0, coalesce(p_duration_ms, 0)) / 1000.0 then
    ok := false; why := 'too_fast';
  end if;
  if ok and coalesce(p_duration_ms, 0) > 6 * 3600 * 1000 then ok := false; why := 'too_long'; end if;
  insert into nx_arcade_runs(user_id, game, score, duration_ms, daily, accepted, reason, meta)
  values (me, p_game, greatest(0, least(coalesce(p_score, 0), 2000000000)), greatest(0, coalesce(p_duration_ms, 0)),
          coalesce(p_daily, false), ok, why, coalesce(p_meta, '{}'::jsonb));
  if not ok then
    if why <> 'rate_limited' then
      insert into nx_arcade_best(user_id, game, last_submit) values (me, p_game, now())
      on conflict (user_id, game) do update set last_submit = now();
    end if;
    return jsonb_build_object('ok', false, 'reason', why);
  end if;
  insert into nx_arcade_best(user_id, game, best, best_at, daily_day, daily_best, plays, last_submit)
  values (me, p_game, p_score, now(), case when p_daily then today end, case when p_daily then p_score else 0 end, 1, now())
  on conflict (user_id, game) do update set
    best = greatest(nx_arcade_best.best, excluded.best),
    best_at = case when excluded.best > nx_arcade_best.best then now() else nx_arcade_best.best_at end,
    daily_day = case when p_daily then today else nx_arcade_best.daily_day end,
    daily_best = case when not p_daily then nx_arcade_best.daily_best
                      when nx_arcade_best.daily_day = today then greatest(nx_arcade_best.daily_best, p_score)
                      else p_score end,
    plays = nx_arcade_best.plays + 1,
    last_submit = now()
  returning * into b;
  -- mirror into the per-game stats used by the generic leaderboard / profile
  insert into nx_game_stats(user_id, game, played, won, lost, draw, rating, best)
  values (me, p_game, 1, 0, 0, 0, 1000, p_score)
  on conflict (user_id, game) do update set played = nx_game_stats.played + 1,
    best = greatest(nx_game_stats.best, excluded.best), updated_at = now();
  select count(*) + 1 into r from nx_arcade_best x where x.game = p_game and x.best > b.best;
  return jsonb_build_object('ok', true, 'best', b.best, 'rank', r, 'daily_best', b.daily_best);
end $function$
;

-- [7] nx_arcade_top(p_game text, p_daily boolean, p_limit integer)
CREATE OR REPLACE FUNCTION public.nx_arcade_top(p_game text, p_daily boolean DEFAULT false, p_limit integer DEFAULT 50)
 RETURNS TABLE(user_id uuid, username text, avatar text, score integer, plays integer, at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select b.user_id, p.username, p.avatar,
         case when p_daily then b.daily_best else b.best end as score, b.plays, b.best_at
    from nx_arcade_best b join profiles p on p.id = b.user_id
   where b.game = p_game
     and (case when p_daily then b.daily_day = (now() at time zone 'utc')::date and b.daily_best > 0 else b.best > 0 end)
   order by 4 desc, b.best_at asc
   limit greatest(1, least(coalesce(p_limit, 50), 100))
$function$
;

-- [7] nx_create_room(p_game text, p_seats integer, p_private boolean,
CREATE OR REPLACE FUNCTION public.nx_create_room(p_game text, p_seats integer, p_private boolean, p_quick boolean DEFAULT false, p_settings jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); b record; s int; rid uuid; c text;
begin
  if me is null then raise exception 'not signed in'; end if;
  if not public.nx_known_game(p_game) then raise exception 'unknown game'; end if;
  select * into b from public.nx_game_bounds(p_game);
  s := greatest(b.min_seats, least(coalesce(p_seats, b.min_seats), b.max_seats));
  perform public._nx_leave_all(me);
  c := public.nx_gen_code();
  insert into public.nx_rooms(code, game, host, seats, is_private, quick, settings, selected_game, kind)
  values (c, p_game, me, s, coalesce(p_private, false), coalesce(p_quick, false), coalesce(p_settings, '{}'::jsonb),
          p_game, 'game')
  returning id into rid;
  insert into public.nx_room_players(room_id, user_id, seat, ready) values (rid, me, 0, true);
  insert into public.nx_room_members(room_id, user_id, role) values (rid, me, 'manager')
    on conflict (room_id, user_id) do update set role = 'manager', last_seen = now();
  insert into public.nx_room_game_players(room_id, user_id, seat, team, ready) values (rid, me, 0, 0, true)
    on conflict (room_id, user_id) do update set ready = true;
  return jsonb_build_object('room_id', rid, 'code', c, 'seats', s, 'capacity', s,
                            'min_players', b.min_seats, 'max_players', b.max_seats);
end $function$
;

-- [7] nx_finish_match(p_match uuid, p_winners integer[], p_scores int
CREATE OR REPLACE FUNCTION public.nx_finish_match(p_match uuid, p_winners integer[], p_scores integer[], p_hash text DEFAULT NULL::text, p_reason text DEFAULT 'finished'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  m nx_matches;
  n int;
  w int[];
  forfeited int[];
  required uuid[];
  missing uuid[];
  n_reports int;
  n_winner_sets int;
  n_hashes int;
  n_null_hash int;
  final_scores int[];
  k int;
  u uuid;
  gone boolean := true;
begin
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then raise exception 'match not found'; end if;
  if me is null or not (me = any(m.players)) then raise exception 'not a player'; end if;
  if m.status <> 'playing' then
    return jsonb_build_object('ok', true, 'already', true, 'winners', m.winner_seats, 'status', m.status);
  end if;
  n := coalesce(array_length(m.players, 1), 0);

  if exists (select 1 from unnest(coalesce(p_winners, '{}'::int[])) x where x is null or x < 0 or x >= n) then
    return jsonb_build_object('ok', false, 'error', 'bad_winners');
  end if;
  select coalesce(array_agg(distinct x order by x), '{}'::int[]) into w from unnest(coalesce(p_winners, '{}'::int[])) x;

  insert into nx_match_reports(match_id, user_id, winners, scores, state_hash, reason)
  values (p_match, me, w, p_scores, nullif(left(p_hash, 128), ''), left(coalesce(p_reason, 'finished'), 40))
  on conflict (match_id, user_id) do nothing;

  forfeited := public._nx_forfeited_seats(p_match);
  select coalesce(array_agg(m.players[g]), '{}'::uuid[]) into required
    from generate_series(1, n) g
   where m.players[g] is not null and not ((g - 1) = any(forfeited));
  select coalesce(array_agg(x), '{}'::uuid[]) into missing
    from unnest(required) x
   where not exists (select 1 from nx_match_reports r where r.match_id = p_match and r.user_id = x);

  select count(*), count(distinct winners), count(distinct state_hash), count(*) filter (where state_hash is null)
    into n_reports, n_winner_sets, n_hashes, n_null_hash
    from nx_match_reports where match_id = p_match;

  if n_winner_sets > 1 or (n_null_hash = 0 and n_hashes > 1) then
    update nx_matches set status = 'disputed', winner_seats = null, reason = 'disputed', ended_at = now()
     where id = p_match;
    perform _nx_room_after_match(m.room_id, m.id);
    return jsonb_build_object('ok', true, 'disputed', true, 'winners', null);
  end if;

  if coalesce(array_length(missing, 1), 0) > 0 then
    if now() <= m.turn_deadline or m.started_at > now() - interval '30 seconds' then
      gone := false;
    else
      foreach u in array missing loop
        if public._nx_player_active(p_match, u, 30, 30)
           or exists (select 1 from nx_room_players rp where rp.room_id = m.room_id and rp.user_id = u
                    and rp.last_seen > now() - interval '30 seconds') then
          gone := false;
          exit;
        end if;
      end loop;
    end if;
    if not gone then
      return jsonb_build_object('ok', true, 'pending', true, 'reports', n_reports,
                                'needed', coalesce(array_length(required, 1), 0));
    end if;
  end if;

  select r.winners into w from nx_match_reports r where r.match_id = p_match limit 1;
  final_scores := null;
  if not exists (select 1 from nx_match_reports r where r.match_id = p_match and r.scores is null) then
    final_scores := '{}'::int[];
    for k in 1..n loop
      final_scores := final_scores || (select min(r.scores[k]) from nx_match_reports r where r.match_id = p_match);
    end loop;
  end if;
  update nx_matches set status = 'finished', winner_seats = w, scores = final_scores,
         reason = left(coalesce(p_reason, 'finished'), 40),
         state_hash = coalesce((select max(r.state_hash) from nx_match_reports r where r.match_id = p_match), state_hash),
         ended_at = now()
   where id = p_match returning * into m;
  perform _nx_apply_result(m, w, final_scores);
  perform _nx_room_after_match(m.room_id, m.id);
  return jsonb_build_object('ok', true, 'winners', w);
end $function$
;

-- [7] nx_finish_match_as(p_match uuid, p_winners integer[], p_loser i
CREATE OR REPLACE FUNCTION public.nx_finish_match_as(p_match uuid, p_winners integer[], p_loser integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_matches;
begin
  update nx_matches set status = 'finished', winner_seats = p_winners, reason = 'forfeit:' || p_loser, ended_at = now()
   where id = p_match and status = 'playing' returning * into m;
  if m.id is null then return jsonb_build_object('ok', false); end if;
  perform _nx_apply_result(m, p_winners, null);
  perform _nx_room_after_match(m.room_id, m.id);
  return jsonb_build_object('ok', true, 'winners', p_winners, 'forfeit', p_loser);
end $function$
;

-- [7] nx_forfeit(p_match uuid, p_seat integer)
CREATE OR REPLACE FUNCTION public.nx_forfeit(p_match uuid, p_seat integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m nx_matches; s int; caller int; n int; gone int[]; alive int[];
begin
  select * into m from nx_matches where id = p_match for update;
  if m.id is null or m.status <> 'playing' then return jsonb_build_object('ok', false, 'reason', 'over'); end if;
  caller := array_position(m.players, me) - 1;
  if caller is null then raise exception 'not a player'; end if;
  n := coalesce(array_length(m.players, 1), 0);
  gone := public._nx_forfeited_seats(p_match);
  s := caller;
  if p_seat is not null and p_seat <> caller then
    -- forfeiting ANOTHER seat: only an active player, only a seat the server also sees as gone
    if p_seat < 0 or p_seat >= n then return jsonb_build_object('ok', false, 'reason', 'bad_seat'); end if;
    if caller = any(gone) then return jsonb_build_object('ok', false, 'reason', 'forfeited'); end if;
    if m.started_at > now() - interval '30 seconds' then
      return jsonb_build_object('ok', false, 'reason', 'too_early');
    end if;
    if exists (select 1 from nx_match_reports r where r.match_id = p_match and r.user_id = m.players[p_seat + 1]) then
      return jsonb_build_object('ok', false, 'reason', 'reported');
    end if;
    if public._nx_player_active(p_match, m.players[p_seat + 1], 25, 30) then
      return jsonb_build_object('ok', false, 'reason', 'active');
    end if;
    s := p_seat;
  end if;
  if s = any(gone) then
    return jsonb_build_object('ok', true, 'seat', s, 'already', true);
  end if;
  insert into nx_match_moves(match_id, seq, seat, by_user, kind, move)
  values (p_match, m.last_seq + 1, s, me, 'forfeit', jsonb_build_object('seat', s));
  update nx_matches set last_seq = m.last_seq + 1 where id = p_match;
  -- lone survivor (any player count): the match ends for everyone
  select coalesce(array_agg(g), '{}'::int[]) into alive
    from generate_series(0, n - 1) g where not (g = any(gone)) and g <> s;
  if coalesce(array_length(alive, 1), 0) = 1 then
    return nx_finish_match_as(p_match, alive, s);
  elsif coalesce(array_length(alive, 1), 0) = 0 then
    update nx_matches set status = 'abandoned', reason = 'abandoned', ended_at = now() where id = p_match;
    perform _nx_room_after_match(m.room_id, m.id);
  end if;
  return jsonb_build_object('ok', true, 'seat', s);
end $function$
;

-- [7] nx_g_hello()
CREATE OR REPLACE FUNCTION public.nx_g_hello()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); url text := _nx_secret('nx_social_url'); key text := _nx_secret('nx_social_service_key'); r profiles;
begin
  if me is null then raise exception 'not signed in'; end if;
  perform set_config('nx.sync', '1', true);
  insert into profiles(id, username) values (me, coalesce(auth.jwt() -> 'user_metadata' ->> 'username', 'Pilot'))
  on conflict (id) do nothing;
  select * into r from profiles where id = me;
  if (r.synced_at is null or r.synced_at < now() - interval '2 minutes') and url is not null then
    perform net.http_post(url := url || '/rest/v1/rpc/nx_bridge_push_profile',
                          headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', key, 'Authorization', 'Bearer ' || key),
                          body := jsonb_build_object('p_user', me), timeout_milliseconds := 8000);
  end if;
  return jsonb_build_object('id', r.id, 'username', r.username, 'xp', r.xp, 'coins', r.coins, 'gems', r.gems, 'level', r.level,
                            'synced_at', r.synced_at);
end $function$
;

-- [7] nx_g_is_muted(u uuid)
CREATE OR REPLACE FUNCTION public.nx_g_is_muted(u uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce((select muted_until > now() from nx_user_mutes where user_id = u), false)
$function$
;

-- [7] nx_g_push(p_match uuid, p_seq integer, p_kind text, p_move json
CREATE OR REPLACE FUNCTION public.nx_g_push(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  m nx_matches;
  caller_seat int;
  seat int;
  n int;
  k text := left(coalesce(p_kind, 'move'), 16);
  t record;
  cur int;
  dl timestamptz;
  nt int;
begin
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then raise exception 'match not found'; end if;
  if m.game not in ('carrom', 'billiards') then raise exception 'nx_g_push is for carrom/billiards'; end if;
  caller_seat := array_position(m.players, me) - 1;
  if caller_seat is null then raise exception 'not a player'; end if;
  if m.status <> 'playing' then
    return jsonb_build_object('ok', false, 'reason', 'over', 'last_seq', m.last_seq);
  end if;
  if p_seq <> m.last_seq + 1 then
    return jsonb_build_object('ok', false, 'reason', 'seq', 'last_seq', m.last_seq);
  end if;
  if p_seat is not null and p_seat <> caller_seat and k not in ('snap', 'timeout', 'system') then
    raise exception 'seat mismatch';
  end if;
  seat := coalesce(p_seat, caller_seat);
  n := greatest(1, coalesce(array_length(m.players, 1), 1));
  select * into t from _nx_g_turn_times(m.game);
  cur := m.turn_seat;
  dl := m.turn_deadline;
  if m.last_seq = 0 then
    if m.game = 'billiards' then cur := (m.seed % 2)::int; end if;
    dl := greatest(dl, m.started_at + interval '60 seconds');
  end if;

  if k = 'move' then
    if seat <> cur then
      return jsonb_build_object('ok', false, 'reason', 'turn', 'turn_seat', cur);
    end if;
    if now() > dl + interval '2 seconds' then
      return jsonb_build_object('ok', false, 'reason', 'timeout', 'turn_seat', cur);
    end if;
    if coalesce(p_move->>'a', '') = 'shot' then
      dl := now() + make_interval(secs => t.sim_s + t.aim_s + 4);
    end if;
  elsif k = 'timeout' then
    if seat <> cur then
      return jsonb_build_object('ok', false, 'reason', 'turn', 'turn_seat', cur);
    end if;
    if now() < dl - interval '5 seconds' then
      return jsonb_build_object('ok', false, 'reason', 'too_early', 'turn_seat', cur);
    end if;
    cur := (cur + 1) % n;
    dl := now() + make_interval(secs => t.aim_s + 4);
  elsif k = 'snap' then
    nt := nullif(p_move->>'nt', '')::int;
    if nt is not null and nt >= 0 and nt < n then
      cur := nt;
      dl := now() + make_interval(secs => t.aim_s + 4);
    end if;
  elsif k not in ('system', 'forfeit') then
    raise exception 'bad kind';
  end if;

  insert into nx_match_moves(match_id, seq, seat, by_user, kind, move, hash)
  values (p_match, p_seq, seat, me, k, coalesce(p_move, '{}'::jsonb), p_hash);
  update nx_matches
     set last_seq = p_seq, state_hash = coalesce(p_hash, state_hash), turn_seat = cur, turn_deadline = dl
   where id = p_match;
  return jsonb_build_object('ok', true, 'seq', p_seq, 'turn_seat', cur);
end;
$function$
;

-- [7] nx_game_bounds(p_game text, OUT min_seats integer, OUT max_seat
CREATE OR REPLACE FUNCTION public.nx_game_bounds(p_game text, OUT min_seats integer, OUT max_seats integer)
 RETURNS record
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select case p_game
           when 'mafia' then 6
           when 'spy_mafia' then 4
           else 2 end,
         case p_game
           when 'finger_soccer' then 6
           when 'mafia' then 12
           when 'spy_mafia' then 8
           when 'ludo' then 4
           when 'snakes_ladders' then 4
           when 'uno' then 4
           when 'kart_racing' then 4
           when 'obstacle_race' then 4
           when 'bomb_arena' then 4
           when 'mini_golf' then 4
           when 'basketball_battle' then 4
           when 'stickman_arena' then 4
           when 'ludo_battle' then 4
           else 2 end
$function$
;

-- [7] nx_gen_code()
CREATE OR REPLACE FUNCTION public.nx_gen_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare c text; alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; i int;
begin
  loop
    c := '';
    for i in 1..6 loop c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1); end loop;
    exit when not exists (select 1 from nx_rooms where code = c);
  end loop;
  return c;
end $function$
;

-- [7] nx_has_perm(p text, u uuid)
CREATE OR REPLACE FUNCTION public.nx_has_perm(p text, u uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u is not null
    and not (u = auth.uid() and coalesce((auth.jwt() -> 'nx_perms') ? 'must_change_password', false))
    and (nx_is_owner(u) or (u = auth.uid() and nx_perm(p))
         or exists (select 1 from nx_staff where user_id = u and (p = any(perms) or 'all' = any(perms))))
$function$
;

-- [7] nx_idle_forfeit(p_match uuid, p_seat integer)
CREATE OR REPLACE FUNCTION public.nx_idle_forfeit(p_match uuid, p_seat integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m public.nx_matches; ts public.nx_match_turn_state;
        caller int; a int; n int; gone int[]; alive int[];
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into m from public.nx_matches where id = p_match for update;
  if m.id is null or m.status <> 'playing' then return jsonb_build_object('ok', false, 'reason', 'over'); end if;
  caller := array_position(m.players, me) - 1;
  if caller is null then raise exception 'not a player'; end if;
  n := coalesce(array_length(m.players, 1), 0);
  if p_seat is null or p_seat < 0 or p_seat >= n then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;
  gone := public._nx_forfeited_seats(p_match);
  if p_seat = any(gone) then return jsonb_build_object('ok', true, 'seat', p_seat, 'already', true); end if;
  if caller = any(gone) then return jsonb_build_object('ok', false, 'reason', 'forfeited'); end if;
  a := public._nx_match_authority(p_match);
  if caller <> a then return jsonb_build_object('ok', false, 'reason', 'not_authority', 'authority', a); end if;
  select * into ts from public.nx_match_turn_state where match_id = p_match for update;
  if ts.match_id is null or ts.seat <> p_seat then
    return jsonb_build_object('ok', false, 'reason', 'not_turn');
  end if;
  if now() < ts.deadline then
    return jsonb_build_object('ok', false, 'reason', 'too_early', 'deadline', ts.deadline);
  end if;
  if exists (select 1 from public.nx_match_reports r
              where r.match_id = p_match and r.user_id = m.players[p_seat + 1]) then
    return jsonb_build_object('ok', false, 'reason', 'reported');
  end if;
  insert into public.nx_match_moves(match_id, seq, seat, by_user, kind, move)
  values (p_match, m.last_seq + 1, p_seat, me, 'forfeit',
          jsonb_build_object('seat', p_seat, 'idle', true));
  update public.nx_matches set last_seq = m.last_seq + 1 where id = p_match;
  select coalesce(array_agg(g), '{}'::int[]) into alive
    from generate_series(0, n - 1) g where not (g = any(gone)) and g <> p_seat;
  if coalesce(array_length(alive, 1), 0) = 1 then
    return public.nx_finish_match_as(p_match, alive, p_seat);
  elsif coalesce(array_length(alive, 1), 0) = 0 then
    update public.nx_matches set status = 'abandoned', reason = 'abandoned', ended_at = now()
     where id = p_match;
    perform public._nx_room_after_match(m.room_id, m.id);
  end if;
  return jsonb_build_object('ok', true, 'seat', p_seat, 'idle', true);
end $function$
;

-- [7] nx_in_match(m uuid)
CREATE OR REPLACE FUNCTION public.nx_in_match(m uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from nx_matches where id = m and auth.uid() = any(players))
$function$
;

-- [7] nx_in_room(r uuid)
CREATE OR REPLACE FUNCTION public.nx_in_room(r uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from nx_room_players where room_id = r and user_id = auth.uid())
$function$
;

-- [7] nx_invite(p_room uuid, p_user uuid)
CREATE OR REPLACE FUNCTION public.nx_invite(p_room uuid, p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); r nx_rooms;
begin
  select * into r from nx_rooms where id = p_room;
  if r.id is null or not nx_in_room(p_room) then raise exception 'not in room'; end if;
  if exists (select 1 from user_blocks where blocker = p_user and blocked = me) then raise exception 'blocked'; end if;
  insert into nx_invites(from_user, to_user, kind, room_id, payload)
  values (me, p_user, 'game', p_room, jsonb_build_object('code', r.code, 'game', r.game,
          'from_name', (select username from profiles where id = me)));
end $function$
;

-- [7] nx_is_owner(u uuid)
CREATE OR REPLACE FUNCTION public.nx_is_owner(u uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u is not null
    and not (u = auth.uid() and coalesce((auth.jwt() -> 'nx_perms') ? 'must_change_password', false))
    and ((u = auth.uid() and nx_perm('owner')) or exists (select 1 from nx_staff where user_id = u and role = 'owner'))
$function$
;

-- [7] nx_is_room_member(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_is_room_member(p_room uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from public.nx_room_members where room_id = p_room and user_id = auth.uid()) $function$
;

-- [7] nx_join_room(p_code text, p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_join_room(p_code text DEFAULT NULL::text, p_room uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare me uuid:=auth.uid(); rid uuid; r nx_rooms; joined jsonb; seat_no int; begin if me is null then raise exception 'not signed in'; end if; if p_room is not null then rid:=p_room; else select id into rid from nx_rooms where code=upper(trim(p_code)); end if; if rid is null then raise exception 'room not found'; end if; select * into r from nx_rooms where id=rid for update; joined:=nx_room_join(rid,'speaker'); seat_no:=nullif(joined->>'seat','')::int; if seat_no is not null and not exists(select 1 from nx_room_players where room_id=rid and user_id=me) then insert into nx_room_players(room_id,user_id,seat,ready) values(rid,me,seat_no,false) on conflict(room_id,user_id) do update set last_seen=now(); end if; update nx_room_members set last_seen=now() where room_id=rid and user_id=me; return jsonb_build_object('room_id',rid,'code',r.code,'seat',seat_no,'role',joined->>'role','status',r.status,'match_id',r.match_id,'rejoined',coalesce((joined->>'rejoined')::boolean,false)); end $function$
;

-- [7] nx_known_game(p_game text)
CREATE OR REPLACE FUNCTION public.nx_known_game(p_game text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select p_game in ('finger_soccer','carrom','billiards','backgammon','ludo','snakes_ladders','uno','quiz','mafia',
                    'kart_racing','obstacle_race','bomb_arena','pool8','mini_golf','basketball_battle','spy_mafia',
                    'stickman_arena','ludo_battle','chess_blitz')
$function$
;

-- [7] nx_leave_room(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_leave_room(p_room uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); r nx_rooms; nh uuid;
begin
  select * into r from nx_rooms where id = p_room for update;
  if r.id is null then return; end if;
  if r.status = 'playing' and r.match_id is not null then
    perform nx_forfeit(r.match_id);
  end if;
  delete from nx_room_players where room_id = p_room and user_id = me;
  if not exists (select 1 from nx_room_players where room_id = p_room) then
    update nx_rooms set status = 'closed', updated_at = now() where id = p_room;
  elsif r.host = me then
    select user_id into nh from nx_room_players where room_id = p_room order by seat limit 1;
    update nx_rooms set host = nh, updated_at = now() where id = p_room;
  end if;
end $function$
;

-- [7] nx_lobby_ping(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_lobby_ping(p_room uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.nx_room_players set last_seen = now() where room_id = p_room and user_id = auth.uid();
  update public.nx_rooms set updated_at = now() where id = p_room and status = 'lobby'
     and exists(select 1 from public.nx_room_players where room_id = p_room and user_id = auth.uid()); $function$
;

-- [7] nx_match_ping(p_match uuid)
CREATE OR REPLACE FUNCTION public.nx_match_ping(p_match uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m nx_matches;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into m from nx_matches where id = p_match;
  if m.id is null then return jsonb_build_object('ok', false, 'reason', 'not_found'); end if;
  if not (me = any(m.players)) then return jsonb_build_object('ok', false, 'reason', 'not_player'); end if;
  if m.status = 'playing' then
    insert into nx_match_presence(match_id, user_id, last_seen) values (p_match, me, now())
    on conflict (match_id, user_id) do update set last_seen = excluded.last_seen;
  end if;
  return jsonb_build_object('ok', true, 'status', m.status, 'last_seq', m.last_seq);
end $function$
;

-- [7] nx_match_turn(p_match uuid, p_seat integer, p_epoch bigint, p_s
CREATE OR REPLACE FUNCTION public.nx_match_turn(p_match uuid, p_seat integer, p_epoch bigint, p_seconds integer DEFAULT 90)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m public.nx_matches; caller int; n int; a int; old public.nx_match_turn_state; secs int;
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into m from public.nx_matches where id = p_match for update;
  if m.id is null or m.status <> 'playing' then return jsonb_build_object('ok', false, 'reason', 'over'); end if;
  caller := array_position(m.players, me) - 1;
  if caller is null then raise exception 'not a player'; end if;
  n := coalesce(array_length(m.players, 1), 0);
  if p_seat is null or p_seat < 0 or p_seat >= n then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;
  if p_seat = any(public._nx_forfeited_seats(p_match)) then
    return jsonb_build_object('ok', false, 'reason', 'forfeited');
  end if;
  a := public._nx_match_authority(p_match);
  if caller <> a then return jsonb_build_object('ok', false, 'reason', 'not_authority', 'authority', a); end if;
  secs := greatest(30, least(coalesce(p_seconds, 90), 300));
  select * into old from public.nx_match_turn_state where match_id = p_match for update;
  if old.match_id is not null and old.authority_user = me and coalesce(p_epoch, 0) <= old.epoch then
    return jsonb_build_object('ok', true, 'unchanged', true, 'seat', old.seat,
                              'deadline', old.deadline, 'epoch', old.epoch);
  end if;
  insert into public.nx_match_turn_state(match_id, authority_user, epoch, seat, deadline, updated_at)
  values (p_match, me, greatest(0, coalesce(p_epoch, 0)), p_seat,
          now() + make_interval(secs => secs), now())
  on conflict (match_id) do update set
    authority_user = excluded.authority_user,
    epoch = excluded.epoch,
    seat = excluded.seat,
    deadline = excluded.deadline,
    updated_at = excluded.updated_at;
  update public.nx_matches set turn_seat = p_seat,
         turn_deadline = now() + make_interval(secs => secs)
   where id = p_match;
  return jsonb_build_object('ok', true, 'seat', p_seat, 'epoch', greatest(0, coalesce(p_epoch, 0)),
                            'deadline', now() + make_interval(secs => secs));
end $function$
;

-- [7] nx_mirror_put(p_rows jsonb)
CREATE OR REPLACE FUNCTION public.nx_mirror_put(p_rows jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare e jsonb; n int := 0; pend boolean;
begin
  perform set_config('nx.sync', '1', true);
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    select exists (select 1 from nx_wallet_tx where user_id = (e ->> 'id')::uuid and acked_at is null) into pend;
    insert into profiles(id, username, avatar, xp, level, coins, gems, role, synced_at)
    values ((e ->> 'id')::uuid, e ->> 'username', e ->> 'avatar', coalesce((e ->> 'xp')::int, 0), coalesce((e ->> 'level')::int, 1),
            coalesce((e ->> 'coins')::int, 0), coalesce((e ->> 'gems')::int, 0), e ->> 'role', now())
    on conflict (id) do update set
      username = excluded.username, avatar = excluded.avatar, role = excluded.role, synced_at = now(),
      xp = case when pend then profiles.xp else excluded.xp end,
      level = case when pend then profiles.level else excluded.level end,
      coins = case when pend then profiles.coins else excluded.coins end,
      gems = case when pend then profiles.gems else excluded.gems end;
    n := n + 1;
  end loop;
  return n;
end $function$
;

-- [7] nx_my_active_match()
CREATE OR REPLACE FUNCTION public.nx_my_active_match()
 RETURNS TABLE(match_id uuid, game text, room_id uuid, started_at timestamp with time zone, seats integer, tournament boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.id, m.game, m.room_id, m.started_at, array_length(m.players, 1),
         (m.settings ? 'tmatch')
    from nx_matches m
   where m.status = 'playing' and auth.uid() = any(m.players)
     and m.started_at > now() - interval '3 hours'
     and not exists (select 1 from nx_match_moves x
                      where x.match_id = m.id and x.kind = 'forfeit'
                        and (x.move->>'seat')::int = array_position(m.players, auth.uid()) - 1)
   order by m.started_at desc
   limit 1;
$function$
;

-- [7] nx_owner_tournaments(p_limit integer)
CREATE OR REPLACE FUNCTION public.nx_owner_tournaments(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g text := _nx_owner_guard(); res jsonb;
begin
  if g is not null then return jsonb_build_object('ok', false, 'error', g); end if;
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]'::jsonb) into res from (
    select t.id, t.title, t.game, t.format, t.status, t.capacity, t.start_at, t.created_at, t.created_by, p.username as creator,
           (select count(*) from nx_t_entries e where e.tournament_id = t.id and e.status = 'approved') as players,
           (select count(*) from nx_t_matches m where m.tournament_id = t.id and m.status = 'disputed') as disputes,
           t.fee_coins, t.fee_gems, t.prize
      from nx_tournaments t left join profiles p on p.id = t.created_by
     order by t.created_at desc limit greatest(1, least(coalesce(p_limit, 100), 500))) x;
  return jsonb_build_object('ok', true, 'tournaments', res);
end $function$
;

-- [7] nx_perm(p text)
CREATE OR REPLACE FUNCTION public.nx_perm(p text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  select coalesce((auth.jwt() -> 'nx_perms') ? 'owner' or (auth.jwt() -> 'nx_perms') ? p, false)
$function$
;

-- [7] nx_push_move(p_match uuid, p_seq integer, p_kind text, p_move j
CREATE OR REPLACE FUNCTION public.nx_push_move(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid();
  m nx_matches;
  caller_seat int;
  effective_seat int;
  n int;
  k text := left(coalesce(p_kind, 'move'), 16);
  vk text;           -- the real kind (app wraps 'move' / 'timeout' as 'system' with move->>'_k')
  gone int[];
  alive int[];
begin
  if me is null then raise exception 'not signed in'; end if;
  select * into m from nx_matches where id = p_match for update;
  if m.id is null then raise exception 'match not found'; end if;
  caller_seat := array_position(m.players, me) - 1;
  if caller_seat is null then raise exception 'not a player'; end if;
  if m.status <> 'playing' then
    return jsonb_build_object('ok', false, 'reason', 'over', 'last_seq', m.last_seq);
  end if;
  if p_seq <> m.last_seq + 1 then
    return jsonb_build_object('ok', false, 'reason', 'seq', 'last_seq', m.last_seq);
  end if;
  if pg_column_size(coalesce(p_move, '{}'::jsonb)) > 16000 then
    return jsonb_build_object('ok', false, 'reason', 'too_large');
  end if;
  n := coalesce(array_length(m.players, 1), 0);
  if p_seat is not null and (p_seat < 0 or p_seat >= n) then
    return jsonb_build_object('ok', false, 'reason', 'bad_seat');
  end if;
  effective_seat := coalesce(p_seat, caller_seat);
  vk := case when k = 'system' and jsonb_typeof(p_move) = 'object' and (p_move ? '_k')
             then left(p_move ->> '_k', 16) else k end;

  gone := public._nx_forfeited_seats(p_match);
  if caller_seat = any(gone) and vk <> 'forfeit' then
    return jsonb_build_object('ok', false, 'reason', 'forfeited', 'last_seq', m.last_seq);
  end if;
  -- seat ownership: gameplay moves and forfeits only for the caller's own seat; the authority may post a snapshot,
  -- a timeout or a genuine system row (pre-match default for an absent side) for another seat
  if effective_seat <> caller_seat and vk not in ('snap', 'timeout', 'system') then
    return jsonb_build_object('ok', false, 'reason', 'seat', 'last_seq', m.last_seq);
  end if;
  if vk = 'forfeit' and effective_seat = any(gone) then
    return jsonb_build_object('ok', false, 'reason', 'forfeited', 'last_seq', m.last_seq);
  end if;

  insert into nx_match_moves(match_id, seq, seat, by_user, kind, move, hash)
  values (p_match, p_seq, effective_seat, me, k,
          case when k = 'forfeit' then coalesce(p_move, '{}'::jsonb) || jsonb_build_object('seat', effective_seat)
               else coalesce(p_move, '{}'::jsonb) end,
          p_hash);

  update nx_matches
     set last_seq = p_seq,
         state_hash = coalesce(p_hash, state_hash),
         turn_seat = effective_seat,
         turn_deadline = now() + interval '45 seconds'
   where id = p_match;

  -- a player who left through the move log: when one seat is left the match ends for everyone
  if k = 'forfeit' then
    select coalesce(array_agg(g), '{}'::int[]) into alive
      from generate_series(0, n - 1) g where not (g = any(gone)) and g <> effective_seat;
    if coalesce(array_length(alive, 1), 0) = 1 then
      perform nx_finish_match_as(p_match, alive, effective_seat);
    end if;
  end if;
  return jsonb_build_object('ok', true, 'seq', p_seq);
end;
$function$
;

-- [7] nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data js
CREATE OR REPLACE FUNCTION public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m nx_matches;
begin
  select * into m from nx_matches where id = p_match;
  if m.id is null or m.players[1] <> auth.uid() then raise exception 'authority only'; end if;
  if not (p_user = any(m.players)) then raise exception 'not a player'; end if;
  insert into nx_match_secrets(match_id, user_id, slot, data) values (p_match, p_user, p_slot, p_data)
  on conflict (match_id, user_id, slot) do update set data = excluded.data, created_at = now();
end $function$
;

-- [7] nx_quick(p_game text, p_seats integer)
CREATE OR REPLACE FUNCTION public.nx_quick(p_game text, p_seats integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); rid uuid; res jsonb; n int; r nx_rooms; mine nx_rooms; s int;
begin
  if me is null then raise exception 'not signed in'; end if;
  if not public.nx_known_game(p_game) then raise exception 'unknown game'; end if;
  s := public._nx_quick_seats(p_game, p_seats);
  perform public._nx_quick_lock(p_game, s);

  -- drop silent seats from this bucket's waiting lobbies, close empty / stale ones
  delete from nx_room_game_players gp using nx_rooms x, nx_room_players rp
   where x.id = gp.room_id and rp.room_id = x.id and rp.user_id = gp.user_id
     and x.quick and x.status = 'lobby' and x.game = p_game and x.seats = s
     and rp.user_id <> me and rp.last_seen < now() - interval '45 seconds';
  delete from nx_room_players rp using nx_rooms x
   where x.id = rp.room_id and x.quick and x.status = 'lobby' and x.game = p_game and x.seats = s
     and rp.user_id <> me and rp.last_seen < now() - interval '45 seconds';
  delete from nx_room_members m using nx_rooms x
   where x.id = m.room_id and x.quick and x.status = 'lobby' and x.game = p_game and x.seats = s
     and not exists(select 1 from nx_room_players rp where rp.room_id = x.id and rp.user_id = m.user_id);
  update nx_rooms x set status = 'closed', updated_at = now()
   where x.status = 'lobby' and x.quick and x.game = p_game and x.seats = s
     and (x.updated_at < now() - interval '10 minutes' or not exists(select 1 from nx_room_players rp where rp.room_id = x.id));

  -- already waiting in this bucket? keep that lobby (reconnect / double tap / heartbeat)
  select x.* into mine from nx_rooms x join nx_room_players rp on rp.room_id = x.id and rp.user_id = me
   where x.quick and x.status = 'lobby' and x.game = p_game and x.seats = s
   order by x.created_at limit 1;
  if mine.id is not null then
    update nx_room_players set last_seen = now() where room_id = mine.id and user_id = me;
    update nx_rooms set updated_at = now() where id = mine.id;
    select count(*) into n from nx_room_players where room_id = mine.id;
    if n >= mine.seats then
      return jsonb_build_object('room_id', mine.id, 'code', mine.code, 'seats', mine.seats, 'rejoined', true)
             || nx_start_match_quick(mine.id);
    end if;
  end if;

  -- an OLDER open lobby of the same bucket (a waiting player only ever moves into an older lobby, so two waiting
  -- players never swap into each other's lobby)
  select x.id into rid from nx_rooms x
   where x.game = p_game and x.status = 'lobby' and x.quick and not x.is_private and x.seats = s
     and (mine.id is null or (x.id <> mine.id and x.created_at < mine.created_at))
     and not exists (select 1 from nx_room_players rp where rp.room_id = x.id and rp.user_id = me)
     and (select count(*) from nx_room_players rp where rp.room_id = x.id) < x.seats
   order by x.created_at limit 1 for update;
  if rid is null then
    if mine.id is not null then
      return jsonb_build_object('room_id', mine.id, 'code', mine.code, 'seats', mine.seats, 'rejoined', true);
    end if;
    res := nx_create_room(p_game, s, false, true, '{}'::jsonb);
    return res || jsonb_build_object('created', true);
  end if;

  res := nx_join_room(null, rid);           -- leaves every other lobby first (_nx_leave_all, lobby-only)
  update nx_room_players set last_seen = now() where room_id = rid and user_id = me;
  select * into r from nx_rooms where id = rid;
  select count(*) into n from nx_room_players where room_id = rid;
  if n >= r.seats then
    res := res || nx_start_match_quick(rid);
  end if;
  return res || jsonb_build_object('seats', r.seats, 'moved', mine.id is not null);
end $function$
;

-- [7] nx_quick_cancel(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_quick_cancel(p_room uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); r nx_rooms; m nx_matches;
begin
  if me is null then return; end if;
  select * into r from nx_rooms where id = p_room;
  if r.id is null or not r.quick then return; end if;
  perform public._nx_quick_lock(r.game, r.seats);
  select * into r from nx_rooms where id = p_room for update;
  if r.status = 'lobby' then
    delete from nx_room_game_players where room_id = p_room and user_id = me;
    delete from nx_room_players where room_id = p_room and user_id = me;
    delete from nx_room_members where room_id = p_room and user_id = me;
    if not exists(select 1 from nx_room_players rp where rp.room_id = p_room) then
      update nx_rooms set status = 'closed', updated_at = now() where id = p_room;
    elsif r.host = me then
      update nx_rooms set host = (select user_id from nx_room_players where room_id = p_room order by seat limit 1),
                          updated_at = now()
       where id = p_room;
    end if;
  elsif r.status = 'playing' and r.match_id is not null then
    -- the lobby filled in the same instant this player backed out: abandon the brand-new match (no rewards) so the
    -- others go back to matchmaking instead of waiting for an absence forfeit
    select * into m from nx_matches where id = r.match_id for update;
    if m.id is not null and m.status = 'playing' and me = any(m.players)
       and m.started_at > now() - interval '20 seconds'
       and not exists (select 1 from nx_match_moves mv where mv.match_id = m.id and mv.by_user = me) then
      update nx_matches set status = 'abandoned', winner_seats = null, reason = 'abandoned', ended_at = now()
       where id = m.id;
      update nx_rooms set status = 'closed', updated_at = now() where id = r.id;
    end if;
  end if;
end $function$
;

-- [7] nx_quiz_answer(p_match uuid, p_round integer, p_choice integer)
CREATE OR REPLACE FUNCTION public.nx_quiz_answer(p_match uuid, p_round integer, p_choice integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid(); m nx_matches; g nx_quiz_games; v_seat int; c record; q nx_quiz_questions;
  e int; ok boolean; pts int; n int;
begin
  select * into c from _nx_quiz_const();
  select * into m from nx_matches where id = p_match;
  if m.id is null or m.game <> 'quiz' then raise exception 'not a quiz match'; end if;
  v_seat := array_position(m.players, me) - 1;
  if v_seat is null then raise exception 'not a player'; end if;
  if v_seat = any(_nx_forfeited_seats(p_match)) then return jsonb_build_object('ok', false, 'reason', 'left'); end if;
  if p_choice is null or p_choice < 0 or p_choice > 3 then return jsonb_build_object('ok', false, 'reason', 'choice'); end if;
  select * into g from nx_quiz_games where match_id = p_match;
  if g.match_id is null or g.phase <> 'question' or g.round_idx <> p_round then
    return jsonb_build_object('ok', false, 'reason', 'round');
  end if;
  if now() < g.phase_started then return jsonb_build_object('ok', false, 'reason', 'early'); end if;
  if now() > g.phase_ends then return jsonb_build_object('ok', false, 'reason', 'late'); end if;
  select * into q from nx_quiz_questions where id = g.qids[g.round_idx + 1];
  e := least(c.q_ms, greatest(0, (extract(epoch from (now() - g.phase_started)) * 1000)::int));
  ok := p_choice = q.correct and e < c.q_ms;
  pts := case when ok then 100 + round(50.0 * (c.q_ms - e) / c.q_ms)::int else 0 end;
  insert into nx_quiz_answers(match_id, round, seat, user_id, choice, elapsed_ms, correct, points)
  values (p_match, p_round, v_seat, me, p_choice, e, ok, pts)
  on conflict do nothing;
  get diagnostics n = row_count;
  if n = 0 then return jsonb_build_object('ok', false, 'reason', 'already'); end if;
  perform _nx_quiz_tick(p_match);
  return jsonb_build_object('ok', true, 'round', p_round);
end $function$
;

-- [7] nx_quiz_start(p_match uuid, p_category text)
CREATE OR REPLACE FUNCTION public.nx_quiz_start(p_match uuid, p_category text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid(); m nx_matches; g nx_quiz_games; v_seat int; cat text; c record; ids text[]; need int;
begin
  select * into c from _nx_quiz_const();
  select * into m from nx_matches where id = p_match;
  if m.id is null or m.game <> 'quiz' then raise exception 'not a quiz match'; end if;
  v_seat := array_position(m.players, me) - 1;
  if v_seat is null then raise exception 'not a player'; end if;
  if m.status <> 'playing' then return nx_quiz_state(p_match); end if;
  insert into nx_quiz_games(match_id) values (p_match) on conflict do nothing;
  select * into g from nx_quiz_games where match_id = p_match for update;
  if g.phase <> 'pick' then return nx_quiz_state(p_match); end if;
  if v_seat <> 0 and now() < m.started_at + make_interval(secs => c.pick_s) then
    raise exception 'the host picks the category';
  end if;
  cat := nullif(nullif(lower(coalesce(p_category, '')), ''), 'mixed');
  if cat is not null and not exists (select 1 from nx_quiz_questions where category = cat and active) then cat := null; end if;
  need := g.rounds;
  -- least-seen first (by anyone in this match), then random; fill from other categories if needed
  ids := array(
    select q.id from nx_quiz_questions q
     where q.active
     order by (case when cat is null or q.category = cat then 0 else 1 end),
              (select count(*) from nx_quiz_seen s where s.question_id = q.id and s.user_id = any(m.players)),
              random()
     limit need);
  insert into nx_quiz_seen(user_id, question_id)
  select u, qid from unnest(m.players) u cross join unnest(ids) qid
  on conflict (user_id, question_id) do update set seen_at = now();
  update nx_quiz_games set category = cat, qids = ids, round_idx = 0, phase = 'question',
         phase_started = now() + make_interval(secs => c.lead_ms / 1000.0),
         phase_ends = now() + make_interval(secs => (c.lead_ms + c.q_ms + c.grace_ms) / 1000.0)
   where match_id = p_match;
  return nx_quiz_state(p_match);
end $function$
;

-- [7] nx_quiz_state(p_match uuid)
CREATE OR REPLACE FUNCTION public.nx_quiz_state(p_match uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  me uuid := auth.uid(); m nx_matches; g nx_quiz_games; v_seat int; c record; q nx_quiz_questions;
  n int; active int[]; due boolean := false; res jsonb; answered int[]; mine jsonb; reveal jsonb;
  sc int[]; cc int[];
begin
  select * into c from _nx_quiz_const();
  select * into m from nx_matches where id = p_match;
  if m.id is null or m.game <> 'quiz' then raise exception 'not a quiz match'; end if;
  v_seat := array_position(m.players, me) - 1;
  if v_seat is null then raise exception 'not a player'; end if;
  insert into nx_quiz_games(match_id) values (p_match) on conflict do nothing;
  select * into g from nx_quiz_games where match_id = p_match;
  n := array_length(m.players, 1);
  active := array(select x from generate_series(0, n - 1) x where not (x = any(_nx_forfeited_seats(p_match))));
  if g.phase in ('question', 'reveal') and now() >= g.phase_ends then due := true; end if;
  if g.phase = 'question' and not due then
    due := (select count(*) from nx_quiz_answers a where a.match_id = p_match and a.round = g.round_idx and a.seat = any(active))
           >= coalesce(array_length(active, 1), 0);
  end if;
  if (g.phase <> 'done' and m.status <> 'playing') then due := true; end if;
  if due then
    perform _nx_quiz_tick(p_match);
    select * into g from nx_quiz_games where match_id = p_match;
    select * into m from nx_matches where id = p_match;
  end if;
  sc := array(select coalesce((select sum(points) from nx_quiz_answers a where a.match_id = p_match and a.seat = x
                                  and (a.round < g.round_idx or g.phase in ('reveal', 'done'))), 0)::int
                from generate_series(0, n - 1) x order by x);
  cc := array(select (select count(*) from nx_quiz_answers a where a.match_id = p_match and a.seat = x and a.correct
                         and (a.round < g.round_idx or g.phase in ('reveal', 'done')))::int
                from generate_series(0, n - 1) x order by x);
  res := jsonb_build_object(
    'phase', g.phase, 'round', g.round_idx, 'rounds', coalesce(array_length(g.qids, 1), g.rounds),
    'category', coalesce(g.category, 'mixed'), 'seat', v_seat, 'players', n,
    'names', to_jsonb(m.names), 'active', to_jsonb(active),
    'scores', to_jsonb(sc), 'correct_counts', to_jsonb(cc),
    'starts_in_ms', greatest(0, (extract(epoch from (g.phase_started - now())) * 1000)::int),
    'ends_in_ms', case when g.phase_ends is null then null
                       else greatest(0, (extract(epoch from (g.phase_ends - now())) * 1000)::int) end,
    'elapsed_ms', greatest(0, (extract(epoch from (now() - g.phase_started)) * 1000)::int),
    'time_limit_ms', c.q_ms, 'status', m.status, 'winners', to_jsonb(coalesce(g.winners, m.winner_seats)),
    'pick_wait_ms', greatest(0, (extract(epoch from (m.started_at + make_interval(secs => c.pick_s) - now())) * 1000)::int));
  if g.phase in ('question', 'reveal') and g.round_idx >= 0 then
    select * into q from nx_quiz_questions where id = g.qids[g.round_idx + 1];
    res := res || jsonb_build_object('question', jsonb_build_object(
      'id', q.id, 'category', q.category, 'difficulty', q.difficulty, 'fa', q.fa, 'en', q.en,
      'options_fa', q.options_fa, 'options_en', q.options_en));
    answered := array(select a.seat from nx_quiz_answers a where a.match_id = p_match and a.round = g.round_idx order by a.seat);
    res := res || jsonb_build_object('answered', to_jsonb(answered));
    select jsonb_build_object('choice', a.choice, 'ms', a.elapsed_ms) into mine
      from nx_quiz_answers a where a.match_id = p_match and a.round = g.round_idx and a.seat = v_seat;
    res := res || jsonb_build_object('mine', mine);
    if g.phase = 'reveal' then
      select jsonb_agg(jsonb_build_object('seat', a.seat, 'choice', a.choice, 'correct', a.correct,
                                          'points', a.points, 'ms', a.elapsed_ms) order by a.seat)
        into reveal from nx_quiz_answers a where a.match_id = p_match and a.round = g.round_idx;
      res := res || jsonb_build_object('correct', q.correct, 'answers', coalesce(reveal, '[]'::jsonb));
    end if;
  end if;
  return res;
end $function$
;

-- [7] nx_room_capacity(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_room_capacity(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms; b record; sel int; aud int; role_v text; g text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into r from public.nx_rooms where id = p_room;
  if r.id is null then raise exception 'room not found'; end if;
  if r.is_private and r.host <> auth.uid() and not public.nx_in_room(r.id) and not public.nx_is_room_member(r.id) then
    raise exception 'room not visible';
  end if;
  g := coalesce(r.selected_game, r.game);
  select * into b from public.nx_game_bounds(g);
  sel := public._nx_room_selected(p_room);
  aud := public._nx_room_audience(p_room);
  role_v := public.nx_room_member_role(p_room);
  return jsonb_build_object(
    'room_id', r.id, 'kind', r.kind, 'game', g, 'status', r.status,
    'min_players', greatest(2, b.min_seats), 'max_players', b.max_seats,
    'capacity', greatest(b.min_seats, least(coalesce(r.seats, b.max_seats), b.max_seats)),
    'selected', sel, 'audience', aud, 'locked', coalesce(r.join_locked, false),
    'is_manager', public._nx_room_can_manage(p_room), 'role', role_v);
end $function$
;

-- [7] nx_room_change_game(p_room uuid, p_game text)
CREATE OR REPLACE FUNCTION public.nx_room_change_game(p_room uuid, p_game text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms; b record;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  if not public.nx_known_game(p_game) then raise exception 'unknown game'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if r.status <> 'lobby' then raise exception 'room already started'; end if;
  select * into b from public.nx_game_bounds(p_game);
  update public.nx_rooms
     set game = p_game, selected_game = p_game, selected_seats = '{}',
         seats = greatest(b.min_seats, least(coalesce(r.seats, b.max_seats), b.max_seats)),
         updated_at = now()
   where id = p_room;
  delete from public.nx_room_game_players where room_id = p_room;
end $function$
;

-- [7] nx_room_close(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_room_close(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  if r.status = 'playing' then raise exception 'a match is running'; end if;
  update public.nx_rooms set status = 'closed', updated_at = now() where id = p_room;
  return jsonb_build_object('room_id', p_room, 'status', 'closed');
end $function$
;

-- [7] nx_room_join(p_room uuid, p_role text)
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
  select count(*) filter (where role in ('manager','speaker')), count(*) filter (where role = 'spectator')
    into speakers, spectators from public.nx_room_members where room_id = p_room;
  if p_role = 'spectator' and (r.spectator_capacity is null or spectators < r.spectator_capacity) then role_to_use := 'spectator';
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
end $function$
;

-- [7] nx_room_kick(p_room uuid, p_user uuid)
CREATE OR REPLACE FUNCTION public.nx_room_kick(p_room uuid, p_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_user is null or p_user = auth.uid() then raise exception 'cannot remove yourself'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  if r.status = 'playing' then raise exception 'room already started'; end if;
  if exists (select 1 from public.nx_room_members where room_id = p_room and user_id = p_user and role = 'manager') then
    raise exception 'cannot remove the manager';
  end if;
  delete from public.nx_room_game_players where room_id = p_room and user_id = p_user;
  delete from public.nx_room_players where room_id = p_room and user_id = p_user;
  delete from public.nx_room_members where room_id = p_room and user_id = p_user;
  update public.nx_rooms set selected_seats = coalesce(
      (select array_agg(seat order by seat) from public.nx_room_game_players where room_id = p_room), '{}'),
    updated_at = now() where id = p_room;
  return public.nx_room_capacity(p_room);
end $function$
;

-- [7] nx_room_leave(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_room_leave(p_room uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); was text; nxt uuid; r public.nx_rooms;
begin
  select role into was from public.nx_room_members where room_id = p_room and user_id = me;
  delete from public.nx_room_game_players where room_id = p_room and user_id = me and
    not exists(select 1 from public.nx_rooms where id = p_room and status = 'playing');
  delete from public.nx_room_players where room_id = p_room and user_id = me;
  delete from public.nx_room_members where room_id = p_room and user_id = me;
  select * into r from public.nx_rooms where id = p_room;
  if was = 'manager' then
    select user_id into nxt from public.nx_room_members where room_id = p_room order by joined_at limit 1;
    if nxt is not null then
      update public.nx_room_members set role = 'manager' where room_id = p_room and user_id = nxt;
      update public.nx_rooms set host = nxt where id = p_room;
    end if;
  end if;
  if r.kind = 'talk' and not exists(select 1 from public.nx_room_members where room_id = p_room) then
    update public.nx_rooms set status = 'closed', updated_at = now() where id = p_room;
  else
    update public.nx_rooms set updated_at = now() where id = p_room;
  end if;
end $function$
;

-- [7] nx_room_member_role(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_room_member_role(p_room uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select role from public.nx_room_members where room_id=p_room and user_id=auth.uid() $function$
;

-- [7] nx_room_open(p_title text, p_private boolean, p_game text)
CREATE OR REPLACE FUNCTION public.nx_room_open(p_title text DEFAULT NULL::text, p_private boolean DEFAULT false, p_game text DEFAULT 'finger_soccer'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); rid uuid; c text; g text := coalesce(nullif(p_game, ''), 'finger_soccer');
begin
  if me is null then raise exception 'not signed in'; end if;
  if not public.nx_known_game(g) then raise exception 'unknown game'; end if;
  insert into public.profiles(id, username) values (me, coalesce(auth.jwt() -> 'user_metadata' ->> 'username', 'Pilot'))
    on conflict (id) do nothing;
  c := public.nx_gen_code();
  insert into public.nx_rooms(code, game, host, seats, is_private, quick, settings, selected_game, title, kind,
                              speaker_capacity, spectator_capacity)
  values (c, g, me, greatest(2, (public.nx_game_bounds(g)).max_seats), coalesce(p_private, false), false, '{}'::jsonb, g,
          nullif(left(btrim(coalesce(p_title, '')), 60), ''), 'talk', null, null)
  returning id into rid;
  insert into public.nx_room_members(room_id, user_id, role) values (rid, me, 'manager');
  return jsonb_build_object('room_id', rid, 'code', c);
end $function$
;

-- [7] nx_room_ping(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_room_ping(p_room uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update public.nx_room_members set last_seen = now() where room_id = p_room and user_id = auth.uid() $function$
;

-- [7] nx_room_select_players(p_room uuid, p_users uuid[])
CREATE OR REPLACE FUNCTION public.nx_room_select_players(p_room uuid, p_users uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare i int := 0; uid uuid; g public.nx_rooms; lim int; users uuid[]; ndist int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  select * into g from public.nx_rooms where id = p_room for update;
  if g.id is null then raise exception 'room not found'; end if;
  if g.status <> 'lobby' then raise exception 'room already started'; end if;
  users := coalesce(p_users, '{}');
  select count(distinct x) into ndist from unnest(users) x;
  if cardinality(users) <> coalesce(ndist, 0) then raise exception 'duplicate players'; end if;
  lim := least(coalesce(g.seats, public._nx_room_seat_limit(coalesce(g.selected_game, g.game))),
               public._nx_room_seat_limit(coalesce(g.selected_game, g.game)));
  if cardinality(users) > lim then raise exception 'this room takes at most % players', lim; end if;
  if exists(select 1 from unnest(users) u
            where not exists(select 1 from public.nx_room_members m where m.room_id = p_room and m.user_id = u)) then
    raise exception 'all players must be room members';
  end if;
  delete from public.nx_room_game_players where room_id = p_room;
  foreach uid in array users loop
    insert into public.nx_room_game_players(room_id, user_id, seat, team) values (p_room, uid, i, i % 2);
    i := i + 1;
  end loop;
  update public.nx_rooms set selected_seats = coalesce((select array_agg(seat order by seat) from public.nx_room_game_players where room_id = p_room), '{}'),
         updated_at = now() where id = p_room;
  return jsonb_build_object('selected', i, 'capacity', lim);
end $function$
;

-- [7] nx_room_send_message(p_room uuid, p_text text)
CREATE OR REPLACE FUNCTION public.nx_room_send_message(p_room uuid, p_text text)
 RETURNS nx_room_messages
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); out_msg public.nx_room_messages;
begin
  if me is null or public.nx_room_member_role(p_room) is null then raise exception 'not a room member'; end if;
  if public.nx_g_is_muted(me) then raise exception 'muted'; end if;
  insert into public.nx_room_messages(room_id, author, text) values (p_room, me, btrim(p_text)) returning * into out_msg;
  update public.nx_room_members set last_seen = now() where room_id = p_room and user_id = me;
  update public.nx_rooms set updated_at = now() where id = p_room;
  return out_msg;
end $function$
;

-- [7] nx_room_set_capacity(p_room uuid, p_capacity integer)
CREATE OR REPLACE FUNCTION public.nx_room_set_capacity(p_room uuid, p_capacity integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms; b record; sel int; g text; cap int := p_capacity;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  if r.status = 'playing' then raise exception 'room already started'; end if;
  g := coalesce(r.selected_game, r.game);
  select * into b from public.nx_game_bounds(g);
  if cap is null then raise exception 'capacity required'; end if;
  if cap < b.min_seats then raise exception 'this game needs at least % players', b.min_seats; end if;
  if cap > b.max_seats then raise exception 'this game takes at most % players', b.max_seats; end if;
  if g = 'finger_soccer' and cap % 2 <> 0 then raise exception 'team games need two equal sides'; end if;
  sel := public._nx_room_selected(p_room);
  if cap < sel then raise exception '% players are already picked (remove players first)', sel; end if;
  update public.nx_rooms set seats = cap, updated_at = now() where id = p_room;
  return public.nx_room_capacity(p_room);
end $function$
;

-- [7] nx_room_set_locked(p_room uuid, p_locked boolean)
CREATE OR REPLACE FUNCTION public.nx_room_set_locked(p_room uuid, p_locked boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  update public.nx_rooms set join_locked = coalesce(p_locked, false), updated_at = now() where id = p_room;
  return public.nx_room_capacity(p_room);
end $function$
;

-- [7] nx_room_set_muted(p_room uuid, p_user uuid, p_muted boolean)
CREATE OR REPLACE FUNCTION public.nx_room_set_muted(p_room uuid, p_user uuid, p_muted boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_user = auth.uid() then raise exception 'use your own mic control'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  if not exists (select 1 from public.nx_room_members m where m.room_id = p_room and m.user_id = p_user) then
    raise exception 'member not found';
  end if;
  update public.nx_room_members set muted = coalesce(p_muted, false) where room_id = p_room and user_id = p_user;
end $function$
;

-- [7] nx_room_set_prefs(p_room uuid, p_prefs jsonb)
CREATE OR REPLACE FUNCTION public.nx_room_set_prefs(p_room uuid, p_prefs jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if pg_column_size(coalesce(p_prefs, '{}'::jsonb)) > 2000 then raise exception 'prefs too large'; end if;
  update public.nx_room_game_players set prefs = coalesce(p_prefs, '{}'::jsonb), ready = true
   where room_id = p_room and user_id = auth.uid();
  if not found then raise exception 'not selected'; end if;
  update public.nx_rooms set updated_at = now() where id = p_room;
end $function$
;

-- [7] nx_room_set_role(p_room uuid, p_user uuid, p_role text)
CREATE OR REPLACE FUNCTION public.nx_room_set_role(p_room uuid, p_user uuid, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_role not in ('speaker','spectator') then raise exception 'bad role'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  select * into r from public.nx_rooms where id = p_room;
  if r.id is null then raise exception 'room not found'; end if;
  if exists (select 1 from public.nx_room_members m where m.room_id = p_room and m.user_id = p_user and m.role = 'manager') then
    raise exception 'cannot change the manager role';
  end if;
  update public.nx_room_members set role = p_role, last_seen = now()
   where room_id = p_room and user_id = p_user;
  if not found then raise exception 'member not found'; end if;
end $function$
;

-- [7] nx_room_set_settings(p_room uuid, p_settings jsonb)
CREATE OR REPLACE FUNCTION public.nx_room_set_settings(p_room uuid, p_settings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if public.nx_room_member_role(p_room) is distinct from 'manager' then raise exception 'manager only'; end if;
  if pg_column_size(coalesce(p_settings, '{}'::jsonb)) > 4000 then raise exception 'settings too large'; end if;
  update public.nx_rooms set settings = settings || coalesce(p_settings, '{}'::jsonb), updated_at = now()
   where id = p_room and status = 'lobby';
end $function$
;

-- [7] nx_room_transfer_host(p_room uuid, p_user uuid)
CREATE OR REPLACE FUNCTION public.nx_room_transfer_host(p_room uuid, p_user uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms; was uuid := auth.uid();
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if p_user is null or p_user = was then raise exception 'pick another member'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  if not exists (select 1 from public.nx_room_members m where m.room_id = p_room and m.user_id = p_user) then
    raise exception 'member not found';
  end if;
  update public.nx_room_members set role = 'manager' where room_id = p_room and user_id = p_user;
  update public.nx_room_members set role = 'speaker' where room_id = p_room and user_id = was and role = 'manager';
  update public.nx_rooms set host = p_user, updated_at = now() where id = p_room;
  return jsonb_build_object('room_id', p_room, 'host', p_user, 'is_manager', false);
end $function$
;

-- [7] nx_set_ready(p_room uuid, p_ready boolean)
CREATE OR REPLACE FUNCTION public.nx_set_ready(p_room uuid, p_ready boolean)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update nx_room_players set ready = p_ready, last_seen = now() where room_id = p_room and user_id = auth.uid();
  update nx_rooms set updated_at = now() where id = p_room;
$function$
;

-- [7] nx_staff_put(p_rows jsonb, p_replace boolean)
CREATE OR REPLACE FUNCTION public.nx_staff_put(p_rows jsonb, p_replace boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare e jsonb; n int := 0;
begin
  if p_replace then delete from nx_staff where user_id not in
    (select (x ->> 'user_id')::uuid from jsonb_array_elements(coalesce(p_rows, '[]')) x); end if;
  for e in select * from jsonb_array_elements(coalesce(p_rows, '[]'::jsonb)) loop
    if coalesce(e ->> 'deleted', 'false') = 'true' then
      delete from nx_staff where user_id = (e ->> 'user_id')::uuid;
    else
      insert into nx_staff(user_id, role, perms, unlimited, gem_budget, updated_at)
      values ((e ->> 'user_id')::uuid, e ->> 'role',
              coalesce((select array_agg(x) from jsonb_array_elements_text(e -> 'perms') x), '{}'),
              coalesce((e ->> 'unlimited')::boolean, false), (e ->> 'gem_budget')::int, now())
      on conflict (user_id) do update set role = excluded.role, perms = excluded.perms, unlimited = excluded.unlimited,
        gem_budget = excluded.gem_budget, updated_at = now();
    end if;
    n := n + 1;
  end loop;
  return n;
end $function$
;

-- [7] nx_start_match(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_start_match(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); r public.nx_rooms; b record; ids uuid[]; nm text[]; mid uuid; sd bigint; n int; cap int;
begin
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if r.host <> me and not r.quick then raise exception 'host only'; end if;
  if r.status = 'playing' and r.match_id is not null then
    return jsonb_build_object('match_id', r.match_id, 'already', true);
  end if;
  select * into b from public.nx_game_bounds(r.game);
  cap := greatest(b.min_seats, least(coalesce(r.seats, b.max_seats), b.max_seats));
  select array_agg(rp.user_id order by rp.seat), array_agg(coalesce(p.username, 'Pilot') order by rp.seat), count(*)
    into ids, nm, n
    from public.nx_room_players rp left join public.profiles p on p.id = rp.user_id where rp.room_id = p_room;
  if n < b.min_seats then raise exception 'need % players', b.min_seats; end if;
  if n > cap then raise exception 'this room takes at most % players', cap; end if;
  if r.game = 'finger_soccer' and n % 2 <> 0 then raise exception 'team games need two equal sides'; end if;
  sd := floor(random() * 2147483646)::bigint + 1;
  insert into public.nx_matches(room_id, game, players, names, seed, settings) values (p_room, r.game, ids, nm, sd, r.settings)
  returning id into mid;
  update public.nx_rooms set status = 'playing', match_id = mid, updated_at = now() where id = p_room;
  return jsonb_build_object('match_id', mid, 'seed', sd);
end $function$
;

-- [7] nx_start_match_quick(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_start_match_quick(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r nx_rooms; ids uuid[]; nm text[]; mid uuid; sd bigint;
begin
  select * into r from nx_rooms where id = p_room for update;
  if r.status <> 'lobby' then return jsonb_build_object('match_id', r.match_id); end if;
  select array_agg(rp.user_id order by rp.seat), array_agg(coalesce(p.username, 'Pilot') order by rp.seat)
    into ids, nm from nx_room_players rp left join profiles p on p.id = rp.user_id where rp.room_id = p_room;
  sd := floor(random() * 2147483646)::bigint + 1;
  insert into nx_matches(room_id, game, players, names, seed, settings) values (p_room, r.game, ids, nm, sd, r.settings)
  returning id into mid;
  update nx_rooms set status = 'playing', match_id = mid, updated_at = now() where id = p_room;
  return jsonb_build_object('match_id', mid, 'seed', sd);
end $function$
;

-- [7] nx_start_room_match(p_room uuid)
CREATE OR REPLACE FUNCTION public.nx_start_room_match(p_room uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.nx_rooms; ids uuid[]; names text[]; prefs jsonb; mid uuid; seed_value bigint; n int; b record; gm text; cap int;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public._nx_room_can_manage(p_room) then raise exception 'manager only'; end if;
  select * into r from public.nx_rooms where id = p_room for update;
  if r.id is null then raise exception 'room not found'; end if;
  if r.status = 'playing' and r.match_id is not null then return jsonb_build_object('match_id', r.match_id, 'already', true); end if;
  gm := coalesce(r.selected_game, r.game);
  select * into b from public.nx_game_bounds(gm);
  cap := least(coalesce(r.seats, b.max_seats), b.max_seats);
  select array_agg(g.user_id order by g.seat), array_agg(coalesce(p.username, 'Pilot') order by g.seat), count(*),
         coalesce(jsonb_object_agg(g.seat::text, g.prefs), '{}'::jsonb)
    into ids, names, n, prefs
    from public.nx_room_game_players g left join public.profiles p on p.id = g.user_id where g.room_id = p_room;
  if n is null or n < greatest(2, b.min_seats) then raise exception 'need at least % selected players', greatest(2, b.min_seats); end if;
  if n > cap then raise exception 'at most % players in this room', cap; end if;
  if gm = 'finger_soccer' and n % 2 <> 0 then raise exception 'finger soccer needs an even number of players (1v1, 2v2, 3v3)'; end if;
  if exists (select 1 from unnest(ids) x group by x having count(*) > 1) then raise exception 'duplicate players'; end if;
  seed_value := floor(random() * 2147483646)::bigint + 1;
  insert into public.nx_matches(room_id, game, players, names, seed, settings)
  values (p_room, gm, ids, names, seed_value, r.settings || jsonb_build_object('room_prefs', prefs, 'room', p_room))
  returning id into mid;
  update public.nx_rooms set status = 'playing', match_id = mid, updated_at = now() where id = p_room;
  return jsonb_build_object('match_id', mid, 'seed', seed_value, 'players', n, 'capacity', cap);
end $function$
;

-- [7] nx_t_admin(p_t uuid, p_action text, p_reason text)
CREATE OR REPLACE FUNCTION public.nx_t_admin(p_t uuid, p_action text, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments; r record;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if not nx_t_can_manage(p_t, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  -- an early manual draw/start happens before anybody could check in: nobody is thrown out for not checking in
  -- check-in purge on a manual action: a manual "draw now" never throws out registered players (the check-in window
  -- may have opened seconds earlier, nobody could check in yet; no-shows lose their first match by walkover instead);
  -- a manual "start now" removes the players who did not check in only once the check-in window is open.
  perform set_config('nx.t_checkin_window',
                     case when p_action in ('draw', 'redraw') and now() < t.start_at then 'closed'
                          when now() >= t.start_at - interval '10 minutes' then 'open' else 'closed' end, true);
  case p_action
    when 'publish' then
      if t.status <> 'draft' then return jsonb_build_object('ok', false, 'error', 'not_draft'); end if;
      update nx_tournaments set status = case when reg_open_at <= now() then 'registering' else 'scheduled' end,
             published_at = now(), updated_at = now() where id = p_t;
      perform _nx_t_sync_jobs(p_t);
    when 'open_reg' then
      if t.status <> 'scheduled' then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
      update nx_tournaments set status = 'registering', reg_open_at = least(reg_open_at, now()), updated_at = now() where id = p_t;
      perform _nx_t_sync_jobs(p_t);
    when 'close_reg' then
      if t.status <> 'registering' then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
      update nx_tournaments set status = 'closed', reg_close_at = greatest(reg_open_at + interval '1 second', least(reg_close_at, now())),
             updated_at = now() where id = p_t;
      update nx_t_jobs set done_at = now() where idem_key = 'close_reg:' || p_t and done_at is null;
    when 'draw', 'redraw' then
      if p_action = 'redraw' then
        if t.status <> 'drawn' then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
        delete from nx_t_matches where tournament_id = p_t;
        update nx_tournaments set status = 'closed', seed = null, stage = 'main' where id = p_t;
      elsif t.status not in ('registering', 'closed') then
        return jsonb_build_object('ok', false, 'error', 'bad_status');
      end if;
      update nx_tournaments set reg_close_at = greatest(reg_open_at + interval '1 second', least(reg_close_at, now())),
             draw_at = greatest(reg_open_at + interval '1 second', least(draw_at, now())) where id = p_t;
      perform _nx_t_draw(p_t, me);
      update nx_t_jobs set done_at = now() where idem_key in ('close_reg:' || p_t, 'draw:' || p_t) and done_at is null;
    when 'start' then
      if t.status not in ('registering', 'closed', 'drawn') then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
      update nx_tournaments set
             reg_close_at = greatest(reg_open_at + interval '1 second', least(reg_close_at, now())),
             draw_at = greatest(reg_open_at + interval '1 second', least(draw_at, now())),
             start_at = greatest(reg_open_at + interval '1 second', least(start_at, now())) where id = p_t;
      perform _nx_t_start(p_t, me);
      update nx_t_jobs set done_at = now() where idem_key in ('close_reg:' || p_t, 'draw:' || p_t, 'start:' || p_t, 'remind_start:' || p_t)
         and done_at is null;
      perform _nx_t_reschedule(p_t);
    when 'pause' then
      update nx_tournaments set paused = true, updated_at = now() where id = p_t;
    when 'resume' then
      update nx_tournaments set paused = false, updated_at = now() where id = p_t;
      for r in select id from nx_t_matches where tournament_id = p_t and status = 'ready_check' loop
        update nx_t_matches set ready_deadline = now() + make_interval(secs => _nx_t_cfg_int(t.config, 'ready_seconds', 300))
         where id = r.id;
      end loop;
    when 'cancel' then
      perform _nx_t_cancel(p_t, coalesce(nullif(p_reason, ''), 'cancelled_by_organizer'), me);
    when 'finish' then
      if t.status <> 'live' then return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
      update nx_t_matches set status = 'void', result_note = 'closed_by_organizer', updated_at = now()
       where tournament_id = p_t and status not in ('done', 'walkover', 'bye', 'void', 'skipped');
      perform _nx_t_finish(p_t);
    when 'delete' then
      if t.status <> 'draft' or exists (select 1 from nx_t_ledger where tournament_id = p_t) then
        return jsonb_build_object('ok', false, 'error', 'not_deletable'); end if;
      delete from nx_tournaments where id = p_t;
      return jsonb_build_object('ok', true, 'deleted', true);
    else
      return jsonb_build_object('ok', false, 'error', 'bad_action');
  end case;
  perform _nx_t_audit(p_t, me, 'admin_' || p_action, jsonb_build_object('reason', p_reason));
  return jsonb_build_object('ok', true, 'status', (select status from nx_tournaments where id = p_t));
end $function$
;

-- [7] nx_t_admin_match(p_m uuid, p_action text, p jsonb)
CREATE OR REPLACE FUNCTION public.nx_t_admin_match(p_m uuid, p_action text, p jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m nx_t_matches; t nx_tournaments; w uuid; l uuid; dr boolean; d record; mid uuid;
        np1 uuid; np2 uuid;
begin
  if p_action = 'add' then
    select * into t from nx_tournaments where id = (p ->> 'tournament_id')::uuid for update;
  else
    select * into m from nx_t_matches where id = p_m for update;
    select * into t from nx_tournaments where id = m.tournament_id for update;
  end if;
  if t.id is null or not nx_t_can_manage(t.id, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if t.status in ('finished', 'cancelled') then return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  case p_action
    when 'result' then
      w := nullif(p ->> 'winner', '')::uuid;
      dr := coalesce((p ->> 'draw')::boolean, false);
      if not dr and (w is null or not (w = m.p1 or w = m.p2)) then return jsonb_build_object('ok', false, 'error', 'bad_winner'); end if;
      if dr and m.bracket in ('W', 'L', 'GF', 'GF2', 'P3') then return jsonb_build_object('ok', false, 'error', 'knockout_needs_winner'); end if;
      l := case when w = m.p1 then m.p2 when w = m.p2 then m.p1 end;
      if m.status in ('done', 'walkover') then
        if not _nx_t_downstream_free(m.id) then return jsonb_build_object('ok', false, 'error', 'downstream_started'); end if;
        update nx_t_matches set winner = w, loser = l, is_draw = dr, status = 'done',
               w1 = coalesce((p ->> 'w1')::int, w1), w2 = coalesce((p ->> 'w2')::int, w2),
               g1 = coalesce((p ->> 'g1')::int, g1), g2 = coalesce((p ->> 'g2')::int, g2),
               result_note = 'admin:' || coalesce(p ->> 'note', ''), updated_at = now() where id = m.id;
        if w is distinct from m.winner then
          -- re-seat the corrected players downstream
          for d in select id, status from nx_t_matches where id in (m.win_to, m.lose_to) loop
            update nx_t_matches set status = 'pending', ready_deadline = null, p1_ready = false, p2_ready = false where id = d.id;
          end loop;
          if m.win_to is not null then perform _nx_t_put(m.win_to, m.win_slot, w); end if;
          if m.lose_to is not null then perform _nx_t_put(m.lose_to, m.lose_slot, l); end if;
          if m.bracket = 'GF' then
            update nx_t_matches set status = 'pending', p1 = null, p2 = null, p1_set = false, p2_set = false
             where tournament_id = t.id and bracket = 'GF2';
            perform _nx_t_propagate(m.id);
          end if;
        end if;
        perform _nx_t_notify(m.p1, t.id, m.id, 'result_corrected', jsonb_build_object('winner', w), 'fix:' || m.id || ':' || clock_timestamp());
        perform _nx_t_notify(m.p2, t.id, m.id, 'result_corrected', jsonb_build_object('winner', w), 'fix:' || m.id || ':' || clock_timestamp());
      else
        if m.p1 is null or m.p2 is null then return jsonb_build_object('ok', false, 'error', 'players_unknown'); end if;
        update nx_t_matches set w1 = coalesce((p ->> 'w1')::int, w1), w2 = coalesce((p ->> 'w2')::int, w2),
               g1 = coalesce((p ->> 'g1')::int, g1), g2 = coalesce((p ->> 'g2')::int, g2) where id = m.id;
        if m.game_match is not null then
          update nx_t_games set accepted = true, winner = w, source = 'admin' where game_match = m.game_match;
          update nx_matches set status = 'abandoned', reason = 'admin', ended_at = now() where id = m.game_match and status = 'playing';
        end if;
        perform _nx_t_complete(m.id, w, l, dr, 'done', 'admin:' || coalesce(p ->> 'note', ''));
      end if;
    when 'replay' then
      if m.status not in ('disputed', 'playing', 'ready_check', 'scheduled') or m.p1 is null or m.p2 is null then
        return jsonb_build_object('ok', false, 'error', 'bad_status'); end if;
      if m.game_match is not null then
        update nx_t_games set accepted = true, source = 'void_replay' where game_match = m.game_match;
        update nx_matches set status = 'abandoned', reason = 'replay', ended_at = now() where id = m.game_match and status = 'playing';
      end if;
      update nx_t_matches set status = 'scheduled', game_match = null, updated_at = now() where id = m.id;
      if t.status = 'live' then perform _nx_t_open_ready(m.id); end if;
    when 'edit' then
      if m.status not in ('pending', 'scheduled', 'ready_check') or m.games > 0 then
        return jsonb_build_object('ok', false, 'error', 'already_started'); end if;
      np1 := case when p ? 'p1' then nullif(p ->> 'p1', '')::uuid else m.p1 end;
      np2 := case when p ? 'p2' then nullif(p ->> 'p2', '')::uuid else m.p2 end;
      if (np1 is not null and not exists (select 1 from nx_t_entries where tournament_id = t.id and user_id = np1 and status = 'approved'))
         or (np2 is not null and not exists (select 1 from nx_t_entries where tournament_id = t.id and user_id = np2 and status = 'approved'))
         or (np1 = np2) then
        return jsonb_build_object('ok', false, 'error', 'bad_players'); end if;
      update nx_t_matches set p1 = np1, p2 = np2,
             p1_set = p1_set or p ? 'p1', p2_set = p2_set or p ? 'p2',
             best_of = case when (p ->> 'best_of')::int between 1 and 15 then (p ->> 'best_of')::int else best_of end,
             status = 'pending', ready_deadline = null, p1_ready = false, p2_ready = false, updated_at = now()
       where id = m.id;
      perform _nx_t_check(m.id);
      if p ? 'scheduled_at' then
        update nx_t_matches set scheduled_at = greatest((p ->> 'scheduled_at')::timestamptz, now()) where id = m.id and status = 'scheduled';
        -- the 10-minute reminder follows the new time
        select * into m from nx_t_matches where id = m.id;
        if m.status = 'scheduled' and m.scheduled_at - interval '10 minutes' > now() + interval '1 minute' then
          perform _nx_t_job('remind_match', t.id, m.id, m.scheduled_at - interval '10 minutes', 'remind_match:' || m.id);
        end if;
      end if;
    when 'add' then
      if t.format <> 'custom' then return jsonb_build_object('ok', false, 'error', 'custom_only'); end if;
      if t.status not in ('drawn', 'live') then return jsonb_build_object('ok', false, 'error', 'draw_first'); end if;
      np1 := nullif(p ->> 'p1', '')::uuid; np2 := nullif(p ->> 'p2', '')::uuid;
      if np1 is null or np2 is null or np1 = np2
         or not exists (select 1 from nx_t_entries where tournament_id = t.id and user_id = np1 and status = 'approved')
         or not exists (select 1 from nx_t_entries where tournament_id = t.id and user_id = np2 and status = 'approved') then
        return jsonb_build_object('ok', false, 'error', 'bad_players'); end if;
      mid := _nx_t_new_match(t, 'main', 'C', greatest(1, coalesce((p ->> 'round')::int, 1)),
                             coalesce((select count(*) from nx_t_matches where tournament_id = t.id and bracket = 'C'
                                        and round = greatest(1, coalesce((p ->> 'round')::int, 1))), 0)::int,
                             greatest(1, coalesce((p ->> 'round')::int, 1)), null,
                             case when (p ->> 'best_of')::int between 1 and 15 then (p ->> 'best_of')::int else 1 end,
                             left(p ->> 'label', 40));
      update nx_t_matches set p1 = np1, p2 = np2, p1_set = true, p2_set = true where id = mid;
      perform _nx_t_check(mid);
      if p ? 'scheduled_at' then
        update nx_t_matches set scheduled_at = greatest((p ->> 'scheduled_at')::timestamptz, now()) where id = mid and status = 'scheduled';
      end if;
      perform _nx_t_audit(t.id, me, 'match_add', jsonb_build_object('match', mid, 'p', p));
      return jsonb_build_object('ok', true, 'id', mid);
    when 'delete' then
      if t.format <> 'custom' or m.games > 0 or m.status not in ('pending', 'scheduled', 'ready_check') then
        return jsonb_build_object('ok', false, 'error', 'not_deletable'); end if;
      delete from nx_t_matches where id = m.id;
    else
      return jsonb_build_object('ok', false, 'error', 'bad_action');
  end case;
  perform _nx_t_audit(t.id, me, 'match_' || p_action, jsonb_build_object('match', p_m, 'p', p));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_t_can_manage(t uuid, u uuid)
CREATE OR REPLACE FUNCTION public.nx_t_can_manage(t uuid, u uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u is not null and (
    nx_t_is_admin(u)
    or exists (select 1 from nx_tournaments x where x.id = t and x.created_by = u and nx_t_is_organizer(u))
    or exists (select 1 from nx_t_staff s where s.tournament_id = t and s.user_id = u)
  )
$function$
;

-- [7] nx_t_checkin(p_t uuid)
CREATE OR REPLACE FUNCTION public.nx_t_checkin(p_t uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments; e nx_t_entries;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select * into t from nx_tournaments where id = p_t;
  if t.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  select * into e from nx_t_entries where tournament_id = p_t and user_id = me for update;
  if e.user_id is null or e.status not in ('approved', 'waitlist') then return jsonb_build_object('ok', false, 'error', 'not_registered'); end if;
  if not _nx_t_cfg_bool(t.config, 'checkin', false) then return jsonb_build_object('ok', true, 'checkin', false); end if;
  if e.checked_in_at is not null then return jsonb_build_object('ok', true, 'checked_in_at', e.checked_in_at); end if;
  if t.status not in ('registering', 'closed') then return jsonb_build_object('ok', false, 'error', 'checkin_closed'); end if;
  if now() < t.start_at - interval '10 minutes' then
    return jsonb_build_object('ok', false, 'error', 'checkin_not_open', 'opens_at', t.start_at - interval '10 minutes'); end if;
  update nx_t_entries set checked_in_at = now(), updated_at = now() where tournament_id = p_t and user_id = me;
  perform _nx_t_audit(p_t, me, 'checked_in', '{}'::jsonb);
  return jsonb_build_object('ok', true, 'checked_in_at', now(), 'status', e.status);
end $function$
;

-- [7] nx_t_code_create(p_t uuid, p_max_uses integer, p_expires_at tim
CREATE OR REPLACE FUNCTION public.nx_t_code_create(p_t uuid, p_max_uses integer DEFAULT 1, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_requires_approval boolean DEFAULT false, p_count integer DEFAULT 1)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); out_codes jsonb := '[]'::jsonb; c text; i int;
begin
  if not nx_t_can_manage(p_t, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  for i in 1..greatest(1, least(coalesce(p_count, 1), 50)) loop
    c := _nx_t_new_code();
    insert into nx_t_codes(tournament_id, code, max_uses, expires_at, requires_approval, created_by)
    values (p_t, c, greatest(1, least(coalesce(p_max_uses, 1), 1000)), p_expires_at, coalesce(p_requires_approval, false), me);
    out_codes := out_codes || to_jsonb(c);
  end loop;
  perform _nx_t_audit(p_t, me, 'codes_created', jsonb_build_object('count', jsonb_array_length(out_codes)));
  return jsonb_build_object('ok', true, 'codes', out_codes);
end $function$
;

-- [7] nx_t_code_peek(p_code text)
CREATE OR REPLACE FUNCTION public.nx_t_code_peek(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); chk jsonb; t nx_tournaments; st text;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  chk := _nx_t_check_code(me, null, p_code);
  if not (chk ->> 'ok')::boolean then return chk; end if;
  select * into t from nx_tournaments where id = (chk ->> 'tournament_id')::uuid;
  if t.id is null or t.status = 'draft' then return jsonb_build_object('ok', false, 'error', 'bad_code'); end if;
  select status into st from nx_t_entries where tournament_id = t.id and user_id = me;
  return jsonb_build_object('ok', true, 'tournament_id', t.id, 'title', t.title, 'game', t.game, 'status', t.status,
    'fee_coins', t.fee_coins, 'fee_gems', t.fee_gems, 'start_at', t.start_at, 'my_status', st,
    'requires_approval', t.reg_mode in ('approval', 'code_approval') or coalesce((chk ->> 'requires_approval')::boolean, false));
end $function$
;

-- [7] nx_t_code_revoke(p_code uuid)
CREATE OR REPLACE FUNCTION public.nx_t_code_revoke(p_code uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t uuid;
begin
  select tournament_id into t from nx_t_codes where id = p_code;
  if t is null or not nx_t_can_manage(t, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  update nx_t_codes set revoked = true where id = p_code;
  perform _nx_t_audit(t, me, 'code_revoked', jsonb_build_object('code', p_code));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_t_decide(p_t uuid, p_user uuid, p_approve boolean, p_note te
CREATE OR REPLACE FUNCTION public.nx_t_decide(p_t uuid, p_user uuid, p_approve boolean, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments; e nx_t_entries; n int; st text;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null or not nx_t_can_manage(p_t, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if t.status not in ('scheduled', 'registering', 'closed') then return jsonb_build_object('ok', false, 'error', 'too_late'); end if;
  select * into e from nx_t_entries where tournament_id = p_t and user_id = p_user for update;
  if e.user_id is null or e.status not in ('pending', 'waitlist') then return jsonb_build_object('ok', false, 'error', 'not_pending'); end if;
  if p_approve then
    select count(*) into n from nx_t_entries where tournament_id = p_t and status = 'approved';
    st := case when n >= t.capacity then 'waitlist' else 'approved' end;
    update nx_t_entries set status = st, decided_by = me, note = p_note, updated_at = now() where tournament_id = p_t and user_id = p_user;
    perform _nx_t_notify(p_user, p_t, null, case st when 'approved' then 'approved' else 'waitlisted' end,
                         jsonb_build_object('note', p_note), 'dec:' || p_t || ':' || p_user || ':' || st);
  else
    st := 'rejected';
    perform _nx_t_refund(p_t, p_user, 'rejected');
    update nx_t_entries set status = st, decided_by = me, note = p_note, updated_at = now() where tournament_id = p_t and user_id = p_user;
    perform _nx_t_notify(p_user, p_t, null, 'rejected', jsonb_build_object('note', p_note), 'dec:' || p_t || ':' || p_user || ':rejected');
  end if;
  perform _nx_t_audit(p_t, me, 'decided', jsonb_build_object('user', p_user, 'status', st, 'note', p_note));
  return jsonb_build_object('ok', true, 'status', st);
end $function$
;

-- [7] nx_t_dispute(p_m uuid, p_reason text)
CREATE OR REPLACE FUNCTION public.nx_t_dispute(p_m uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m nx_t_matches;
begin
  select * into m from nx_t_matches where id = p_m;
  if m.id is null or not (me = m.p1 or me = m.p2) then return jsonb_build_object('ok', false, 'error', 'not_a_player'); end if;
  if m.status in ('done', 'walkover', 'bye', 'void', 'skipped') then return jsonb_build_object('ok', false, 'error', 'too_late'); end if;
  perform _nx_t_dispute(p_m, me, coalesce(nullif(left(p_reason, 120), ''), 'player_dispute'));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_t_gem_budget_left(u uuid, p_except uuid)
CREATE OR REPLACE FUNCTION public.nx_t_gem_budget_left(u uuid DEFAULT auth.uid(), p_except uuid DEFAULT NULL::uuid)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when nx_unlimited(u) then 2147483647
    else greatest(0, coalesce((select gem_budget from nx_staff where user_id = u), 0)
      - coalesce((select sum(_nx_t_cfg_int(prize, 'fixed_gems', 0)) from nx_tournaments
                   where created_by = u and status <> 'cancelled' and (p_except is null or id <> p_except)), 0)::int) end
$function$
;

-- [7] nx_t_is_admin(u uuid)
CREATE OR REPLACE FUNCTION public.nx_t_is_admin(u uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u is not null and (nx_has_perm('tournaments', u)
    or exists (select 1 from nx_staff where user_id = u and role = 'admin'))
$function$
;

-- [7] nx_t_is_organizer(u uuid)
CREATE OR REPLACE FUNCTION public.nx_t_is_organizer(u uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u is not null and (nx_t_is_admin(u) or nx_has_perm('organizer', u)
    or exists (select 1 from nx_staff where user_id = u and role = 'organizer'))
$function$
;

-- [7] nx_t_join_code(p_code text)
CREATE OR REPLACE FUNCTION public.nx_t_join_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); chk jsonb; res jsonb; t uuid;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  chk := _nx_t_check_code(me, null, p_code);
  if not (chk ->> 'ok')::boolean then return chk; end if;
  t := (chk ->> 'tournament_id')::uuid;
  -- the check above logged a successful attempt; nx_t_register validates (and logs) once more on purpose
  res := nx_t_register(t, p_code);
  return res || jsonb_build_object('tournament_id', t);
end $function$
;

-- [7] nx_t_logs(p_t uuid)
CREATE OR REPLACE FUNCTION public.nx_t_logs(p_t uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not nx_t_can_manage(p_t) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  return jsonb_build_object('ok', true,
    'audit', coalesce((select jsonb_agg(to_jsonb(a) || jsonb_build_object('actor_name', p.username) order by a.created_at desc)
                         from (select * from nx_t_audit where tournament_id = p_t order by created_at desc limit 300) a
                         left join profiles p on p.id = a.actor), '[]'::jsonb),
    'jobs', coalesce((select jsonb_agg(to_jsonb(j) order by j.run_at) from nx_t_jobs j where j.tournament_id = p_t), '[]'::jsonb),
    'ledger', coalesce((select jsonb_agg(to_jsonb(l) order by l.id) from nx_t_ledger l where l.tournament_id = p_t), '[]'::jsonb));
end $function$
;

-- [7] nx_t_mark_read()
CREATE OR REPLACE FUNCTION public.nx_t_mark_read()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  update nx_t_notifications set read = true where user_id = auth.uid() and not read;
$function$
;

-- [7] nx_t_my_role()
CREATE OR REPLACE FUNCTION public.nx_t_my_role()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object('admin', nx_t_is_admin(auth.uid()), 'organizer', nx_t_is_organizer(auth.uid()), 'uid', auth.uid(),
                            'owner', nx_is_owner(auth.uid()), 'unlimited', nx_unlimited(auth.uid()))
$function$
;

-- [7] nx_t_ready(p_m uuid)
CREATE OR REPLACE FUNCTION public.nx_t_ready(p_m uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); m nx_t_matches; t nx_tournaments; gm uuid;
begin
  select * into m from nx_t_matches where id = p_m for update;
  if m.id is null or me is null or not (me = m.p1 or me = m.p2) then return jsonb_build_object('ok', false, 'error', 'not_a_player'); end if;
  if m.status = 'playing' then return jsonb_build_object('ok', true, 'status', 'playing', 'game_match', m.game_match); end if;
  if m.status <> 'ready_check' then return jsonb_build_object('ok', false, 'error', 'not_ready_time', 'status', m.status); end if;
  select * into t from nx_tournaments where id = m.tournament_id;
  if t.paused or t.status <> 'live' then return jsonb_build_object('ok', false, 'error', 'paused'); end if;
  if me = m.p1 then update nx_t_matches set p1_ready = true, updated_at = now() where id = p_m returning * into m;
  else update nx_t_matches set p2_ready = true, updated_at = now() where id = p_m returning * into m; end if;
  if m.p1_ready and m.p2_ready then
    gm := _nx_t_launch(p_m);
    return jsonb_build_object('ok', true, 'status', 'playing', 'game_match', gm);
  end if;
  return jsonb_build_object('ok', true, 'status', 'ready_check', 'p1_ready', m.p1_ready, 'p2_ready', m.p2_ready);
end $function$
;

-- [7] nx_t_register(p_t uuid, p_code text)
CREATE OR REPLACE FUNCTION public.nx_t_register(p_t uuid, p_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments; e nx_t_entries; pr record; rating int; chk jsonb := null; approval boolean;
        lid bigint; st text; n_appr int; code_id uuid;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null or t.status = 'draft' then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if t.status <> 'registering' then return jsonb_build_object('ok', false, 'error', 'registration_closed'); end if;
  select * into e from nx_t_entries where tournament_id = p_t and user_id = me for update;
  if e.user_id is not null and e.status in ('pending', 'approved', 'waitlist') then
    return jsonb_build_object('ok', true, 'status', e.status, 'already', true);
  end if;
  if e.user_id is not null and e.status in ('removed', 'rejected') then
    return jsonb_build_object('ok', false, 'error', 'not_allowed');
  end if;
  select level, xp, coins, coalesce(gems, 0) as gems into pr from profiles where id = me;
  if pr is null then return jsonb_build_object('ok', false, 'error', 'no_profile'); end if;
  select coalesce((select s.rating from nx_game_stats s where s.user_id = me and s.game = t.game), 1000) into rating;
  if coalesce(pr.level, 1) < t.min_level then return jsonb_build_object('ok', false, 'error', 'min_level', 'need', t.min_level); end if;
  if coalesce(pr.xp, 0) < t.min_xp then return jsonb_build_object('ok', false, 'error', 'min_xp', 'need', t.min_xp); end if;
  if rating < t.min_rating then return jsonb_build_object('ok', false, 'error', 'min_rating', 'need', t.min_rating); end if;
  if coalesce(p_code, '') <> '' then
    chk := _nx_t_check_code(me, p_t, p_code);
    if not (chk ->> 'ok')::boolean then return chk; end if;
    code_id := (chk ->> 'code_id')::uuid;
  elsif t.reg_mode in ('code', 'code_approval') then
    return jsonb_build_object('ok', false, 'error', 'code_required');
  end if;
  approval := t.reg_mode in ('approval', 'code_approval') or coalesce((chk ->> 'requires_approval')::boolean, false);
  lid := _nx_t_charge(p_t, me, t.fee_coins, t.fee_gems);
  if lid is null then return jsonb_build_object('ok', false, 'error', 'insufficient_funds',
                                                'fee_coins', t.fee_coins, 'fee_gems', t.fee_gems); end if;
  select count(*) into n_appr from nx_t_entries where tournament_id = p_t and status = 'approved';
  st := case when approval then 'pending' when n_appr >= t.capacity then 'waitlist' else 'approved' end;
  insert into nx_t_entries(tournament_id, user_id, status, rating, paid_coins, paid_gems, fee_ref, code_id)
  values (p_t, me, st, rating, t.fee_coins, t.fee_gems, nullif(lid, 0), code_id)
  on conflict (tournament_id, user_id) do update set status = excluded.status, rating = excluded.rating,
     paid_coins = excluded.paid_coins, paid_gems = excluded.paid_gems, fee_ref = excluded.fee_ref, code_id = excluded.code_id,
     note = null, place = null, seed = null, group_no = null, decided_by = null, created_at = now(), updated_at = now();
  if code_id is not null then update nx_t_codes set uses = uses + 1 where id = code_id; end if;
  perform _nx_t_notify(me, p_t, null, case st when 'approved' then 'approved' when 'waitlist' then 'waitlisted' else 'registered' end,
                       '{}'::jsonb, 'reg:' || p_t || ':' || coalesce(lid, 0));
  if st = 'pending' then
    perform _nx_t_notify_managers(p_t, null, 'approval_needed', jsonb_build_object('user', me), 'appr:' || p_t || ':' || me || ':' || coalesce(lid, 0));
  end if;
  perform _nx_t_audit(p_t, me, 'registered', jsonb_build_object('status', st, 'code', code_id, 'fee_coins', t.fee_coins, 'fee_gems', t.fee_gems));
  return jsonb_build_object('ok', true, 'status', st);
end $function$
;

-- [7] nx_t_remove_entry(p_t uuid, p_user uuid, p_note text)
CREATE OR REPLACE FUNCTION public.nx_t_remove_entry(p_t uuid, p_user uuid, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments; e nx_t_entries; r record; n int := 0;
begin
  select * into t from nx_tournaments where id = p_t for update;
  if t.id is null or not nx_t_can_manage(p_t, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if t.status not in ('scheduled', 'registering', 'closed', 'drawn', 'live') then
    return jsonb_build_object('ok', false, 'error', 'too_late'); end if;
  select * into e from nx_t_entries where tournament_id = p_t and user_id = p_user for update;
  if e.user_id is null or e.status not in ('pending', 'approved', 'waitlist') then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
  if t.status in ('scheduled', 'registering', 'closed') or e.status <> 'approved' then
    -- before the draw: removed with a full refund, the waitlist moves up
    perform _nx_t_refund(p_t, p_user, 'removed');
    update nx_t_entries set status = 'removed', note = p_note, decided_by = me, updated_at = now() where tournament_id = p_t and user_id = p_user;
    perform _nx_t_notify(p_user, p_t, null, 'rejected', jsonb_build_object('note', p_note, 'removed', true), 'rm:' || p_t || ':' || p_user);
    if e.status = 'approved' then perform _nx_t_fill_from_waitlist(p_t); end if;
    perform _nx_t_audit(p_t, me, 'removed', jsonb_build_object('user', p_user, 'note', p_note));
    return jsonb_build_object('ok', true);
  end if;
  -- after the draw: disqualification. The entry fee stays in the pool; every open match is a walkover for the opponent,
  -- and matches the player would reach later are walkovers too (_nx_t_check).
  update nx_t_entries set status = 'removed', note = coalesce(nullif(p_note, ''), 'disqualified'), decided_by = me, updated_at = now()
   where tournament_id = p_t and user_id = p_user;
  perform _nx_t_notify(p_user, p_t, null, 'disqualified', jsonb_build_object('note', p_note), 'dq:' || p_t || ':' || p_user);
  perform _nx_t_audit(p_t, me, 'disqualified', jsonb_build_object('user', p_user, 'note', p_note));
  for r in select id, game_match from nx_t_matches
            where tournament_id = p_t and (p1 = p_user or p2 = p_user) and p1 is not null and p2 is not null
              and status in ('pending', 'scheduled', 'ready_check', 'playing', 'disputed')
            order by round, idx loop
    if r.game_match is not null then
      update nx_t_games set accepted = true, source = 'disqualified' where game_match = r.game_match and not accepted;
      update nx_matches set status = 'abandoned', reason = 'disqualified', ended_at = now()
       where id = r.game_match and status = 'playing';
    end if;
    perform _nx_t_complete(r.id, (select case when x.p1 = p_user then x.p2 else x.p1 end from nx_t_matches x where x.id = r.id),
                           p_user, false, 'walkover', 'disqualified');
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'disqualified', true, 'walkovers', n);
end $function$
;

-- [7] nx_t_report(p_game uuid, p_winner_seat integer, p_s0 integer, p
CREATE OR REPLACE FUNCTION public.nx_t_report(p_game uuid, p_winner_seat integer, p_s0 integer, p_s1 integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); g nx_t_games; w uuid;
begin
  select * into g from nx_t_games where game_match = p_game;
  if g.game_match is null or me is null or not (me = g.home or me = g.away) then
    return jsonb_build_object('ok', false, 'error', 'not_a_player'); end if;
  if p_winner_seat not in (-1, 0, 1) or p_s0 is null or p_s1 is null or p_s0 not between 0 and 99 or p_s1 not between 0 and 99 then
    return jsonb_build_object('ok', false, 'error', 'bad_report'); end if;
  if (p_winner_seat = 0 and p_s0 < p_s1) or (p_winner_seat = 1 and p_s1 < p_s0) or (p_winner_seat = -1 and p_s0 <> p_s1) then
    return jsonb_build_object('ok', false, 'error', 'inconsistent_report'); end if;
  w := case p_winner_seat when 0 then g.home when 1 then g.away end;
  insert into nx_t_reports(game_match, user_id, winner, s_home, s_away) values (p_game, me, w, p_s0, p_s1)
  on conflict (game_match, user_id) do nothing;
  perform _nx_t_try_accept(p_game, false);
  return jsonb_build_object('ok', true, 'accepted', (select accepted from nx_t_games where game_match = p_game),
                            'disputed', (select disputed from nx_t_games where game_match = p_game));
end $function$
;

-- [7] nx_t_save(p jsonb)
CREATE OR REPLACE FUNCTION public.nx_t_save(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments; old nx_tournaments; isnew boolean; adm boolean; paid boolean;
        n_appr int; times_changed boolean := false; prize jsonb; dsum int := 0; v jsonb;
begin
  if me is null then return jsonb_build_object('ok', false, 'error', 'not_signed_in'); end if;
  adm := nx_t_is_admin(me);
  isnew := (p ->> 'id') is null;
  if isnew then
    if not nx_t_is_organizer(me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
    t.id := gen_random_uuid(); t.status := 'draft'; t.created_by := me; t.config := '{}'; t.prize := '{}';
    t.game := 'finger_soccer'; t.format := 'single_elim'; t.capacity := 16; t.min_players := 2; t.reg_mode := 'open';
    t.min_level := 0; t.min_xp := 0; t.min_rating := 0; t.fee_coins := 0; t.fee_gems := 0; t.seeding := 'random';
    t.description := ''; t.rules := ''; t.paused := false; t.stage := 'main'; t.escrow_coins := 0; t.escrow_gems := 0;
    t.paid_out := false; t.created_at := now();
  else
    select * into t from nx_tournaments where id = (p ->> 'id')::uuid for update;
    if t.id is null then return jsonb_build_object('ok', false, 'error', 'not_found'); end if;
    if not nx_t_can_manage(t.id, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
    if t.status in ('finished', 'cancelled') then return jsonb_build_object('ok', false, 'error', 'locked'); end if;
  end if;
  old := t;
  -- always editable
  if p ? 'title' then t.title := left(trim(p ->> 'title'), 80); end if;
  if p ? 'description' then t.description := left(coalesce(p ->> 'description', ''), 4000); end if;
  if p ? 'rules' then t.rules := left(coalesce(p ->> 'rules', ''), 4000); end if;
  if p ? 'reg_open_at' and t.status in ('draft', 'scheduled') then t.reg_open_at := (p ->> 'reg_open_at')::timestamptz; end if;
  if p ? 'reg_close_at' and t.status in ('draft', 'scheduled', 'registering') then t.reg_close_at := (p ->> 'reg_close_at')::timestamptz; end if;
  if p ? 'draw_at' and t.status in ('draft', 'scheduled', 'registering', 'closed') then t.draw_at := (p ->> 'draw_at')::timestamptz; end if;
  if p ? 'start_at' and t.status in ('draft', 'scheduled', 'registering', 'closed', 'drawn') then t.start_at := (p ->> 'start_at')::timestamptz; end if;
  if p ? 'config' then
    if t.status in ('draft', 'scheduled', 'registering', 'closed') then
      t.config := _nx_t_validate_cfg(p -> 'config');
    else
      -- after the draw only timing settings may change
      v := p -> 'config';
      t.config := _nx_t_validate_cfg(t.config || jsonb_strip_nulls(jsonb_build_object(
        'round_starts', v -> 'round_starts', 'round_minutes', v -> 'round_minutes', 'ready_seconds', v -> 'ready_seconds',
        'max_game_minutes', v -> 'max_game_minutes')));
    end if;
  end if;
  if t.status in ('draft', 'scheduled', 'registering', 'closed') then
    select count(*) into n_appr from nx_t_entries where tournament_id = t.id and status = 'approved';
    select exists (select 1 from nx_t_entries where tournament_id = t.id and (paid_coins > 0 or paid_gems > 0)) into paid;
    if p ? 'game' then t.game := p ->> 'game'; end if;
    if p ? 'format' then t.format := p ->> 'format'; end if;
    if p ? 'capacity' then t.capacity := greatest(n_appr, (p ->> 'capacity')::int); end if;
    if p ? 'min_players' then t.min_players := greatest(2, least((p ->> 'min_players')::int, t.capacity)); end if;
    if p ? 'reg_mode' then t.reg_mode := p ->> 'reg_mode'; end if;
    if p ? 'min_level' then t.min_level := greatest(0, (p ->> 'min_level')::int); end if;
    if p ? 'min_xp' then t.min_xp := greatest(0, (p ->> 'min_xp')::int); end if;
    if p ? 'min_rating' then t.min_rating := greatest(0, (p ->> 'min_rating')::int); end if;
    if p ? 'seeding' then t.seeding := p ->> 'seeding'; end if;
    if not paid then
      if p ? 'fee_coins' then t.fee_coins := greatest(0, (p ->> 'fee_coins')::int); end if;
      if p ? 'fee_gems' then t.fee_gems := greatest(0, (p ->> 'fee_gems')::int); end if;
    elsif (p ? 'fee_coins' and (p ->> 'fee_coins')::int <> t.fee_coins) or (p ? 'fee_gems' and (p ->> 'fee_gems')::int <> t.fee_gems) then
      return jsonb_build_object('ok', false, 'error', 'fee_locked');
    end if;
    if p ? 'prize' then
      prize := coalesce(p -> 'prize', '{}'::jsonb);
      prize := jsonb_build_object(
        'fixed_coins', greatest(0, _nx_t_cfg_int(prize, 'fixed_coins', 0)),
        'fixed_gems', greatest(0, _nx_t_cfg_int(prize, 'fixed_gems', 0)),
        'pool_pct', greatest(0, least(_nx_t_cfg_int(prize, 'pool_pct', 0), 100)),
        'fee_pct', greatest(0, least(_nx_t_cfg_int(prize, 'fee_pct', 0), 50)),
        'dist', case when jsonb_typeof(prize -> 'dist') = 'array' then prize -> 'dist' else '[60,30,10]'::jsonb end);
      select coalesce(sum(greatest(0, x::numeric::int)), 0) into dsum from jsonb_array_elements_text(prize -> 'dist') x;
      if dsum > 100 or jsonb_array_length(prize -> 'dist') > 64 then
        return jsonb_build_object('ok', false, 'error', 'bad_distribution'); end if;
      -- minting coins/gems out of nothing is an admin decision
      -- (admins, the owner and tournament admins with the 'unlimited' perk; nothing is deducted from their balance,
      --  every payout is still written to nx_t_ledger)
      if (_nx_t_cfg_int(prize, 'fixed_coins', 0) > _nx_t_cfg_int(old.prize, 'fixed_coins', 0)
          or _nx_t_cfg_int(prize, 'fixed_gems', 0) > _nx_t_cfg_int(old.prize, 'fixed_gems', 0)) then
        if not (adm or nx_unlimited(me)) then
          -- limited managers: gem prizes within their budget (set by the main admin); coin prizes stay admin-only
          if _nx_t_cfg_int(prize, 'fixed_coins', 0) > _nx_t_cfg_int(old.prize, 'fixed_coins', 0) then
            return jsonb_build_object('ok', false, 'error', 'fixed_prize_admin_only'); end if;
          if _nx_t_cfg_int(prize, 'fixed_gems', 0) > nx_t_gem_budget_left(me, t.id) then
            return jsonb_build_object('ok', false, 'error', 'gem_budget_exceeded',
                                      'left', nx_t_gem_budget_left(me, t.id)); end if;
        end if;
        perform _nx_t_audit(t.id, me, 'fixed_prize_minted', jsonb_build_object(
          'fixed_coins', _nx_t_cfg_int(prize, 'fixed_coins', 0), 'fixed_gems', _nx_t_cfg_int(prize, 'fixed_gems', 0),
          'by', case when adm then 'admin' when nx_unlimited(me) then 'manager_unlimited' else 'manager_budget' end));
      end if;
      t.prize := prize;
    end if;
  end if;
  if t.title is null or char_length(t.title) < 3 then return jsonb_build_object('ok', false, 'error', 'bad_title'); end if;
  if t.format not in ('single_elim', 'double_elim', 'two_legs', 'round_robin', 'groups_ko', 'swiss', 'custom') then
    return jsonb_build_object('ok', false, 'error', 'bad_format'); end if;
  if t.capacity is null or t.capacity < 2 or t.capacity > 64 then return jsonb_build_object('ok', false, 'error', 'bad_capacity'); end if;
  if t.game not in ('finger_soccer', 'carrom', 'billiards', 'backgammon', 'quiz', 'kart_racing', 'obstacle_race',
                    'bomb_arena', 'pool8', 'mini_golf', 'basketball_battle') then
    return jsonb_build_object('ok', false, 'error', 'bad_game'); end if;
  if t.reg_open_at is null or t.reg_close_at is null or t.draw_at is null or t.start_at is null
     or not (t.reg_open_at < t.reg_close_at and t.reg_close_at <= t.draw_at and t.draw_at <= t.start_at) then
    return jsonb_build_object('ok', false, 'error', 'bad_times'); end if;
  if t.format = 'groups_ko' and t.capacity < 4 then return jsonb_build_object('ok', false, 'error', 'groups_need_4'); end if;
  times_changed := not isnew and old.status <> 'draft' and (old.reg_open_at, old.reg_close_at, old.draw_at, old.start_at, old.config -> 'round_starts', old.config -> 'round_minutes')
                   is distinct from (t.reg_open_at, t.reg_close_at, t.draw_at, t.start_at, t.config -> 'round_starts', t.config -> 'round_minutes');
  t.updated_at := now();
  if isnew then
    insert into nx_tournaments select t.*;
    perform _nx_t_audit(t.id, me, 'created', jsonb_build_object('title', t.title, 'format', t.format));
  else
    update nx_tournaments set title = t.title, description = t.description, rules = t.rules, game = t.game, format = t.format,
           capacity = t.capacity, min_players = t.min_players, config = t.config, reg_mode = t.reg_mode, min_level = t.min_level,
           min_xp = t.min_xp, min_rating = t.min_rating, fee_coins = t.fee_coins, fee_gems = t.fee_gems, prize = t.prize,
           reg_open_at = t.reg_open_at, reg_close_at = t.reg_close_at, draw_at = t.draw_at, start_at = t.start_at,
           seeding = t.seeding, updated_at = now()
     where id = t.id;
    perform _nx_t_audit(t.id, me, 'edited', jsonb_build_object('times_changed', times_changed));
  end if;
  if times_changed then
    perform _nx_t_sync_jobs(t.id);
    perform _nx_t_reschedule(t.id);
    perform _nx_t_notify_all(t.id, 'time_changed', jsonb_build_object('start_at', t.start_at, 'reg_close_at', t.reg_close_at,
              'draw_at', t.draw_at), 'time:' || t.id || ':' || floor(extract(epoch from clock_timestamp()))::bigint,
              array['approved', 'pending', 'waitlist']);
  end if;
  return jsonb_build_object('ok', true, 'id', t.id);
end $function$
;

-- [7] nx_t_set_runner(p_t uuid, p_user uuid, p_add boolean)
CREATE OR REPLACE FUNCTION public.nx_t_set_runner(p_t uuid, p_user uuid, p_add boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid();
begin
  if not (nx_t_is_admin(me) or exists (select 1 from nx_tournaments where id = p_t and created_by = me)) then
    return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if p_add then
    insert into nx_t_staff(tournament_id, user_id, added_by) values (p_t, p_user, me) on conflict do nothing;
  else
    delete from nx_t_staff where tournament_id = p_t and user_id = p_user;
  end if;
  perform _nx_t_audit(p_t, me, 'set_runner', jsonb_build_object('user', p_user, 'add', p_add));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_t_set_seed(p_t uuid, p_user uuid, p_seed integer)
CREATE OR REPLACE FUNCTION public.nx_t_set_seed(p_t uuid, p_user uuid, p_seed integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments;
begin
  select * into t from nx_tournaments where id = p_t;
  if t.id is null or not nx_t_can_manage(p_t, me) then return jsonb_build_object('ok', false, 'error', 'forbidden'); end if;
  if t.status not in ('draft', 'scheduled', 'registering', 'closed') then return jsonb_build_object('ok', false, 'error', 'too_late'); end if;
  update nx_t_entries set seed = greatest(1, least(p_seed, 64)), updated_at = now() where tournament_id = p_t and user_id = p_user;
  perform _nx_t_audit(p_t, me, 'seed', jsonb_build_object('user', p_user, 'seed', p_seed));
  return jsonb_build_object('ok', true);
end $function$
;

-- [7] nx_t_standings(p_t uuid)
CREATE OR REPLACE FUNCTION public.nx_t_standings(p_t uuid)
 RETURNS TABLE(group_no integer, user_id uuid, username text, seed integer, played integer, won integer, drawn integer, lost integer, gf integer, ga integer, pts integer, rank integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t nx_tournaments; g int;
begin
  select * into t from nx_tournaments where id = p_t;
  if t.id is null or not nx_t_visible(p_t) then return; end if;
  if t.format = 'groups_ko' then
    for g in select distinct e.group_no from nx_t_entries e where e.tournament_id = p_t and e.group_no is not null order by 1 loop
      return query
        select g, x.user_id, p.username, x.seed, x.played, x.won, x.drawn, x.lost, x.gf, x.ga, x.pts,
               (row_number() over (order by x.pts desc, (x.gf - x.ga) desc, x.gf desc, x.won desc, x.seed))::int
          from _nx_t_table(p_t, 'groups', g) x left join profiles p on p.id = x.user_id;
    end loop;
  else
    return query
      select null::int, x.user_id, p.username, x.seed, x.played, x.won, x.drawn, x.lost, x.gf, x.ga, x.pts,
             (row_number() over (order by x.pts desc, (x.gf - x.ga) desc, x.gf desc, x.won desc, x.seed))::int
        from _nx_t_table(p_t, 'main', null) x left join profiles p on p.id = x.user_id;
  end if;
end $function$
;

-- [7] nx_t_tick()
CREATE OR REPLACE FUNCTION public.nx_t_tick()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare j nx_t_jobs; r record; nj int := 0; nr int := 0; nn int := 0; na int := 0;
begin
  if not pg_try_advisory_xact_lock(74230011) then return jsonb_build_object('skipped', true); end if;
  for j in select jb.* from nx_t_jobs jb left join nx_tournaments t on t.id = jb.tournament_id
            where jb.done_at is null and jb.run_at <= now()
              and not (coalesce(t.paused, false) and jb.kind in ('draw', 'start'))
            order by jb.run_at limit 200 loop
    begin
      perform _nx_t_run_job(j);
      update nx_t_jobs set done_at = now(), attempts = attempts + 1, last_error = null where id = j.id;
      nj := nj + 1;
    exception when others then
      update nx_t_jobs set attempts = attempts + 1, last_error = left(sqlerrm, 300),
             run_at = now() + make_interval(mins => least(attempts + 1, 15)),
             done_at = case when attempts + 1 >= 60 then now() end
       where id = j.id;
    end;
  end loop;
  -- due matches → ready check
  for r in select m.id from nx_t_matches m join nx_tournaments t on t.id = m.tournament_id
            where m.status = 'scheduled' and m.scheduled_at <= now() and t.status = 'live' and not t.paused
            order by m.scheduled_at limit 500 loop
    begin perform _nx_t_open_ready(r.id); nr := nr + 1;
    exception when others then perform _nx_t_audit(null, null, 'error_ready', jsonb_build_object('match', r.id, 'error', sqlerrm)); end;
  end loop;
  -- ready deadlines → walkovers
  for r in select m.id from nx_t_matches m join nx_tournaments t on t.id = m.tournament_id
            where m.status = 'ready_check' and m.ready_deadline < now() and not t.paused limit 500 loop
    begin perform _nx_t_no_show(r.id); nn := nn + 1;
    exception when others then perform _nx_t_audit(null, null, 'error_no_show', jsonb_build_object('match', r.id, 'error', sqlerrm)); end;
  end loop;
  -- results waiting for the second report
  for r in select g.game_match from nx_t_games g where not g.accepted and not g.disputed and g.ended_at is not null limit 500 loop
    begin perform _nx_t_try_accept(r.game_match, true); na := na + 1;
    exception when others then perform _nx_t_audit(null, null, 'error_accept', jsonb_build_object('game', r.game_match, 'error', sqlerrm)); end;
  end loop;
  -- games that never ended (both phones gone) → dispute for an organizer
  for r in select g.tmatch from nx_t_games g join nx_t_matches m on m.id = g.tmatch join nx_tournaments t on t.id = m.tournament_id
            where not g.accepted and not g.disputed and g.ended_at is null and m.status = 'playing'
              and g.created_at < now() - make_interval(mins => greatest(5, _nx_t_cfg_int(t.config, 'max_game_minutes', 30)))
            limit 100 loop
    begin perform _nx_t_dispute(r.tmatch, null, 'game_timeout');
    exception when others then null; end;
  end loop;
  return jsonb_build_object('jobs', nj, 'ready', nr, 'no_show', nn, 'accept', na);
end $function$
;

-- [7] nx_t_visible(t uuid)
CREATE OR REPLACE FUNCTION public.nx_t_visible(t uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from nx_tournaments x where x.id = t and x.status <> 'draft') or nx_t_can_manage(t)
$function$
;

-- [7] nx_t_withdraw(p_t uuid)
CREATE OR REPLACE FUNCTION public.nx_t_withdraw(p_t uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare me uuid := auth.uid(); t nx_tournaments; e nx_t_entries; refunded boolean := false;
begin
  select * into t from nx_tournaments where id = p_t for update;
  select * into e from nx_t_entries where tournament_id = p_t and user_id = me for update;
  if e.user_id is null or e.status not in ('pending', 'approved', 'waitlist') then
    return jsonb_build_object('ok', false, 'error', 'not_registered'); end if;
  if t.status not in ('registering', 'closed') then return jsonb_build_object('ok', false, 'error', 'too_late'); end if;
  if t.status = 'registering' then refunded := _nx_t_refund(p_t, me, 'withdrawn'); end if;
  update nx_t_entries set status = 'withdrawn', updated_at = now() where tournament_id = p_t and user_id = me;
  if e.status = 'approved' then perform _nx_t_fill_from_waitlist(p_t); end if;
  perform _nx_t_audit(p_t, me, 'withdrawn', jsonb_build_object('refunded', refunded));
  return jsonb_build_object('ok', true, 'refunded', refunded);
end $function$
;

-- [7] nx_talk_rooms()
CREATE OR REPLACE FUNCTION public.nx_talk_rooms()
 RETURNS TABLE(id uuid, code text, title text, game text, status text, host uuid, host_name text, members integer, capacity integer, min_players integer, max_players integer, locked boolean, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select r.id, r.code, r.title, coalesce(r.selected_game, r.game), r.status, r.host, p.username,
         public._nx_room_audience(r.id),
         greatest((public.nx_game_bounds(coalesce(r.selected_game, r.game))).min_seats,
                  least(coalesce(r.seats, (public.nx_game_bounds(coalesce(r.selected_game, r.game))).max_seats),
                        (public.nx_game_bounds(coalesce(r.selected_game, r.game))).max_seats)),
         greatest(2, (public.nx_game_bounds(coalesce(r.selected_game, r.game))).min_seats),
         (public.nx_game_bounds(coalesce(r.selected_game, r.game))).max_seats,
         coalesce(r.join_locked, false),
         r.created_at
    from public.nx_rooms r left join public.profiles p on p.id = r.host
   where r.kind = 'talk' and r.status <> 'closed' and not r.is_private
     and exists(select 1 from public.nx_room_members m where m.room_id = r.id and m.last_seen > now() - interval '30 minutes')
   order by r.updated_at desc limit 60 $function$
;

-- [7] nx_unlimited(u uuid)
CREATE OR REPLACE FUNCTION public.nx_unlimited(u uuid DEFAULT auth.uid())
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select u is not null and (nx_is_owner(u) or (u = auth.uid() and nx_perm('unlimited_gems'))
    or exists (select 1 from nx_staff where user_id = u and unlimited))
$function$
;

-- [7] nx_update_room(p_room uuid, p_seats integer, p_settings jsonb)
CREATE OR REPLACE FUNCTION public.nx_update_room(p_room uuid, p_seats integer, p_settings jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r nx_rooms; b record; n int;
begin
  select * into r from nx_rooms where id = p_room for update;
  if r.host <> auth.uid() then raise exception 'host only'; end if;
  if r.status <> 'lobby' then raise exception 'already started'; end if;
  select * into b from nx_game_bounds(r.game);
  select count(*) into n from nx_room_players where room_id = p_room;
  update nx_rooms set seats = greatest(n, greatest(b.min_seats, least(coalesce(p_seats, r.seats), b.max_seats))),
         settings = coalesce(p_settings, settings), updated_at = now() where id = p_room;
end $function$
;

-- [7] nx_wallet_push()
CREATE OR REPLACE FUNCTION public.nx_wallet_push()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare url text := _nx_secret('nx_social_url'); key text := _nx_secret('nx_social_service_key'); rows jsonb; rid bigint; n int;
begin
  if url is null or key is null then return 0; end if;
  -- ack what the other side answered with 2xx
  update nx_wallet_tx t set acked_at = now()
    from net._http_response r
   where t.acked_at is null and t.request_id = r.id and r.status_code between 200 and 299;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'user_id', user_id, 'xp', xp, 'coins', coins, 'gems', gems,
                                               'reason', reason) order by id), '[]'::jsonb), count(*)
    into rows, n
    from (select * from nx_wallet_tx
           where acked_at is null and (sent_at is null or sent_at < now() - interval '50 seconds') and tries < 200
           order by id limit 200) x;
  if n = 0 then return 0; end if;
  select net.http_post(url := url || '/rest/v1/rpc/nx_bridge_apply_batch',
                       headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', key,
                                                     'Authorization', 'Bearer ' || key),
                       body := jsonb_build_object('p_rows', rows), timeout_milliseconds := 8000) into rid;
  update nx_wallet_tx set sent_at = now(), request_id = rid, tries = tries + 1
   where id in (select (e ->> 'id')::bigint from jsonb_array_elements(rows) e);
  return n;
end $function$
;

-- [8] nx_leaderboard
create or replace view public.nx_leaderboard as  SELECT s.game,
    s.user_id,
    p.username,
    p.avatar,
    s.rating,
    s.played,
    s.won,
    s.lost,
    s.draw,
    s.best
   FROM (nx_game_stats s
     JOIN profiles p ON ((p.id = s.user_id)));

-- [8] nx_leaderboard_global
create or replace view public.nx_leaderboard_global as  SELECT p.id AS user_id,
    p.username,
    p.avatar,
    p.xp,
    p.level,
    (COALESCE(sum(s.won), (0)::bigint))::integer AS won,
    (COALESCE(sum(s.played), (0)::bigint))::integer AS played
   FROM (profiles p
     LEFT JOIN nx_game_stats s ON ((s.user_id = p.id)))
  GROUP BY p.id, p.username, p.avatar, p.xp, p.level;

-- [9] nx_matches_physics_contract
CREATE TRIGGER nx_matches_physics_contract BEFORE INSERT ON public.nx_matches FOR EACH ROW EXECUTE FUNCTION nx_apply_physics_contract();

-- [9] nx_matches_server_result_guard
CREATE TRIGGER nx_matches_server_result_guard BEFORE UPDATE ON public.nx_matches FOR EACH ROW EXECUTE FUNCTION _nx_server_result_guard();

-- [9] nx_profiles_delta
CREATE TRIGGER nx_profiles_delta BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION _nx_profiles_delta();

-- [9] nx_t_audit_immutable
CREATE TRIGGER nx_t_audit_immutable BEFORE DELETE OR UPDATE ON public.nx_t_audit FOR EACH ROW EXECUTE FUNCTION _nx_t_ledger_immutable();

-- [9] nx_t_ledger_immutable
CREATE TRIGGER nx_t_ledger_immutable BEFORE DELETE OR UPDATE ON public.nx_t_ledger FOR EACH ROW EXECUTE FUNCTION _nx_t_ledger_immutable();

-- [9] nx_t_notif_guard
CREATE TRIGGER nx_t_notif_guard BEFORE UPDATE ON public.nx_t_notifications FOR EACH ROW EXECUTE FUNCTION _nx_t_notif_guard();

-- [9] nx_t_on_match_end
CREATE TRIGGER nx_t_on_match_end AFTER UPDATE OF status ON public.nx_matches FOR EACH ROW EXECUTE FUNCTION _nx_t_on_match_end();

-- [9] nx_wallet_tx_kick
CREATE TRIGGER nx_wallet_tx_kick AFTER INSERT ON public.nx_wallet_tx FOR EACH STATEMENT EXECUTE FUNCTION _nx_wallet_tx_kick();

-- [10] nx_admin_audit
alter table public.nx_admin_audit enable row level security;

-- [10] nx_arcade_best
alter table public.nx_arcade_best enable row level security;

-- [10] nx_arcade_runs
alter table public.nx_arcade_runs enable row level security;

-- [10] nx_cosmetic_equipped
alter table public.nx_cosmetic_equipped enable row level security;

-- [10] nx_cosmetic_owned
alter table public.nx_cosmetic_owned enable row level security;

-- [10] nx_cosmetics
alter table public.nx_cosmetics enable row level security;

-- [10] nx_game_stats
alter table public.nx_game_stats enable row level security;

-- [10] nx_invites
alter table public.nx_invites enable row level security;

-- [10] nx_match_moves
alter table public.nx_match_moves enable row level security;

-- [10] nx_match_presence
alter table public.nx_match_presence enable row level security;

-- [10] nx_match_reports
alter table public.nx_match_reports enable row level security;

-- [10] nx_match_results
alter table public.nx_match_results enable row level security;

-- [10] nx_match_secrets
alter table public.nx_match_secrets enable row level security;

-- [10] nx_match_turn_state
alter table public.nx_match_turn_state enable row level security;

-- [10] nx_matches
alter table public.nx_matches enable row level security;

-- [10] nx_physics_contracts
alter table public.nx_physics_contracts enable row level security;

-- [10] nx_quiz_answers
alter table public.nx_quiz_answers enable row level security;

-- [10] nx_quiz_games
alter table public.nx_quiz_games enable row level security;

-- [10] nx_quiz_questions
alter table public.nx_quiz_questions enable row level security;

-- [10] nx_quiz_seen
alter table public.nx_quiz_seen enable row level security;

-- [10] nx_room_game_players
alter table public.nx_room_game_players enable row level security;

-- [10] nx_room_members
alter table public.nx_room_members enable row level security;

-- [10] nx_room_messages
alter table public.nx_room_messages enable row level security;

-- [10] nx_room_players
alter table public.nx_room_players enable row level security;

-- [10] nx_rooms
alter table public.nx_rooms enable row level security;

-- [10] nx_staff
alter table public.nx_staff enable row level security;

-- [10] nx_t_audit
alter table public.nx_t_audit enable row level security;

-- [10] nx_t_code_attempts
alter table public.nx_t_code_attempts enable row level security;

-- [10] nx_t_codes
alter table public.nx_t_codes enable row level security;

-- [10] nx_t_entries
alter table public.nx_t_entries enable row level security;

-- [10] nx_t_games
alter table public.nx_t_games enable row level security;

-- [10] nx_t_jobs
alter table public.nx_t_jobs enable row level security;

-- [10] nx_t_ledger
alter table public.nx_t_ledger enable row level security;

-- [10] nx_t_matches
alter table public.nx_t_matches enable row level security;

-- [10] nx_t_notifications
alter table public.nx_t_notifications enable row level security;

-- [10] nx_t_reports
alter table public.nx_t_reports enable row level security;

-- [10] nx_t_staff
alter table public.nx_t_staff enable row level security;

-- [10] nx_tournaments
alter table public.nx_tournaments enable row level security;

-- [10] nx_user_mutes
alter table public.nx_user_mutes enable row level security;

-- [10] nx_wallet_tx
alter table public.nx_wallet_tx enable row level security;

-- [10] nx_xp_events
alter table public.nx_xp_events enable row level security;

-- [10] profiles
alter table public.profiles enable row level security;

-- [11] nx_admin_audit.nx_admin_audit_read
create policy nx_admin_audit_read on public.nx_admin_audit as PERMISSIVE for SELECT to authenticated using (nx_has_perm('admins'::text));

-- [11] nx_arcade_best.nx_arcade_best_read
create policy nx_arcade_best_read on public.nx_arcade_best as PERMISSIVE for SELECT to public using (true);

-- [11] nx_arcade_runs.nx_arcade_runs_own
create policy nx_arcade_runs_own on public.nx_arcade_runs as PERMISSIVE for SELECT to public using ((user_id = auth.uid()));

-- [11] nx_cosmetic_equipped.nx_cosmetic_equipped_own
create policy nx_cosmetic_equipped_own on public.nx_cosmetic_equipped as PERMISSIVE for SELECT to authenticated using ((user_id = auth.uid()));

-- [11] nx_cosmetic_equipped.nx_cosmetic_equipped_read
create policy nx_cosmetic_equipped_read on public.nx_cosmetic_equipped as PERMISSIVE for SELECT to authenticated using (true);

-- [11] nx_cosmetic_owned.nx_cosmetic_owned_own
create policy nx_cosmetic_owned_own on public.nx_cosmetic_owned as PERMISSIVE for SELECT to authenticated using ((user_id = auth.uid()));

-- [11] nx_cosmetics.nx_cosmetics_admin
create policy nx_cosmetics_admin on public.nx_cosmetics as PERMISSIVE for UPDATE to authenticated using (nx_perm('shop'::text)) with check (nx_perm('shop'::text));

-- [11] nx_cosmetics.nx_cosmetics_read
create policy nx_cosmetics_read on public.nx_cosmetics as PERMISSIVE for SELECT to anon, authenticated using (true);

-- [11] nx_game_stats.nx_game_stats_read
create policy nx_game_stats_read on public.nx_game_stats as PERMISSIVE for SELECT to public using (true);

-- [11] nx_invites.nx_invites_read
create policy nx_invites_read on public.nx_invites as PERMISSIVE for SELECT to authenticated using (((to_user = auth.uid()) OR (from_user = auth.uid())));

-- [11] nx_invites.nx_invites_upd
create policy nx_invites_upd on public.nx_invites as PERMISSIVE for UPDATE to authenticated using ((to_user = auth.uid())) with check ((to_user = auth.uid()));

-- [11] nx_match_moves.nx_match_moves_read
create policy nx_match_moves_read on public.nx_match_moves as PERMISSIVE for SELECT to authenticated using (nx_in_match(match_id));

-- [11] nx_match_results.nx_match_results_read
create policy nx_match_results_read on public.nx_match_results as PERMISSIVE for SELECT to authenticated using (true);

-- [11] nx_match_secrets.nx_match_secrets_read
create policy nx_match_secrets_read on public.nx_match_secrets as PERMISSIVE for SELECT to authenticated using ((user_id = auth.uid()));

-- [11] nx_matches.nx_matches_read
create policy nx_matches_read on public.nx_matches as PERMISSIVE for SELECT to authenticated using (true);

-- [11] nx_room_game_players.nx_room_players_read
create policy nx_room_players_read on public.nx_room_game_players as PERMISSIVE for SELECT to authenticated using (nx_is_room_member(room_id));

-- [11] nx_room_members.nx_room_members_read
create policy nx_room_members_read on public.nx_room_members as PERMISSIVE for SELECT to authenticated using (nx_is_room_member(room_id));

-- [11] nx_room_messages.nx_room_messages_read
create policy nx_room_messages_read on public.nx_room_messages as PERMISSIVE for SELECT to authenticated using ((nx_is_room_member(room_id) AND (NOT deleted)));

-- [11] nx_room_players.nx_room_players_read
create policy nx_room_players_read on public.nx_room_players as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM nx_rooms r
  WHERE ((r.id = nx_room_players.room_id) AND ((NOT r.is_private) OR nx_in_room(r.id))))));

-- [11] nx_rooms.nx_rooms_read
create policy nx_rooms_read on public.nx_rooms as PERMISSIVE for SELECT to authenticated using (((NOT is_private) OR (host = auth.uid()) OR nx_in_room(id)));

-- [11] nx_staff.nx_staff_read
create policy nx_staff_read on public.nx_staff as PERMISSIVE for SELECT to authenticated using (true);

-- [11] nx_t_audit.nx_t_audit_read
create policy nx_t_audit_read on public.nx_t_audit as PERMISSIVE for SELECT to authenticated using (nx_t_can_manage(tournament_id));

-- [11] nx_t_codes.nx_t_codes_read
create policy nx_t_codes_read on public.nx_t_codes as PERMISSIVE for SELECT to authenticated using (nx_t_can_manage(tournament_id));

-- [11] nx_t_entries.nx_t_entries_read
create policy nx_t_entries_read on public.nx_t_entries as PERMISSIVE for SELECT to authenticated using (((user_id = auth.uid()) OR ((status = ANY (ARRAY['approved'::text, 'waitlist'::text])) AND nx_t_visible(tournament_id)) OR nx_t_can_manage(tournament_id)));

-- [11] nx_t_games.nx_t_games_read
create policy nx_t_games_read on public.nx_t_games as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM nx_t_matches m
  WHERE ((m.id = nx_t_games.tmatch) AND nx_t_visible(m.tournament_id)))));

-- [11] nx_t_ledger.nx_t_ledger_read
create policy nx_t_ledger_read on public.nx_t_ledger as PERMISSIVE for SELECT to authenticated using (((user_id = auth.uid()) OR nx_t_can_manage(tournament_id)));

-- [11] nx_t_matches.nx_t_matches_read
create policy nx_t_matches_read on public.nx_t_matches as PERMISSIVE for SELECT to authenticated using (nx_t_visible(tournament_id));

-- [11] nx_t_notifications.nx_t_notif_del
create policy nx_t_notif_del on public.nx_t_notifications as PERMISSIVE for DELETE to authenticated using ((user_id = auth.uid()));

-- [11] nx_t_notifications.nx_t_notif_read
create policy nx_t_notif_read on public.nx_t_notifications as PERMISSIVE for SELECT to authenticated using ((user_id = auth.uid()));

-- [11] nx_t_notifications.nx_t_notif_upd
create policy nx_t_notif_upd on public.nx_t_notifications as PERMISSIVE for UPDATE to authenticated using ((user_id = auth.uid())) with check ((user_id = auth.uid()));

-- [11] nx_t_reports.nx_t_reports_read
create policy nx_t_reports_read on public.nx_t_reports as PERMISSIVE for SELECT to authenticated using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM (nx_t_games g
     JOIN nx_t_matches m ON ((m.id = g.tmatch)))
  WHERE ((g.game_match = nx_t_reports.game_match) AND nx_t_can_manage(m.tournament_id))))));

-- [11] nx_t_staff.nx_t_staff_read
create policy nx_t_staff_read on public.nx_t_staff as PERMISSIVE for SELECT to authenticated using (nx_t_visible(tournament_id));

-- [11] nx_tournaments.nx_tournaments_read
create policy nx_tournaments_read on public.nx_tournaments as PERMISSIVE for SELECT to authenticated using (((status <> 'draft'::text) OR nx_t_can_manage(id)));

-- [11] nx_user_mutes.nx_user_mutes_own
create policy nx_user_mutes_own on public.nx_user_mutes as PERMISSIVE for SELECT to authenticated using (((user_id = auth.uid()) OR nx_has_perm('users'::text)));

-- [11] nx_wallet_tx.nx_wallet_tx_own
create policy nx_wallet_tx_own on public.nx_wallet_tx as PERMISSIVE for SELECT to authenticated using ((user_id = auth.uid()));

-- [11] nx_xp_events.nx_xp_events_read
create policy nx_xp_events_read on public.nx_xp_events as PERMISSIVE for SELECT to authenticated using ((user_id = auth.uid()));

-- [11] profiles.profiles_read
create policy profiles_read on public.profiles as PERMISSIVE for SELECT to authenticated using (true);

-- [12] nx_admin_auditanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_admin_audit to anon;

-- [12] nx_admin_auditauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_admin_audit to authenticated;

-- [12] nx_admin_auditservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_admin_audit to service_role;

-- [12] nx_arcade_bestanon
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_arcade_best to anon;

-- [12] nx_arcade_bestauthenticated
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_arcade_best to authenticated;

-- [12] nx_arcade_bestservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_arcade_best to service_role;

-- [12] nx_arcade_runsanon
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_arcade_runs to anon;

-- [12] nx_arcade_runsauthenticated
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_arcade_runs to authenticated;

-- [12] nx_arcade_runsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_arcade_runs to service_role;

-- [12] nx_cosmetic_equippedanon
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_cosmetic_equipped to anon;

-- [12] nx_cosmetic_equippedauthenticated
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_cosmetic_equipped to authenticated;

-- [12] nx_cosmetic_equippedservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_cosmetic_equipped to service_role;

-- [12] nx_cosmetic_ownedanon
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_cosmetic_owned to anon;

-- [12] nx_cosmetic_ownedauthenticated
grant REFERENCES, SELECT, TRIGGER, TRUNCATE on public.nx_cosmetic_owned to authenticated;

-- [12] nx_cosmetic_ownedservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_cosmetic_owned to service_role;

-- [12] nx_cosmeticsanon
grant REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_cosmetics to anon;

-- [12] nx_cosmeticsauthenticated
grant REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_cosmetics to authenticated;

-- [12] nx_cosmeticsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_cosmetics to service_role;

-- [12] nx_game_statsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_game_stats to anon;

-- [12] nx_game_statsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_game_stats to authenticated;

-- [12] nx_game_statsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_game_stats to service_role;

-- [12] nx_invitesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_invites to anon;

-- [12] nx_invitesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_invites to authenticated;

-- [12] nx_invitesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_invites to service_role;

-- [12] nx_leaderboard_globalanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_leaderboard_global to anon;

-- [12] nx_leaderboard_globalauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_leaderboard_global to authenticated;

-- [12] nx_leaderboard_globalservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_leaderboard_global to service_role;

-- [12] nx_leaderboardanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_leaderboard to anon;

-- [12] nx_leaderboardauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_leaderboard to authenticated;

-- [12] nx_leaderboardservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_leaderboard to service_role;

-- [12] nx_match_movesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_moves to anon;

-- [12] nx_match_movesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_moves to authenticated;

-- [12] nx_match_movesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_moves to service_role;

-- [12] nx_match_presenceservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_presence to service_role;

-- [12] nx_match_reportsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_reports to service_role;

-- [12] nx_match_resultsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_results to anon;

-- [12] nx_match_resultsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_results to authenticated;

-- [12] nx_match_resultsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_results to service_role;

-- [12] nx_match_secretsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_secrets to anon;

-- [12] nx_match_secretsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_secrets to authenticated;

-- [12] nx_match_secretsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_secrets to service_role;

-- [12] nx_match_turn_stateservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_match_turn_state to service_role;

-- [12] nx_matchesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_matches to anon;

-- [12] nx_matchesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_matches to authenticated;

-- [12] nx_matchesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_matches to service_role;

-- [12] nx_physics_contractsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_physics_contracts to service_role;

-- [12] nx_quiz_answersservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_quiz_answers to service_role;

-- [12] nx_quiz_gamesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_quiz_games to service_role;

-- [12] nx_quiz_questionsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_quiz_questions to service_role;

-- [12] nx_quiz_seenservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_quiz_seen to service_role;

-- [12] nx_room_game_playersanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_game_players to anon;

-- [12] nx_room_game_playersauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_game_players to authenticated;

-- [12] nx_room_game_playersservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_game_players to service_role;

-- [12] nx_room_membersanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_members to anon;

-- [12] nx_room_membersauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_members to authenticated;

-- [12] nx_room_membersservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_members to service_role;

-- [12] nx_room_messagesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_messages to anon;

-- [12] nx_room_messagesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_messages to authenticated;

-- [12] nx_room_messagesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_messages to service_role;

-- [12] nx_room_playersanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_players to anon;

-- [12] nx_room_playersauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_players to authenticated;

-- [12] nx_room_playersservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_room_players to service_role;

-- [12] nx_roomsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_rooms to anon;

-- [12] nx_roomsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_rooms to authenticated;

-- [12] nx_roomsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_rooms to service_role;

-- [12] nx_staffanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_staff to anon;

-- [12] nx_staffauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_staff to authenticated;

-- [12] nx_staffservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_staff to service_role;

-- [12] nx_t_auditanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_audit to anon;

-- [12] nx_t_auditauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_audit to authenticated;

-- [12] nx_t_auditservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_audit to service_role;

-- [12] nx_t_code_attemptsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_code_attempts to anon;

-- [12] nx_t_code_attemptsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_code_attempts to authenticated;

-- [12] nx_t_code_attemptsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_code_attempts to service_role;

-- [12] nx_t_codesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_codes to anon;

-- [12] nx_t_codesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_codes to authenticated;

-- [12] nx_t_codesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_codes to service_role;

-- [12] nx_t_entriesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_entries to anon;

-- [12] nx_t_entriesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_entries to authenticated;

-- [12] nx_t_entriesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_entries to service_role;

-- [12] nx_t_gamesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_games to anon;

-- [12] nx_t_gamesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_games to authenticated;

-- [12] nx_t_gamesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_games to service_role;

-- [12] nx_t_jobsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_jobs to anon;

-- [12] nx_t_jobsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_jobs to authenticated;

-- [12] nx_t_jobsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_jobs to service_role;

-- [12] nx_t_ledgeranon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_ledger to anon;

-- [12] nx_t_ledgerauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_ledger to authenticated;

-- [12] nx_t_ledgerservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_ledger to service_role;

-- [12] nx_t_matchesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_matches to anon;

-- [12] nx_t_matchesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_matches to authenticated;

-- [12] nx_t_matchesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_matches to service_role;

-- [12] nx_t_notificationsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_notifications to anon;

-- [12] nx_t_notificationsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_notifications to authenticated;

-- [12] nx_t_notificationsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_notifications to service_role;

-- [12] nx_t_reportsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_reports to anon;

-- [12] nx_t_reportsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_reports to authenticated;

-- [12] nx_t_reportsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_reports to service_role;

-- [12] nx_t_staffanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_staff to anon;

-- [12] nx_t_staffauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_staff to authenticated;

-- [12] nx_t_staffservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_t_staff to service_role;

-- [12] nx_tournamentsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_tournaments to anon;

-- [12] nx_tournamentsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_tournaments to authenticated;

-- [12] nx_tournamentsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_tournaments to service_role;

-- [12] nx_user_mutesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_user_mutes to anon;

-- [12] nx_user_mutesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_user_mutes to authenticated;

-- [12] nx_user_mutesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_user_mutes to service_role;

-- [12] nx_wallet_txanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_wallet_tx to anon;

-- [12] nx_wallet_txauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_wallet_tx to authenticated;

-- [12] nx_wallet_txservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_wallet_tx to service_role;

-- [12] nx_xp_eventsanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_xp_events to anon;

-- [12] nx_xp_eventsauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_xp_events to authenticated;

-- [12] nx_xp_eventsservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.nx_xp_events to service_role;

-- [12] profilesanon
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.profiles to anon;

-- [12] profilesauthenticated
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.profiles to authenticated;

-- [12] profilesservice_role
grant DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE on public.profiles to service_role;

-- [13] _nx_apply_result
revoke all on function public._nx_apply_result(m nx_matches, p_winners integer[], p_scores integer[]) from public, anon, authenticated;

-- [13] _nx_forfeited_seats
revoke all on function public._nx_forfeited_seats(p_match uuid) from public, anon, authenticated;

-- [13] _nx_g_turn_times
revoke all on function public._nx_g_turn_times(p_game text, OUT aim_s integer, OUT sim_s integer) from public, anon, authenticated; grant execute on function public._nx_g_turn_times(p_game text, OUT aim_s integer, OUT sim_s integer) to anon; grant execute on function public._nx_g_turn_times(p_game text, OUT aim_s integer, OUT sim_s integer) to authenticated;

-- [13] _nx_leave_all
revoke all on function public._nx_leave_all(me uuid) from public, anon, authenticated;

-- [13] _nx_match_authority
revoke all on function public._nx_match_authority(p_match uuid) from public, anon, authenticated;

-- [13] _nx_owner_guard
revoke all on function public._nx_owner_guard() from public, anon, authenticated;

-- [13] _nx_player_active
revoke all on function public._nx_player_active(p_match uuid, p_user uuid, p_ping_sec integer, p_move_sec integer) from public, anon, authenticated;

-- [13] _nx_profiles_delta
revoke all on function public._nx_profiles_delta() from public, anon, authenticated; grant execute on function public._nx_profiles_delta() to anon; grant execute on function public._nx_profiles_delta() to authenticated;

-- [13] _nx_quick_lock
revoke all on function public._nx_quick_lock(p_game text, p_seats integer) from public, anon, authenticated;

-- [13] _nx_quick_seats
revoke all on function public._nx_quick_seats(p_game text, p_seats integer) from public, anon, authenticated; grant execute on function public._nx_quick_seats(p_game text, p_seats integer) to anon; grant execute on function public._nx_quick_seats(p_game text, p_seats integer) to authenticated;

-- [13] _nx_quiz_const
revoke all on function public._nx_quiz_const(OUT q_ms integer, OUT grace_ms integer, OUT reveal_ms integer, OUT lead_ms integer, OUT pick_s integer) from public, anon, authenticated; grant execute on function public._nx_quiz_const(OUT q_ms integer, OUT grace_ms integer, OUT reveal_ms integer, OUT lead_ms integer, OUT pick_s integer) to anon; grant execute on function public._nx_quiz_const(OUT q_ms integer, OUT grace_ms integer, OUT reveal_ms integer, OUT lead_ms integer, OUT pick_s integer) to authenticated;

-- [13] _nx_quiz_tick
revoke all on function public._nx_quiz_tick(p_match uuid) from public, anon, authenticated;

-- [13] _nx_room_after_match
revoke all on function public._nx_room_after_match(p_room uuid, p_match uuid) from public, anon, authenticated;

-- [13] _nx_room_audience
revoke all on function public._nx_room_audience(p_room uuid) from public, anon, authenticated; grant execute on function public._nx_room_audience(p_room uuid) to anon; grant execute on function public._nx_room_audience(p_room uuid) to authenticated;

-- [13] _nx_room_can_manage
revoke all on function public._nx_room_can_manage(p_room uuid) from public, anon, authenticated; grant execute on function public._nx_room_can_manage(p_room uuid) to anon; grant execute on function public._nx_room_can_manage(p_room uuid) to authenticated;

-- [13] _nx_room_seat_limit
revoke all on function public._nx_room_seat_limit(p_game text) from public, anon, authenticated; grant execute on function public._nx_room_seat_limit(p_game text) to anon; grant execute on function public._nx_room_seat_limit(p_game text) to authenticated;

-- [13] _nx_room_selected
revoke all on function public._nx_room_selected(p_room uuid) from public, anon, authenticated; grant execute on function public._nx_room_selected(p_room uuid) to anon; grant execute on function public._nx_room_selected(p_room uuid) to authenticated;

-- [13] _nx_secret
revoke all on function public._nx_secret(n text) from public, anon, authenticated;

-- [13] _nx_server_result_guard
revoke all on function public._nx_server_result_guard() from public, anon, authenticated; grant execute on function public._nx_server_result_guard() to anon; grant execute on function public._nx_server_result_guard() to authenticated;

-- [13] _nx_t_audit
revoke all on function public._nx_t_audit(p_t uuid, p_actor uuid, p_action text, p_data jsonb) from public, anon, authenticated;

-- [13] _nx_t_better_seed
revoke all on function public._nx_t_better_seed(p_t uuid, a uuid, b uuid) from public, anon, authenticated;

-- [13] _nx_t_bo
revoke all on function public._nx_t_bo(t nx_tournaments, p_kind text) from public, anon, authenticated;

-- [13] _nx_t_cancel
revoke all on function public._nx_t_cancel(p_t uuid, p_reason text, p_actor uuid) from public, anon, authenticated;

-- [13] _nx_t_cfg_bool
revoke all on function public._nx_t_cfg_bool(c jsonb, k text, d boolean) from public, anon, authenticated;

-- [13] _nx_t_cfg_int
revoke all on function public._nx_t_cfg_int(c jsonb, k text, d integer) from public, anon, authenticated;

-- [13] _nx_t_charge
revoke all on function public._nx_t_charge(p_t uuid, p_user uuid, p_coins integer, p_gems integer) from public, anon, authenticated;

-- [13] _nx_t_check
revoke all on function public._nx_t_check(p_m uuid) from public, anon, authenticated;

-- [13] _nx_t_check_code
revoke all on function public._nx_t_check_code(p_user uuid, p_t uuid, p_code text) from public, anon, authenticated;

-- [13] _nx_t_complete
revoke all on function public._nx_t_complete(p_m uuid, p_winner uuid, p_loser uuid, p_draw boolean, p_status text, p_note text) from public, anon, authenticated;

-- [13] _nx_t_dispute
revoke all on function public._nx_t_dispute(p_m uuid, p_actor uuid, p_reason text) from public, anon, authenticated;

-- [13] _nx_t_downstream_free
revoke all on function public._nx_t_downstream_free(p_m uuid) from public, anon, authenticated;

-- [13] _nx_t_draw
revoke all on function public._nx_t_draw(p_t uuid, p_actor uuid) from public, anon, authenticated;

-- [13] _nx_t_fill_from_waitlist
revoke all on function public._nx_t_fill_from_waitlist(p_t uuid) from public, anon, authenticated;

-- [13] _nx_t_finish
revoke all on function public._nx_t_finish(p_t uuid) from public, anon, authenticated;

-- [13] _nx_t_game_result
revoke all on function public._nx_t_game_result(p_gm uuid, p_winner uuid, p_s_home integer, p_s_away integer, p_source text) from public, anon, authenticated;

-- [13] _nx_t_gen_de
revoke all on function public._nx_t_gen_de(p_t uuid, players uuid[]) from public, anon, authenticated;

-- [13] _nx_t_gen_on
revoke all on function public._nx_t_gen_on() from public, anon, authenticated;

-- [13] _nx_t_gen_rr
revoke all on function public._nx_t_gen_rr(p_t uuid, players uuid[], p_group integer, p_double boolean, r_off integer, s_off integer, p_bracket text, p_stage text) from public, anon, authenticated;

-- [13] _nx_t_gen_se
revoke all on function public._nx_t_gen_se(p_t uuid, players uuid[], p_stage text, r_off integer, s_off integer) from public, anon, authenticated;

-- [13] _nx_t_job
revoke all on function public._nx_t_job(p_kind text, p_t uuid, p_ref uuid, p_run timestamp with time zone, p_key text) from public, anon, authenticated;

-- [13] _nx_t_launch
revoke all on function public._nx_t_launch(p_m uuid) from public, anon, authenticated;

-- [13] _nx_t_lb_count
revoke all on function public._nx_t_lb_count(p integer, m integer) from public, anon, authenticated;

-- [13] _nx_t_ledger_immutable
revoke all on function public._nx_t_ledger_immutable() from public, anon, authenticated;

-- [13] _nx_t_mid
revoke all on function public._nx_t_mid(p_t uuid, p_stage text, p_bracket text, p_round integer, p_idx integer) from public, anon, authenticated;

-- [13] _nx_t_new_code
revoke all on function public._nx_t_new_code() from public, anon, authenticated;

-- [13] _nx_t_new_match
revoke all on function public._nx_t_new_match(t nx_tournaments, p_stage text, p_bracket text, p_round integer, p_idx integer, p_slot integer, p_group integer, p_bo integer, p_label text) from public, anon, authenticated;

-- [13] _nx_t_no_show
revoke all on function public._nx_t_no_show(p_m uuid) from public, anon, authenticated;

-- [13] _nx_t_notif_guard
revoke all on function public._nx_t_notif_guard() from public, anon, authenticated;

-- [13] _nx_t_notify
revoke all on function public._nx_t_notify(p_user uuid, p_t uuid, p_tm uuid, p_kind text, p_data jsonb, p_dedup text) from public, anon, authenticated;

-- [13] _nx_t_notify_all
revoke all on function public._nx_t_notify_all(p_t uuid, p_kind text, p_data jsonb, p_dedup text, p_statuses text[]) from public, anon, authenticated;

-- [13] _nx_t_notify_managers
revoke all on function public._nx_t_notify_managers(p_t uuid, p_tm uuid, p_kind text, p_data jsonb, p_dedup text) from public, anon, authenticated;

-- [13] _nx_t_on_match_end
revoke all on function public._nx_t_on_match_end() from public, anon, authenticated;

-- [13] _nx_t_open_ready
revoke all on function public._nx_t_open_ready(p_m uuid) from public, anon, authenticated;

-- [13] _nx_t_payout
revoke all on function public._nx_t_payout(p_t uuid) from public, anon, authenticated;

-- [13] _nx_t_place_elim
revoke all on function public._nx_t_place_elim(p_t uuid, p_stage text) from public, anon, authenticated;

-- [13] _nx_t_planned
revoke all on function public._nx_t_planned(t nx_tournaments, p_slot integer) from public, anon, authenticated;

-- [13] _nx_t_prize_total
revoke all on function public._nx_t_prize_total(p_fixed integer, p_escrow integer, p_pool_pct integer, p_fee_pct integer) from public, anon, authenticated;

-- [13] _nx_t_progress
revoke all on function public._nx_t_progress(p_t uuid) from public, anon, authenticated;

-- [13] _nx_t_propagate
revoke all on function public._nx_t_propagate(p_m uuid) from public, anon, authenticated;

-- [13] _nx_t_put
revoke all on function public._nx_t_put(p_m uuid, p_slot integer, p_player uuid) from public, anon, authenticated;

-- [13] _nx_t_refund
revoke all on function public._nx_t_refund(p_t uuid, p_user uuid, p_reason text) from public, anon, authenticated;

-- [13] _nx_t_reschedule
revoke all on function public._nx_t_reschedule(p_t uuid) from public, anon, authenticated;

-- [13] _nx_t_run_job
revoke all on function public._nx_t_run_job(j nx_t_jobs) from public, anon, authenticated;

-- [13] _nx_t_seed_order
revoke all on function public._nx_t_seed_order(p integer) from public, anon, authenticated;

-- [13] _nx_t_split
revoke all on function public._nx_t_split(p_t uuid, p_total integer, p_dist integer[]) from public, anon, authenticated;

-- [13] _nx_t_start
revoke all on function public._nx_t_start(p_t uuid, p_actor uuid) from public, anon, authenticated;

-- [13] _nx_t_swiss_round
revoke all on function public._nx_t_swiss_round(p_t uuid, p_r integer) from public, anon, authenticated;

-- [13] _nx_t_sync_jobs
revoke all on function public._nx_t_sync_jobs(p_t uuid) from public, anon, authenticated;

-- [13] _nx_t_table
revoke all on function public._nx_t_table(p_t uuid, p_stage text, p_group integer) from public, anon, authenticated;

-- [13] _nx_t_try_accept
revoke all on function public._nx_t_try_accept(p_gm uuid, p_from_tick boolean) from public, anon, authenticated;

-- [13] _nx_t_validate_cfg
revoke all on function public._nx_t_validate_cfg(c jsonb) from public, anon, authenticated;

-- [13] _nx_wallet_tx_kick
revoke all on function public._nx_wallet_tx_kick() from public, anon, authenticated; grant execute on function public._nx_wallet_tx_kick() to anon; grant execute on function public._nx_wallet_tx_kick() to authenticated;

-- [13] buy_cosmetic
revoke all on function public.buy_cosmetic(p_item text) from public, anon, authenticated; grant execute on function public.buy_cosmetic(p_item text) to authenticated;

-- [13] equip_cosmetic
revoke all on function public.equip_cosmetic(p_item text) from public, anon, authenticated; grant execute on function public.equip_cosmetic(p_item text) to authenticated;

-- [13] is_admin
revoke all on function public.is_admin(uid uuid) from public, anon, authenticated; grant execute on function public.is_admin(uid uuid) to anon; grant execute on function public.is_admin(uid uuid) to authenticated;

-- [13] is_owner
revoke all on function public.is_owner(uid uuid) from public, anon, authenticated; grant execute on function public.is_owner(uid uuid) to anon; grant execute on function public.is_owner(uid uuid) to authenticated;

-- [13] level_for_xp
revoke all on function public.level_for_xp(x integer) from public, anon, authenticated; grant execute on function public.level_for_xp(x integer) to anon; grant execute on function public.level_for_xp(x integer) to authenticated;

-- [13] my_cosmetics
revoke all on function public.my_cosmetics() from public, anon, authenticated; grant execute on function public.my_cosmetics() to authenticated;

-- [13] nx_admin_close_room
revoke all on function public.nx_admin_close_room(p_room uuid, p_reason text) from public, anon, authenticated; grant execute on function public.nx_admin_close_room(p_room uuid, p_reason text) to authenticated;

-- [13] nx_admin_end_match
revoke all on function public.nx_admin_end_match(p_match uuid, p_reason text) from public, anon, authenticated; grant execute on function public.nx_admin_end_match(p_match uuid, p_reason text) to authenticated;

-- [13] nx_admin_kick
revoke all on function public.nx_admin_kick(p_room uuid, p_user uuid, p_reason text) from public, anon, authenticated; grant execute on function public.nx_admin_kick(p_room uuid, p_user uuid, p_reason text) to authenticated;

-- [13] nx_admin_live_matches
revoke all on function public.nx_admin_live_matches(p_limit integer) from public, anon, authenticated; grant execute on function public.nx_admin_live_matches(p_limit integer) to authenticated;

-- [13] nx_admin_mute
revoke all on function public.nx_admin_mute(p_user uuid, p_minutes integer, p_reason text) from public, anon, authenticated; grant execute on function public.nx_admin_mute(p_user uuid, p_minutes integer, p_reason text) to authenticated;

-- [13] nx_admin_room_clear_chat
revoke all on function public.nx_admin_room_clear_chat(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_admin_room_clear_chat(p_room uuid) to authenticated;

-- [13] nx_admin_room_members
revoke all on function public.nx_admin_room_members(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_admin_room_members(p_room uuid) to authenticated;

-- [13] nx_admin_room_message
revoke all on function public.nx_admin_room_message(p_room uuid, p_text text) from public, anon, authenticated; grant execute on function public.nx_admin_room_message(p_room uuid, p_text text) to authenticated;

-- [13] nx_admin_room_update
revoke all on function public.nx_admin_room_update(p_room uuid, p_private boolean, p_seats integer, p_title text) from public, anon, authenticated; grant execute on function public.nx_admin_room_update(p_room uuid, p_private boolean, p_seats integer, p_title text) to authenticated;

-- [13] nx_admin_rooms
revoke all on function public.nx_admin_rooms(p_limit integer) from public, anon, authenticated; grant execute on function public.nx_admin_rooms(p_limit integer) to authenticated;

-- [13] nx_admin_rooms_broadcast
revoke all on function public.nx_admin_rooms_broadcast(p_text text) from public, anon, authenticated; grant execute on function public.nx_admin_rooms_broadcast(p_text text) to authenticated;

-- [13] nx_apply_physics_contract
revoke all on function public.nx_apply_physics_contract() from public, anon, authenticated;

-- [13] nx_arcade_limits
revoke all on function public.nx_arcade_limits(p_game text, OUT max_score integer, OUT max_rate numeric, OUT min_ms integer) from public, anon, authenticated; grant execute on function public.nx_arcade_limits(p_game text, OUT max_score integer, OUT max_rate numeric, OUT min_ms integer) to anon; grant execute on function public.nx_arcade_limits(p_game text, OUT max_score integer, OUT max_rate numeric, OUT min_ms integer) to authenticated;

-- [13] nx_arcade_submit
revoke all on function public.nx_arcade_submit(p_game text, p_score integer, p_duration_ms integer, p_daily boolean, p_meta jsonb) from public, anon, authenticated; grant execute on function public.nx_arcade_submit(p_game text, p_score integer, p_duration_ms integer, p_daily boolean, p_meta jsonb) to anon; grant execute on function public.nx_arcade_submit(p_game text, p_score integer, p_duration_ms integer, p_daily boolean, p_meta jsonb) to authenticated;

-- [13] nx_arcade_top
revoke all on function public.nx_arcade_top(p_game text, p_daily boolean, p_limit integer) from public, anon, authenticated; grant execute on function public.nx_arcade_top(p_game text, p_daily boolean, p_limit integer) to anon; grant execute on function public.nx_arcade_top(p_game text, p_daily boolean, p_limit integer) to authenticated;

-- [13] nx_create_room
revoke all on function public.nx_create_room(p_game text, p_seats integer, p_private boolean, p_quick boolean, p_settings jsonb) from public, anon, authenticated; grant execute on function public.nx_create_room(p_game text, p_seats integer, p_private boolean, p_quick boolean, p_settings jsonb) to authenticated;

-- [13] nx_finish_match
revoke all on function public.nx_finish_match(p_match uuid, p_winners integer[], p_scores integer[], p_hash text, p_reason text) from public, anon, authenticated; grant execute on function public.nx_finish_match(p_match uuid, p_winners integer[], p_scores integer[], p_hash text, p_reason text) to authenticated;

-- [13] nx_finish_match_as
revoke all on function public.nx_finish_match_as(p_match uuid, p_winners integer[], p_loser integer) from public, anon, authenticated;

-- [13] nx_forfeit
revoke all on function public.nx_forfeit(p_match uuid, p_seat integer) from public, anon, authenticated; grant execute on function public.nx_forfeit(p_match uuid, p_seat integer) to authenticated;

-- [13] nx_g_hello
revoke all on function public.nx_g_hello() from public, anon, authenticated; grant execute on function public.nx_g_hello() to anon; grant execute on function public.nx_g_hello() to authenticated;

-- [13] nx_g_is_muted
revoke all on function public.nx_g_is_muted(u uuid) from public, anon, authenticated; grant execute on function public.nx_g_is_muted(u uuid) to anon; grant execute on function public.nx_g_is_muted(u uuid) to authenticated;

-- [13] nx_g_push
revoke all on function public.nx_g_push(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer) from public, anon, authenticated; grant execute on function public.nx_g_push(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer) to authenticated;

-- [13] nx_game_bounds
revoke all on function public.nx_game_bounds(p_game text, OUT min_seats integer, OUT max_seats integer) from public, anon, authenticated; grant execute on function public.nx_game_bounds(p_game text, OUT min_seats integer, OUT max_seats integer) to anon; grant execute on function public.nx_game_bounds(p_game text, OUT min_seats integer, OUT max_seats integer) to authenticated;

-- [13] nx_gen_code
revoke all on function public.nx_gen_code() from public, anon, authenticated; grant execute on function public.nx_gen_code() to anon; grant execute on function public.nx_gen_code() to authenticated;

-- [13] nx_has_perm
revoke all on function public.nx_has_perm(p text, u uuid) from public, anon, authenticated; grant execute on function public.nx_has_perm(p text, u uuid) to anon; grant execute on function public.nx_has_perm(p text, u uuid) to authenticated;

-- [13] nx_idle_forfeit
revoke all on function public.nx_idle_forfeit(p_match uuid, p_seat integer) from public, anon, authenticated; grant execute on function public.nx_idle_forfeit(p_match uuid, p_seat integer) to authenticated;

-- [13] nx_in_match
revoke all on function public.nx_in_match(m uuid) from public, anon, authenticated; grant execute on function public.nx_in_match(m uuid) to anon; grant execute on function public.nx_in_match(m uuid) to authenticated;

-- [13] nx_in_room
revoke all on function public.nx_in_room(r uuid) from public, anon, authenticated; grant execute on function public.nx_in_room(r uuid) to anon; grant execute on function public.nx_in_room(r uuid) to authenticated;

-- [13] nx_invite
revoke all on function public.nx_invite(p_room uuid, p_user uuid) from public, anon, authenticated; grant execute on function public.nx_invite(p_room uuid, p_user uuid) to anon; grant execute on function public.nx_invite(p_room uuid, p_user uuid) to authenticated;

-- [13] nx_is_owner
revoke all on function public.nx_is_owner(u uuid) from public, anon, authenticated; grant execute on function public.nx_is_owner(u uuid) to anon; grant execute on function public.nx_is_owner(u uuid) to authenticated;

-- [13] nx_is_room_member
revoke all on function public.nx_is_room_member(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_is_room_member(p_room uuid) to anon; grant execute on function public.nx_is_room_member(p_room uuid) to authenticated;

-- [13] nx_join_room
revoke all on function public.nx_join_room(p_code text, p_room uuid) from public, anon, authenticated; grant execute on function public.nx_join_room(p_code text, p_room uuid) to anon; grant execute on function public.nx_join_room(p_code text, p_room uuid) to authenticated;

-- [13] nx_known_game
revoke all on function public.nx_known_game(p_game text) from public, anon, authenticated; grant execute on function public.nx_known_game(p_game text) to anon; grant execute on function public.nx_known_game(p_game text) to authenticated;

-- [13] nx_leave_room
revoke all on function public.nx_leave_room(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_leave_room(p_room uuid) to anon; grant execute on function public.nx_leave_room(p_room uuid) to authenticated;

-- [13] nx_lobby_ping
revoke all on function public.nx_lobby_ping(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_lobby_ping(p_room uuid) to authenticated;

-- [13] nx_match_ping
revoke all on function public.nx_match_ping(p_match uuid) from public, anon, authenticated; grant execute on function public.nx_match_ping(p_match uuid) to authenticated;

-- [13] nx_match_turn
revoke all on function public.nx_match_turn(p_match uuid, p_seat integer, p_epoch bigint, p_seconds integer) from public, anon, authenticated; grant execute on function public.nx_match_turn(p_match uuid, p_seat integer, p_epoch bigint, p_seconds integer) to authenticated;

-- [13] nx_mirror_put
revoke all on function public.nx_mirror_put(p_rows jsonb) from public, anon, authenticated;

-- [13] nx_my_active_match
revoke all on function public.nx_my_active_match() from public, anon, authenticated; grant execute on function public.nx_my_active_match() to authenticated;

-- [13] nx_owner_tournaments
revoke all on function public.nx_owner_tournaments(p_limit integer) from public, anon, authenticated; grant execute on function public.nx_owner_tournaments(p_limit integer) to authenticated;

-- [13] nx_perm
revoke all on function public.nx_perm(p text) from public, anon, authenticated; grant execute on function public.nx_perm(p text) to anon; grant execute on function public.nx_perm(p text) to authenticated;

-- [13] nx_push_move
revoke all on function public.nx_push_move(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer) from public, anon, authenticated; grant execute on function public.nx_push_move(p_match uuid, p_seq integer, p_kind text, p_move jsonb, p_hash text, p_seat integer) to authenticated;

-- [13] nx_put_secret
revoke all on function public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb) from public, anon, authenticated; grant execute on function public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb) to anon; grant execute on function public.nx_put_secret(p_match uuid, p_user uuid, p_slot text, p_data jsonb) to authenticated;

-- [13] nx_quick
revoke all on function public.nx_quick(p_game text, p_seats integer) from public, anon, authenticated; grant execute on function public.nx_quick(p_game text, p_seats integer) to authenticated;

-- [13] nx_quick_cancel
revoke all on function public.nx_quick_cancel(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_quick_cancel(p_room uuid) to authenticated;

-- [13] nx_quiz_answer
revoke all on function public.nx_quiz_answer(p_match uuid, p_round integer, p_choice integer) from public, anon, authenticated; grant execute on function public.nx_quiz_answer(p_match uuid, p_round integer, p_choice integer) to authenticated;

-- [13] nx_quiz_start
revoke all on function public.nx_quiz_start(p_match uuid, p_category text) from public, anon, authenticated; grant execute on function public.nx_quiz_start(p_match uuid, p_category text) to authenticated;

-- [13] nx_quiz_state
revoke all on function public.nx_quiz_state(p_match uuid) from public, anon, authenticated; grant execute on function public.nx_quiz_state(p_match uuid) to authenticated;

-- [13] nx_room_capacity
revoke all on function public.nx_room_capacity(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_room_capacity(p_room uuid) to authenticated;

-- [13] nx_room_change_game
revoke all on function public.nx_room_change_game(p_room uuid, p_game text) from public, anon, authenticated; grant execute on function public.nx_room_change_game(p_room uuid, p_game text) to anon; grant execute on function public.nx_room_change_game(p_room uuid, p_game text) to authenticated;

-- [13] nx_room_close
revoke all on function public.nx_room_close(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_room_close(p_room uuid) to authenticated;

-- [13] nx_room_join
revoke all on function public.nx_room_join(p_room uuid, p_role text) from public, anon, authenticated; grant execute on function public.nx_room_join(p_room uuid, p_role text) to authenticated;

-- [13] nx_room_kick
revoke all on function public.nx_room_kick(p_room uuid, p_user uuid) from public, anon, authenticated; grant execute on function public.nx_room_kick(p_room uuid, p_user uuid) to authenticated;

-- [13] nx_room_leave
revoke all on function public.nx_room_leave(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_room_leave(p_room uuid) to anon; grant execute on function public.nx_room_leave(p_room uuid) to authenticated;

-- [13] nx_room_member_role
revoke all on function public.nx_room_member_role(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_room_member_role(p_room uuid) to anon; grant execute on function public.nx_room_member_role(p_room uuid) to authenticated;

-- [13] nx_room_open
revoke all on function public.nx_room_open(p_title text, p_private boolean, p_game text) from public, anon, authenticated; grant execute on function public.nx_room_open(p_title text, p_private boolean, p_game text) to authenticated;

-- [13] nx_room_ping
revoke all on function public.nx_room_ping(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_room_ping(p_room uuid) to authenticated;

-- [13] nx_room_select_players
revoke all on function public.nx_room_select_players(p_room uuid, p_users uuid[]) from public, anon, authenticated; grant execute on function public.nx_room_select_players(p_room uuid, p_users uuid[]) to anon; grant execute on function public.nx_room_select_players(p_room uuid, p_users uuid[]) to authenticated;

-- [13] nx_room_send_message
revoke all on function public.nx_room_send_message(p_room uuid, p_text text) from public, anon, authenticated; grant execute on function public.nx_room_send_message(p_room uuid, p_text text) to anon; grant execute on function public.nx_room_send_message(p_room uuid, p_text text) to authenticated;

-- [13] nx_room_set_capacity
revoke all on function public.nx_room_set_capacity(p_room uuid, p_capacity integer) from public, anon, authenticated; grant execute on function public.nx_room_set_capacity(p_room uuid, p_capacity integer) to authenticated;

-- [13] nx_room_set_locked
revoke all on function public.nx_room_set_locked(p_room uuid, p_locked boolean) from public, anon, authenticated; grant execute on function public.nx_room_set_locked(p_room uuid, p_locked boolean) to authenticated;

-- [13] nx_room_set_muted
revoke all on function public.nx_room_set_muted(p_room uuid, p_user uuid, p_muted boolean) from public, anon, authenticated; grant execute on function public.nx_room_set_muted(p_room uuid, p_user uuid, p_muted boolean) to authenticated;

-- [13] nx_room_set_prefs
revoke all on function public.nx_room_set_prefs(p_room uuid, p_prefs jsonb) from public, anon, authenticated; grant execute on function public.nx_room_set_prefs(p_room uuid, p_prefs jsonb) to authenticated;

-- [13] nx_room_set_role
revoke all on function public.nx_room_set_role(p_room uuid, p_user uuid, p_role text) from public, anon, authenticated; grant execute on function public.nx_room_set_role(p_room uuid, p_user uuid, p_role text) to authenticated;

-- [13] nx_room_set_settings
revoke all on function public.nx_room_set_settings(p_room uuid, p_settings jsonb) from public, anon, authenticated; grant execute on function public.nx_room_set_settings(p_room uuid, p_settings jsonb) to authenticated;

-- [13] nx_room_transfer_host
revoke all on function public.nx_room_transfer_host(p_room uuid, p_user uuid) from public, anon, authenticated; grant execute on function public.nx_room_transfer_host(p_room uuid, p_user uuid) to authenticated;

-- [13] nx_set_ready
revoke all on function public.nx_set_ready(p_room uuid, p_ready boolean) from public, anon, authenticated; grant execute on function public.nx_set_ready(p_room uuid, p_ready boolean) to anon; grant execute on function public.nx_set_ready(p_room uuid, p_ready boolean) to authenticated;

-- [13] nx_staff_put
revoke all on function public.nx_staff_put(p_rows jsonb, p_replace boolean) from public, anon, authenticated;

-- [13] nx_start_match
revoke all on function public.nx_start_match(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_start_match(p_room uuid) to anon; grant execute on function public.nx_start_match(p_room uuid) to authenticated;

-- [13] nx_start_match_quick
revoke all on function public.nx_start_match_quick(p_room uuid) from public, anon, authenticated;

-- [13] nx_start_room_match
revoke all on function public.nx_start_room_match(p_room uuid) from public, anon, authenticated; grant execute on function public.nx_start_room_match(p_room uuid) to anon; grant execute on function public.nx_start_room_match(p_room uuid) to authenticated;

-- [13] nx_t_admin
revoke all on function public.nx_t_admin(p_t uuid, p_action text, p_reason text) from public, anon, authenticated; grant execute on function public.nx_t_admin(p_t uuid, p_action text, p_reason text) to authenticated;

-- [13] nx_t_admin_match
revoke all on function public.nx_t_admin_match(p_m uuid, p_action text, p jsonb) from public, anon, authenticated; grant execute on function public.nx_t_admin_match(p_m uuid, p_action text, p jsonb) to authenticated;

-- [13] nx_t_can_manage
revoke all on function public.nx_t_can_manage(t uuid, u uuid) from public, anon, authenticated; grant execute on function public.nx_t_can_manage(t uuid, u uuid) to anon; grant execute on function public.nx_t_can_manage(t uuid, u uuid) to authenticated;

-- [13] nx_t_checkin
revoke all on function public.nx_t_checkin(p_t uuid) from public, anon, authenticated; grant execute on function public.nx_t_checkin(p_t uuid) to authenticated;

-- [13] nx_t_code_create
revoke all on function public.nx_t_code_create(p_t uuid, p_max_uses integer, p_expires_at timestamp with time zone, p_requires_approval boolean, p_count integer) from public, anon, authenticated; grant execute on function public.nx_t_code_create(p_t uuid, p_max_uses integer, p_expires_at timestamp with time zone, p_requires_approval boolean, p_count integer) to authenticated;

-- [13] nx_t_code_peek
revoke all on function public.nx_t_code_peek(p_code text) from public, anon, authenticated; grant execute on function public.nx_t_code_peek(p_code text) to authenticated;

-- [13] nx_t_code_revoke
revoke all on function public.nx_t_code_revoke(p_code uuid) from public, anon, authenticated; grant execute on function public.nx_t_code_revoke(p_code uuid) to authenticated;

-- [13] nx_t_decide
revoke all on function public.nx_t_decide(p_t uuid, p_user uuid, p_approve boolean, p_note text) from public, anon, authenticated; grant execute on function public.nx_t_decide(p_t uuid, p_user uuid, p_approve boolean, p_note text) to authenticated;

-- [13] nx_t_dispute
revoke all on function public.nx_t_dispute(p_m uuid, p_reason text) from public, anon, authenticated; grant execute on function public.nx_t_dispute(p_m uuid, p_reason text) to authenticated;

-- [13] nx_t_gem_budget_left
revoke all on function public.nx_t_gem_budget_left(u uuid, p_except uuid) from public, anon, authenticated; grant execute on function public.nx_t_gem_budget_left(u uuid, p_except uuid) to anon; grant execute on function public.nx_t_gem_budget_left(u uuid, p_except uuid) to authenticated;

-- [13] nx_t_is_admin
revoke all on function public.nx_t_is_admin(u uuid) from public, anon, authenticated; grant execute on function public.nx_t_is_admin(u uuid) to anon; grant execute on function public.nx_t_is_admin(u uuid) to authenticated;

-- [13] nx_t_is_organizer
revoke all on function public.nx_t_is_organizer(u uuid) from public, anon, authenticated; grant execute on function public.nx_t_is_organizer(u uuid) to anon; grant execute on function public.nx_t_is_organizer(u uuid) to authenticated;

-- [13] nx_t_join_code
revoke all on function public.nx_t_join_code(p_code text) from public, anon, authenticated; grant execute on function public.nx_t_join_code(p_code text) to authenticated;

-- [13] nx_t_logs
revoke all on function public.nx_t_logs(p_t uuid) from public, anon, authenticated; grant execute on function public.nx_t_logs(p_t uuid) to authenticated;

-- [13] nx_t_mark_read
revoke all on function public.nx_t_mark_read() from public, anon, authenticated; grant execute on function public.nx_t_mark_read() to authenticated;

-- [13] nx_t_my_role
revoke all on function public.nx_t_my_role() from public, anon, authenticated; grant execute on function public.nx_t_my_role() to authenticated;

-- [13] nx_t_ready
revoke all on function public.nx_t_ready(p_m uuid) from public, anon, authenticated; grant execute on function public.nx_t_ready(p_m uuid) to authenticated;

-- [13] nx_t_register
revoke all on function public.nx_t_register(p_t uuid, p_code text) from public, anon, authenticated; grant execute on function public.nx_t_register(p_t uuid, p_code text) to authenticated;

-- [13] nx_t_remove_entry
revoke all on function public.nx_t_remove_entry(p_t uuid, p_user uuid, p_note text) from public, anon, authenticated; grant execute on function public.nx_t_remove_entry(p_t uuid, p_user uuid, p_note text) to authenticated;

-- [13] nx_t_report
revoke all on function public.nx_t_report(p_game uuid, p_winner_seat integer, p_s0 integer, p_s1 integer) from public, anon, authenticated; grant execute on function public.nx_t_report(p_game uuid, p_winner_seat integer, p_s0 integer, p_s1 integer) to authenticated;

-- [13] nx_t_save
revoke all on function public.nx_t_save(p jsonb) from public, anon, authenticated; grant execute on function public.nx_t_save(p jsonb) to authenticated;

-- [13] nx_t_set_runner
revoke all on function public.nx_t_set_runner(p_t uuid, p_user uuid, p_add boolean) from public, anon, authenticated; grant execute on function public.nx_t_set_runner(p_t uuid, p_user uuid, p_add boolean) to authenticated;

-- [13] nx_t_set_seed
revoke all on function public.nx_t_set_seed(p_t uuid, p_user uuid, p_seed integer) from public, anon, authenticated; grant execute on function public.nx_t_set_seed(p_t uuid, p_user uuid, p_seed integer) to authenticated;

-- [13] nx_t_standings
revoke all on function public.nx_t_standings(p_t uuid) from public, anon, authenticated; grant execute on function public.nx_t_standings(p_t uuid) to authenticated;

-- [13] nx_t_tick
revoke all on function public.nx_t_tick() from public, anon, authenticated;

-- [13] nx_t_visible
revoke all on function public.nx_t_visible(t uuid) from public, anon, authenticated; grant execute on function public.nx_t_visible(t uuid) to anon; grant execute on function public.nx_t_visible(t uuid) to authenticated;

-- [13] nx_t_withdraw
revoke all on function public.nx_t_withdraw(p_t uuid) from public, anon, authenticated; grant execute on function public.nx_t_withdraw(p_t uuid) to authenticated;

-- [13] nx_talk_rooms
revoke all on function public.nx_talk_rooms() from public, anon, authenticated; grant execute on function public.nx_talk_rooms() to authenticated;

-- [13] nx_unlimited
revoke all on function public.nx_unlimited(u uuid) from public, anon, authenticated; grant execute on function public.nx_unlimited(u uuid) to anon; grant execute on function public.nx_unlimited(u uuid) to authenticated;

-- [13] nx_update_room
revoke all on function public.nx_update_room(p_room uuid, p_seats integer, p_settings jsonb) from public, anon, authenticated; grant execute on function public.nx_update_room(p_room uuid, p_seats integer, p_settings jsonb) to anon; grant execute on function public.nx_update_room(p_room uuid, p_seats integer, p_settings jsonb) to authenticated;

-- [13] nx_wallet_push
revoke all on function public.nx_wallet_push() from public, anon, authenticated;

