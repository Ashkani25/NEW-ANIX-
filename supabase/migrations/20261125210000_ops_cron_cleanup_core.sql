-- Ops (core project eisstodgncimypdawisy): unschedule pg_cron jobs that only tick the retired v1 backend or duplicate
-- the games project. Rollback: supabase/maintenance/rollback_ops_cron_core.sql.
--
-- Why each is dead (checked live 2026-11-25):
--   nexora-sweep       _sweep_rooms()     rooms / room_players / matches / tournament_matches   (S6-locked, 0 rows)
--   nexora-worldcup    wc_tick()          legacy tournaments (S6-locked); only keeps re-creating a monthly world_cup row
--   nexora-tournaments tournament_tick()  legacy tournaments v2 / tournament_matches           (S6-locked)
--   nexora-games       gm_sweep()         legacy game_state / rooms (S6-locked, 0 rows) — every 10 s
--   nexora-cups        cup_tick()         legacy cups / cup_matches (S6-locked, 0 rows)  — every 10 s
--   nx_t_tick          nx_t_tick()        core copy of nx_tournaments/nx_t_* (0 rows); the app's tournaments live on the
--                                         games project, whose own nx_t_tick job keeps running.
-- Kept: nexora-cleanup (_daily_cleanup), nx-storage-purge (live storage purge). No data is touched; functions stay.
do $$
declare j text;
begin
  foreach j in array array['nexora-sweep','nexora-worldcup','nexora-tournaments','nexora-games','nexora-cups','nx_t_tick'] loop
    if exists (select 1 from cron.job where jobname = j) then perform cron.unschedule(j); end if;
  end loop;
end $$;
