import { useState, useCallback } from 'react'
import { Bell } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import { useToast } from '../contexts/ToastContext'
import {
  useNotifications,
  useDismissNotification,
  useDismissAllNotifications,
} from '../hooks/useNotificationQueries'
import { Pagination } from '../components/Pagination'
import { EmptyState } from '../components/ui'
import { formatRelativeTime } from '../utils/format'
import { PAGE_SIZE } from '../utils/constants'
import type { Notification } from '../types'

interface NotificationsProps {
  onNavigateToPost: (notification: Notification) => void
}

function getNotificationMessage(notification: Notification): string {
  // Aggregated: replies + votes on your post
  const parts: string[] = []
  if (notification.reply_count > 0) {
    parts.push(`${notification.reply_count} ${notification.reply_count === 1 ? 'reply' : 'replies'}`)
  }
  if (notification.upvotes > 0) {
    parts.push(`${notification.upvotes} ${notification.upvotes === 1 ? 'like' : 'likes'}`)
  }
  if (notification.downvotes > 0) {
    parts.push(`${notification.downvotes} ${notification.downvotes === 1 ? 'dislike' : 'dislikes'}`)
  }
  return parts.length > 0
    ? `Your post received ${parts.join(' and ')}`
    : 'Activity on your post'
}

export function Notifications({ onNavigateToPost }: NotificationsProps) {
  const { user } = useAuth()
  const { showError } = useToast()
  const [page, setPage] = useState(1)

  const { data, isLoading } = useNotifications(user?.id || null, page)
  const dismissNotification = useDismissNotification(user?.id || null)
  const dismissAllNotifications = useDismissAllNotifications(user?.id || null)

  const notifications = data?.notifications || []
  const totalCount = data?.totalCount || 0
  const totalPages = Math.ceil(totalCount / PAGE_SIZE.POSTS)

  const handleNotificationClick = useCallback(
    async (notification: Notification) => {
      try {
        // Dismiss the notification first
        await dismissNotification.mutateAsync(notification.id)
      } catch {
        showError('Failed to dismiss notification')
      }
      // Navigate to the post regardless of dismiss success
      onNavigateToPost(notification)
    },
    [dismissNotification, onNavigateToPost, showError]
  )

  const handleDismissAll = useCallback(() => {
    dismissAllNotifications.mutate(undefined, {
      onError: () => showError('Failed to dismiss notifications'),
    })
  }, [dismissAllNotifications, showError])

  if (!user) {
    return (
      <div className="notifications-container">
        <div className="notifications-sign-in-prompt">
          Please sign in to view notifications.
        </div>
      </div>
    )
  }

  return (
    <div className="notifications-container">
      <div className="notifications-header">
        <h2>Alerts</h2>
        {notifications.length > 0 && (
          <button
            className="dismiss-all-btn"
            onClick={handleDismissAll}
            disabled={dismissAllNotifications.isPending}
          >
            Dismiss All
          </button>
        )}
      </div>

      {totalPages > 1 && (
        <Pagination
          currentPage={page}
          totalPages={totalPages}
          onPageChange={setPage}
          totalItems={totalCount}
          itemsPerPage={PAGE_SIZE.POSTS}
          itemName="notifications"
        />
      )}

      {isLoading ? (
        <div className="notifications-loading">Loading...</div>
      ) : notifications.length === 0 ? (
        <EmptyState
          icon={Bell}
          description="No notifications yet. You'll be notified when someone interacts with your posts."
        />
      ) : (
        <div className="notifications-list">
          {notifications.map((notification) => (
            <div
              key={notification.id}
              className="notification-item"
              onClick={() => handleNotificationClick(notification)}
            >
              <div className="notification-icon">
                <Bell size={16} />
              </div>
              <div className="notification-content">
                <div className="notification-message">
                  {getNotificationMessage(notification)}
                </div>
                <div className="notification-context">
                  <span className="notification-thread">
                    in: {notification.thread_title}
                  </span>
                  <span className="notification-date">
                    {formatRelativeTime(notification.updated_at)}
                  </span>
                </div>
                {notification.post_content && (
                  <div className="notification-preview">
                    {notification.post_content}
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {totalPages > 1 && (
        <Pagination
          currentPage={page}
          totalPages={totalPages}
          onPageChange={setPage}
          totalItems={totalCount}
          itemsPerPage={PAGE_SIZE.POSTS}
          itemName="notifications"
        />
      )}
    </div>
  )
}
