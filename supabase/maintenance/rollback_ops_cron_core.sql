-- Rollback for 20261125210000_ops_cron_cleanup_core.sql (core project eisstodgncimypdawisy).
-- Re-creates the six legacy/duplicate pg_cron jobs exactly as they were scheduled on 2026-11-25 (jobid in brackets;
-- pg_cron assigns new ids on re-schedule). Run as postgres in the SQL editor / Management API.
select cron.schedule('nexora-sweep',       '* * * * *',  'select public._sweep_rooms()');     -- [5]  legacy rooms/matches
select cron.schedule('nexora-worldcup',    '7 * * * *',  'select public.wc_tick()');          -- [6]  legacy monthly world cup
select cron.schedule('nexora-tournaments', '* * * * *',  'select public.tournament_tick()');  -- [12] legacy tournaments v2
select cron.schedule('nexora-games',       '10 seconds', 'select public.gm_sweep()');         -- [20] legacy game_state
select cron.schedule('nexora-cups',        '10 seconds', 'select public.cup_tick()');         -- [24] legacy cups
select cron.schedule('nx_t_tick',          '* * * * *',  'select public.nx_t_tick()');        -- [25] core copy of games' nx_t_tick
