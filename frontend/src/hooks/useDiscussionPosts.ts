import { useCallback, useMemo } from 'react'
import {
  useBookmarks,
  usePostBookmarks,
  useVotePost,
  useToggleBookmark,
  useTogglePostBookmark,
  useToggleFlagged,
  usePaginatedBookmarkedPosts,
} from './useForumQueries'
import { useDiscussionPagination } from './useDiscussionPagination'
import { useThreadListData } from './useThreadListData'
import { usePostViewData } from './usePostViewData'
import type { View, SelectedThread, SelectedPost } from './useDiscussionNavigation'
import type { SortBy, ReplySortBy, SearchMode } from './useDiscussionFilters'
import type { BookmarkedPost } from '../types'

interface UseDiscussionPostsProps {
  view: View
  selectedThread: SelectedThread
  selectedPost: SelectedPost
  sortBy: SortBy
  replySortBy: ReplySortBy
  isBookmarksView: boolean
  userId?: string
  authorUsername?: string | null
  searchText?: string | null
  searchMode?: SearchMode
  isAdmin?: boolean
  isDeleted?: boolean
  isFlagged?: boolean
  postType?: 'all' | 'op' | 'replies'
}

export function useDiscussionPosts({
  view,
  selectedThread,
  selectedPost,
  sortBy,
  replySortBy,
  isBookmarksView,
  userId,
  authorUsername,
  searchText,
  searchMode = 'threads',
  isAdmin = false,
  isDeleted = false,
  isFlagged = false,
  postType = 'all',
}: UseDiscussionPostsProps) {
  // Pagination state and reset logic
  const pagination = useDiscussionPagination({
    sortBy,
    replySortBy,
    searchMode,
    authorUsername: authorUsername ?? null,
    searchText: searchText ?? null,
    isBookmarksView,
    selectedThreadId: selectedThread?.id ?? null,
    selectedPostId: selectedPost?.id ?? null,
    isAdmin,
    isDeleted,
    isFlagged,
  })

  // Posts search mode is active when:
  // - There's an author filter (@username)
  // - There's a post type filter (@op or @replies)
  // - There's an admin filter (@deleted or @flagged)
  // - Or legacy: searchMode is 'posts' with any filter
  const isPostsSearchView =
    authorUsername !== null || postType !== 'all' || isDeleted || isFlagged ||
    (searchMode === 'posts' && searchText !== null)

  // Stable empty set fallback (prevents new object creation on each render)
  const emptySet = useMemo(() => new Set<number>(), [])

  // Bookmarks query (thread bookmarks)
  const bookmarksQuery = useBookmarks(userId)
  const bookmarks = bookmarksQuery.data ?? emptySet

  // Post bookmarks query
  const postBookmarksQuery = usePostBookmarks(userId, view !== 'thread')
  const postBookmarks = postBookmarksQuery.data ?? emptySet

  // Thread list data (paginated threads - not used in bookmarks view or posts search mode)
  const threadListData = useThreadListData({
    enabled: view === 'list' && !isPostsSearchView && !isBookmarksView,
    sortBy,
    threadsPage: pagination.threadsPage,
    threadsPageSize: pagination.threadsPageSize,
    authorUsername,
    searchText,
    isDeleted,
    isFlagged,
  })

  // Bookmarked posts query (for bookmarks view)
  // When in bookmarks view, searchText contains the text after @bookmarked
  const bookmarkedPostsQuery = usePaginatedBookmarkedPosts(
    userId,
    pagination.bookmarksPage,
    view === 'list' && isBookmarksView,
    isBookmarksView ? searchText : null
  )

  // Post view data (posts, replies, sub-replies, posts search)
  const postViewData = usePostViewData({
    view,
    selectedThread,
    selectedPost,
    replySortBy,
    repliesPage: pagination.repliesPage,
    subRepliesPage: pagination.subRepliesPage,
    authorPostsPage: pagination.authorPostsPage,
    authorUsername,
    searchText,
    isPostsSearchView,
    isDeleted,
    isFlagged,
    postType,
  })

  // ============ MUTATIONS ============

  const voteMutation = useVotePost()
  const toggleBookmarkMutation = useToggleBookmark(userId)
  const togglePostBookmarkMutation = useTogglePostBookmark(userId)
  const toggleFlaggedMutation = useToggleFlagged()

  // ============ LOADING & ERROR STATES ============

  // Initial loading (no data yet) - shows blocking spinner
  const loading =
    (view === 'list' && !isPostsSearchView && !isBookmarksView && threadListData.isLoading) ||
    (view === 'list' && isBookmarksView && bookmarkedPostsQuery.isLoading) ||
    (view === 'list' && isPostsSearchView && postViewData.postsSearchLoading) ||
    postViewData.isLoading

  // Background fetching (has data, refreshing) - shows subtle indicator
  const isFetching =
    (view === 'list' && !isPostsSearchView && !isBookmarksView && threadListData.isFetching) ||
    (view === 'list' && isBookmarksView && bookmarkedPostsQuery.isFetching) ||
    (view === 'list' && isPostsSearchView && postViewData.postsSearchLoading) ||
    postViewData.isFetching

  // Only consider query errors when the query is actually enabled/fetched
  // React Query keeps error state even when query is disabled, so we check fetchStatus
  const bookmarksQueryActuallyFailed = isBookmarksView && bookmarkedPostsQuery.isError && bookmarkedPostsQuery.fetchStatus !== 'idle'

  const queryError =
    (view === 'list' && !isPostsSearchView && !isBookmarksView && threadListData.isError) ||
    (view === 'list' && bookmarksQueryActuallyFailed) ||
    (view === 'list' && isPostsSearchView && postViewData.postsSearchError) ||
    postViewData.isError

  // ============ ACTIONS ============

  const handleRetry = useCallback(() => {
    if (view === 'list' && isBookmarksView) {
      bookmarkedPostsQuery.refetch()
    } else if (view === 'list' && !isPostsSearchView) {
      threadListData.refetch()
    } else if (view === 'list' && isPostsSearchView) {
      postViewData.refetchPostsSearch()
    } else if (view === 'thread') {
      postViewData.refetchPosts()
      postViewData.refetchReplies()
    } else if (view === 'replies') {
      postViewData.refetchSubReplies()
      postViewData.refetchRootPosts()
      postViewData.refetchLevel1Replies()
    }
  }, [view, isBookmarksView, isPostsSearchView, bookmarkedPostsQuery, threadListData, postViewData])

  // ============ RETURN ============

  return {
    // Data
    threads: threadListData.threads,
    posts: postViewData.rawPosts,
    postsById: postViewData.postsById,
    bookmarks,
    postBookmarks,
    bookmarkedPosts: bookmarkedPostsQuery.data?.posts ?? ([] as BookmarkedPost[]),
    originalPost: postViewData.originalPost,
    resolvedSelectedPost: postViewData.resolvedSelectedPost,
    replies: postViewData.replies,
    sortedSubReplies: postViewData.sortedSubReplies,
    subRepliesLoading: postViewData.subRepliesLoading,
    postsSearchData: postViewData.postsSearchData,
    postsSearchLoading: postViewData.postsSearchLoading,
    postsSearchIsPrivate: postViewData.postsSearchIsPrivate,
    isPostsSearchView,

    // Pagination (using helper to build info objects)
    pagination: {
      threads: pagination.buildPaginationInfo('threads', threadListData.totalCount),
      postsSearch: pagination.buildPaginationInfo('postsSearch', postViewData.postsSearchTotalCount),
      bookmarks: pagination.buildPaginationInfo('bookmarks', bookmarkedPostsQuery.data?.totalCount ?? 0),
      replies: pagination.buildPaginationInfo('replies', postViewData.repliesTotalCount),
      subReplies: pagination.buildPaginationInfo('subReplies', postViewData.subRepliesTotalCount),
    },

    // Page size control
    pageSizeControl: {
      pageSizeInput: pagination.pageSizeInput,
      setPageSizeInput: pagination.setPageSizeInput,
      handlePageSizeBlur: pagination.handlePageSizeBlur,
    },

    // State
    loading,
    isFetching,
    queryError,

    // Mutations
    voteMutation,
    toggleBookmarkMutation,
    togglePostBookmarkMutation,
    toggleFlaggedMutation,

    // Actions
    handleRetry,
  }
}

export type DiscussionPostsReturn = ReturnType<typeof useDiscussionPosts>
