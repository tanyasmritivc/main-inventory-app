import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    const jwt = authHeader.replace('Bearer', '').trim()
    if (!jwt) {
      throw new Error('Invalid authorization header')
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    // Service role client for DB + admin auth operations.
    // NOTE: Do NOT forward the user's JWT as the client's Authorization header,
    // otherwise PostgREST will execute under the user's RLS policies.
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Get user from JWT (token passed explicitly)
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(jwt)

    if (authError || !user) {
      throw new Error('Invalid authentication')
    }

    const userId = user.id

    const deleteRows = async (table: string, column = 'user_id') => {
      const { error } = await supabase.from(table).delete().eq(column, userId)
      if (error) {
        console.error(`delete-user: ${table} cleanup failed`, error.message)
        throw new Error('We could not delete your account. Please try again.')
      }
    }

    // Remove private document objects using the paths recorded in the database.
    const documentPaths: string[] = []
    const pageSize = 500
    for (let offset = 0; ; offset += pageSize) {
      const { data: documents, error } = await supabase
        .from('documents')
        .select('storage_path')
        .eq('user_id', userId)
        .range(offset, offset + pageSize - 1)
      if (error) {
        console.error('delete-user: document lookup failed', error.message)
        throw new Error('We could not delete your account. Please try again.')
      }
      documentPaths.push(
        ...(documents ?? [])
          .map((document) => document.storage_path)
          .filter((path): path is string => Boolean(path)),
      )
      if ((documents ?? []).length < pageSize) break
    }
    for (let offset = 0; offset < documentPaths.length; offset += pageSize) {
      const { error } = await supabase.storage
        .from('documents')
        .remove(documentPaths.slice(offset, offset + pageSize))
      if (error) {
        console.error('delete-user: document storage cleanup failed', error.message)
        throw new Error('We could not delete your account. Please try again.')
      }
    }

    // Item images are stored directly inside a folder named with the user UUID.
    const itemImagesBucket = Deno.env.get('SUPABASE_STORAGE_BUCKET') ?? 'item-images'
    // Always re-list from offset zero after each removal; advancing an offset
    // while deleting would skip the objects that shift into the first page.
    for (;;) {
      const { data: imageObjects, error } = await supabase.storage
        .from(itemImagesBucket)
        .list(userId, { limit: pageSize, offset: 0 })
      if (error) {
        console.error('delete-user: image storage lookup failed', error.message)
        throw new Error('We could not delete your account. Please try again.')
      }
      const imagePaths = (imageObjects ?? [])
        .filter((object) => object.id)
        .map((object) => `${userId}/${object.name}`)
      if (imagePaths.length === 0) break
      const { error: removeError } = await supabase.storage.from(itemImagesBucket).remove(imagePaths)
      if (removeError) {
        console.error('delete-user: image storage cleanup failed', removeError.message)
        throw new Error('We could not delete your account. Please try again.')
      }
    }

    // Keep this ordered: several tables have foreign-key relationships and the
    // auth identity must remain until every application row has been removed.
    await deleteRows('team_notification_reads')
    await deleteRows('team_activity', 'actor_id')
    await deleteRows('team_spaces', 'linked_by')
    await deleteRows('team_members', 'member_user_id')
    await deleteRows('team_memberships')
    await deleteRows('checkouts')
    await deleteRows('item_events')
    await deleteRows('documents')
    await deleteRows('activity_log')
    await deleteRows('usage_counters')
    await deleteRows('query_logs')
    await deleteRows('conversation_history')
    await deleteRows('conversation_sessions')
    await deleteRows('conversations')
    await deleteRows('user_memory')
    await deleteRows('user_plan')
    await deleteRows('usage_limits')
    await deleteRows('bins')
    await deleteRows('items')
    await deleteRows('spaces')
    await deleteRows('team_shares', 'owner_user_id')
    await deleteRows('teams', 'owner_user_id')
    await deleteRows('profiles', 'id')

    // Delete the auth user using admin API
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId)
    
    if (deleteError) {
      console.error('delete-user: auth cleanup failed', deleteError.message)
      throw new Error('We could not delete your account. Please try again.')
    }

    return new Response(
      JSON.stringify({ success: true }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    console.error('Error in delete-user function:', message)
    return new Response(
      JSON.stringify({ error: message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
