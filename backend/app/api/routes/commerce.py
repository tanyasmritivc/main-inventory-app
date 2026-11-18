"""Personal or organization-owned commerce connections. No physical stock writes."""
import hmac
import re
import secrets
import time
from datetime import date, datetime, timezone, timedelta
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile
from starlette.concurrency import run_in_threadpool
from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.limiter import limiter
from app.services.commerce import repository as repo
from app.services.commerce.config import settings
from app.services.commerce.models import Provider, ProviderError
from app.services.commerce.providers import ProviderClient, REGIONS, authorization_url
from app.services.commerce.purchase_import import MAX_BYTES, preview
from app.services.commerce.security import digest, seal, shop_domain, unseal, validate_shopify_callback
from app.services.commerce.webhooks import verified_event

from app.api.routes.purchase_email import router as purchase_email_router

router = APIRouter(prefix='/commerce', tags=['commerce'])
router.include_router(purchase_email_router)


@router.post('/webhooks/shopify')
async def shopify_webhook(request: Request):
    # Keep privacy/uninstall processing available even when new connects are off.
    cfg = settings()
    if not cfg.shopify_client_secret:
        raise HTTPException(503, 'Shopify webhooks are not configured.')
    raw = bytearray()
    async for chunk in request.stream():
        raw.extend(chunk)
        if len(raw) > 1024 * 1024:
            raise HTTPException(413, 'Webhook is too large.')
    params = verified_event(bytes(raw), request.headers, cfg.shopify_client_secret.get_secret_value())
    await run_in_threadpool(lambda: repo.execute(repo.get_supabase_raw().rpc('findez_commerce_shopify_event', params)))
    return {'received': True}


@router.get('/connections/{connection_id}/privacy-exports')
def privacy_exports(connection_id: UUID, user: AuthenticatedUser = Depends(get_current_user)):
    c = repo.connection(connection_id, user.user_id)
    rows = repo.execute(repo.get_supabase_raw().table('commerce_privacy_exports')
                        .select('request_id,records,created_at').eq('connection_id', c['id'])
                        .order('created_at', desc=True).limit(100)) or []
    return {'requests': rows, 'delivery': 'Merchant must provide the requested export to the requester; downloading does not send it.'}


class ConnectRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    inventory_id: UUID | None = None  # Legacy clients only.
    scope_type: Literal['personal', 'organization'] = 'personal'
    organization_id: UUID | None = None

    @model_validator(mode='after')
    def validate_owner(self):
        if self.inventory_id and (self.scope_type != 'personal' or self.organization_id):
            raise ValueError('Inventory and owner scope cannot be combined.')
        if (self.scope_type == 'organization') != (self.organization_id is not None):
            raise ValueError('Choose Personal or an organization.')
        return self
    provider: Provider
    external_account: str = Field(default='', max_length=200)
    region: Literal['na', 'eu', 'fe'] = 'na'
    marketplace: str = Field(default='ATVPDKIKX0DER', max_length=30)


class CompleteRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    # Forward decoded callback parameters exactly once. The client must reject
    # duplicate query keys; Shopify's signature covers every supplied parameter.
    parameters: dict[str, str] = Field(max_length=20)


class SyncRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    resource: Literal['catalog', 'orders', 'stock']
    since: datetime | None = None


def failed(actor, c):
    try:
        repo.transition(actor, c['id'], 'fail', {'lease_id': c['lease_id']})
    except HTTPException:
        # The original failure remains visible; an expired claim cannot overwrite
        # a disconnect or a newer sync. Its lease expires independently.
        pass


@router.get('/capabilities')
def capabilities(user: AuthenticatedUser = Depends(get_current_user)):
    cfg = settings()
    result = []
    for provider in ('shopify', 'amazon_seller', 'amazon_consumer'):
        try:
            cfg.require(provider)
            if provider != 'amazon_consumer':
                seal({}, 'configuration-check')
            ready = True
        except HTTPException:
            ready = False
        result.append({'provider': provider, 'configured': ready,
                       'mode': 'purchase_csv' if provider == 'amazon_consumer' else 'merchant_oauth',
                       'physical_stock_writes': False})
    try:
        cfg.require_gmail()
        gmail_ready = True
    except HTTPException:
        gmail_ready = False
    return {'providers': result, 'amazon_gmail': {'configured': gmail_ready, 'mode': 'gmail_oauth'},
            'shopify_buyer': 'not_implemented', 'consumer_cart': 'not_implemented'}


@router.get('/connections')
def list_connections(inventory_id: UUID | None = None, scope_type: Literal['personal', 'organization'] = 'personal',
                     organization_id: UUID | None = None, user: AuthenticatedUser = Depends(get_current_user)):
    settings().require()
    if inventory_id and (scope_type != 'personal' or organization_id):
        raise HTTPException(422, 'Inventory and owner scope cannot be combined.')
    return {'connections': repo.connections(inventory_id, user.user_id) if inventory_id else repo.connections(None, user.user_id, scope_type, organization_id)}


