import { useState, useCallback, useMemo } from 'react'
import { Bell, MessageCircle } from 'lucide-react'
import happyPanda from '../assets/webp/happy-panda.webp'
import sadPanda from '../assets/webp/sad-panda.webp'
import { useAuth } from '../hooks/useAuth'
import { useToast } from '../contexts/ToastContext'
import {
  useNotifications,
  useDismissNotification,
  useDismissAllNotifications,
} from '../hooks/useNotificationQueries'
import { Pagination } from '../components/Pagination'
import { PostCard } from '../components/PostCard'
import { EmptyState } from '../components/ui'
import { formatRelativeTime } from '../utils/format'
import { PAGE_SIZE } from '../utils/constants'
import type { Notification, Post } from '../types'

interface NotificationsProps {
  onNavigateToPost: (notification: Notification) => void
}

// Convert notification to Post for PostCard display
function notificationToPost(notification: Notification): Post {
  return {
    id: notification.post_id,
    thread_id: notification.thread_id,
    parent_id: notification.post_parent_id,
    author_id: notification.post_author_id,
    author_name: notification.post_author_name || 'Unknown',
    author_avatar: notification.post_author_avatar,
    content: notification.post_content || '',
    created_at: notification.post_created_at,
    edited_at: null,
    likes: notification.post_likes || 0,
    dislikes: notification.post_dislikes || 0,
    user_vote: null,
    reply_count: notification.post_reply_count || 0,
    first_reply_content: null,
    first_reply_author: null,
    first_reply_avatar: null,
    first_reply_date: null,
    is_flagged: false,
    flag_reason: null,
    is_deleted: false,
    deleted_by: null,
    additional_comments: null,
  }
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

  // Memoize notification-to-post conversions to prevent PostCard re-renders
  const notificationPosts = useMemo(
    () => notifications.map((n) => ({ notification: n, post: notificationToPost(n) })),
    [notifications]
  )

  const handleNotificationClick = useCallback(
    (notification: Notification) => {
      // Navigate immediately for better UX - don't block on dismiss
      onNavigateToPost(notification)
      // Dismiss in background - errors are non-critical since user already navigated
      dismissNotification.mutate(notification.id)
    },
    [dismissNotification, onNavigateToPost]
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
      ) : notificationPosts.length === 0 ? (
        <EmptyState
          icon={Bell}
          description="No notifications yet. You'll be notified when someone interacts with your posts."
        />
      ) : (
        <div className="author-posts-list">
          {notificationPosts.map(({ notification, post }) => {
            // Skip rendering if notification data is incomplete (post_id is required)
            if (!notification.post_id) {
              return null
            }
            return (
              <div key={notification.id} className="author-post-item">
                {/* Thread header - same style as search */}
                <div className="author-post-thread-info">
                  <span className="thread-link-btn" style={{ cursor: 'default' }}>
                    In thread: {notification.thread_title}
                  </span>
                  <span className="notification-date">
                    {formatRelativeTime(notification.updated_at)}
                  </span>
                </div>
                {/* Activity badges - what triggered the notification */}
                <div className="notification-badges">
                  {notification.new_reply_count > 0 && (
                    <span className="reply-count-badge">
                      <MessageCircle size={14} />
                      {notification.new_reply_count} new {notification.new_reply_count === 1 ? 'reply' : 'replies'}
                    </span>
                  )}
                  {notification.new_upvotes > 0 && (
                    <span className="notification-badge likes">
                      <img src={happyPanda} alt="" className="notification-panda-icon" />
                      {notification.new_upvotes} new
                    </span>
                  )}
                  {notification.new_downvotes > 0 && (
                    <span className="notification-badge dislikes">
                      <img src={sadPanda} alt="" className="notification-panda-icon" />
                      {notification.new_downvotes} new
                    </span>
                  )}
                </div>
                {/* Full post card - same as search results */}
                <div
                  className="author-post-card-wrapper"
                  onClick={() => handleNotificationClick(notification)}
                >
                  <PostCard
                    post={post}
                    user={user}
                    variant="reply"
                  />
                </div>
              </div>
            )
          })}
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
