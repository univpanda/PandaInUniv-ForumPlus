import { memo } from 'react'
import { MessageCircle } from 'lucide-react'

interface ReplyCountProps {
  count: number
  /** If provided, renders as clickable button */
  onClick?: (e: React.MouseEvent) => void
  disabled?: boolean
  title?: string
  size?: number
}

/**
 * Shared reply count display.
 * Can be static (span) or interactive (button) based on onClick prop.
 */
export const ReplyCount = memo(function ReplyCount({
  count,
  onClick,
  disabled = false,
  title = 'Reply',
  size = 14,
}: ReplyCountProps) {
  const content = (
    <>
      <MessageCircle size={size} />
      {count}
    </>
  )

  if (onClick && !disabled) {
    return (
      <button className="reply-count-badge clickable" onClick={onClick} title={title}>
        {content}
      </button>
    )
  }

  return <span className="reply-count-badge">{content}</span>
})
