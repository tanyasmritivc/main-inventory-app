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

    // Delete all user data from all tables.
    // IMPORTANT: Supabase JS delete() calls do not throw by default; errors come
    // back on the response. We must check them explicitly to avoid partial deletes
    // followed by deleting the auth user.
    const [itemsRes, docsRes, activityRes, profileRes] = await Promise.all([
      supabase.from('items').delete().eq('user_id', userId),
      supabase.from('documents').delete().eq('user_id', userId),
      supabase.from('activity_log').delete().eq('user_id', userId),
      supabase.from('profiles').delete().eq('id', userId),
    ])

    const deleteErrors = [
      itemsRes.error && `items: ${itemsRes.error.message}`,
      docsRes.error && `documents: ${docsRes.error.message}`,
      activityRes.error && `activity_log: ${activityRes.error.message}`,
      profileRes.error && `profiles: ${profileRes.error.message}`,
    ].filter(Boolean)

    if (deleteErrors.length > 0) {
      console.error('delete-user: failed to delete all user data', deleteErrors)
      throw new Error('Failed to delete all user data')
    }

    // Delete the auth user using admin API
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId)
    
    if (deleteError) {
      throw new Error(`Failed to delete auth user: ${deleteError.message}`)
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
