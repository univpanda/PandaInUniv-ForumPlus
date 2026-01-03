import { useCallback } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { forumKeys } from './forumQueryKeys'
import { chatKeys } from './useChatQueries'
import { profileKeys } from './useUserProfile'
import { PAGE_SIZE } from '../utils/constants'
import type { UserConversation, BookmarkedPost } from '../types'

/**
 * Hook to prefetch user data into React Query cache on login.
 * Call this once when user becomes available to warm the cache
 * for bookmarks, conversations, and profile data.
 */
export function usePrefetchUserData() {
  const queryClient = useQueryClient()

  return useCallback(
    (userId: string) => {
      // Prefetch bookmarks (thread bookmark IDs)
      queryClient.prefetchQuery({
        queryKey: forumKeys.bookmarks(userId),
        queryFn: async () => {
          const { data, error } = await supabase.rpc('get_bookmarked_thread_ids', {
            p_user_id: userId,
          })
          if (error) throw error
          return new Set((data as number[]) ?? [])
        },
      })

      // Prefetch post bookmarks (individual post IDs)
      queryClient.prefetchQuery({
        queryKey: forumKeys.postBookmarks(userId),
        queryFn: async () => {
          const { data, error } = await supabase
            .from('post_bookmarks')
            .select('post_id')
            .eq('user_id', userId)
          if (error) throw error
          return new Set(data?.map((b) => b.post_id) ?? [])
        },
      })

      // Prefetch first page of bookmarked posts (full data for @bookmarked search)
      queryClient.prefetchQuery({
        queryKey: forumKeys.bookmarkedPosts(userId, 1, null),
        queryFn: async () => {
          const pageSize = PAGE_SIZE.POSTS
          const { data, error } = await supabase.rpc('get_bookmarked_posts', {
            p_user_id: userId,
            p_limit: pageSize,
            p_offset: 0,
            p_search_text: null,
          })
          if (error) throw error
          const result = data as { posts: BookmarkedPost[]; total_count: number } | null
          return {
            posts: result?.posts ?? [],
            totalCount: result?.total_count ?? 0,
          }
        },
      })

      // Prefetch conversations (top 5 recent)
      queryClient.prefetchQuery({
        queryKey: chatKeys.conversations(userId),
        queryFn: async () => {
          const { data, error } = await supabase.rpc('get_user_conversations', {
            p_user_id: userId,
          })
          if (error) throw error
          return (data || []) as UserConversation[]
        },
      })

      // Prefetch user profile
      queryClient.prefetchQuery({
        queryKey: profileKeys.user(userId),
        queryFn: async () => {
          const { data, error } = await supabase.rpc('get_public_user_profile', {
            p_user_id: userId,
          })
          if (error) throw error
          return (data ?? [])[0] ?? null
        },
      })

      // Prefetch reserved usernames (static, cached forever)
      queryClient.prefetchQuery({
        queryKey: profileKeys.reservedUsernames(),
        queryFn: async () => {
          const { data, error } = await supabase.rpc('get_reserved_usernames')
          if (error) return new Set<string>()
          return new Set((data as string[]) || [])
        },
      })
    },
    [queryClient]
  )
}
