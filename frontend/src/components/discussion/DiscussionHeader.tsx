import { memo } from 'react'

interface DiscussionHeaderProps {
  // Navigation
  view: 'list' | 'thread' | 'replies'
  threadTitle?: string
  onGoToThreadFromTitle?: () => void
}

export const DiscussionHeader = memo(function DiscussionHeader({
  view,
  threadTitle,
  onGoToThreadFromTitle,
}: DiscussionHeaderProps) {
  return (
    view !== 'list' && threadTitle ? (
      <div className="discussion-header">
        <h2 className="thread-title-clickable" onClick={onGoToThreadFromTitle}>
          {threadTitle}
        </h2>
      </div>
    ) : null
  )
})
