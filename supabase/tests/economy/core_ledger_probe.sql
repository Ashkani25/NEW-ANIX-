-- ANIX · Economy E1 probe (core). Run AFTER the ledger migration inside BEGIN; ... ROLLBACK; (never commits).
-- Uses the user in probe_cfg; every check appends to pg_temp.probe; the last select returns all of them.
create temp table probe(n serial, check_name text, ok boolean, detail jsonb);
create temp table probe_cfg as select '53853bcb-22d8-4647-b7e3-f781878e42d9'::uuid as u;
grant all on probe, probe_cfg to authenticated;
grant usage on sequence probe_n_seq to authenticated;

insert into probe(check_name, ok, detail)
select 'opening rows = 2 per profile', (select count(*) from nx_wallet_ledger where source = 'opening') = 2 * (select count(*) from profiles),
       jsonb_build_object('rows', (select count(*) from nx_wallet_ledger));
insert into probe(check_name, ok, detail) select 'audit clean after backfill', not exists (select 1 from nx_wallet_audit()), null;

-- core function: credit, idempotency, strict, clamp
insert into probe(check_name, ok, detail)
select 'apply +5 coins', (r ->> 'ok')::boolean and (r ->> 'applied_coins')::int = 5, r
  from (select nx_wallet_apply((select u from probe_cfg), 5, 0, 'probe', 'x', 'probe:1') r) s;
insert into probe(check_name, ok, detail)
select 'apply same idem = dup', (r ->> 'dup')::boolean and (r ->> 'applied_coins')::int = 0, r
  from (select nx_wallet_apply((select u from probe_cfg), 5, 0, 'probe', 'x', 'probe:1') r) s;
insert into probe(check_name, ok, detail)
select 'strict overspend refused', not (r ->> 'ok')::boolean and r ->> 'error' = 'insufficient_coins', r
  from (select nx_wallet_apply((select u from probe_cfg), -100000000, 0, 'probe', null, null, 'strict') r) s;
insert into probe(check_name, ok, detail)
select 'clamp overspend -> 0 + shortfall', (r ->> 'coins')::int = 0 and (r ->> 'short_coins')::int > 0, r
  from (select nx_wallet_apply((select u from probe_cfg), -100000000, 0, 'probe', null, 'probe:2', 'clamp') r) s;
insert into probe(check_name, ok, detail)
select 'restore via apply', (r ->> 'ok')::boolean, r
  from (select nx_wallet_apply((select u from probe_cfg), 576, 0, 'probe_restore', null, 'probe:3') r) s;

-- untracked direct change is still ledgered
update profiles set gems = gems + 1 where id = (select u from probe_cfg);
insert into probe(check_name, ok, detail)
select 'direct update ledgered as untracked', l.reason like 'untracked:%' and l.source = 'trigger' and l.delta = 1, to_jsonb(l)
  from (select * from nx_wallet_ledger where user_id = (select u from probe_cfg) order by id desc limit 1) l;
update profiles set gems = gems - 1 where id = (select u from probe_cfg);

-- append-only
do $$ begin
  begin
    update nx_wallet_ledger set delta = 0 where id = (select min(id) from nx_wallet_ledger);
    insert into probe(check_name, ok) values ('ledger update blocked', false);
  exception when others then insert into probe(check_name, ok, detail) values ('ledger update blocked', true, to_jsonb(sqlerrm)); end;
  begin
    delete from nx_wallet_ledger where id = (select min(id) from nx_wallet_ledger);
    insert into probe(check_name, ok) values ('ledger delete blocked', false);
  exception when others then insert into probe(check_name, ok, detail) values ('ledger delete blocked', true, to_jsonb(sqlerrm)); end;
end $$;

-- games bridge: normal delta, replay, shortfall
insert into probe(check_name, ok, detail)
select 'bridge -10 applied', (r ->> 'applied')::int = 1, r from (select nx_bridge_apply_batch(jsonb_build_array(
  jsonb_build_object('id', 900000001, 'user_id', (select u from probe_cfg), 'xp', 0, 'coins', -10, 'gems', 0, 'reason', 'cosmetic:probe')
)) r) s;
insert into probe(check_name, ok, detail)
select 'bridge replay ignored', (r ->> 'applied')::int = 0, r from (select nx_bridge_apply_batch(jsonb_build_array(
  jsonb_build_object('id', 900000001, 'user_id', (select u from probe_cfg), 'xp', 0, 'coins', -10, 'gems', 0, 'reason', 'cosmetic:probe')
)) r) s;
select nx_bridge_apply_batch(jsonb_build_array(
  jsonb_build_object('id', 900000002, 'user_id', (select u from probe_cfg), 'xp', 3, 'coins', -999999, 'gems', 0, 'reason', 'tournament_entry_fee')));
insert into probe(check_name, ok, detail)
select 'bridge shortfall flagged', f.id is not null and (select coins from profiles where id = (select u from probe_cfg)) = 0, to_jsonb(f)
  from (select 1) one left join nx_wallet_flags f on f.kind = 'games_shortfall' and f.ref = 'games_tx:900000002';
