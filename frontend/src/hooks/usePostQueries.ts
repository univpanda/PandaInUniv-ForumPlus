import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { checkContent } from '../utils/contentModeration'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import { extractPaginatedResponse } from '../utils/queryHelpers'
import { forumKeys } from './forumQueryKeys'
import { profileKeys } from './useUserProfile'
import { useOptimisticMutation } from './useOptimisticMutation'
import type { Post, Thread, GetThreadPostsResponse, GetPaginatedPostsResponse } from '../types'

// Posts query (used to fetch all posts for a thread, then filtered/sorted client-side)
export function usePosts(threadId: number, parentId: number | null, enabled: boolean = true) {
  return useQuery({
    queryKey: forumKeys.posts(threadId, parentId),
    queryFn: async (): Promise<GetThreadPostsResponse> => {
      const { data, error } = await supabase.rpc('get_thread_posts', {
        p_thread_id: threadId,
        p_parent_id: parentId,
      })
      if (error) throw error
      return (data ?? []) as GetThreadPostsResponse
    },
    enabled,
    staleTime: STALE_TIME.SHORT,
  })
}

// Paginated posts query with server-side sorting
export function usePaginatedPosts(
  threadId: number,
  parentId: number | null,
  page: number,
  pageSize: number = PAGE_SIZE.POSTS,
  sort: 'popular' | 'new' = 'popular',
  enabled: boolean = true
) {
  return useQuery({
    queryKey: forumKeys.paginatedPosts(threadId, parentId, page, sort),
    queryFn: async (): Promise<GetPaginatedPostsResponse> => {
      const { data, error } = await supabase.rpc('get_paginated_thread_posts', {
        p_thread_id: threadId,
        p_parent_id: parentId,
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
        p_sort: sort,
      })
      if (error) throw error
      const { items: posts, totalCount } = extractPaginatedResponse<Post>(data)
      return { posts, totalCount }
    },
    enabled,
    staleTime: STALE_TIME.SHORT,
    placeholderData: (prev) => prev,
  })
}

// Prefetch posts for a thread (call on hover to preload data)
export function usePrefetchPosts() {
  const queryClient = useQueryClient()

  return (threadId: number) => {
    queryClient.prefetchQuery({
      queryKey: forumKeys.posts(threadId, null),
      queryFn: async (): Promise<GetThreadPostsResponse> => {
        const { data, error } = await supabase.rpc('get_thread_posts', {
          p_thread_id: threadId,
          p_parent_id: null,
        })
        if (error) throw error
        return (data ?? []) as GetThreadPostsResponse
      },
      staleTime: STALE_TIME.SHORT,
    })
  }
}

// Add reply variables - includes user info for optimistic update
export interface AddReplyVariables {
  threadId: number
  content: string
  parentId: number | null
  // User info for optimistic reply creation
  userId: string
  userName: string
  userAvatar: string | null
  // Current page/sort for optimistic cache update
  page: number
  sort: 'popular' | 'new'
  // Optimistic ID for updating with real ID after success
  optimisticId: number
}

// Helper to create optimistic reply object
function createOptimisticReply(variables: AddReplyVariables): Post {
  return {
    id: variables.optimisticId, // Temporary negative ID, will be replaced with real ID on success
    thread_id: variables.threadId,
    parent_id: variables.parentId,
    content: variables.content,
    author_id: variables.userId,
    author_name: variables.userName,
    author_avatar: variables.userAvatar,
    author_avatar_path: null, // Will be fetched on refetch
    created_at: new Date().toISOString(),
    likes: 1, // Auto-upvoted
    dislikes: 0,
    reply_count: 0,
    user_vote: 1, // Author auto-upvotes their own post
    first_reply_content: null,
    first_reply_author: null,
    first_reply_avatar: null,
    first_reply_avatar_path: null,
    first_reply_date: null,
    is_deleted: false,
    deleted_by: null,
    additional_comments: null,
    is_flagged: false,
    flag_reason: null,
  }
}

