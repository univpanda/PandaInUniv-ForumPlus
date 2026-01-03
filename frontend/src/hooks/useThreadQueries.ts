import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { checkThreadContent } from '../utils/contentModeration'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import { getCachedThreads, isCacheEnabled } from '../lib/cacheApi'
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
  const { session, isAdmin } = useAuth()

  return useQuery({
    queryKey: forumKeys.paginatedThreads(sortBy, page, authorUsername, searchText, isDeleted, isFlagged),
    queryFn: async (): Promise<GetPaginatedThreadsResponse> => {
      if (!isAdmin && !isDeleted && !isFlagged && isCacheEnabled()) {
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
          const { items: threads, totalCount } = extractPaginatedResponse<Thread>(cached)
          return { threads, totalCount }
        }
      }

      const { data, error } = await supabase.rpc('get_paginated_forum_threads', {
        p_category_ids: null,
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
        p_sort_by: sortBy,
        p_author_username: authorUsername || null,
        p_search_text: searchText || null,
        p_flagged_only: isFlagged,
        p_deleted_only: isDeleted,
      })
      if (error) throw error
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

  return useOptimisticMutation<never, CreateThreadVariables, CreateThreadResponse>({
    mutationFn: async ({ title, content }): Promise<CreateThreadResponse> => {
      // Check content for inappropriate words
      const flagCheck = checkThreadContent(title, content)

      const { data, error } = await supabase.rpc('create_thread', {
        p_title: title,
        p_category_id: null,
        p_content: content,
        p_is_flagged: flagCheck.isFlagged,
        p_flag_reason: flagCheck.isFlagged ? flagCheck.reasons.join(', ') : null,
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
    },
  })
}
