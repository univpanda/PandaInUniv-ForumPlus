import { supabase } from './supabase'

/**
 * PostgreSQL error code for RLS policy violation
 */
const RLS_VIOLATION_CODE = '42501'

/**
 * Check if an error is an RLS policy violation (blocked user or other permission issue)
 */
export function isRLSError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false

  const err = error as { code?: string; message?: string }

  // Check for PostgreSQL RLS violation code
  if (err.code === RLS_VIOLATION_CODE) return true

  // Check for common RLS error messages
  const message = err.message?.toLowerCase() || ''
  return (
    message.includes('policy') ||
    message.includes('permission denied') ||
    message.includes('row-level security')
  )
}

/**
 * Check if current user is blocked and sign them out if so.
 * Returns true if user was blocked and signed out.
 */
export async function checkAndSignOutIfBlocked(): Promise<boolean> {
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return false

    const { data } = await supabase.rpc('get_my_profile_status')
    const profile = (data as Array<{ is_blocked: boolean }> | null)?.[0]

    if (profile?.is_blocked) {
      await supabase.auth.signOut()
      return true
    }

    return false
  } catch {
    // Error checking blocked status - don't sign out
    return false
  }
}

/**
 * Handle mutation errors - check if user is blocked on RLS violations
 * Call this in mutation onError handlers
 */
export async function handleMutationError(error: unknown): Promise<void> {
  if (isRLSError(error)) {
    const wasBlocked = await checkAndSignOutIfBlocked()
    if (wasBlocked) {
      // User was blocked - page will re-render due to auth state change
      // No need to show error message
      return
    }
  }
  // For non-blocked users or non-RLS errors, let the normal error handling proceed
}
