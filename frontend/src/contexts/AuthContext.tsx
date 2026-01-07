import { useEffect, useState, useRef, useCallback, useMemo } from 'react'
import type { ReactNode } from 'react'
import type { User, Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { AuthContext } from './AuthContextType'
import { cleanOAuthHash } from '../utils/url'
import { invalidateUserCache, updateLoginMetadata } from '../lib/cacheApi'
import { generateNewUserIdentity } from '../utils/avatars'

// ============================================================================
// Local Storage Auth Cache - for instant refresh without network delay
// Security: This is UI-only. All actual permissions enforced server-side via RLS.
// ============================================================================
const AUTH_CACHE_KEY = 'panda_auth_profile'
const AUTH_CACHE_TTL = 60 * 60 * 1000 // 1 hour

interface CachedAuthProfile {
  userId: string
  role: string
  isBlocked: boolean
  timestamp: number
}

function getLocalAuthCache(userId: string): CachedAuthProfile | null {
  try {
    const cached = localStorage.getItem(AUTH_CACHE_KEY)
    if (!cached) return null
    const profile = JSON.parse(cached) as CachedAuthProfile
    // Validate: same user and not expired
    if (profile.userId === userId && Date.now() - profile.timestamp < AUTH_CACHE_TTL) {
      return profile
    }
  } catch {
    // Invalid cache
  }
  return null
}

function setLocalAuthCache(userId: string, role: string, isBlocked: boolean): void {
  try {
    const profile: CachedAuthProfile = { userId, role, isBlocked, timestamp: Date.now() }
    localStorage.setItem(AUTH_CACHE_KEY, JSON.stringify(profile))
  } catch {
    // localStorage not available
  }
}

function clearLocalAuthCache(): void {
  try {
    localStorage.removeItem(AUTH_CACHE_KEY)
  } catch {
    // localStorage not available
  }
}

function clearSupabaseAuthStorage(): void {
  try {
    const keysToRemove: string[] = []
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i)
      if (key && key.startsWith('sb-')) {
        keysToRemove.push(key)
      }
    }
    keysToRemove.forEach((key) => localStorage.removeItem(key))
  } catch {
    // localStorage not available
  }

  try {
    const keysToRemove: string[] = []
    for (let i = 0; i < sessionStorage.length; i += 1) {
      const key = sessionStorage.key(i)
      if (key && key.startsWith('sb-')) {
        keysToRemove.push(key)
      }
    }
    keysToRemove.forEach((key) => sessionStorage.removeItem(key))
  } catch {
    // sessionStorage not available
  }
}

function isAuthCallbackUrl(): boolean {
  if (typeof window === 'undefined') return false
  const hash = window.location.hash || ''
  if (hash.includes('access_token=') || hash.includes('refresh_token=') || hash.includes('provider_token=')) {
    return true
  }
  const search = window.location.search || ''
  if (search.includes('code=')) {
    return true
  }
  return false
}

function getSupabaseAuthTokenFromStorage(): { access_token?: string } | null {
  const readFrom = (storage: Storage) => {
    for (let i = 0; i < storage.length; i += 1) {
      const key = storage.key(i)
      if (key && key.startsWith('sb-') && key.endsWith('-auth-token')) {
        const raw = storage.getItem(key)
        if (!raw) return null
        try {
          return JSON.parse(raw) as { access_token?: string }
        } catch {
          return null
        }
      }
    }
    return null
  }

  try {
    return readFrom(localStorage)
  } catch {
    // localStorage not available
  }

  try {
    return readFrom(sessionStorage)
  } catch {
    // sessionStorage not available
  }

  return null
}

