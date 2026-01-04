import { useState, useCallback, useDeferredValue, useMemo } from 'react'
import type { ThreadSortBy } from './useForumQueries'
import { parseSearchQuery } from '../utils/search'

// UI sort - no longer includes 'bookmarks' (now handled via @bookmarked search)
export type SortBy = ThreadSortBy
export type ReplySortBy = 'popular' | 'new'
export type SearchMode = 'threads' | 'posts'

export function useDiscussionFilters() {
  // Sort state
  const [sortBy, setSortBy] = useState<SortBy>('popular')
  const [replySortBy, setReplySortBy] = useState<ReplySortBy>('popular')

  // Search state
  const [searchQuery, setSearchQuery] = useState('')
  const deferredSearchQuery = useDeferredValue(searchQuery)
  const [searchMode, setSearchMode] = useState<SearchMode>('threads')

  // Parse search query to detect @bookmarked
  const parsedSearch = useMemo(() => parseSearchQuery(deferredSearchQuery), [deferredSearchQuery])

  // Derived state - bookmarks view is now triggered by @bookmarked in search
  const isBookmarksView = parsedSearch.isBookmarked

  // Handle sort change
  const handleSortChange = useCallback((newSort: SortBy) => {
    setSortBy(newSort)
  }, [])

  // Show bookmarks view by setting search to @bookmarked
  const showBookmarksView = useCallback(() => {
    setSearchQuery('@bookmarked')
  }, [])

  // Set to recent sort (used when navigating to thread from posts search)
  const setRecentSort = useCallback(() => {
    setSortBy('recent')
  }, [])

  return {
    // Sort state
    sortBy,
    replySortBy,
    setReplySortBy,

    // Search state
    searchQuery,
    setSearchQuery,
    deferredSearchQuery,
    searchMode,
    setSearchMode,

    // Parsed search (includes isBookmarked, authorUsername, searchTerms)
    parsedSearch,

    // Derived state
    isBookmarksView,

    // Actions
    handleSortChange,
    showBookmarksView,
    setRecentSort,
  }
}

export type DiscussionFiltersReturn = ReturnType<typeof useDiscussionFilters>
