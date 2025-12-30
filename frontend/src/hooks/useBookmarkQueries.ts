import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import { forumKeys } from './forumQueryKeys'
import { useOptimisticMutation } from './useOptimisticMutation'
import type { BookmarkedPost } from '../types'

// Thread bookmarks query (threads where OP is bookmarked in post_bookmarks)
export function useBookmarks(userId: string | undefined) {
  return useQuery({
    queryKey: forumKeys.bookmarks(userId ?? ''),
    queryFn: async () => {
      if (!userId) return new Set<number>()
      const { data, error } = await supabase.rpc('get_bookmarked_thread_ids', {
        p_user_id: userId,
      })
      if (error) throw error
      return new Set((data as number[]) ?? [])
    },
    enabled: !!userId,
    staleTime: STALE_TIME.LONG,
  })
}

// Toggle thread bookmark mutation (bookmarks the OP post)
export function useToggleBookmark(userId: string | undefined) {
  return useOptimisticMutation<Set<number>, number, void>({
    mutationFn: async (threadId) => {
      const { error } = await supabase.rpc('toggle_thread_bookmark', {
        p_thread_id: threadId,
      })
      if (error) throw error
    },
    cacheUpdates: [
      {
        queryKey: forumKeys.bookmarks(userId ?? ''),
        updater: (bookmarks, threadId) => {
          if (!bookmarks || !userId) return bookmarks
          const next = new Set(bookmarks)
          if (next.has(threadId)) {
            next.delete(threadId)
          } else {
            next.add(threadId)
          }
          return next
        },
      },
    ],
    // Invalidate post bookmarks and bookmarked posts list since toggle_thread_bookmark modifies post_bookmarks
    invalidateKeys: [
      forumKeys.postBookmarks(userId ?? ''),
      forumKeys.bookmarkedPostsAll(userId ?? ''),
    ],
    invalidateOnSettled: false,
  })
}

// ============ POST BOOKMARKS ============

/**
 * Query to fetch user's bookmarked post IDs (excluding deleted posts)
 */
export function usePostBookmarks(userId: string | undefined) {
  return useQuery({
    queryKey: forumKeys.postBookmarks(userId ?? ''),
    queryFn: async () => {
      if (!userId) return new Set<number>()
      const { data, error } = await supabase.rpc('get_user_bookmark_post_ids', {
        p_user_id: userId,
      })
      if (error) throw error
      return new Set((data as number[]) ?? [])
    },
    enabled: !!userId,
    staleTime: STALE_TIME.LONG,
  })
}

/**
 * Toggle post bookmark mutation with optimistic update
 */
export function useTogglePostBookmark(userId: string | undefined) {
  return useOptimisticMutation<Set<number>, number, void>({
    mutationFn: async (postId) => {
      const { error } = await supabase.rpc('toggle_post_bookmark', {
        p_post_id: postId,
      })
      if (error) throw error
    },
    cacheUpdates: [
      {
        queryKey: forumKeys.postBookmarks(userId ?? ''),
        updater: (bookmarks, postId) => {
          if (!bookmarks || !userId) return bookmarks
          const next = new Set(bookmarks)
          if (next.has(postId)) {
            next.delete(postId)
          } else {
            next.add(postId)
          }
          return next
        },
      },
    ],
    // Invalidate thread bookmarks (in case post is an OP) and bookmarked posts list
    invalidateKeys: [
      forumKeys.bookmarks(userId ?? ''),
      forumKeys.bookmarkedPostsAll(userId ?? ''),
    ],
    invalidateOnSettled: false,
  })
}

/**
 * Response type for paginated bookmarked posts
 */
export interface GetPaginatedBookmarkedPostsResponse {
  posts: BookmarkedPost[]
  totalCount: number
}

/**
 * Paginated query for bookmarked posts with optional search text filtering
 */
export function usePaginatedBookmarkedPosts(
  userId: string | undefined,
  page: number,
  enabled: boolean = true,
  searchText?: string | null
) {
  return useQuery({
    queryKey: forumKeys.bookmarkedPosts(userId ?? '', page, searchText),
    queryFn: async (): Promise<GetPaginatedBookmarkedPostsResponse> => {
      if (!userId) return { posts: [], totalCount: 0 }

      const pageSize = PAGE_SIZE.POSTS
      const { data, error } = await supabase.rpc('get_bookmarked_posts', {
        p_user_id: userId,
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
        p_search_text: searchText || null,
      })

      if (error) throw error

      const result = data as { posts: BookmarkedPost[]; total_count: number } | null
      return {
        posts: result?.posts ?? [],
        totalCount: result?.total_count ?? 0,
      }
    },
    enabled: !!userId && enabled,
    staleTime: STALE_TIME.SHORT, // Short stale time since bookmarks change by user action
    placeholderData: (prev) => prev,
  })
}
