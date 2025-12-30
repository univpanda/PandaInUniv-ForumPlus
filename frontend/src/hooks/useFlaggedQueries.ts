import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import { extractPaginatedResponse } from '../utils/queryHelpers'
import { forumKeys } from './forumQueryKeys'
import { useOptimisticMutation } from './useOptimisticMutation'
import { userKeys } from './useUserQueries'
import {
  extractSingleResult,
  type FlaggedPost,
  type GetPaginatedFlaggedPostsResponse,
  type ToggleFlaggedResponse,
} from '../types'

// Paginated flagged posts query (admin only)
export function usePaginatedFlaggedPosts(
  page: number,
  pageSize: number = PAGE_SIZE.POSTS,
  enabled: boolean = true
) {
  return useQuery({
    queryKey: forumKeys.paginatedFlaggedPosts(page),
    queryFn: async (): Promise<GetPaginatedFlaggedPostsResponse> => {
      const { data, error } = await supabase.rpc('get_flagged_posts', {
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
      })
      if (error) throw error
      const { items: posts, totalCount } = extractPaginatedResponse<FlaggedPost>(data)
      return { posts, totalCount }
    },
    enabled,
    staleTime: STALE_TIME.MEDIUM,
    placeholderData: (prev) => prev,
  })
}

// Toggle post flagged status (admin only)
// Uses targeted invalidation instead of broad cache updates for better performance
export function useToggleFlagged() {
  const queryClient = useQueryClient()

  interface ToggleFlaggedVariables {
    postId: number
    threadId: number
    parentId: number | null
  }

  return useOptimisticMutation<
    FlaggedPost[],
    ToggleFlaggedVariables,
    ToggleFlaggedResponse
  >({
    mutationFn: async ({ postId }): Promise<ToggleFlaggedResponse> => {
      const { data, error } = await supabase.rpc('toggle_post_flagged', {
        p_post_id: postId,
      })
      if (error) throw error
      const result = extractSingleResult(data as ToggleFlaggedResponse[])
      if (!result?.success) {
        throw new Error(result?.message || 'Failed to toggle flagged status')
      }
      return result
    },
    cacheUpdates: [
      // Optimistically remove from flagged posts list (for unflagging)
      {
        queryKey: forumKeys.flaggedPosts(),
        updater: (flaggedPosts, { postId }) => {
          if (!flaggedPosts) return flaggedPosts
          return flaggedPosts.filter((post) => post.id !== postId)
        },
      },
    ],
    invalidateOnSettled: true, // Refetch flaggedPosts after mutation settles
    invalidateKeys: [
      userKeys.all, // Update user flagged counts in admin panel
    ],
    onSuccess: (_data, { threadId, parentId }) => {
      // Invalidate only the specific thread's posts (both paginated and non-paginated)
      // Uses prefix matching: posts key is prefix of paginatedPosts key
      queryClient.invalidateQueries({ queryKey: forumKeys.posts(threadId, parentId) })
    },
  })
}
