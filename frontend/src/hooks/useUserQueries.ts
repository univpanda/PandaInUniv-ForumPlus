import { useCallback } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME } from '../utils/constants'
import type { UserWithStats } from '../types'
import { getCachedPaginatedUsers, invalidateUserCache, isCacheEnabled } from '../lib/cacheApi'
import { useAuth } from './useAuth'

// Re-export for backwards compatibility
export type { UserWithStats } from '../types'

export interface PaginatedUsersResult {
  users: UserWithStats[]
  totalCount: number
}

// Query key factory
export const userKeys = {
  all: ['users'] as const,
  paginated: (page: number, pageSize: number, search: string) =>
    [...userKeys.all, 'paginated', { page, pageSize, search }] as const,
}

// Fetch function for paginated users (extracted for prefetching)
async function fetchPaginatedUsers(
  pageSize: number,
  offset: number,
  search: string,
  accessToken?: string
): Promise<PaginatedUsersResult> {
  // Try cache first
  if (isCacheEnabled() && accessToken) {
    const cached = await getCachedPaginatedUsers(
      accessToken,
      pageSize,
      offset,
      search || undefined
    )
    if (cached) {
      return { users: cached.users, totalCount: cached.totalCount }
    }
  }

  // Fallback to Supabase
  const { data, error } = await supabase.rpc('get_users_paginated', {
    p_limit: pageSize,
    p_offset: offset,
    p_search: search || null,
  })
  if (error) throw error

  // Extract total_count from first row
  const rows = (data ?? []) as Array<UserWithStats & { total_count: number }>
  const totalCount = rows.length > 0 ? Number(rows[0].total_count) : 0

  // Remove total_count from each row
  const users = rows.map((row) => {
    const { total_count: _totalCount, ...user } = row
    void _totalCount
    return user as UserWithStats
  })

  return { users, totalCount }
}

// Hook to fetch paginated users with stats (admin only)
export function usePaginatedUsers(
  isAdmin: boolean,
  page: number,
  pageSize: number,
  search: string,
  options?: { enabled?: boolean }
) {
  const { session } = useAuth()

  return useQuery({
    queryKey: userKeys.paginated(page, pageSize, search),
    queryFn: async (): Promise<PaginatedUsersResult> => {
      if (!isAdmin) {
        throw new Error('Unauthorized: Admin access required')
      }
      const offset = (page - 1) * pageSize
      return fetchPaginatedUsers(pageSize, offset, search, session?.access_token)
    },
    enabled: isAdmin && options?.enabled !== false,
    staleTime: STALE_TIME.MEDIUM,
    placeholderData: (previousData) => previousData, // Keep previous data while fetching
  })
}

// Hook to prefetch paginated users on hover
export function usePrefetchUsers() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useCallback(
    (page: number, pageSize: number, search: string) => {
      const offset = (page - 1) * pageSize
      queryClient.prefetchQuery({
        queryKey: userKeys.paginated(page, pageSize, search),
        queryFn: () => fetchPaginatedUsers(pageSize, offset, search, session?.access_token),
        staleTime: STALE_TIME.MEDIUM,
      })
    },
    [queryClient, session?.access_token]
  )
}

// Mutation to toggle admin role
export function useToggleAdmin() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useMutation({
    mutationFn: async ({ userId, currentRole }: { userId: string; currentRole: string }) => {
      const newRole = currentRole === 'admin' ? 'user' : 'admin'
      const { error } = await supabase.rpc('set_user_role', {
        p_user_id: userId,
        p_role: newRole,
      })
      if (error) throw error
      return userId
    },
    onSuccess: (userId) => {
      queryClient.invalidateQueries({ queryKey: userKeys.all })
      // Invalidate DynamoDB cache (invalidates both user profile and users list)
      if (session?.access_token) {
        invalidateUserCache(userId, session.access_token)
      }
    },
  })
}

// Mutation to toggle block status
export function useToggleBlock() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useMutation({
    mutationFn: async ({ userId, currentlyBlocked }: { userId: string; currentlyBlocked: boolean }) => {
      const { error } = await supabase.rpc('set_user_blocked', {
        p_user_id: userId,
        p_is_blocked: !currentlyBlocked,
      })
      if (error) throw error
      return userId
    },
    onSuccess: (userId) => {
      queryClient.invalidateQueries({ queryKey: userKeys.all })
      // Invalidate DynamoDB cache
      if (session?.access_token) {
        invalidateUserCache(userId, session.access_token)
      }
    },
  })
}

// Mutation to delete user
export function useDeleteUser() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useMutation({
    mutationFn: async ({ userId }: { userId: string }) => {
      const { error } = await supabase.rpc('delete_user_account', { p_user_id: userId })
      if (error) throw error
      return userId
    },
    onSuccess: (userId) => {
      queryClient.invalidateQueries({ queryKey: userKeys.all })
      // Invalidate DynamoDB cache
      if (session?.access_token) {
        invalidateUserCache(userId, session.access_token)
      }
    },
  })
}
