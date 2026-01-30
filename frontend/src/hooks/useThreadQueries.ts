import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase, supabasePublic } from '../lib/supabase'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import { getCachedThreads, invalidateThreadsCache, isCacheEnabled } from '../lib/cacheApi'
import { extractPaginatedResponse } from '../utils/queryHelpers'
import { forumKeys, type ThreadSortBy } from './forumQueryKeys'
import { profileKeys } from './useUserProfile'
import { useOptimisticMutation } from './useOptimisticMutation'
import { useAuth } from './useAuth'
import type {
  Thread,
  GetPaginatedThreadsResponse,
  CreateThreadResponse,
} from '../types'

// Paginated threads query
export function usePaginatedThreads(
  sortBy: ThreadSortBy,
  page: number,
  pageSize: number = PAGE_SIZE.THREADS,
  enabled: boolean = true,
  authorUsername?: string | null,
  searchText?: string | null,
  isDeleted: boolean = false,
  isFlagged: boolean = false
) {
  const { isAdmin, session } = useAuth()
  const client = session?.access_token ? supabase : supabasePublic

  return useQuery({
    queryKey: forumKeys.paginatedThreads(
      sortBy,
      page,
      pageSize,
      authorUsername,
      searchText,
      isDeleted,
      isFlagged
    ),
    networkMode: 'always',
    queryFn: async (): Promise<GetPaginatedThreadsResponse> => {
      const isCachedEligible = !isAdmin && !isDeleted && !isFlagged && isCacheEnabled()

      if (isCachedEligible) {
        const cached = await getCachedThreads({
          limit: pageSize,
          offset: (page - 1) * pageSize,
          sort: sortBy,
          author: authorUsername || null,
          search: searchText || null,
          flagged: isFlagged,
          deleted: isDeleted,
        })
        if (cached) {
          const { items: threads, totalCount } = extractPaginatedResponse<Thread>(
            cached as Array<Thread & { total_count: number }>
          )
          return { threads, totalCount }
        }
      }

      // Add timeout to prevent infinite loading for anonymous users
      const rpcPromise = client.rpc('get_paginated_forum_threads', {
        p_category_ids: null,
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
        p_sort_by: sortBy,
        p_author_username: authorUsername || null,
        p_search_text: searchText || null,
        p_flagged_only: isFlagged,
        p_deleted_only: isDeleted,
      })

      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('Request timeout: threads query took too long')), 15000)
      )

      const { data, error } = await Promise.race([rpcPromise, timeoutPromise])

      if (error) {
        console.error('Threads RPC error:', error.message, error.code)
        throw error
      }

      const { items: threads, totalCount } = extractPaginatedResponse<Thread>(data)

      return { threads, totalCount }
    },
    enabled,
    staleTime: STALE_TIME.SHORT,
    placeholderData: (prev) => prev,
  })
}

// Create thread variables
export interface CreateThreadVariables {
  title: string
  content: string
  userId: string // For profile stats invalidation
}

// Create thread mutation using factory pattern
export function useCreateThread() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useOptimisticMutation<never, CreateThreadVariables, CreateThreadResponse>({
    mutationFn: async ({ title, content }): Promise<CreateThreadResponse> => {
      const { data, error } = await supabase.rpc('create_thread', {
        p_title: title,
        p_category_id: null,
        p_content: content,
      })
      if (error) throw error
      return data as CreateThreadResponse
    },
    cacheUpdates: [], // No optimistic updates for new content
    invalidateOnSettled: false, // Handle in invalidateKeys
    invalidateKeys: [
      forumKeys.threadsAll(), // Invalidate all paginated thread caches
    ],
    onSuccess: (_, { userId }) => {
      // Update profile stats (thread count increased)
      queryClient.invalidateQueries({ queryKey: profileKeys.userStats(userId) })

      if (session?.access_token) {
        invalidateThreadsCache(session.access_token)
      }
    },
  })
}
