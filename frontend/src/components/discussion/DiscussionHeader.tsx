import { memo, useMemo, useEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { ChevronDown } from 'lucide-react'
import { SearchInput } from '../ui'
import { getSearchHelpText } from '../../utils/search'
import type { SortBy } from '../../hooks/useDiscussionFilters'

interface DiscussionHeaderProps {
  // Navigation
  view: 'list' | 'thread' | 'replies'
  threadTitle?: string
  onGoToThreadFromTitle?: () => void
  onGoToList?: () => void

  // Sort
  sortBy: SortBy
  onSortChange: (sort: SortBy) => void

  // Search
  searchQuery: string
  onSearchQueryChange: (query: string) => void

  // Admin
  isAdmin: boolean

  // User actions
  user: { id: string } | null

  // Page size control
  pageSizeInput: string
  onPageSizeInputChange: (value: string) => void
  onPageSizeBlur: () => void
}

export const DiscussionHeader = memo(function DiscussionHeader({
  view,
  threadTitle,
  onGoToThreadFromTitle,
  onGoToList,
  sortBy,
  onSortChange,
  searchQuery,
  onSearchQueryChange,
  isAdmin,
  user,
  pageSizeInput,
  onPageSizeInputChange,
  onPageSizeBlur,
}: DiscussionHeaderProps) {
  // Get appropriate help text based on user status
  const searchHelpText = useMemo(
    () => getSearchHelpText(!!user, isAdmin),
    [user, isAdmin]
  )

  const ensureListView = () => {
    if (view !== 'list') {
      onGoToList?.()
    }
  }

  const [utilityRoot, setUtilityRoot] = useState<HTMLElement | null>(null)

  useEffect(() => {
    setUtilityRoot(document.getElementById('header-utilities'))
  }, [])

  const utilities = (
    <div className={`discussion-utilities ${searchQuery ? 'search-expanded' : ''}`}>
      <div className="discussion-utility discussion-utility-sort">
        <div className="sort-options sort-select-container">
          <select
            className="sort-select"
            value={sortBy}
            onChange={(e) => {
              ensureListView()
              onSortChange(e.target.value as SortBy)
            }}
            aria-label="Sort threads"
          >
            <option value="popular">Popular</option>
            <option value="recent">Recent</option>
            <option value="new">New</option>
          </select>
          <ChevronDown className="sort-select-icon" size={16} aria-hidden="true" />
        </div>
      </div>
      <div className="discussion-utility discussion-utility-search">
        <SearchInput
          value={searchQuery}
          onChange={(value) => {
            ensureListView()
            onSearchQueryChange(value)
          }}
          placeholder="Forage for discussions..."
          className={`header-search ${searchQuery ? 'has-value' : ''}`}
          iconSize={16}
          showHelp
          helpText={searchHelpText}
        />
      </div>
      <div className="discussion-utility discussion-utility-actions">
        {isAdmin && (
          <input
            type="number"
            min="1"
            max="500"
            className="page-size-input"
            value={pageSizeInput}
            onChange={(e) => {
              ensureListView()
              onPageSizeInputChange(e.target.value)
            }}
            onBlur={onPageSizeBlur}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                onPageSizeBlur()
                e.currentTarget.blur()
              }
            }}
            title="Items per page"
          />
        )}
      </div>
    </div>
  )

  const utilityPortal = utilityRoot && utilities
    ? createPortal(utilities, utilityRoot)
    : null

  const showInlineUtilities = !utilityRoot

  return (
    <>
      {utilityPortal}
      {(view !== 'list' || showInlineUtilities) && (
        <div className="discussion-header">
          {showInlineUtilities && utilities}
          {view !== 'list' && threadTitle && (
            <h2 className="thread-title-clickable" onClick={onGoToThreadFromTitle}>
              {threadTitle}
            </h2>
          )}
        </div>
      )}
    </>
  )
})
