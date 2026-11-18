"""Direct APNs, one recorded attempt per request; unknown outcomes never retry."""
import logging
import random
import time
from datetime import datetime, timedelta, timezone
import httpx
from app.services import push_notifications
from app.services.supabase_client import get_supabase_raw

log = logging.getLogger(__name__)


def send_once(device, notification_id, recipient, content):
    credentials = push_notifications._credentials()
    if credentials is None:
        return 'failed', 'not_configured'
    host = 'api.sandbox.push.apple.com' if device.get('environment') == 'sandbox' else 'api.push.apple.com'
    try:
        with httpx.Client(http2=True, timeout=10.0) as client:
            response = client.post(
                f"https://{host}/3/device/{device['device_token']}",
                headers={'authorization': f'bearer {push_notifications._authorization()}',
                         'apns-topic': credentials[3], 'apns-push-type': 'alert',
                         'apns-priority': '10', 'apns-collapse-id': notification_id,
                         'apns-expiration': '0'},
                json={'aps': {'alert': content, 'sound': 'default', 'category': 'PERSONALIZATION'},
                      'action': 'personalization', 'notification_id': notification_id,
                      'recipient_user_id': recipient})
    except httpx.HTTPError:
        return 'unknown', 'transport_unknown'
    if response.status_code == 200:
        return 'accepted', None
    try:
        reason = response.json().get('reason')
    except (ValueError, AttributeError):
        reason = None
    if response.status_code == 410 or reason in {'BadDeviceToken','DeviceTokenNotForTopic','Unregistered'}:
        get_supabase_raw().table('push_devices').update({'enabled': False}).eq('device_token', device['device_token']).eq('user_id', recipient).execute()
        return 'failed', 'invalid_token'
    if response.status_code == 429 or response.status_code >= 500:
        return 'retry', 'provider_transient'
    return 'failed', 'provider_rejected'


def dispatch(limit=50):
    client = get_supabase_raw()
    candidates = client.rpc('findez_personalization_candidates', {'p_limit': min(100,max(1,limit))}).execute().data or []
    accepted = 0
    for row in candidates:
        try:
            claimed = client.rpc('findez_personalization_claim', {'p_id': row['id']}).execute().data
            if not claimed:
                continue
            cutoff = (datetime.now(timezone.utc)-timedelta(days=90)).isoformat()
            devices = client.table('push_devices').select('device_token,environment').eq('user_id',claimed['user_id']).eq('enabled',True).eq('personalization_destinations',True).gte('updated_at',cutoff).order('updated_at',desc=True).limit(1).execute().data or []
            if not devices:
                client.rpc('findez_notification_cancel_reservation', {'p_id':row['id']}).execute()
                continue
            # Most-recent active device avoids duplicate banners across phones.
            for attempt in range(3):
                content = client.rpc('findez_notification_content', {'p_id':row['id']}).execute().data
                revision = content.pop('revision',None) if content else None
                if not content or revision is None or client.rpc('findez_notification_begin_attempt', {'p_id':row['id'],'p_device':devices[0]['device_token'],'p_revision':revision}).execute().data is not True:
                    client.rpc('findez_notification_cancel_reservation', {'p_id':row['id']}).execute()
                    break
                state, error = send_once(devices[0], row['id'], claimed['user_id'], content)
                if state == 'retry' and attempt < 2:
                    time.sleep(2**attempt + random.uniform(0,1))
                    continue
                if state == 'retry':
                    state = 'failed'
                client.rpc('findez_notification_finish', {'p_id':row['id'],'p_result':state,'p_error':error}).execute()
                accepted += int(state == 'accepted')
                break
        except Exception:
            # Logs never include tokens, notification content or transport URLs.
            log.warning('notification_dispatch_unavailable')
    return {'configured':True,'accepted':accepted}
