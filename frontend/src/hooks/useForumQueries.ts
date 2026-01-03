// Re-export all forum query hooks and utilities from their respective modules
// This file maintains backwards compatibility - consumers can still import from useForumQueries

// Query keys and types
export { forumKeys, type ThreadSortBy } from './forumQueryKeys'

// Thread queries
export {
  usePaginatedThreads,
  useCreateThread,
  type CreateThreadVariables,
} from './useThreadQueries'

// Post queries
export {
  usePostById,
  usePaginatedPosts,
  useThreadView,
  usePrefetchPosts,
  useAddReply,
  type AddReplyVariables,
  type ThreadViewResponse,
} from './usePostQueries'

// Post mutations
export {
  useVotePost,
  useEditPost,
  useDeletePost,
  calculateVoteUpdate,
  type VotePostVariables,
} from './usePostMutations'

// Flagged queries
export { usePaginatedFlaggedPosts, useToggleFlagged } from './useFlaggedQueries'

// Author posts queries
export { usePaginatedAuthorPosts } from './useAuthorPostsQueries'

// Bookmark queries (threads and posts)
export {
  useBookmarks,
  useToggleBookmark,
  usePostBookmarks,
  useTogglePostBookmark,
  usePaginatedBookmarkedPosts,
  type GetPaginatedBookmarkedPostsResponse,
} from './useBookmarkQueries'

// Re-export types and utilities for backwards compatibility
export type { Thread, Post, FlaggedPost, AuthorPost } from '../types'
export { flaggedPostToPost, authorPostToPost } from '../types'
