"""Run from the existing backend environment's scheduled worker, never a public route.

Database claims serialize per-user caps across workers. APNs acceptance is not
OS delivery. A timeout is unknown and is never automatically resent.
"""
import logging
import os
from datetime import datetime, timedelta, timezone
from app.services.supabase_client import get_supabase_raw
from app.services import push_notifications

log = logging.getLogger(__name__)


def dispatch(limit=50):
    if os.environ.get('FINDEZ_PERSONALIZATION_PUSH_ENABLED') != '1': return {'configured':False,'accepted':0}
    if push_notifications._credentials() is None: return {'configured':False,'accepted':0}
    client = get_supabase_raw()
    candidates = client.rpc('findez_personalization_candidates', {'p_limit':min(100,max(1,limit))}).execute().data or []
    accepted = 0
    for row in candidates:
        try:
            claimed = client.rpc('findez_personalization_claim', {'p_id':row['id']}).execute().data
            if not claimed: continue
            cutoff=(datetime.now(timezone.utc)-timedelta(days=90)).isoformat()
            devices=client.table('push_devices').select('device_token,environment').eq('user_id',claimed['user_id']).eq('enabled',True).eq('personalization_destinations',True).gte('updated_at',cutoff).order('updated_at',desc=True).limit(1).execute().data or []
            # One most-recent active device: no multi-device notification amplification.
            ready=client.rpc('findez_personalization_delivery_ready', {'p_id':row['id']}).execute().data
            if not devices or ready is not True:
                client.table('personalization_notifications').update({'state':'resolved'}).eq('id',row['id']).eq('state','sending').execute()
                continue
            body = 'An item crossed your saved low-stock threshold. Open it to check.' if claimed['category']=='low_stock' else 'A scan is still waiting for review. Open it to finish.'
            ok=push_notifications._send(devices[0],title='FindEZ',body=body,
                data={'action':'personalization','notification_id':row['id'], 'recipient_user_id':claimed['user_id']},
                thread_id='findez-'+claimed['category'], max_attempts=1, collapse_id=row['id'])
            update={'state':'accepted' if ok else 'unknown'}
            if ok: update['accepted_at']=datetime.now(timezone.utc).isoformat()
            client.table('personalization_notifications').update(update).eq('id',row['id']).eq('state','sending').execute()
            accepted+=int(ok)
        except Exception:
            # A lost response leaves a consumed slot, not a duplicate send.
            log.warning('personalization_dispatch_unavailable')
    return {'configured':True,'accepted':accepted}


def main():
    result=dispatch()
    get_supabase_raw().rpc('findez_personalization_cleanup',{}).execute()
    print(result)  # Aggregate counts only, never tokens or content.


if __name__=='__main__': main()
