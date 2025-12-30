import { useMemo } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { usePosts, usePaginatedPosts, usePaginatedAuthorPosts, forumKeys } from './useForumQueries'
import { PAGE_SIZE } from '../utils/constants'
import type { View } from './useDiscussionNavigation'
import type { ReplySortBy } from './useDiscussionFilters'
import type { Thread, Post, AuthorPost } from '../types'

interface UsePostViewDataProps {
  view: View
  selectedThread: Thread | null
  selectedPost: Post | null
  replySortBy: ReplySortBy
  repliesPage: number
  subRepliesPage: number
  authorPostsPage: number
  authorUsername?: string | null
  searchText?: string | null
  isPostsSearchView: boolean
  isDeleted?: boolean
  isFlagged?: boolean
  postType?: 'all' | 'op' | 'replies'
}

export interface PostViewDataReturn {
  // Raw posts data
  rawPosts: Post[]

  // Computed post data
  originalPost: Post | undefined
  replies: Post[]
  sortedSubReplies: Post[]

  // Posts search data
  postsSearchData: AuthorPost[]
  postsSearchLoading: boolean
  postsSearchError: boolean
  postsSearchTotalCount: number
  postsSearchIsPrivate: boolean

  // Loading/error states
  isLoading: boolean
  isError: boolean

  // Pagination totals
  repliesTotalCount: number
  subRepliesTotalCount: number

  // Refetch functions
  refetchPosts: () => void
  refetchReplies: () => void
  refetchSubReplies: () => void
  refetchPostsSearch: () => void
}

export function usePostViewData({
  view,
  selectedThread,
  selectedPost,
  replySortBy,
  repliesPage,
  subRepliesPage,
  authorPostsPage,
  authorUsername,
  searchText,
  isPostsSearchView,
  isDeleted = false,
  isFlagged = false,
  postType = 'all',
}: UsePostViewDataProps): PostViewDataReturn {
  const queryClient = useQueryClient()

  // Derive thread ID safely (null when no thread selected)
  const threadId = selectedThread?.id ?? null

  // For thread view, we need the OP first to get paginated replies
  const postsQuery = usePosts(threadId ?? 0, null, view === 'thread' && threadId !== null)

  // Get the OP's ID from the legacy query to use for paginated replies
  const opId = useMemo(() => {
    if (view !== 'thread') return null
    const op = postsQuery.data?.find((p) => p.parent_id === null)
    return op?.id ?? null
  }, [view, postsQuery.data])

  // Paginated replies for thread view (replies to OP) - server-side sorted
  const paginatedRepliesQuery = usePaginatedPosts(
    threadId ?? 0,
    opId ?? 0,
    repliesPage,
    PAGE_SIZE.POSTS,
    replySortBy,
    view === 'thread' && threadId !== null && opId !== null
  )

  // Sub-replies query for replies view - server-side sorted
  const hasSubReplies = view === 'replies' && (selectedPost?.reply_count ?? 0) > 0
  const paginatedSubRepliesQuery = usePaginatedPosts(
    threadId ?? 0,
    selectedPost?.id ?? 0,
    subRepliesPage,
    PAGE_SIZE.POSTS,
    replySortBy,
    view === 'replies' && threadId !== null && hasSubReplies
  )

  // Root posts query for replies view (to show OP)
  const rootPostsQueryKey = threadId !== null ? forumKeys.posts(threadId, null) : null
  const cachedRootPosts = rootPostsQueryKey
    ? queryClient.getQueryData<Post[]>(rootPostsQueryKey)
    : undefined
  const threadRootPostsQuery = usePosts(
    threadId ?? 0,
    null,
    view === 'replies' && threadId !== null && !cachedRootPosts
  )

  // Paginated posts search query (searches all posts when searchMode is 'posts')
  const paginatedPostsSearchQuery = usePaginatedAuthorPosts(
    authorUsername ?? '',
    authorPostsPage,
    PAGE_SIZE.POSTS,
    searchText,
    view === 'list' && isPostsSearchView,
    isDeleted,
    isFlagged,
    postType
  )

  // ============ COMPUTED DATA ============

  // Raw posts from query (used for finding posts by ID)
  const rawPosts = postsQuery.data ?? []

  // Computed original post and replies (server-side sorted)
  const { originalPost, replies } = useMemo(() => {
    if (view === 'list') return { originalPost: undefined, replies: [] }
    if (view === 'replies') {
      const rootPosts = cachedRootPosts ?? threadRootPostsQuery.data ?? []
      const original = rootPosts.find((p) => p.parent_id === null)
      return { originalPost: original, replies: [] }
    }
    // For thread view: OP from postsQuery, replies from paginated query
    const posts = postsQuery.data ?? []
    const original = posts.find((p) => p.parent_id === null)
    const paginatedReplies = paginatedRepliesQuery.data?.posts ?? []
    return { originalPost: original, replies: paginatedReplies }
  }, [postsQuery.data, paginatedRepliesQuery.data, view, cachedRootPosts, threadRootPostsQuery.data])

  // Sub-replies for replies view
  const sortedSubReplies = useMemo(() => {
    if (view !== 'replies') return []
    return paginatedSubRepliesQuery.data?.posts ?? []
  }, [paginatedSubRepliesQuery.data, view])

  // Posts search data
  const postsSearchData = paginatedPostsSearchQuery.data?.posts ?? []

  // ============ LOADING & ERROR STATES ============

  const needsRootPostsLoading = !cachedRootPosts && threadRootPostsQuery.isLoading
  const isLoading =
    (view === 'thread' && (postsQuery.isLoading || (opId !== null && paginatedRepliesQuery.isLoading))) ||
    (view === 'replies' && ((hasSubReplies && paginatedSubRepliesQuery.isLoading) || needsRootPostsLoading))

  const isError =
    (view === 'thread' && (postsQuery.isError || paginatedRepliesQuery.isError)) ||
    (view === 'replies' && paginatedSubRepliesQuery.isError)

  return {
    rawPosts,
    originalPost,
    replies,
    sortedSubReplies,
    postsSearchData,
    postsSearchLoading: paginatedPostsSearchQuery.isLoading,
    postsSearchError: paginatedPostsSearchQuery.isError,
    postsSearchTotalCount: paginatedPostsSearchQuery.data?.totalCount ?? 0,
    postsSearchIsPrivate: paginatedPostsSearchQuery.data?.isPrivate ?? false,
    isLoading,
    isError,
    repliesTotalCount: paginatedRepliesQuery.data?.totalCount ?? 0,
    subRepliesTotalCount: paginatedSubRepliesQuery.data?.totalCount ?? 0,
    refetchPosts: postsQuery.refetch,
    refetchReplies: paginatedRepliesQuery.refetch,
    refetchSubReplies: paginatedSubRepliesQuery.refetch,
    refetchPostsSearch: paginatedPostsSearchQuery.refetch,
  }
}
