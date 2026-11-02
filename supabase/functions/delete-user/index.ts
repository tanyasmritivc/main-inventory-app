import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Content-Type': 'application/json' }
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers })
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
