import { createClient } from '@supabase/supabase-js'
import type { Database } from '@respondr/types'

const supabaseUrl = process.env.SUPABASE_URL
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY

if (!supabaseUrl || !supabaseServiceRoleKey) {
  throw new Error('Missed environment variables SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY')
}

export const supabase = createClient<Database>(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
  },
})
