import React, { memo, useRef, useEffect, useCallback } from 'react'
import { MessageSquare, Loader2 } from 'lucide-react'
import { formatTime, formatDateLabel, getDateKey, getAvatarUrl } from '../../utils/format'
import type { ChatMessage } from '../../types'
import { LoadingSpinner, EmptyState } from '../ui'

interface ChatMessageListProps {
  messages: ChatMessage[]
  loading: boolean
  currentUserId: string
  partnerAvatar: string | null
  partnerAvatarPath?: string | null
  partnerUsername: string | null
  /** Whether there are more messages to load */
  hasMore?: boolean
  /** Function to load more messages */
  onLoadMore?: () => void
  /** Whether more messages are currently being loaded */
  isLoadingMore?: boolean
}

export const ChatMessageList = memo(function ChatMessageList({
  messages,
  loading,
  currentUserId,
  partnerAvatar,
  partnerAvatarPath,
  partnerUsername,
  hasMore = false,
  onLoadMore,
  isLoadingMore = false,
}: ChatMessageListProps) {
  const displayName = partnerUsername || 'Private Panda'
  const avatarUrl = getAvatarUrl(partnerAvatar, displayName, partnerAvatarPath)
  const messagesContainerRef = useRef<HTMLDivElement>(null)
  const prevScrollHeightRef = useRef<number>(0)

  // Scroll to bottom when messages change (for new messages)
  useEffect(() => {
    if (!loading && messages.length > 0 && !isLoadingMore && messagesContainerRef.current) {
      messagesContainerRef.current.scrollTop = messagesContainerRef.current.scrollHeight
    }
  }, [messages, loading, isLoadingMore])

  // Maintain scroll position when loading older messages
  useEffect(() => {
    if (!isLoadingMore && prevScrollHeightRef.current > 0 && messagesContainerRef.current) {
      const newScrollHeight = messagesContainerRef.current.scrollHeight
      const scrollDiff = newScrollHeight - prevScrollHeightRef.current
      if (scrollDiff > 0) {
        messagesContainerRef.current.scrollTop = scrollDiff
      }
      prevScrollHeightRef.current = 0
    }
  }, [messages, isLoadingMore])

  // Detect scroll to top to load more messages
  const handleScroll = useCallback(() => {
    if (!messagesContainerRef.current || !hasMore || isLoadingMore || !onLoadMore) return

    const { scrollTop } = messagesContainerRef.current
    if (scrollTop < 50) {
      prevScrollHeightRef.current = messagesContainerRef.current.scrollHeight
      onLoadMore()
    }
  }, [hasMore, isLoadingMore, onLoadMore])

  return (
    <div className="chat-messages" ref={messagesContainerRef} onScroll={handleScroll}>
      {loading ? (
        <LoadingSpinner className="chat-loading" />
      ) : messages.length === 0 ? (
        <EmptyState
          icon={MessageSquare}
          description="No messages yet. Say hello!"
          className="chat-empty"
        />
      ) : (
        <>
          {/* Load more indicator at top */}
          {hasMore && (
            <div className="chat-load-more">
              {isLoadingMore ? (
                <Loader2 size={16} className="spin" />
              ) : (
                <span>Scroll up for older messages</span>
              )}
            </div>
          )}
          {messages.map((msg, index) => {
            const showDateSeparator =
              index === 0 ||
              getDateKey(msg.created_at) !== getDateKey(messages[index - 1].created_at)

            const isSent = msg.user_id === currentUserId
            const showAvatar = !isSent && (
              index === messages.length - 1 ||
              messages[index + 1]?.user_id === currentUserId
            )

            return (
              <React.Fragment key={msg.id}>
                {showDateSeparator && (
                  <div className="chat-date-separator">
                    <span>{formatDateLabel(msg.created_at)}</span>
                  </div>
                )}
                <div className={`chat-message ${isSent ? 'sent' : 'received'}`}>
                  {!isSent && showAvatar && (
                    <div className="chat-message-avatar">
                      <img src={avatarUrl} alt="" />
                    </div>
                  )}
                  {!isSent && !showAvatar && <div className="chat-message-avatar-spacer" />}
                  <div className="chat-message-bubble">
                    <p>{msg.content}</p>
                    <span className="chat-message-time">{formatTime(msg.created_at)}</span>
                  </div>
                </div>
              </React.Fragment>
            )
          })}
          <div />
        </>
      )}
    </div>
  )
})
