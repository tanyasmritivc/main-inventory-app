"""Exercise the final engagement slot from independent PostgreSQL connections."""
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4

if not (
    os.environ.get("FINDEZ_DISPOSABLE_SQL_TESTS") == "1"
    and os.environ.get("PGDATABASE", "").startswith("notification_")
    and os.environ.get("PGHOST") in {"localhost", "127.0.0.1"}
):
    raise RuntimeError("Requires a disposable localhost notification test database")


def sql(statement):
    result = subprocess.run(
        ["psql", "-XAtq", "-v", "ON_ERROR_STOP=1"],
        input=statement, text=True, capture_output=True, timeout=20, check=True,
    )
    return result.stdout.strip()


def check_race():
    user, inventory = uuid4(), uuid4()
    sql(f"""
        INSERT INTO auth.users VALUES ('{user}');
        INSERT INTO app_inventories(inventory_id, owner_user_id) VALUES ('{inventory}', '{user}');
        INSERT INTO test_grants VALUES ('{user}', '{inventory}', 'owner');
        INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations)
        VALUES ('{user}','{user}','sandbox',true,now(),true);
        UPDATE notification_preferences SET quiet_enabled=false, daily_enabled=false,
            cleanup_insights=true, weekly_recap=true, timezone='UTC' WHERE user_id='{user}';
        INSERT INTO items(item_id,inventory_id,user_id)
            SELECT gen_random_uuid(),'{inventory}','{user}' FROM generate_series(1,4);
        SELECT findez_seed_inventory_pushes(100);
        INSERT INTO notification_delivery_attempts(user_id,category,critical,state)
            VALUES ('{user}','snap',false,'accepted'), ('{user}','add_item',false,'unknown'),
                   ('{user}','locate_item',false,'accepted');
    """)
    ids = sql(f"""SELECT id FROM personalization_notifications WHERE user_id='{user}'
                  AND category IN ('discovery','weekly_insight') ORDER BY category""").splitlines()
    assert len(ids) == 2
    start = Barrier(2)

    def claim(notification):
        start.wait(timeout=10)
        # Hold the winning transaction open while the other connection contends.
        return sql(f"""BEGIN;
                       SELECT findez_personalization_claim('{notification}') IS NOT NULL;
                       SELECT pg_sleep(0.2);
                       COMMIT;""")

    with ThreadPoolExecutor(max_workers=2) as workers:
        assert sorted(workers.map(claim, ids)) == ["f", "t"]
    assert sql(f"""SELECT count(*) FROM notification_delivery_attempts
                   WHERE user_id='{user}' AND state<>'cancelled'""") == "4"
    assert sql(f"""SELECT count(*) FROM personalization_notifications
                   WHERE user_id='{user}' AND suppression_reason='engagement_cap'""") == "1"

    daily = sql(f"""
        UPDATE notification_preferences SET daily_enabled=true WHERE user_id='{user}';
        INSERT INTO personalization_notifications(user_id,category,entity_type,entity_id,condition_key,policy_version)
        VALUES ('{user}','daily_inventory','account',gen_random_uuid(),'daily-inventory/'||(now() AT TIME ZONE 'UTC')::date,1)
        RETURNING id;
    """)
    assert sql(f"SELECT findez_personalization_claim('{daily}') IS NULL") == "t"
    assert sql(f"SELECT suppression_reason FROM personalization_notifications WHERE id='{daily}'") == "engagement_cap"
    # A reservation carried over from yesterday must pass today's budget again before APNs.
    sql(f"""
        INSERT INTO notification_delivery_attempts(notification_id,user_id,category,critical,reserved_at)
        VALUES ('{daily}','{user}','daily_inventory',false,now()-interval '1 day');
        UPDATE personalization_notifications SET state='sending',scheduled_for=now() WHERE id='{daily}';
    """)
    assert sql(f"SELECT findez_notification_begin_attempt('{daily}')") == "f"
    assert sql(f"SELECT state FROM notification_delivery_attempts WHERE notification_id='{daily}'") == "cancelled"


def check_persistent_low_stock():
    user, inventory, item = uuid4(), uuid4(), uuid4()
    actor = f"""SET request.jwt.claims='{{"sub":"{user}"}}';"""
    sql(f"""
        INSERT INTO auth.users VALUES ('{user}');
        INSERT INTO app_inventories(inventory_id,owner_user_id) VALUES ('{inventory}','{user}');
        INSERT INTO test_grants VALUES ('{user}','{inventory}','owner');
        INSERT INTO push_devices(device_token,user_id,environment,enabled,updated_at,personalization_destinations)
        VALUES ('{user}','{user}','sandbox',true,now(),true);
        UPDATE notification_preferences SET quiet_enabled=false,timezone='UTC' WHERE user_id='{user}';
        INSERT INTO items(item_id,inventory_id,user_id,quantity,reorder_enabled,reorder_threshold,location,created_at)
        VALUES ('{item}','{inventory}','{user}',10,true,3,'Bin A',now()-interval '30 days');
    """)
    events = f"SELECT count(*) FROM personalization_notifications WHERE user_id='{user}' AND category='low_stock'"
    sql(actor + f"UPDATE items SET quantity=3 WHERE item_id='{item}'")
    for day, quantity in enumerate([3, 2, 1]):
        day_sql = f"(now() AT TIME ZONE 'UTC')::date + {day}"
        sql(actor + f"""
            UPDATE items SET quantity={quantity} WHERE item_id='{item}';
            SELECT findez_seed_daily_inventory(100,(({day_sql})+time '11:00') AT TIME ZONE 'UTC');
            SELECT findez_seed_inventory_pushes(100);
            SELECT findez_seed_inventory_pushes(100);
        """)
        assert sql(f"SELECT findez_choose_daily_focus('{user}',{day_sql},gen_random_uuid())->>'kind'") == "rediscover"
        assert sql(events) == "1"
    sql(actor + f"UPDATE items SET quantity=12 WHERE item_id='{item}'")
    assert sql(events + " AND state='resolved'") == "1"
    sql(actor + f"UPDATE items SET quantity=2 WHERE item_id='{item}'")
    assert sql(events) == "2"
    assert sql(events + " AND state='pending'") == "1"


if __name__ == "__main__":
    spacing = sql("SELECT spacing FROM notification_channel_policy WHERE singleton")
    try:
        sql("UPDATE notification_channel_policy SET spacing=interval '0'")
        check_race()
        check_persistent_low_stock()
    finally:
        sql(f"UPDATE notification_channel_policy SET spacing=interval '{spacing}'")
    print("PASS: competing engagement reservations, late daily opt-in and midnight provider recheck")
    print("PASS: persistent low stock across three simulated dates, recovery and a fresh crossing")
