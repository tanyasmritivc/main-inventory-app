"""Real Chat confirmation races in the composed disposable database only."""
import json
import os
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from resource_permission_concurrency import sql


def main():
    if os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') != '1':
        raise SystemExit('This requires the explicitly prepared disposable database.')
    demo = json.loads(sql("SELECT jsonb_object_agg(key,id) FROM chat_action_demo").stdout.strip())
    owner, actor, inv, space, ws = [demo[key] for key in ('owner', 'editor', 'inventory', 'space', 'workspace')]
    assert sql(f"SELECT email='permission4@example.invalid' FROM auth.users WHERE id='{actor}'").stdout.strip() == 't'
    def proposal():
        action, conversation = str(uuid.uuid4()), str(uuid.uuid4())
        value = {'id': action, 'version': 1, 'inventory_id': inv, 'operation': 'add', 'status': 'pending',
                 'expires_at': '2099-01-01T00:00:00Z', 'items': [{'name': 'Concurrent QA bolt', 'category': 'Other',
                 'quantity': 1, 'location': 'Chat shelf', 'space_id': space}]}
        # Synthetic service-owned setup only; no customer identity/data exists.
        sql(f"INSERT INTO public.conversations(id,user_id,inventory_id,title) VALUES('{conversation}','{actor}','{inv}','Concurrency QA');"
            f"INSERT INTO public.messages(conversation_id,inventory_id,role,content,answer_context) VALUES('{conversation}','{inv}','assistant','Synthetic review','{json.dumps({'pending_actions': [value]})}'::jsonb);")
        return action
    def confirm(action, check=True):
        return sql("BEGIN; SET LOCAL ROLE service_role; SELECT set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);"
                   f"SELECT public.findez_chat_item_action('{actor}','{inv}','{action}','confirm',1000); COMMIT;", check=check)
    action = proposal()
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = [pool.submit(confirm, action) for _ in range(2)]
        [future.result(timeout=15) for future in results]
    expected = str(uuid.UUID(__import__('hashlib').md5(f'{action}:1'.encode()).hexdigest()))
    assert sql(f"SELECT count(*) FROM public.items WHERE item_id='{expected}'").stdout.strip() == '1'
    assert sql(f"SELECT count(*) FROM public.app_access_audit WHERE target_id='{action}'").stdout.strip() == '1'
    action = proposal()
    label = 'chat-revocation-' + uuid.uuid4().hex
    with ThreadPoolExecutor(max_workers=1) as pool:
        revocation = pool.submit(sql, f"BEGIN; SET LOCAL application_name='{label}'; SELECT 1 FROM public.teams WHERE team_id='{ws}' FOR UPDATE;"
                                f"UPDATE public.team_memberships SET role='viewer' WHERE team_id='{ws}' AND user_id='{actor}'; SELECT pg_sleep(1); COMMIT;")
        for _ in range(100):
            if sql(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{label}' AND wait_event='PgSleep'").stdout.strip() == '1':
                break
            time.sleep(.02)
        else:
            raise AssertionError('Revocation never reached the lock barrier')
        result = confirm(action, check=False)
        revocation.result(timeout=15)
    assert result.returncode != 0 and '42501' in result.stderr, result.stderr
    assert sql(f"SELECT count(*) FROM public.app_access_audit WHERE target_id='{action}'").stdout.strip() == '0'
    sql(f"UPDATE public.team_memberships SET role='member' WHERE team_id='{ws}' AND user_id='{actor}'")
    print(json.dumps({'double_confirmation': 'one item and one receipt', 'revocation_race': 'denied', 'passed': True}))


if __name__ == '__main__':
    main()
