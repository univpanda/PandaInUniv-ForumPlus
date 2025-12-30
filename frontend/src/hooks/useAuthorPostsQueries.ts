import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import { forumKeys } from './forumQueryKeys'
import type { AuthorPost, GetPaginatedAuthorPostsResponse } from '../types'

// Response shape from get_posts_by_author RPC (returns JSON object, not array)
interface AuthorPostsRpcResponse {
  posts: AuthorPost[]
  total_count: number
  is_private: boolean
}

// Post type filter for @op and @replies
export type PostTypeFilter = 'all' | 'op' | 'replies'

// Paginated author posts query
export function usePaginatedAuthorPosts(
  username: string,
  page: number,
  pageSize: number = PAGE_SIZE.POSTS,
  searchText: string | null = null,
  enabled: boolean = true,
  isDeleted: boolean = false,
  isFlagged: boolean = false,
  postType: PostTypeFilter = 'all'
) {
  // Enable if: has username OR has search text OR is filtering by deleted/flagged OR filtering by post type
  const isEnabled =
    enabled &&
    (username.length > 0 || (searchText !== null && searchText.length > 0) || isDeleted || isFlagged || postType !== 'all')

  return useQuery({
    queryKey: forumKeys.authorPosts(username, page, searchText, isDeleted, isFlagged, postType),
    queryFn: async (): Promise<GetPaginatedAuthorPostsResponse> => {
      const { data, error } = await supabase.rpc('get_posts_by_author', {
        p_author_username: username || null, // null = all authors
        p_search_text: searchText,
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
        p_flagged_only: isFlagged,
        p_deleted_only: isDeleted,
        p_post_type: postType === 'all' ? null : postType,
      })
      if (error) throw error
      // RPC returns JSON object: { posts: [...], total_count: number, is_private: boolean }
      const response = data as AuthorPostsRpcResponse
      return {
        posts: response.posts ?? [],
        totalCount: response.total_count ?? 0,
        isPrivate: response.is_private ?? false,
      }
    },
    enabled: isEnabled,
    staleTime: STALE_TIME.MEDIUM,
    placeholderData: (prev) => prev,
  })
}
