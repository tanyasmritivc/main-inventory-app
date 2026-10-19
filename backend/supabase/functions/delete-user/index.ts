import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Content-Type': 'application/json' }
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers })

// Apple codes and refresh tokens are used only for this request, never stored or
// logged. The token endpoint authenticates the code; its signed identity must
// match the Apple identity already attached to the verified Supabase account.
async function revokeAppleAuthorization(user: { identities?: { provider: string; id?: string; identity_data?: Record<string, unknown> }[] }, body: Record<string, unknown>) {
  const identity = user.identities?.find(item => item.provider === 'apple')
  if (!identity) return null
  const code = body.apple_authorization_code
  const refresh = body.apple_refresh_token
  const clientId = body.apple_client_id
  const allowed = (Deno.env.get('APPLE_CLIENT_IDS') ?? '').split(',')
  if (typeof clientId !== 'string' || !allowed.includes(clientId) ||
      !(typeof code === 'string' && code.length > 0 && code.length <= 4096) &&
      !(typeof refresh === 'string' && refresh.length > 0 && refresh.length <= 4096)) {
    return reply(409, { code: 'APPLE_REAUTH_REQUIRED', error: 'Confirm Sign in with Apple again before deleting this account. On the web, sign out and sign back in with Apple, or use the latest FindEZ iOS app.' })
  }
  const pem = Deno.env.get('APPLE_SIGN_IN_PRIVATE_KEY') || atob(Deno.env.get('APPLE_SIGN_IN_PRIVATE_KEY_BASE64') ?? '')
  const keyId = Deno.env.get('APPLE_SIGN_IN_KEY_ID')
  const teamId = Deno.env.get('APPLE_TEAM_ID')
  if (!pem || !keyId || !teamId) return reply(503, { code: 'APPLE_REVOCATION_UNAVAILABLE', error: 'Apple account deletion is temporarily unavailable. No account data was deleted. Please try again later.' })
  try {
    const encode = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
    const text = (value: unknown) => encode(new TextEncoder().encode(JSON.stringify(value)))
    const raw = Uint8Array.from(atob(pem.replace(/-----[^-]+-----|\s/g, '')), char => char.charCodeAt(0))
    const key = await crypto.subtle.importKey('pkcs8', raw, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign'])
    const now = Math.floor(Date.now() / 1000)
    const payload = `${text({ alg: 'ES256', kid: keyId })}.${text({ iss: teamId, iat: now, exp: now + 300, aud: 'https://appleid.apple.com', sub: clientId })}`
    const signature = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(payload))
    const secret = `${payload}.${encode(new Uint8Array(signature))}`
    const exchange = await fetch('https://appleid.apple.com/auth/token', {
      method: 'POST', signal: AbortSignal.timeout(15000),
      body: new URLSearchParams({ client_id: clientId, client_secret: secret,
        ...(typeof code === 'string' && code ? { grant_type: 'authorization_code', code } : { grant_type: 'refresh_token', refresh_token: refresh as string }) }),
    })
    if (!exchange.ok) return reply(409, { code: 'APPLE_REAUTH_REQUIRED', error: 'Apple could not confirm this authorization. No account data was deleted. Confirm Sign in with Apple again and retry.' })
    const tokens = await exchange.json()
    const encoded = typeof tokens.id_token === 'string' ? tokens.id_token.split('.')[1] : ''
    const claims = JSON.parse(atob(encoded.replace(/-/g, '+').replace(/_/g, '/')))
    const subject = identity.identity_data?.sub ?? identity.id
    if (!subject || claims.sub !== subject || claims.aud !== clientId || claims.iss !== 'https://appleid.apple.com' || typeof claims.exp !== 'number' || claims.exp <= now) {
      return reply(403, { code: 'APPLE_IDENTITY_MISMATCH', error: 'Use the Apple account connected to this FindEZ account. No account data was deleted.' })
    }
    const token = tokens.refresh_token || refresh || tokens.access_token
    if (typeof token !== 'string' || !token) throw new Error('Missing revocation token')
    const revoked = await fetch('https://appleid.apple.com/auth/revoke', {
      method: 'POST', signal: AbortSignal.timeout(15000),
      body: new URLSearchParams({ client_id: clientId, client_secret: secret, token,
        token_type_hint: tokens.refresh_token || refresh ? 'refresh_token' : 'access_token' }),
    })
    if (!revoked.ok) throw new Error('Apple did not acknowledge revocation')
    return null
  } catch {
    return reply(503, { code: 'APPLE_REVOCATION_UNAVAILABLE', error: 'Apple authorization could not be revoked. No account data was deleted. Please try again.' })
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers })
  if (req.method !== 'POST') return reply(405, { error: 'Use POST to delete your account.' })
  try {
    const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '')
    if (!token) return reply(401, { error: 'Please sign in again.' })
    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data: { user }, error: authError } = await client.auth.getUser(token)
    if (authError || !user) return reply(401, { error: 'Please sign in again.' })
    const actor = user.id
    // Preflight creates only a private manifest. A blocked request deletes nothing.
    const { data: prepared, error: prepareError } = await client.rpc('findez_prepare_account_deletion', { p_actor: actor })
    if (prepareError) return reply(503, { error: 'Account deletion checks could not finish. No cleanup was started. Please try again.' })
    if (!prepared?.ready) return reply(409, prepared ?? { error: 'Account deletion could not be prepared.' })
    const files: { kind: string; path: string; owner: string }[] = []
    for (const [bucket, prefix, kind] of [
      [Deno.env.get('SUPABASE_STORAGE_BUCKET') ?? 'item-images', actor, 'image'],
      ['documents', `${actor}/docs`, 'document'], ['profile-photos', actor, 'profile'],
    ]) {
      for (let offset = 0; ; offset += 500) {
        const { data, error } = await client.storage.from(bucket).list(prefix, { limit: 500, offset })
        if (error) return reply(503, { error: 'Account file checks could not finish. No cleanup was started. Please try again.' })
        files.push(...(data ?? []).filter(object => object.id).map(object => ({ kind, path: `${prefix}/${object.name}`, owner: actor })))
        if ((data ?? []).length < 500) break
      }
    }
    const { data: snapshot, error: snapshotError } = await client.rpc('findez_prepare_account_deletion', { p_actor: actor, p_files: files })
    if (snapshotError) return reply(503, { error: 'Account deletion could not be prepared. No cleanup was started.' })
    if (!snapshot?.ready) return reply(409, snapshot ?? { error: 'Account deletion could not be prepared.' })
    let body: Record<string, unknown> = {}
    if (user.identities?.some(identity => identity.provider === 'apple')) {
      try { body = await req.json() } catch { /* Older clients receive a reauthentication instruction. */ }
      if (!body || typeof body !== 'object' || Array.isArray(body)) body = {}
      const appleError = await revokeAppleAuthorization(user, body)
      if (appleError) return appleError
    }
    // Auth performs identity/session removal and canonical cascades atomically.
    // Never erase records or objects first: failed Auth must leave them intact.
    const { error: deleteError } = await client.auth.admin.deleteUser(actor)
    if (deleteError) return reply(409, { error: 'Account deletion could not finish. No file cleanup was started. Refresh your organizations and workspaces, then try again or contact info@findez.ai.' })
    // Durable background cleanup can resume even if the user is now signed out.
    await client.rpc('findez_finish_account_deletion', { p_actor: actor })
    return reply(200, { success: true, file_cleanup_pending: true })
  } catch {
    return reply(503, { error: 'Deletion could not be confirmed. Refresh and try again or contact info@findez.ai.' })
  }
})
