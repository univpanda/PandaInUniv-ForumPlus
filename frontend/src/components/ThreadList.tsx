import { memo } from 'react'
import { MessageSquare } from 'lucide-react'
import { formatRelativeTime } from '../utils/format'
import type { Thread } from '../types'
import { usePrefetchPosts } from '../hooks/useForumQueries'
import { EmptyState, VoteDisplay, ReplyCount, BookmarkButton } from './ui'

interface ThreadListProps {
  threads: Thread[]
  bookmarks: Set<number>
  user: { id: string } | null
  onOpenThread: (thread: Thread) => void
  onToggleBookmark: (threadId: number, e: React.MouseEvent) => void
}

export const ThreadList = memo(function ThreadList({
  threads,
  bookmarks,
  user,
  onOpenThread,
  onToggleBookmark,
}: ThreadListProps) {
  const prefetchPosts = usePrefetchPosts()
  if (threads.length === 0) {
    return (
      <EmptyState
        icon={MessageSquare}
        description="No threads yet. Be the first to start a discussion!"
      />
    )
  }

  return (
    <div className="thread-list">
      {threads.map((thread) => (
        <div
          key={thread.id}
          className="thread-card"
          onClick={() => onOpenThread(thread)}
          onMouseEnter={() => prefetchPosts(thread.id)}
        >
          {/* Thread row: title - time - votes - replies - bookmark */}
          <div className="thread-header">
            <h3 className="thread-title">{thread.title}</h3>
            <div className="thread-stats">
              <span className="thread-date">{formatRelativeTime(thread.created_at)}</span>
              <VoteDisplay
                likes={thread.total_likes || 0}
                dislikes={thread.total_dislikes || 0}
              />
              <ReplyCount count={thread.reply_count} />
              {user && (
                <BookmarkButton
                  isBookmarked={bookmarks.has(thread.id)}
                  onClick={(e) => onToggleBookmark(thread.id, e)}
                />
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  )
})
