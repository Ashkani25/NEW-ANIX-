-- ANIX · Economy E1 probe (games): mirror_put acks tx <= tx_upto and takes core balance. Always rolled back.
begin;
create temp table r as select coins from profiles where id='<some user id>';
-- local spend creates a pending tx
select set_config('nx.reason','probe',true);
update profiles set coins = coins - 7 where id='<some user id>';
create temp table tx as select max(id) id from nx_wallet_tx where user_id='<some user id>';
-- core answers with tx_upto = that tx and a (clamped) authoritative balance 100
select nx_mirror_put(jsonb_build_array(jsonb_build_object('id','<some user id>','username','x','coins',100,'gems',5,'xp',1,'level',1,'tx_upto',(select id from tx))));
select (select coins from profiles where id='<some user id>') coins_after, (select acked_at is not null from nx_wallet_tx where id=(select id from tx)) acked,
       (select count(*) from net.http_request_queue) q;
rollback;