function isTokenExpired(accessToken: string): boolean {
  try {
    const payload = accessToken.split('.')[1]
    if (!payload) return false
    const normalized = payload.replace(/-/g, '+').replace(/_/g, '/')
    const padded = normalized + '==='.slice((normalized.length + 3) % 4)
    const decoded = JSON.parse(atob(padded)) as { exp?: number }
    if (!decoded.exp) return false
    // 60s skew to avoid edge-of-expiry issues
    return decoded.exp * 1000 < Date.now() + 60_000
  } catch {
    return false
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [isAdmin, setIsAdmin] = useState(false)
  const [authError, setAuthError] = useState<string | null>(null)

  // Refs to prevent race conditions
  const isInitialized = useRef(false)
  const processingUserId = useRef<string | null>(null)

  const clearAuthError = useCallback(() => setAuthError(null), [])

  // Verify user profile with Supabase (used for background verification)
  const verifyUserProfile = useCallback(
    async (
      newSession: Session,
      isActive: () => boolean
    ): Promise<{ role: string; isBlocked: boolean } | null> => {
      const userId = newSession.user.id

      const { data, error } = await supabase.rpc('get_my_profile_status')

      if (!isActive()) return null

      const status = (data as Array<{ role: string; is_blocked: boolean }> | null)?.[0]

      if (error || !status) {
        // Profile doesn't exist (new user) - create it
        const email = newSession.user.email
        if (email) {
          // Generate username and avatar on frontend
          const identity = generateNewUserIdentity()

          const { error: createError } = await supabase.rpc('create_user_profile', {
            p_user_id: userId,
            p_email: email,
            p_username: identity.username,
            p_avatar_path: identity.avatarPath,
          })

          if (createError) {
            console.error('Failed to create user profile:', createError)
            return null
          }
        }
        // New user - default role
        return { role: 'user', isBlocked: false }
      }

      return { role: status.role ?? 'user', isBlocked: status.is_blocked ?? false }
    },
    []
  )

  // Unified function to handle user session - prevents duplicate calls
  const handleUserSession = useCallback(
    async (newSession: Session | null, isActive: () => boolean, isInitialLoad: boolean = false): Promise<boolean> => {
      if (!newSession?.user) {
        if (isActive()) {
          processingUserId.current = null // Reset on sign out
          clearLocalAuthCache()
          if (!isAuthCallbackUrl()) {
            clearSupabaseAuthStorage()
          }
          setSession(null)
          setUser(null)
          setIsAdmin(false)
        }
        return true
      }

      const userId = newSession.user.id

      // Prevent duplicate processing for the same user, but allow if same user trying again
      // (could be a retry after previous attempt timed out)
      if (processingUserId.current === userId) {
        // Only skip if we're still actively processing (give it 100ms grace)
        return false
      }
      processingUserId.current = userId

      try {
        // On initial load, try local cache for instant display
        if (isInitialLoad) {
          const localCache = getLocalAuthCache(userId)
          if (localCache && !localCache.isBlocked) {
            // Instant display from cache
            setSession(newSession)
            setUser(newSession.user)
            setIsAdmin(localCache.role === 'admin')
            setLoading(false)

            // Verify in background (don't block UI)
            verifyUserProfile(newSession, isActive).then((profile) => {
              if (!profile || !isActive()) return

              if (profile.isBlocked) {
                // User was blocked - sign out
                clearLocalAuthCache()
                setSession(null)
                setUser(null)
                setIsAdmin(false)
                supabase.auth.signOut()
              } else {
                // Update cache and state if role changed
                setLocalAuthCache(userId, profile.role, false)
                setIsAdmin(profile.role === 'admin')
              }
            })

            // Update login info in background
            updateLoginInfo(userId, newSession.access_token)

            processingUserId.current = null
            return true
          }
        }

        // No cache or not initial load - verify with Supabase
        const profile = await verifyUserProfile(newSession, isActive)

        if (!isActive()) {
          processingUserId.current = null
          return false
        }

        if (!profile) {
          processingUserId.current = null
          return false
        }

        if (profile.isBlocked) {
          // Clear state and sign out silently
          clearLocalAuthCache()
          setSession(null)
          setUser(null)
          setIsAdmin(false)
          await supabase.auth.signOut()
          processingUserId.current = null
          return true
        }

        // Update local cache
        setLocalAuthCache(userId, profile.role, false)

        setSession(newSession)
        setUser(newSession.user)
        setIsAdmin(profile.role === 'admin')

        // Update login info in background (don't await)
        updateLoginInfo(userId, newSession.access_token)

        processingUserId.current = null
        return true
      } catch {
        // Auth error - don't log sensitive details to console
        processingUserId.current = null
        return false
      }
    },
    [verifyUserProfile]
  )

  const updateLoginInfo = async (userId: string, authToken?: string) => {
    try {
      if (authToken) {
        const cached = await updateLoginMetadata(authToken)
        if (cached) {
          invalidateUserCache(userId, authToken)
          return
        }
      }

      await supabase.rpc('update_login_metadata', {
        p_last_login: new Date().toISOString(),
        p_last_ip: null,
        p_last_location: null,
      })

      // Invalidate cache after profile update
      if (authToken) {
        invalidateUserCache(userId, authToken)
      }
    } catch {
      // Supabase update failed - silently continue (non-critical)
    }
  }

  useEffect(() => {
    let isActive = true
    const checkIsActive = () => isActive
    let initResolved = false

    // Reset processingUserId on mount to prevent stale state from previous renders
    processingUserId.current = null

    // Check for expired tokens on mount and clear them properly
    // This ensures stale auth data doesn't cause API calls to hang
    const token = getSupabaseAuthTokenFromStorage()
    const hasExpiredToken = token?.access_token && isTokenExpired(token.access_token)
    if (hasExpiredToken) {
      clearLocalAuthCache()
      // signOut with scope: 'local' clears both storage AND in-memory Supabase client state
      supabase.auth.signOut({ scope: 'local' }).catch(() => {
        // If signOut fails, manually clear storage as fallback
        clearSupabaseAuthStorage()
      })
    }

    // Timeout to prevent infinite loading state - show error to user
    const timeoutId = setTimeout(async () => {
      if (!isActive) return
      clearLocalAuthCache()
      // Use signOut to properly clear both storage AND in-memory Supabase client state
      // This prevents stale tokens from being used in subsequent API calls
      try {
        await supabase.auth.signOut({ scope: 'local' })
      } catch {
        // If signOut fails, manually clear storage
        clearSupabaseAuthStorage()
      }
      setSession(null)
      setUser(null)
      setIsAdmin(false)
      setAuthError('Authentication timed out. Please refresh and try again.')
      setLoading(false)
      isInitialized.current = true
      initResolved = true
      try {
        const reloadFlag = 'panda_auth_timeout_reloaded'
        const hasReloaded = sessionStorage.getItem(reloadFlag)
        if (!hasReloaded) {
          sessionStorage.setItem(reloadFlag, 'true')
          setTimeout(() => {
            if (isActive) {
              window.location.reload()
            }
          }, 100)
        }
      } catch {
        // sessionStorage not available; skip auto-reload
      }
    }, 5000)

    const finalizeInit = async (session: Session | null) => {
      if (!isActive || initResolved) return
      initResolved = true
      clearTimeout(timeoutId)

      // Hard fallback - if handleUserSession hangs, force completion
      const handled = await Promise.race([
        handleUserSession(session, checkIsActive, true),
        new Promise<boolean>((resolve) => setTimeout(() => resolve(false), 2000)),
      ])

      if (!handled && isActive) {
        // Force clean state if session handling failed/timed out
        // Use signOut to clear both storage AND in-memory Supabase client state
        clearLocalAuthCache()
        try {
          await supabase.auth.signOut({ scope: 'local' })
        } catch {
          clearSupabaseAuthStorage()
        }
        setSession(null)
        setUser(null)
        setIsAdmin(false)
      }

      isInitialized.current = true
      if (isActive) setLoading(false)

      // Clear reload guard on successful init so future timeouts can still trigger reload
      if (handled) {
        try {
          sessionStorage.removeItem('panda_auth_timeout_reloaded')
        } catch {
          // sessionStorage not available
        }
      }
    }

    // Get initial session - only runs once on mount
    const initSession = async () => {
      try {
        const sessionPromise = supabase.auth.getSession().then(({ data }) => data.session)
        const timeoutPromise = new Promise<Session | null>((resolve) =>
          setTimeout(() => resolve(null), 1500)
        )
        const session = await Promise.race([sessionPromise, timeoutPromise])
        // Always finalize - even if session is null (user not logged in or timeout)
        await finalizeInit(session)
      } catch {
        // Auth initialization failed - don't log details to console
        // Still mark as initialized so future auth changes are processed
        if (isActive && !initResolved) {
          isInitialized.current = true
          setLoading(false)
        }
      }
    }

    // Listen for auth changes (sign in, sign out, token refresh)
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      if (!isActive) return

      if (!isInitialized.current) {
        await finalizeInit(session)
        return
      }

      try {
        // Timeout wrapper to prevent infinite loading on hung RPC calls
        const handled = await Promise.race([
          handleUserSession(session, checkIsActive),
          new Promise<boolean>((resolve) => setTimeout(() => resolve(false), 5000)),
        ])

        // Clean up OAuth hash from URL after successful sign-in
        if (session?.user) {
          cleanOAuthHash()
        }

        // If handling timed out and user had a session, force set state
        if (!handled && session?.user && isActive) {
          setSession(session)
          setUser(session.user)
          // Default to non-admin, will verify in background
          setIsAdmin(false)
        }
      } catch {
        // Auth state change error - silently continue
      }
      if (isActive) setLoading(false)
    })

    initSession()

    return () => {
      isActive = false
      clearTimeout(timeoutId)
      subscription.unsubscribe()
    }
  }, [handleUserSession])

  const signInWithGoogle = useCallback(async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: window.location.origin,
      },
    })
    if (error) {
      throw error
    }
  }, [])

  const signOut = useCallback(async () => {
    try {
      // Clear state and cache immediately for responsive UI
      clearLocalAuthCache()
      setUser(null)
      setSession(null)
      setIsAdmin(false)

      await supabase.auth.signOut()
      // Ignore errors - state is already cleared locally
    } catch {
      // Sign out error - state is already cleared, user appears signed out
    } finally {
      clearSupabaseAuthStorage()
    }
  }, [])

  const contextValue = useMemo(
    () => ({
      user,
      session,
      loading,
      isAdmin,
      authError,
      signInWithGoogle,
      signOut,
      clearAuthError,
    }),
    [user, session, loading, isAdmin, authError, signInWithGoogle, signOut, clearAuthError]
  )

  return (
    <AuthContext.Provider value={contextValue}>
      {children}
    </AuthContext.Provider>
  )
}
