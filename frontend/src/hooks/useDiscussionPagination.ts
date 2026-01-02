import { useState, useEffect, useMemo, useCallback } from 'react'
import { PAGE_SIZE } from '../utils/constants'
import type { SortBy, ReplySortBy, SearchMode } from './useDiscussionFilters'

interface PaginationState {
  page: number
  setPage: (page: number) => void
  totalPages: number
  totalCount: number
  pageSize: number
}

// Persist page size to localStorage
const PAGE_SIZE_KEY = 'discussion.pageSize'

function getStoredPageSize(): number {
  try {
    const stored = localStorage.getItem(PAGE_SIZE_KEY)
    if (stored) {
      const parsed = parseInt(stored, 10)
      if (!isNaN(parsed) && parsed >= 1 && parsed <= 500) {
        return parsed
      }
    }
  } catch {
    // localStorage not available
  }
  return PAGE_SIZE.THREADS
}

interface UseDiscussionPaginationProps {
  // Dependencies for reset triggers
  sortBy: SortBy
  replySortBy: ReplySortBy
  searchMode: SearchMode
  authorUsername: string | null
  searchText: string | null
  isBookmarksView: boolean
  selectedThreadId: number | null
  selectedPostId: number | null
  // Only admins can customize page size
  isAdmin: boolean
  // Admin-only filters
  isDeleted: boolean
  isFlagged: boolean
}

interface UseDiscussionPaginationReturn {
  // Page states
  threadsPage: number
  setThreadsPage: (page: number) => void
  authorPostsPage: number
  setAuthorPostsPage: (page: number) => void
  bookmarksPage: number
  setBookmarksPage: (page: number) => void
  repliesPage: number
  setRepliesPage: (page: number) => void
  subRepliesPage: number
  setSubRepliesPage: (page: number) => void

  // Page size state (for threads/bookmarks - affects list view)
  threadsPageSize: number
  setThreadsPageSize: (size: number) => void
  pageSizeInput: string
  setPageSizeInput: (input: string) => void
  handlePageSizeBlur: () => void

  // Helper to build pagination info
  buildPaginationInfo: (
    key: 'threads' | 'postsSearch' | 'bookmarks' | 'replies' | 'subReplies',
    totalCount: number
  ) => PaginationState
}

export function useDiscussionPagination({
  sortBy,
  replySortBy,
  searchMode,
  authorUsername,
  searchText,
  isBookmarksView,
  selectedThreadId,
  selectedPostId,
  isAdmin,
  isDeleted,
  isFlagged,
}: UseDiscussionPaginationProps): UseDiscussionPaginationReturn {
  // Pagination state
  const [threadsPage, setThreadsPage] = useState(1)
  const [authorPostsPage, setAuthorPostsPage] = useState(1)
  const [bookmarksPage, setBookmarksPage] = useState(1)
  const [repliesPage, setRepliesPage] = useState(1)
  const [subRepliesPage, setSubRepliesPage] = useState(1)

  // Page size state (shared for threads/bookmarks in list view)
  // Only admins can use stored page size
  const initialPageSize = isAdmin ? getStoredPageSize() : PAGE_SIZE.THREADS
  const [threadsPageSize, setThreadsPageSizeState] = useState<number>(initialPageSize)
  const [pageSizeInput, setPageSizeInput] = useState<string>(String(initialPageSize))

  // Page size change handler with localStorage persistence
  const setThreadsPageSize = useCallback((newSize: number) => {
    setThreadsPageSizeState(newSize)
    setPageSizeInput(String(newSize))
    setThreadsPage(1) // Reset to first page when changing page size
    setBookmarksPage(1)
    setAuthorPostsPage(1)
    // Persist to localStorage
    try {
      localStorage.setItem(PAGE_SIZE_KEY, String(newSize))
    } catch {
      // localStorage not available
    }
  }, [])

  // Handle blur on page size input
  const handlePageSizeBlur = useCallback(() => {
    const val = parseInt(pageSizeInput, 10)
    if (!isNaN(val) && val >= 1 && val <= 500) {
      if (val !== threadsPageSize) {
        setThreadsPageSize(val)
      }
    } else {
      // Reset input to current valid value
      setPageSizeInput(String(threadsPageSize))
    }
  }, [pageSizeInput, threadsPageSize, setThreadsPageSize])

  // Reset pagination when sort, view, or search filter changes
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setThreadsPage(1)
  }, [sortBy, authorUsername, searchText, isDeleted, isFlagged])

  // Reset posts search pagination when search mode or filters change
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setAuthorPostsPage(1)
  }, [searchMode, authorUsername, searchText, isDeleted, isFlagged])

  // Reset bookmarks pagination when entering bookmarks view
  useEffect(() => {
    if (isBookmarksView) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setBookmarksPage(1)
    }
  }, [isBookmarksView])

  // Reset replies pagination when thread or sort changes
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setRepliesPage(1)
  }, [selectedThreadId, replySortBy])

  // Reset sub-replies pagination when selected post or sort changes
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setSubRepliesPage(1)
  }, [selectedPostId, replySortBy])

  // Helper to build pagination info object
  const buildPaginationInfo = useMemo(() => {
    const configs = {
      threads: {
        page: threadsPage,
        setPage: setThreadsPage,
        pageSize: threadsPageSize,
      },
      postsSearch: {
        page: authorPostsPage,
        setPage: setAuthorPostsPage,
        pageSize: threadsPageSize,
      },
      bookmarks: {
        page: bookmarksPage,
        setPage: setBookmarksPage,
        pageSize: threadsPageSize,
      },
      replies: {
        page: repliesPage,
        setPage: setRepliesPage,
        pageSize: PAGE_SIZE.POSTS,
      },
      subReplies: {
        page: subRepliesPage,
        setPage: setSubRepliesPage,
        pageSize: PAGE_SIZE.POSTS,
      },
    }

    return (
      key: 'threads' | 'postsSearch' | 'bookmarks' | 'replies' | 'subReplies',
      totalCount: number
    ): PaginationState => {
      const config = configs[key]
      return {
        page: config.page,
        setPage: config.setPage,
        totalPages: Math.ceil(totalCount / config.pageSize),
        totalCount,
        pageSize: config.pageSize,
      }
    }
  }, [threadsPage, authorPostsPage, bookmarksPage, repliesPage, subRepliesPage, threadsPageSize])

  return {
    threadsPage,
    setThreadsPage,
    authorPostsPage,
    setAuthorPostsPage,
    bookmarksPage,
    setBookmarksPage,
    repliesPage,
    setRepliesPage,
    subRepliesPage,
    setSubRepliesPage,
    threadsPageSize,
    setThreadsPageSize,
    pageSizeInput,
    setPageSizeInput,
    handlePageSizeBlur,
    buildPaginationInfo,
  }
}

export type { PaginationState }
