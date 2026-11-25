-- #3 follow-up (core): _nx_trusted() is called by the INVOKER trigger functions _nx_profiles_guard / _nx_nx_profiles_guard
-- while the app writes profiles / nx_profiles directly, so the caller needs EXECUTE on it. It only reads current_user
-- and two GUCs that clients cannot set through PostgREST.
grant execute on function public._nx_trusted() to anon, authenticated;
