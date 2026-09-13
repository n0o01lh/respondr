import { createBrowserClient } from '@supabase/ssr'
import type { Database } from '@respondr/types'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || ''
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || ''

if (supabaseUrl == '' || supabaseAnonKey == '') {
  throw new Error(
    'Missed environment variables NEXT_PUBLIC_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_ANON_KEY'
  )
}

export function createClient() {
  return createBrowserClient<Database>(supabaseUrl, supabaseAnonKey, {})
}
