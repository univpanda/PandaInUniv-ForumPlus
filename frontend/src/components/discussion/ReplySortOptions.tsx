import { memo } from 'react'

interface ReplySortOptionsProps {
  sortBy: 'popular' | 'new'
  onSortChange: (sort: 'popular' | 'new') => void
  show?: boolean
}

export const ReplySortOptions = memo(function ReplySortOptions({
  sortBy,
  onSortChange,
  show = true,
}: ReplySortOptionsProps) {
  if (!show) return null

  return (
    <div className="sort-options reply-sort">
      <button
        className={`sort-btn ${sortBy === 'popular' ? 'active' : ''}`}
        onClick={() => onSortChange('popular')}
      >
        Popular
      </button>
      <button
        className={`sort-btn ${sortBy === 'new' ? 'active' : ''}`}
        onClick={() => onSortChange('new')}
      >
        New
      </button>
    </div>
  )
})
