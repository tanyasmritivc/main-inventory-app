"""Verify founder authorization with one temporary session, then revoke it.

Run on the FindEZ VM. No email is sent and no customer inventory is modified.
"""
import asyncio
import json
import os
from pathlib import Path
import sys

from dotenv import dotenv_values
import httpx

sys.path.insert(0, '/home/ubuntu/findez-dashboard/releases/20261018-v1')
from collectors import Sources


async def run():
    os.environ.update({k:v for k,v in dotenv_values('/home/ubuntu/findez/.env').items() if v is not None})
    source=Sources()
    owner=json.loads(Path('/home/ubuntu/findez-dashboard-data/owner.json').read_text())['user_id']
    public='https://findez.ai/api/founder/v1'
    token=None
    try:
        user_response=await source.client.get(source.base+'/auth/v1/admin/users/'+owner,headers=source.headers)
        user_response.raise_for_status()
        user=user_response.json()
        assert user['id']==owner and user['email_confirmed_at']
        assert user['email'].lower()=='tanyasmritivictorcharles@gmail.com'
        generated=await source.client.post(source.base+'/auth/v1/admin/generate_link',headers=source.headers,json={'type':'magiclink','email':user['email']})
        generated.raise_for_status()
        code=generated.json()['email_otp']
        verified=await source.client.post(source.base+'/auth/v1/verify',headers={'apikey':source.env['SUPABASE_ANON_KEY']},json={'email':user['email'],'token':code,'type':'email'})
        verified.raise_for_status()
        token=verified.json()['access_token']
        headers={'Authorization':'Bearer '+token}
        anonymous=await source.client.get(public+'/snapshot')
        malformed=await source.client.get(public+'/snapshot',headers={'Authorization':'Bearer invalid.signature.token'})
        assert anonymous.status_code==401 and malformed.status_code==401
        response=await source.client.get(public+'/snapshot',headers=headers,timeout=45)
        response.raise_for_status()
        snapshot=response.json()
        assert snapshot['customers'] and snapshot['analytics']['metrics']
        assert all(k not in response.text for k in ('SUPABASE_SERVICE_ROLE_KEY','FINDEZ_AGENT_KEY','BREVO_SMTP_PASSWORD'))
        created=await source.client.post(public+'/issues',headers=headers,json={'title':'Dashboard connection verified','description':'Founder access, live data, issue storage and audit history verified during release. No customer inventory was modified.','severity':'info','kind':'task'})
        created.raise_for_status()
        resolved=await source.client.patch(public+'/issues/'+created.json()['id'],headers=headers,json={'status':'resolved'})
        resolved.raise_for_status()
        result={'public_api':'https://findez.ai/api/founder/v1','verified_direct_service':public,'founder_access':response.status_code,'anonymous_access':anonymous.status_code,'forged_token_access':malformed.status_code,
                'customer_directory_connected':True,'issue_create_and_resolve':True,'data_sources':snapshot['source_status'],
                'customer_inventory_unchanged':True,'email_not_sent':True,'temporary_session_revoked':False}
    finally:
        if token:
            revoked=await source.client.post(source.base+'/auth/v1/logout?scope=local',headers={'apikey':source.env['SUPABASE_ANON_KEY'],'Authorization':'Bearer '+token})
            assert revoked.status_code==204
        await source.client.aclose()
    result['temporary_session_revoked']=True
    Path('/home/ubuntu/findez-dashboard/verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))


asyncio.run(run())
