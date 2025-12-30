import { memo } from 'react'
import { Bookmark } from 'lucide-react'

interface BookmarkButtonProps {
  isBookmarked: boolean
  onClick: (e: React.MouseEvent) => void
  disabled?: boolean
  /** Custom title, defaults to "Remove bookmark" / "Bookmark" */
  title?: string
  size?: number
}

/**
 * Shared bookmark toggle button.
 * Used for both thread bookmarks (OP) and individual post bookmarks.
 */
export const BookmarkButton = memo(function BookmarkButton({
  isBookmarked,
  onClick,
  disabled = false,
  title,
  size = 16,
}: BookmarkButtonProps) {
  return (
    <button
      className={`bookmark-btn ${isBookmarked ? 'active' : ''}`}
      onClick={onClick}
      disabled={disabled}
      title={title ?? (isBookmarked ? 'Remove bookmark' : 'Bookmark')}
    >
      <Bookmark size={size} />
    </button>
  )
})
