import { useMemo } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { usePosts, usePaginatedPosts, usePaginatedAuthorPosts, useThreadView, forumKeys } from './useForumQueries'
import { PAGE_SIZE } from '../utils/constants'
import { isPostStub, isFullPost } from '../types'
import type { View, SelectedThread, SelectedPost } from './useDiscussionNavigation'
import type { ReplySortBy } from './useDiscussionFilters'
import type { Post, AuthorPost, GetPaginatedPostsResponse, ThreadViewResponse } from '../types'

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
  isFetching: boolean
  isError: boolean

  // Pagination totals
  repliesTotalCount: number
  subRepliesTotalCount: number

  // Refetch functions
  refetchPosts: () => void
  refetchReplies: () => void
  refetchSubReplies: () => void
  refetchPostsSearch: () => void
  refetchRootPosts: () => void
  refetchLevel1Replies: () => void
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

  // ============ THREAD VIEW: Single query for OP + paginated replies ============
  // Uses get_thread_view RPC which returns both in one call (no waterfall)
  const threadViewQuery = useThreadView(
    threadId ?? 0,
    repliesPage,
    PAGE_SIZE.POSTS,
    replySortBy,
    view === 'thread' && threadId !== null
  )

  // ============ REPLIES VIEW: Sub-replies + OP lookup ============

  // Sub-replies query for replies view - server-side sorted
  // Only check reply_count if we have a full Post (not a stub)
  const hasSubReplies = view === 'replies' && isFullPost(selectedPost) && selectedPost.reply_count > 0
  const paginatedSubRepliesQuery = usePaginatedPosts(
    threadId ?? 0,
    selectedPost?.id ?? 0,
    subRepliesPage,
    PAGE_SIZE.POSTS,
    replySortBy,
    view === 'replies' && threadId !== null && !!hasSubReplies
  )

  // Root posts query for replies view (to show OP)
  // First check cache from thread view, then fall back to query
  const threadViewCacheKey = threadId !== null ? forumKeys.threadView(threadId, 1, 'popular') : null
  const cachedThreadView = threadViewCacheKey
    ? queryClient.getQueryData<{ originalPost: Post | undefined }>(threadViewCacheKey)
    : undefined
  const cachedOp = cachedThreadView?.originalPost

  // Legacy root posts cache (for backwards compatibility)
  const rootPostsQueryKey = threadId !== null ? forumKeys.posts(threadId, null) : null
  const cachedRootPosts = rootPostsQueryKey
    ? queryClient.getQueryData<Post[]>(rootPostsQueryKey)
    : undefined

  // Only fetch if we don't have OP from any cache
  const needsOpFetch = view === 'replies' && threadId !== null && !cachedOp && !cachedRootPosts
  const threadRootPostsQuery = usePosts(threadId ?? 0, null, needsOpFetch)

  // Get OP ID for replies view (needed to fetch level-1 replies where selectedPost lives)
  const repliesViewOpId = useMemo(() => {
    if (view !== 'replies') return null
    // Try cached OP first
    if (cachedOp) return cachedOp.id
    // Then legacy cache
    const rootPosts = cachedRootPosts ?? threadRootPostsQuery.data ?? []
    const op = rootPosts.find((p) => p.parent_id === null)
    return op?.id ?? null
  }, [view, cachedOp, cachedRootPosts, threadRootPostsQuery.data])

  // Check if selectedPost is a stub (only has id, missing content)
  const isSelectedPostStub = view === 'replies' && isPostStub(selectedPost)

  // Fetch level-1 replies to find selectedPost when it's a stub
  const level1RepliesQuery = usePosts(
    threadId ?? 0,
    repliesViewOpId ?? 0,
    view === 'replies' && threadId !== null && repliesViewOpId !== null && isSelectedPostStub
  )

  // ============ POSTS SEARCH ============

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

  // Raw posts - for thread view, combine OP and replies from single query
  const rawPosts = useMemo(() => {
    if (view === 'thread') {
      const posts: Post[] = []
      if (threadViewQuery.data?.originalPost) posts.push(threadViewQuery.data.originalPost)
      posts.push(...(threadViewQuery.data?.replies ?? []))
      return posts
    }
    return []
  }, [view, threadViewQuery.data])

  // Computed original post and replies
  const { originalPost, replies } = useMemo(() => {
    if (view === 'list') return { originalPost: undefined, replies: [] }
    if (view === 'thread') {
      // Thread view: data comes from single threadView query
      return {
        originalPost: threadViewQuery.data?.originalPost,
        replies: threadViewQuery.data?.replies ?? [],
      }
    }
    // Replies view: get OP from cache or fetch
    if (cachedOp) {
      return { originalPost: cachedOp, replies: [] }
    }
    const rootPosts = cachedRootPosts ?? threadRootPostsQuery.data ?? []
    const original = rootPosts.find((p) => p.parent_id === null)
    return { originalPost: original, replies: [] }
  }, [view, threadViewQuery.data, cachedOp, cachedRootPosts, threadRootPostsQuery.data])

  // Resolve selectedPost from fetched data when it's a stub
  const resolvedSelectedPost = useMemo(() => {
    if (view !== 'replies' || !selectedPost) return undefined
    const targetId = selectedPost.id
    const cache = queryClient.getQueryCache()

    const findPostInData = (data: unknown): Post | undefined => {
      if (!data) return undefined
      if (Array.isArray(data)) {
        return (data as Post[]).find((p) => p.id === targetId)
      }
      if (typeof data === 'object' && data) {
        if ('posts' in data && Array.isArray((data as GetPaginatedPostsResponse).posts)) {
          return (data as GetPaginatedPostsResponse).posts.find((p) => p.id === targetId)
        }
        if ('originalPost' in data && 'replies' in data) {
          const threadView = data as ThreadViewResponse
          const opMatch = threadView.originalPost?.id === targetId ? threadView.originalPost : undefined
          if (opMatch) return opMatch
          return threadView.replies.find((p) => p.id === targetId)
        }
      }
      return undefined
    }

    if (threadId !== null) {
      // Search all post-related caches for this thread (threadView, root, replies pages).
      const key = ['forum', 'posts', threadId] as const
      const queries = cache.findAll({ queryKey: key })
      for (const query of queries) {
        const found = findPostInData(query.state.data)
        if (found) return found
      }
    }

    // Otherwise, find it in the level-1 replies
    const level1Replies = level1RepliesQuery.data ?? []
    const resolved = level1Replies.find((p) => p.id === targetId)
    if (resolved) return resolved

    // Fallback to original selected post (stub or full)
    return isPostStub(selectedPost) ? undefined : selectedPost
  }, [queryClient, repliesViewOpId, selectedPost, threadId, view, level1RepliesQuery.data])

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

  const needsRootPostsLoading = needsOpFetch && threadRootPostsQuery.isLoading
  const needsLevel1RepliesLoading = isSelectedPostStub && level1RepliesQuery.isLoading

  // Thread view: simple loading - just wait for single query
  const isThreadViewLoading = view === 'thread' && threadViewQuery.isLoading
  const isThreadViewFetching = view === 'thread' && threadViewQuery.isFetching

  // Replies view: loading if sub-replies loading OR we need OP and it's loading
  const isRepliesViewLoading =
    view === 'replies' &&
    ((hasSubReplies && paginatedSubRepliesQuery.isLoading) || needsRootPostsLoading || needsLevel1RepliesLoading)

  const isLoading = isThreadViewLoading || isRepliesViewLoading

  const isRepliesViewFetching =
    view === 'replies' &&
    ((hasSubReplies && paginatedSubRepliesQuery.isFetching) ||
      (needsOpFetch && threadRootPostsQuery.isFetching) ||
      (isSelectedPostStub && level1RepliesQuery.isFetching))

  const isFetching = isThreadViewFetching || isRepliesViewFetching

  const isThreadViewError = view === 'thread' && threadViewQuery.isError
  const isRepliesViewError =
    view === 'replies' &&
    ((hasSubReplies && paginatedSubRepliesQuery.isError) ||
      (needsOpFetch && threadRootPostsQuery.isError) ||
      (isSelectedPostStub && level1RepliesQuery.isError))

  const isError = isThreadViewError || isRepliesViewError

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
    isFetching,
    isError,
    repliesTotalCount: threadViewQuery.data?.totalCount ?? 0,
    subRepliesTotalCount: paginatedSubRepliesQuery.data?.totalCount ?? 0,
    refetchPosts: threadViewQuery.refetch,
    refetchReplies: threadViewQuery.refetch,
    refetchSubReplies: paginatedSubRepliesQuery.refetch,
    refetchPostsSearch: paginatedPostsSearchQuery.refetch,
    refetchRootPosts: threadRootPostsQuery.refetch,
    refetchLevel1Replies: level1RepliesQuery.refetch,
  }
}
