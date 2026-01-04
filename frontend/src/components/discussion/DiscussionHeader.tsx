import { memo, useMemo } from 'react'
import { X, Plus } from 'lucide-react'
import { SearchInput } from '../ui'
import { getSearchHelpText } from '../../utils/search'
import type { SortBy } from '../../hooks/useDiscussionFilters'

interface DiscussionHeaderProps {
  // Navigation
  view: 'list' | 'thread' | 'replies'

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
  showNewThread: boolean
  onToggleNewThread: () => void

  // Page size control
  pageSizeInput: string
  onPageSizeInputChange: (value: string) => void
  onPageSizeBlur: () => void
}

export const DiscussionHeader = memo(function DiscussionHeader({
  view,
  sortBy,
  onSortChange,
  searchQuery,
  onSearchQueryChange,
  isAdmin,
  user,
  showNewThread,
  onToggleNewThread,
  pageSizeInput,
  onPageSizeInputChange,
  onPageSizeBlur,
}: DiscussionHeaderProps) {
  // Get appropriate help text based on user status
  const searchHelpText = useMemo(() => getSearchHelpText(!!user, isAdmin), [user, isAdmin])

  return (
    <div className="discussion-header">
      {view === 'list' && (
        <div className="sort-options">
          <button
            className={`sort-btn ${sortBy === 'popular' ? 'active' : ''}`}
            onClick={() => onSortChange('popular')}
          >
            Popular
          </button>
          <button
            className={`sort-btn ${sortBy === 'recent' ? 'active' : ''}`}
            onClick={() => onSortChange('recent')}
          >
            Recent
          </button>
          <button
            className={`sort-btn ${sortBy === 'new' ? 'active' : ''}`}
            onClick={() => onSortChange('new')}
          >
            New
          </button>
        </div>
      )}

      {view === 'list' && (
        <div className="header-actions">
          <SearchInput
            value={searchQuery}
            onChange={onSearchQueryChange}
            placeholder="Forage..."
            iconSize={16}
            showHelp
            helpText={searchHelpText}
          />
          {isAdmin && (
            <input
              type="number"
              min="1"
              max="500"
              className="page-size-input"
              value={pageSizeInput}
              onChange={(e) => onPageSizeInputChange(e.target.value)}
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
          {user && (
            <button
              className={`new-thread-btn ${showNewThread ? 'cancel' : ''}`}
              onClick={onToggleNewThread}
            >
              {showNewThread ? <X size={18} /> : <Plus size={18} />}
              <span className="btn-text">{showNewThread ? 'Nah' : 'Chomp'}</span>
            </button>
          )}
        </div>
      )}
    </div>
  )
})