// Helper to prepend optimistic reply to paginated posts
function prependOptimisticReply(
  old: GetPaginatedPostsResponse | undefined,
  variables: AddReplyVariables
): GetPaginatedPostsResponse {
  const optimisticReply = createOptimisticReply(variables)
  if (!old) return { posts: [optimisticReply], totalCount: 1 }
  return { posts: [optimisticReply, ...old.posts], totalCount: old.totalCount + 1 }
}

// Add reply mutation with optimistic update using factory pattern
export function useAddReply() {
  const queryClient = useQueryClient()

  return useOptimisticMutation<GetPaginatedPostsResponse, AddReplyVariables, number>({
    mutationFn: async ({ threadId, content, parentId }): Promise<number> => {
      // Check content for inappropriate words
      const flagCheck = checkContent(content)

      const { data, error } = await supabase.rpc('add_reply', {
        p_thread_id: threadId,
        p_content: content,
        p_parent_id: parentId,
        p_is_flagged: flagCheck.isFlagged,
        p_flag_reason: flagCheck.isFlagged ? flagCheck.reasons.join(', ') : null,
      })
      if (error) throw error
      return data as number // Returns the new post ID
    },
    cacheUpdates: [
      // Update current page/sort cache the user is viewing
      {
        queryKey: ({ threadId, parentId, page, sort }) =>
          forumKeys.paginatedPosts(threadId, parentId, page, sort),
        updater: prependOptimisticReply,
      },
    ],
    invalidateOnSettled: false, // Keep optimistic position until user navigates away or refreshes
    onSuccess: (realPostId, variables) => {
      // Replace optimistic ID with real ID in the cache
      const cacheKey = forumKeys.paginatedPosts(variables.threadId, variables.parentId, variables.page, variables.sort)
      queryClient.setQueryData<GetPaginatedPostsResponse>(cacheKey, (old) => {
        if (!old) return old
        return {
          ...old,
          posts: old.posts.map((p) =>
            p.id === variables.optimisticId ? { ...p, id: realPostId } : p
          ),
        }
      })

      // Update reply_count in all root posts caches (for sub-replies)
      if (variables.parentId !== null) {
        // Handle both paginated ({ posts, totalCount }) and legacy (Post[]) formats
        const updateParentReplyCount = (oldData: GetPaginatedPostsResponse | GetThreadPostsResponse | undefined) => {
          if (!oldData) return oldData

          // Paginated format: { posts: Post[], totalCount: number }
          if (typeof oldData === 'object' && 'posts' in oldData) {
            return {
              ...oldData,
              posts: oldData.posts.map((p) =>
                p.id === variables.parentId
                  ? { ...p, reply_count: p.reply_count + 1 }
                  : p
              ),
            }
          }

          // Legacy format: Post[]
          if (Array.isArray(oldData)) {
            return oldData.map((p) =>
              p.id === variables.parentId
                ? { ...p, reply_count: p.reply_count + 1 }
                : p
            )
          }

          return oldData
        }
        // Use partial key match to update all root posts caches (paginated and legacy)
        queryClient.setQueriesData(
          { queryKey: forumKeys.posts(variables.threadId, null) },
          updateParentReplyCount
        )
      }

      // Surgically update reply_count in all paginated thread caches instead of invalidating
      const updatePaginatedThreadReplyCount = (oldData: { threads: Thread[]; totalCount: number } | undefined) => {
        if (!oldData) return oldData
        return {
          ...oldData,
          threads: oldData.threads.map((thread) =>
            thread.id === variables.threadId
              ? { ...thread, reply_count: thread.reply_count + 1 }
              : thread
          ),
        }
      }
      // Update all cached paginated thread pages across all sort types
      queryClient.setQueriesData(
        { queryKey: forumKeys.threadsAll() },
        updatePaginatedThreadReplyCount
      )

      // Update profile stats (post count increased)
      queryClient.invalidateQueries({ queryKey: profileKeys.userStats(variables.userId) })
    },
  })
}