insert into probe(check_name, ok, detail)
select 'bridge ledger reason', exists (select 1 from nx_wallet_ledger where idem_key = 'games_tx:900000001' and reason = 'games:cosmetic:probe'), null;
select nx_wallet_apply((select u from probe_cfg), 566, 0, 'probe_restore', null, 'probe:4');

-- IAP credit / dup / refund
insert into probe(check_name, ok, detail)
select 'iap credit', (r ->> 'ok')::boolean and (r ->> 'granted_gems')::int = 100, r
  from (select nx_iap_credit((select u from probe_cfg), 'bazaar', 'anix_gems_100', 'probe_tok_1', 'o1', now(), '{}'::jsonb) r) s;
insert into probe(check_name, ok, detail)
select 'iap credit dup', (r ->> 'dup')::boolean and (r ->> 'ok')::boolean, r
  from (select nx_iap_credit((select u from probe_cfg), 'bazaar', 'anix_gems_100', 'probe_tok_1') r) s;
insert into probe(check_name, ok, detail)
select 'iap token other user refused', not (r ->> 'ok')::boolean and r ->> 'error' = 'token_used', r
  from (select nx_iap_credit('32ae6ed7-4331-4e26-bd73-deb1bf65e38e', 'bazaar', 'anix_gems_100', 'probe_tok_1') r) s;
insert into probe(check_name, ok, detail)
select 'iap ledger one credit row', (select count(*) from nx_wallet_ledger where idem_key = 'iap:bazaar:probe_tok_1') = 1, null;
insert into probe(check_name, ok, detail)
select 'iap refund debits', (r ->> 'debited_gems')::int = 100 and (r ->> 'short_gems')::int = 0, r
  from (select nx_iap_mark_refunded('bazaar', 'probe_tok_1', '{"purchaseState":1}') r) s;
insert into probe(check_name, ok, detail)
select 'iap refund idempotent', (r ->> 'dup')::boolean, r
  from (select nx_iap_mark_refunded('bazaar', 'probe_tok_1') r) s;
-- refund after spending: credit 1000 gems, spend them, refund -> shortfall flagged
select nx_iap_credit((select u from probe_cfg), 'bazaar', 'anix_gems_1000', 'probe_tok_2');
select nx_wallet_apply((select u from probe_cfg), 0, -1200, 'probe_spend', null, 'probe:5');
create temp table probe_r as select nx_iap_mark_refunded('bazaar', 'probe_tok_2') r;
insert into probe(check_name, ok, detail)
select 'iap refund after spend -> shortfall flag', (r ->> 'short_gems')::int > 0
       and exists (select 1 from nx_wallet_flags where kind = 'iap_refund_shortfall' and ref = 'iap:bazaar:probe_tok_2'), r
  from probe_r;
insert into probe(check_name, ok, detail)
select 'recheck_due lists credited only', not exists (select 1 from nx_iap_recheck_due(500, 45, 1) d where d.purchase_token like 'probe_tok_%'), null;

-- as the player (authenticated)
select set_config('request.jwt.claims', jsonb_build_object('sub', (select u from probe_cfg), 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', (select u::text from probe_cfg), true);
set local role authenticated;
insert into probe(check_name, ok, detail) select 'client: nx_wallet', (r ->> 'ok')::boolean, r from (select nx_wallet() r) s;
insert into probe(check_name, ok, detail) select 'client: daily gems +10', (r ->> 'granted')::int = 10, r from (select nx_daily_gems() r) s;
insert into probe(check_name, ok, detail) select 'client: daily gems again = 0', (r ->> 'granted')::int = 0, r from (select nx_daily_gems() r) s;
insert into probe(check_name, ok, detail) select 'client: coin purchase', (r ->> 'ok')::boolean, r
  from (select nx_purchase('decor_tablet_stand', 0) r) s;
insert into probe(check_name, ok, detail) select 'client: award daily', true, r
  from (select nx_award('daily', 0, 0, 'probe-key-daily-1') r) s;
insert into probe(check_name, ok, detail) select 'client: history readable', jsonb_array_length(r) > 0, jsonb_build_object('n', jsonb_array_length(r), 'top', r -> 0)
  from (select nx_wallet_history(10) r) s;
do $$ begin
  begin
    perform nx_wallet_apply(auth.uid(), 1000000, 0, 'hack');
    insert into probe(check_name, ok) values ('client cannot call nx_wallet_apply', false);
  exception when insufficient_privilege then insert into probe(check_name, ok) values ('client cannot call nx_wallet_apply', true); end;
  begin
    update profiles set coins = coins + 1000 where id = auth.uid();
    insert into probe(check_name, ok, detail) values ('client direct coin edit neutralised', (select coins from profiles where id = auth.uid()) < 100000, null);
  exception when others then insert into probe(check_name, ok, detail) values ('client direct coin edit neutralised', true, to_jsonb(sqlerrm)); end;
end $$;
insert into probe(check_name, ok, detail) select 'client sees only own ledger', (select count(distinct user_id) from nx_wallet_ledger) = 1, null;
reset role;

insert into probe(check_name, ok, detail)
select 'audit clean at end', not exists (select 1 from nx_wallet_audit()), (select jsonb_agg(to_jsonb(a)) from nx_wallet_audit() a);
select n, check_name, ok, detail from probe order by n;