@router.post('/connections')
@limiter.limit('5/minute')
def connect(request: Request, body: ConnectRequest, user: AuthenticatedUser = Depends(get_current_user)):
    settings().require(body.provider)
    if body.inventory_id:
        repo.authorize(body.inventory_id, user.user_id)
    else:
        repo.authorize_scope(body.scope_type, body.organization_id, user.user_id)
    account = body.external_account
    if body.provider == 'shopify':
        account = shop_domain(account)
    elif body.provider == 'amazon_seller':
        if not re.fullmatch(r'[A-Z0-9]{5,32}', account) or body.marketplace not in REGIONS[body.region][2]:
            raise HTTPException(422, 'Use a valid seller ID and supported marketplace for the chosen region.')
    else:
        account = digest(user.user_id + ':' + str(body.inventory_id)) if body.inventory_id else digest(body.scope_type + ':' + (str(body.organization_id) if body.organization_id else user.user_id))
    state = secrets.token_urlsafe(32)
    url = None
    if body.provider != 'amazon_consumer':
        seal({}, 'configuration-check')
        url = authorization_url(body.provider, account, body.region, state)
    args = (body.provider, account, body.region if body.provider == 'amazon_seller' else '',
            body.marketplace if body.provider == 'amazon_seller' else '', digest(state))
    c = repo.start(user.user_id, body.inventory_id, *args) if body.inventory_id else repo.start_scoped(user.user_id, body.scope_type, body.organization_id, *args)
    return {'connection': repo.public(c), 'authorization_url': url, 'expires_in': 600 if url else None}


@router.post('/connections/{connection_id}/complete')
@limiter.limit('10/minute')
def complete(request: Request, connection_id: UUID, body: CompleteRequest,
             user: AuthenticatedUser = Depends(get_current_user)):
    c = repo.connection(connection_id, user.user_id)
    cfg = settings()
    cfg.require(c['provider'])
    params = body.parameters
    if c['provider'] == 'amazon_consumer':
        raise HTTPException(422, 'Consumer purchase imports do not use OAuth.')
    if any(len(k) > 100 or len(v) > 4096 for k, v in params.items()) or not params.get('state'):
        raise HTTPException(422, 'Invalid authorization parameters.')
    if c['provider'] == 'shopify':
        validate_shopify_callback(params, c['external_account'], cfg.shopify_client_secret.get_secret_value())
        code = params.get('code')
    else:
        if params.get('selling_partner_id') != c['external_account']:
            raise HTTPException(400, 'The authorization does not match this seller account.')
        code = params.get('spapi_oauth_code')
    if not code:
        raise HTTPException(400, 'Authorization was not completed. Connect again.')
    c = repo.transition(user.user_id, c['id'], 'oauth_claim', {'state_hash': digest(params['state'])})
    provider = ProviderClient()
    try:
        tokens = provider.tokens(c, code=code)
        result = repo.transition(user.user_id, c['id'], 'oauth_finish', {
            'lease_id': c['lease_id'], 'token_ciphertext': seal(tokens, c['id']),
            'scopes': [s for s in tokens.get('scope', '').split(',') if s]})
        return {'connection': repo.public(result)}
    except ProviderError as exc:
        failed(user.user_id, c)
        raise HTTPException(exc.status, str(exc)) from None
    except Exception:
        failed(user.user_id, c)
        raise
    finally:
        provider.close()


@router.post('/connections/{connection_id}/sync')
@limiter.limit('3/minute')
def sync(request: Request, connection_id: UUID, body: SyncRequest,
         user: AuthenticatedUser = Depends(get_current_user)):
    c = repo.connection(connection_id, user.user_id)
    settings().require(c['provider'])
    allowed = {'shopify': {'catalog', 'orders'}, 'amazon_seller': {'orders', 'stock'}}
    if body.resource not in allowed.get(c['provider'], set()):
        raise HTTPException(422, 'This connection does not support that sync resource.')
    now = datetime.now(timezone.utc)
    since = body.since or now - timedelta(days=30)
    if since.tzinfo is None or since >= now - timedelta(minutes=2) or since < now - timedelta(days=59):
        raise HTTPException(422, 'Choose an order start time between 59 days ago and two minutes ago, including timezone.')
    c = repo.transition(user.user_id, c['id'], 'sync_claim')
    provider = ProviderClient()
    try:
        tokens = unseal(c['token_ciphertext'], c['id'])
        if tokens['expires_at'] <= time.time() + 120:
            tokens = provider.tokens(c, refresh_token=tokens['refresh_token'])
            repo.transition(user.user_id, c['id'], 'tokens', {
                'lease_id': c['lease_id'], 'token_ciphertext': seal(tokens, c['id'])})
        records = provider.sync(c, tokens['access_token'], body.resource, since.isoformat())
        result = repo.transition(user.user_id, c['id'], 'commit', {
            'lease_id': c['lease_id'], 'resource': body.resource, 'records': records})
        return {'connection': repo.public(result), 'record_count': len(records), 'stock_effect': 'none',
                'coverage': {'resource': body.resource, 'orders_updated_since': since.isoformat() if body.resource == 'orders' else None,
                             'full_order_history': False}}
    except ProviderError as exc:
        failed(user.user_id, c)
        raise HTTPException(exc.status, str(exc)) from None
    except Exception:
        failed(user.user_id, c)
        raise
    finally:
        provider.close()


