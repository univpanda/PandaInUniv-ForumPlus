import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import { extractPaginatedResponse } from '../utils/queryHelpers'
import { forumKeys } from './forumQueryKeys'
import { userKeys } from './useUserQueries'
import {
  extractSingleResult,
  type FlaggedPost,
  type GetPaginatedFlaggedPostsResponse,
  type GetPaginatedPostsResponse,
  type Post,
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
// Uses same pattern as useVotePost/useEditPost for consistent cache handling
export function useToggleFlagged() {
  const queryClient = useQueryClient()

  interface ToggleFlaggedVariables {
    postId: number
    threadId: number
  }

  return useMutation<ToggleFlaggedResponse, Error, ToggleFlaggedVariables, { previousData: Map<string, unknown> }>({
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

    onMutate: async ({ postId, threadId }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['forum', 'posts', threadId] })

      const previousData = new Map<string, unknown>()
      const cache = queryClient.getQueryCache()

      // Find all post caches for this thread (matches both Post[] and paginated formats)
      const queries = cache.findAll({ queryKey: ['forum', 'posts', threadId] })

      for (const query of queries) {
        const key = query.queryKey
        const data = query.state.data
        if (!data) continue

        // Handle paginated format: { posts: Post[], totalCount: number }
        if (typeof data === 'object' && 'posts' in data && Array.isArray((data as GetPaginatedPostsResponse).posts)) {
          const paginatedData = data as GetPaginatedPostsResponse
          if (paginatedData.posts.some((p) => p.id === postId)) {
            previousData.set(JSON.stringify(key), paginatedData)
            queryClient.setQueryData<GetPaginatedPostsResponse>(key, {
              ...paginatedData,
              posts: paginatedData.posts.map((p) =>
                p.id === postId ? { ...p, is_flagged: !p.is_flagged } : p
              ),
            })
          }
        }
        // Handle legacy format: Post[]
        else if (Array.isArray(data)) {
          const posts = data as Post[]
          if (posts.some((p) => p.id === postId)) {
            previousData.set(JSON.stringify(key), posts)
            queryClient.setQueryData<Post[]>(
              key,
              posts.map((p) => (p.id === postId ? { ...p, is_flagged: !p.is_flagged } : p))
            )
          }
        }
      }

      return { previousData }
    },

    onError: (_err, _variables, context) => {
      // Rollback on error
      if (context?.previousData) {
        for (const [keyStr, data] of context.previousData) {
          queryClient.setQueryData(JSON.parse(keyStr), data)
        }
      }
    },

    onSettled: () => {
      // Refetch flagged posts list and user stats
      queryClient.invalidateQueries({ queryKey: forumKeys.flaggedPosts() })
      queryClient.invalidateQueries({ queryKey: userKeys.all })
    },
  })
}
