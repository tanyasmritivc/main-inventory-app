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
    // Create a Supabase client with the Auth context of the logged in user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    // Create client with service role key for admin operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    })

    // Get user from JWT
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()

    if (authError || !user) {
      throw new Error('Invalid authentication')
    }

    const userId = user.id

    // Delete all user data from all tables
    const deletePromises = []

    // Delete items
    deletePromises.push(
      supabase
        .from('items')
        .delete()
        .eq('user_id', userId)
    )

    // Delete documents
    deletePromises.push(
      supabase
        .from('documents')
        .delete()
        .eq('user_id', userId)
    )

    // Delete activity logs
    deletePromises.push(
      supabase
        .from('activity_log')
        .delete()
        .eq('user_id', userId)
    )

    // Delete profile if exists
    deletePromises.push(
      supabase
        .from('profiles')
        .delete()
        .eq('id', userId)
    )

    // Execute all deletions
    const results = await Promise.allSettled(deletePromises)

    // Check if any deletions failed
    const failures = results.filter(result => result.status === 'rejected')
    if (failures.length > 0) {
      console.error('Some deletions failed:', failures)
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
    console.error('Error in delete-user function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