@router.get('/connections/{connection_id}/records')
def source_records(connection_id: UUID, offset: int = Query(0, ge=0, le=1000000),
                   limit: int = Query(100, ge=1, le=250), user: AuthenticatedUser = Depends(get_current_user)):
    settings().require()
    return repo.records(connection_id, user.user_id, offset, limit)


@router.delete('/connections/{connection_id}')
def disconnect(connection_id: UUID, purge: bool = False, user: AuthenticatedUser = Depends(get_current_user)):
    # Owners can remove their credentials even when feature configuration or
    # inventory access is subsequently revoked. This never deletes physical items.
    c = repo.connection(connection_id, user.user_id, require_access=False)
    if c['provider'] == 'amazon_consumer' and c['status'] == 'connected' and c.get('inventory_id'):
        from app.services.commerce import gmail
        gmail.disconnect(user.user_id, c['inventory_id'], purge)
    return repo.transition(user.user_id, connection_id, 'disconnect', {'purge': purge})


@router.post('/connections/{connection_id}/purchase-file')
@limiter.limit('5/minute')
async def purchase_file(request: Request, connection_id: UUID, file: UploadFile = File(...),
                        confirmed_sha256: str | None = Form(None), user: AuthenticatedUser = Depends(get_current_user)):
    settings().require('amazon_consumer')
    c = repo.connection(connection_id, user.user_id)
    if c['provider'] != 'amazon_consumer' or c['status'] != 'connected':
        raise HTTPException(422, 'Select a connected Amazon consumer import destination.')
    result = await run_in_threadpool(preview, await file.read(MAX_BYTES + 1))
    if confirmed_sha256 is None:
        return {**result, 'committed': False}
    if not re.fullmatch(r'[0-9a-f]{64}', confirmed_sha256) or not hmac.compare_digest(confirmed_sha256, result['sha256']):
        raise HTTPException(409, 'The file changed since preview. Review the new file before confirming.')
    c = repo.transition(user.user_id, c['id'], 'sync_claim')
    try:
        repo.transition(user.user_id, c['id'], 'commit', {
            'lease_id': c['lease_id'], 'resource': 'purchases', 'records': result['records']})
    except Exception:
        failed(user.user_id, c)
        raise
    return {'committed': True, 'count': result['count'], 'sha256': result['sha256'], 'stock_effect': 'none'}


@router.post('/purchase-file/preview')
@limiter.limit('10/minute')
async def preview_purchase_file(request: Request, inventory_id: UUID | None = Form(None), file: UploadFile = File(...),
                                scope_type: Literal['personal', 'organization'] = Form('personal'), organization_id: UUID | None = Form(None),
                                user: AuthenticatedUser = Depends(get_current_user)):
    settings().require('amazon_consumer')
    if inventory_id:
        if scope_type != 'personal' or organization_id:
            raise HTTPException(422, 'Inventory and owner scope cannot be combined.')
        await run_in_threadpool(repo.authorize, inventory_id, user.user_id)
    else:
        await run_in_threadpool(repo.authorize_scope, scope_type, organization_id, user.user_id)
    result = await run_in_threadpool(preview, await file.read(MAX_BYTES + 1))
    return {**result, 'committed': False}


class PurchaseCheckRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    scope_type: Literal['personal', 'organization'] = 'personal'
    organization_id: UUID | None = None
    query: str = Field(min_length=2, max_length=1000)


def purchase_world(scope_type, organization_id):
    if (scope_type == 'organization') != (organization_id is not None):
        raise HTTPException(422, 'Choose Personal or an organization.')
    return str(organization_id) if organization_id else 'personal'


@router.get('/purchases')
def purchase_library(scope_type: Literal['personal', 'organization'] = 'personal',
                     organization_id: UUID | None = None, query: str = Query('', max_length=1000),
                     status: Literal['all', 'active', 'purchased', 'shipped', 'delivered', 'cancelled', 'returned', 'unknown'] = 'all',
                     offset: int = Query(0, ge=0, le=10000), category: str = Query('all', max_length=60),
                     date_from: date | None = None, date_to: date | None = None,
                     sort: Literal['newest', 'oldest', 'frequent', 'name'] = 'newest',
                     inventory: Literal['all', 'matched', 'unmatched'] = 'all', repeated: bool = False,
                     user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.commerce.purchase_intelligence import library
    try:
        return library(user.user_id, purchase_world(scope_type, organization_id), query, status, offset,
                       category=category, date_from=date_from.isoformat() if date_from else None,
                       date_to=date_to.isoformat() if date_to else None, sort=sort, inventory=inventory, repeated=repeated)
    except ValueError:
        raise HTTPException(422, 'Choose valid filters and a start date on or before the end date.') from None


@router.post('/purchase-check')
@limiter.limit('20/minute')
def check_before_buying(request: Request, body: PurchaseCheckRequest, user: AuthenticatedUser = Depends(get_current_user)):
    from app.services.commerce.purchase_intelligence import check
    return check(user.user_id, purchase_world(body.scope_type, body.organization_id), body.query)
