import { useEffect, useState, useRef, useCallback, useMemo } from 'react'
import type { ReactNode } from 'react'
import type { User, Session } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { AuthContext } from './AuthContextType'
import { cleanOAuthHash } from '../utils/url'
import { invalidateUserCache } from '../lib/cacheApi'
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
          clearLocalAuthCache()
          setSession(null)
          setUser(null)
          setIsAdmin(false)
        }
        return true
      }

      const userId = newSession.user.id

      // Prevent duplicate processing for the same user
      if (processingUserId.current === userId) {
        return false // Already processing this user
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
    const enableGeoLookup = import.meta.env.VITE_ENABLE_GEOLOOKUP === 'true'
    let ip: string | null = null
    let location: string | null = null

    if (enableGeoLookup) {
      // Optional: avoid CORS issues by enabling via server-side proxy/edge function.
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 5000) // 5s timeout

      try {
        const geoRes = await fetch('https://ipapi.co/json/', { signal: controller.signal })
        if (geoRes.ok) {
          const geo = await geoRes.json()
          ip = geo?.ip || null
          location =
            geo?.city && geo?.country_name
              ? `${geo.city}, ${geo.country_name}`
              : geo?.country_name || null
        }
      } catch {
        // IP/geo fetch failed - continue with null values
      } finally {
        clearTimeout(timeoutId)
      }
    }

    // Always update login info, even if IP/location failed
    try {
      await supabase.rpc('update_login_metadata', {
        p_last_login: new Date().toISOString(),
        p_last_ip: ip,
        p_last_location: location,
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

    // Timeout to prevent infinite loading state - show error to user
    const timeoutId = setTimeout(() => {
      if (!isActive) return
      setAuthError('Authentication timed out. Please refresh and try again.')
      setLoading(false)
    }, 5000)

    // Get initial session - only runs once on mount
    const initSession = async () => {
      try {
        const {
          data: { session },
        } = await supabase.auth.getSession()
        clearTimeout(timeoutId)

        if (!isActive) return

        // Pass isInitialLoad=true to use local cache for instant display
        await handleUserSession(session, checkIsActive, true)

        // Mark as initialized AFTER session handling completes
        // This ensures onAuthStateChange doesn't skip updates during initial processing
        isInitialized.current = true
      } catch {
        clearTimeout(timeoutId)
        // Auth initialization failed - don't log details to console
        // Still mark as initialized so future auth changes are processed
        isInitialized.current = true
      }
      if (isActive) setLoading(false)
    }

    initSession()

    // Listen for auth changes (sign in, sign out, token refresh)
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      if (!isActive) return

      // Skip if this is the initial session (already handled above)
      if (!isInitialized.current) return

      try {
        await handleUserSession(session, checkIsActive)

        // Clean up OAuth hash from URL after successful sign-in
        if (session?.user) {
          cleanOAuthHash()
        }
      } catch {
        // Auth state change error - silently continue
      }
      if (isActive) setLoading(false)
    })

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
