#!/usr/bin/env python3
"""Opt-in real HTTP scan acceptance using disposable, marked QA accounts only.

Requires httpx and FINDEZ_QA_API_BASE, FINDEZ_QA_AUTH_BASE,
FINDEZ_QA_SERVICE_KEY. Never prints credentials, photos, item text or signed URLs.
See docs/plans/scan-test-plan.md for the repeatable automated/manual matrix.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import time
from uuid import uuid4
from urllib.parse import unquote, urlparse

import httpx


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def scan(client, api, headers, content, *, preview=True):
    started = last = time.monotonic()
    max_gap = 0
    keepalives = 0
    events = []
    first_progress = None
    payload = {
        'message': 'Auto extract the items in this photo. Keep a draft for review before saving.',
        'auto_extract': 'true', 'supports_capture': 'true',
        'supports_task_actions': 'true', 'supports_item_management': 'true',
        'preview_only': str(preview).lower(), 'request_id': str(uuid4()),
    }
    with client.stream('POST', api + '/worlds/personal/ai_photo_question',
                       headers=headers, data=payload,
                       files={'file': ('qa-photo.jpg', content, 'image/jpeg')}) as response:
        require(response.status_code == 200, f'scan HTTP {response.status_code}')
        require('text/event-stream' in response.headers.get('content-type', ''), 'not SSE')
        data = []
        for line in response.iter_lines():
            now = time.monotonic()
            max_gap = max(max_gap, now - last)
            last = now
            require(now - started < 300, 'scan exceeded five-minute acceptance deadline')
            if line.startswith(':'):
                keepalives += 1
            elif line.startswith('data:'):
                data.append(line[5:].lstrip())
            elif not line and data:
                event = json.loads('\n'.join(data))
                data = []
                require(event.get('type') != 'error', 'server returned scan error')
                events.append(event)
                if event.get('type') == 'status' and first_progress is None:
                    first_progress = round(now - started, 2)
                if event.get('type') == 'done':
                    break  # Client must not wait for TCP EOF after terminal receipt.
    done = [e for e in events if e.get('type') == 'done']
    require(len(done) == 1, 'missing terminal receipt')
    draft = done[0].get('answer_context', {}).get('chat_capture', {})
    require(draft.get('status') == 'draft' and draft.get('id'), 'missing durable draft')
    rows = draft.get('items', [])
    require(rows, 'fixture returned no items')
    require(all(r['item'].get('image_url') and r['item'].get('scan_evidence') for r in rows),
            'missing item crop or evidence')
    require(max_gap < 120, 'stream exceeded mobile idle timeout')
    return done[0]['conversation_id'], draft, {
        'seconds': round(time.monotonic() - started, 2),
        'first_progress_seconds': first_progress, 'max_line_gap_seconds': round(max_gap, 2),
        'keepalives': keepalives, 'items': len(rows),
        'unknown_items': sum(r['item']['name'].lower().startswith('unknown') for r in rows),
        'terminal_draft': True,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-disposable-writes', action='store_true', required=True)
    parser.add_argument('--regular', type=Path, required=True)
    parser.add_argument('--crowded', type=Path)
    parser.add_argument('--legacy-web', action='store_true', help='Also exercise the old extra-reply contract')
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    api = os.environ['FINDEZ_QA_API_BASE'].rstrip('/')
    auth_base = os.environ['FINDEZ_QA_AUTH_BASE'].rstrip('/')
    key = os.environ['FINDEZ_QA_SERVICE_KEY']
    bucket = os.environ.get('FINDEZ_QA_BUCKET', 'item-images')
    require(api.startswith('https://') or api.startswith('http://127.0.0.1:'), 'HTTPS or localhost required')
    regular = args.regular.read_bytes()
    crowded = args.crowded.read_bytes() if args.crowded else None
    report = {'cases': [], 'cleanup': [], 'client_ui_tested': False}
    marker = 'scan-acceptance-' + secrets.token_hex(8)
    accounts = []
    admin = {'apikey': key, 'Authorization': 'Bearer ' + key}
    client = httpx.Client(timeout=httpx.Timeout(connect=20, read=120, write=30, pool=20))

    def request(method, path, *, headers=None, status=200, **kwargs):
        response = client.request(method, api + path, headers=headers, **kwargs)
        require(response.status_code == status, f'{method} acceptance HTTP {response.status_code}, expected {status}')
        return response.json() if response.content else None

    def auth(method, path, **kwargs):
        response = client.request(method, auth_base + '/auth/v1' + path, headers=admin, **kwargs)
        require(response.is_success, f'QA auth HTTP {response.status_code}')
        return response.json() if response.content else None

    def run_case(name, action):
        try:
            result = action() or {}
            entry = {'name': name, 'passed': True, **result}
        except Exception as error:
            # Only assertion text written by this runner is safe to emit.
            entry = {'name': name, 'passed': False, 'error_type': type(error).__name__}
            if isinstance(error, AssertionError):
                entry['reason'] = str(error)
        report['cases'].append(entry)
        print(json.dumps(entry), flush=True)

    try:
        for _ in range(2):
            email = marker + '-' + secrets.token_hex(4) + '@example.test'
            password = secrets.token_urlsafe(32)
            user = auth('POST', '/admin/users', json={'email': email, 'password': password,
                'email_confirm': True, 'app_metadata': {'findez_qa_run': marker}})
            accounts.append({'id': user['id']})
            token = auth('POST', '/token?grant_type=password', json={'email': email, 'password': password})['access_token']
            accounts[-1]['headers'] = {'Authorization': 'Bearer ' + token, 'Accept': 'text/event-stream'}
        owner, foreign = accounts
        def invalid_inputs():
            request('POST', '/worlds/personal/ai_photo_question', status=401)
            request('POST', '/worlds/personal/ai_photo_question', headers=owner['headers'], status=422,
                    files={'file': ('bad.jpg', b'not an image', 'image/jpeg')})
            return {'anonymous_denied': True, 'invalid_image_rejected': True}
        run_case('authentication-and-invalid-image', invalid_inputs)

        def check_scan(content, *, preview=True, save=False, minimum=1):
            cid, draft, result = scan(client, api, owner['headers'], content, preview=preview)
            print(json.dumps({'scan_completed': result, 'preview_only': preview}), flush=True)
            require(len(draft['items']) >= minimum, 'fixture detected fewer regions than acceptance minimum')
            path = f'/worlds/personal/conversations/{cid}/captures/{draft["id"]}'
            recovered = request('GET', path, headers=owner['headers'])['capture']
            require(recovered['id'] == draft['id'] and len(recovered['items']) == len(draft['items']), 'draft reload lost items')
            denied = client.get(api + path, headers=foreign['headers'])
            require(denied.status_code in (403, 404), 'foreign account read a private draft')
            # Storage URLs are locators, not bearer grants. Match both clients:
            # fetch private pixels through the authorized application endpoint.
            photo_path = unquote(urlparse(draft['items'][0]['item']['image_url']).path.split('/' + bucket + '/', 1)[1])
            require(photo_path.startswith(owner['id'] + '/'), 'unexpected QA image owner')
            photo = client.get(api + '/media/item-image', params={'path': photo_path}, headers=owner['headers'])
            require(photo.status_code == 200 and photo.headers.get('content-type', '').startswith('image/'), 'crop not readable')
            require(client.get(api + '/media/item-image', params={'path': photo_path}, headers=foreign['headers']).status_code == 404,
                    'foreign account read private crop')
            result.update(draft_reload=True, foreign_denied=True, crop_readable=True)
            if save:
                inv = request('POST', '/inventory-workspaces/personal/inventories', headers=owner['headers'],
                              json={'name': 'Disposable scan acceptance'})['inventory']['inventory_id']
                space = request('POST', f'/inventories/{inv}/spaces', headers=owner['headers'],
                                json={'name': 'QA scan destination'})['space']['id']
                bound = request('PATCH', path, headers=owner['headers'], json={'revision': draft['revision'],
                    'changes': {'inventory_id': inv, 'space_id': space}})['capture']
                body = {'revision': bound['revision'], 'confirm_items': True, 'allow_duplicates': False}
                saved = request('POST', path + '/save', headers=owner['headers'], json=body)['capture']
                require(saved['status'] == 'saved', 'explicit save not confirmed')
                again = request('POST', path + '/save', headers=owner['headers'], json=body)['capture']
                require(again['receipt'] == saved['receipt'], 'save replay changed receipt')
                response = client.get(auth_base + '/rest/v1/items', headers=admin,
                    params={'user_id': 'eq.' + owner['id'], 'inventory_id': 'eq.' + inv, 'select': 'item_id,location'})
                require(response.status_code == 200, 'cannot verify QA-only saved rows')
                items = response.json()
                require(len(items) == saved['receipt']['saved_count'] == len(draft['items']), 'save replay duplicated or lost items')
                require(all(item['location'] == 'QA scan destination' for item in items), 'wrong save destination')
                result.update(save_as_is=True, save_replay_no_duplicates=True, saved_items=len(items))
            return result

        run_case('regular-draft-save-replay', lambda: check_scan(regular, save=True))
        run_case('regular-repeat', lambda: check_scan(regular))
        if args.legacy_web:
            run_case('legacy-web-extra-reply', lambda: check_scan(regular, preview=False))
        if crowded:
            run_case('crowded-more-than-eight', lambda: check_scan(crowded, minimum=9))
    finally:
        for account in accounts:
            try:
                uid = account['id']
                require(auth('GET', '/admin/users/' + uid)['app_metadata'].get('findez_qa_run') == marker,
                        'refusing to clean an unmarked account')
                removed = 0
                while True:
                    listing = client.post(auth_base + '/storage/v1/object/list/' + bucket, headers=admin,
                                          json={'prefix': uid, 'limit': 1000, 'offset': 0})
                    require(listing.status_code == 200, 'QA image list failed')
                    paths = [uid + '/' + f['name'] for f in listing.json() if f.get('id')]
                    if not paths:
                        break
                    removal = client.request('DELETE', auth_base + '/storage/v1/object/' + bucket,
                                             headers=admin, json={'prefixes': paths})
                    require(removal.is_success, 'QA image cleanup failed')
                    removed += len(paths)
                auth('DELETE', '/admin/users/' + uid)
                require(client.get(auth_base + '/auth/v1/admin/users/' + uid, headers=admin).status_code == 404,
                        'QA account removal unconfirmed')
                report['cleanup'].append({'passed': True, 'images_removed': removed})
            except Exception as error:
                report['cleanup'].append({'passed': False, 'error_type': type(error).__name__})
        client.close()
        args.report.write_text(json.dumps(report, indent=2) + '\n')
    require(report['cases'] and all(c['passed'] for c in report['cases'] + report['cleanup']),
            'acceptance failed; see sanitized report')


if __name__ == '__main__':
    main()
