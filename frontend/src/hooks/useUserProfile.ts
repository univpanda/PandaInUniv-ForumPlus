import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME } from '../utils/constants'
import type { UserProfile } from '../types'
import { getCachedUserProfile, getPublicUserProfile, invalidateUserCache, isCacheEnabled } from '../lib/cacheApi'
import { useAuth } from './useAuth'

// Re-export for backwards compatibility
export type { UserProfile } from '../types'

// Query key factory - single source of truth for all profile-related queries
export const profileKeys = {
  all: ['profile'] as const,
  user: (userId: string) => [...profileKeys.all, 'user', userId] as const,
  usernameCheck: (username: string) => [...profileKeys.all, 'check', username] as const,
  userStats: (userId: string) => [...profileKeys.all, 'stats', userId] as const,
  publicStats: (userId: string) => [...profileKeys.all, 'publicStats', userId] as const,
  reservedUsernames: () => [...profileKeys.all, 'reservedUsernames'] as const,
}

// Hook to fetch user profile (with cache support)
export function useUserProfile(userId: string | null) {
  const { session } = useAuth()

  return useQuery({
    queryKey: profileKeys.user(userId || ''),
    queryFn: async (): Promise<UserProfile | null> => {
      if (!userId) return null

      // Try cache first if enabled
      if (isCacheEnabled()) {
        if (session?.access_token) {
          const cached = await getCachedUserProfile(userId, session.access_token)
          if (cached) {
            return {
              id: cached.id,
              username: cached.username,
              avatar_url: cached.avatar_url,
              avatar_path: cached.avatar_path ?? null,
              is_private: cached.is_private,
            }
          }
        } else {
          const cached = await getPublicUserProfile(userId)
          if (cached) {
            return {
              id: cached.id,
              username: cached.username,
              avatar_url: cached.avatar_url,
              avatar_path: cached.avatar_path ?? null,
              is_private: cached.is_private,
            }
          }
        }
      }

      // Fallback to Supabase
      const { data, error } = await supabase.rpc('get_public_user_profile', {
        p_user_id: userId,
      })

      if (error) throw error
      const profile = (data as UserProfile[] | null)?.[0] ?? null
      return profile
    },
    enabled: !!userId,
    staleTime: STALE_TIME.LONG,
  })
}

// Check username availability (imperative async function, not a hook)
// Case-insensitive check to prevent "User" and "user" from being different users
export async function isUsernameAvailable(username: string): Promise<boolean> {
  const { data, error } = await supabase.rpc('is_username_available', {
    p_username: username,
  })

  if (error) throw error
  return Boolean(data)
}

// Hook to fetch reserved usernames from database (cached for app lifetime)
export function useReservedUsernames() {
  return useQuery({
    queryKey: profileKeys.reservedUsernames(),
    queryFn: async (): Promise<Set<string>> => {
      const { data, error } = await supabase.rpc('get_reserved_usernames')

      if (error) {
        console.error('Failed to fetch reserved usernames:', error.message)
        // Return empty set on error - server will still validate
        return new Set()
      }

      // Convert array to Set for O(1) lookup
      return new Set((data as string[]) || [])
    },
    staleTime: Infinity, // Never refetch - list doesn't change at runtime
    gcTime: Infinity, // Keep in cache forever
  })
}

// Check if a username is reserved (uses cached data)
export function isReservedUsername(username: string, reservedSet: Set<string>): boolean {
  return reservedSet.has(username.toLowerCase())
}

// Hook to update username
export function useUpdateUsername() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useMutation({
    mutationFn: async ({ newUsername }: { newUsername: string; userId: string }) => {
      const { data, error } = await supabase.rpc('update_username', {
        p_new_username: newUsername,
      })

      if (error) throw error

      // RPC returns {success: boolean, message: string}
      const result = data?.[0] ?? data
      if (!result?.success) {
        throw new Error(result?.message || 'Failed to update username')
      }

      return newUsername
    },
    onSuccess: (newUsername, variables) => {
      // Update the cached profile with new username
      queryClient.setQueryData(profileKeys.user(variables.userId), (old: UserProfile | null) => {
        if (!old) return old
        return { ...old, username: newUsername }
      })

      // Invalidate DynamoDB cache
      if (session?.access_token) {
        invalidateUserCache(variables.userId, session.access_token)
      }
    },
  })
}

// Check if a username is private (for search)
export function useCheckUsernamePrivacy(username: string | null, enabled: boolean = true) {
  return useQuery({
    queryKey: ['username-privacy', username?.toLowerCase() ?? ''],
    queryFn: async (): Promise<{ userExists: boolean; isPrivate: boolean }> => {
      if (!username) return { userExists: false, isPrivate: false }

      const { data, error } = await supabase.rpc('check_username_privacy', {
        p_username: username,
      })

      if (error) throw error
      const result = data?.[0]
      return {
        userExists: result?.user_exists ?? false,
        isPrivate: result?.is_private ?? false,
      }
    },
    enabled: !!username && enabled,
    staleTime: STALE_TIME.MEDIUM,
  })
}

// Check if a user is private by ID
export function useCheckUserPrivacy(userId: string | null, enabled: boolean = true) {
  return useQuery({
    queryKey: ['user-privacy', userId ?? ''],
    queryFn: async (): Promise<boolean> => {
      if (!userId) return false

      const { data, error } = await supabase.rpc('get_public_user_profile', {
        p_user_id: userId,
      })

      if (error) return false
      const profile = (data as UserProfile[] | null)?.[0]
      return profile?.is_private ?? false
    },
    enabled: !!userId && enabled,
    staleTime: STALE_TIME.MEDIUM,
  })
}

// Hook to toggle private status
export function useTogglePrivate() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useMutation({
    mutationFn: async (userId: string) => {
      const { data, error } = await supabase.rpc('toggle_private', {
        p_user_id: userId,
      })

      if (error) throw error
      return data as boolean
    },
    onSuccess: (newPrivateStatus, userId) => {
      // Update the cached profile with new private status
      queryClient.setQueryData(profileKeys.user(userId), (old: UserProfile | null) => {
        if (!old) return old
        return { ...old, is_private: newPrivateStatus }
      })

      // Invalidate DynamoDB cache
      if (session?.access_token) {
        invalidateUserCache(userId, session.access_token)
      }
    },
    onError: (_, userId) => {
      // Refetch on error to ensure UI is in sync
      queryClient.invalidateQueries({ queryKey: profileKeys.user(userId) })
    },
  })
}
