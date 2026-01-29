import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error(
    'Missing Supabase environment variables. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in your .env file.'
  )
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Public client: avoids any persisted session or auto-refresh for signed-out flows.
export const supabasePublic = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    storageKey: 'sb-public-auth-token',
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false,
  },
})

// Helper to get public storage URLs without hardcoding the project ID
export const getStorageUrl = (bucket: string, path: string): string => {
  return `${supabaseUrl}/storage/v1/object/public/${bucket}/${path}`
}
