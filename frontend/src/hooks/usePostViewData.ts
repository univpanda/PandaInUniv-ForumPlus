import { useMemo } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { usePosts, usePaginatedPosts, usePaginatedAuthorPosts, forumKeys } from './useForumQueries'
import { PAGE_SIZE } from '../utils/constants'
import { isPostStub } from '../types'
import type { View, SelectedThread, SelectedPost } from './useDiscussionNavigation'
import type { ReplySortBy } from './useDiscussionFilters'
import type { Post, AuthorPost } from '../types'

interface UsePostViewDataProps {
  view: View
  selectedThread: SelectedThread
  selectedPost: SelectedPost
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
  resolvedSelectedPost: Post | undefined
  replies: Post[]
  sortedSubReplies: Post[]

  // Post lookup cache for O(1) access
  postsById: Map<number, Post>

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
  // Only check reply_count if we have a full Post (not a stub)
  const hasSubReplies = view === 'replies' && selectedPost && !isPostStub(selectedPost) && selectedPost.reply_count > 0
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

  // Get OP ID for replies view (needed to fetch level-1 replies where selectedPost lives)
  const repliesViewOpId = useMemo(() => {
    if (view !== 'replies') return null
    const rootPosts = cachedRootPosts ?? threadRootPostsQuery.data ?? []
    const op = rootPosts.find((p) => p.parent_id === null)
    return op?.id ?? null
  }, [view, cachedRootPosts, threadRootPostsQuery.data])

  // Check if selectedPost is a stub (only has id, missing content)
  const isSelectedPostStub = view === 'replies' && isPostStub(selectedPost)

  // Fetch level-1 replies to find selectedPost when it's a stub
  const level1RepliesQuery = usePosts(
    threadId ?? 0,
    repliesViewOpId ?? 0,
    view === 'replies' && threadId !== null && repliesViewOpId !== null && isSelectedPostStub
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

  // Resolve selectedPost from fetched data when it's a stub
  const resolvedSelectedPost = useMemo(() => {
    if (view !== 'replies' || !selectedPost) return undefined
    // If selectedPost is a full Post (not a stub), use it as-is
    if (!isPostStub(selectedPost)) return selectedPost
    // Otherwise, find it in the level-1 replies
    const level1Replies = level1RepliesQuery.data ?? []
    return level1Replies.find((p) => p.id === selectedPost.id)
  }, [view, selectedPost, level1RepliesQuery.data])

  // Sub-replies for replies view
  const sortedSubReplies = useMemo(() => {
    if (view !== 'replies') return []
    return paginatedSubRepliesQuery.data?.posts ?? []
  }, [paginatedSubRepliesQuery.data, view])

  // Posts search data
  const postsSearchData = paginatedPostsSearchQuery.data?.posts ?? []

  // Post lookup cache for O(1) access by ID (used by vote actions)
  const postsById = useMemo(() => {
    const map = new Map<number, Post>()
    // Add all posts from various sources
    rawPosts.forEach((p) => map.set(p.id, p))
    replies.forEach((p) => map.set(p.id, p))
    sortedSubReplies.forEach((p) => map.set(p.id, p))
    if (originalPost) map.set(originalPost.id, originalPost)
    return map
  }, [rawPosts, replies, sortedSubReplies, originalPost])

  // ============ LOADING & ERROR STATES ============

  const needsRootPostsLoading = !cachedRootPosts && threadRootPostsQuery.isLoading
  const needsLevel1RepliesLoading = isSelectedPostStub && level1RepliesQuery.isLoading
  const isLoading =
    (view === 'thread' && (postsQuery.isLoading || (opId !== null && paginatedRepliesQuery.isLoading))) ||
    (view === 'replies' && ((hasSubReplies && paginatedSubRepliesQuery.isLoading) || needsRootPostsLoading || needsLevel1RepliesLoading))

  const isError =
    (view === 'thread' && (postsQuery.isError || paginatedRepliesQuery.isError)) ||
    (view === 'replies' && paginatedSubRepliesQuery.isError)

  return {
    rawPosts,
    originalPost,
    resolvedSelectedPost,
    replies,
    sortedSubReplies,
    postsById,
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
