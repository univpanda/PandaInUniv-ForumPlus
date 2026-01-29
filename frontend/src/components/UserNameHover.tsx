import { memo, useState, useRef, useCallback } from 'react'
import { MessagesSquare } from 'lucide-react'
import { useClickOutside } from '../hooks/useClickOutside'

interface UserNameHoverProps {
  userId: string
  username: string | null
  avatar: string | null
  avatarPath?: string | null
  currentUserId: string | null
  className?: string
  children?: React.ReactNode
}

// Custom event type for starting a chat
export interface StartChatEvent {
  userId: string
  username: string
  avatar: string | null
  avatarPath?: string | null
}

export const UserNameHover = memo(function UserNameHover(props: UserNameHoverProps) {
  const {
    userId,
    username,
    avatar,
    avatarPath,
    currentUserId,
    className = '',
    children,
  } = props
  const displayName = username ?? 'Private Panda'
  const [showPopup, setShowPopup] = useState(false)
  const containerRef = useRef<HTMLSpanElement>(null)

  // Don't show chat option for own username or when not logged in
  const canChat = currentUserId && currentUserId !== userId
  const isInteractive = !!currentUserId

  const handleTogglePopup = useCallback((event: React.MouseEvent) => {
    event.stopPropagation()
    if (!isInteractive) return
    setShowPopup((prev) => !prev)
  }, [isInteractive])

  const handleChatClick = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()

    // Dispatch custom event to trigger chat
    const event = new CustomEvent('startChatWithUser', {
      detail: { userId, username: displayName, avatar, avatarPath } as StartChatEvent,
    })
    window.dispatchEvent(event)
    setShowPopup(false)
  }

  useClickOutside(containerRef, () => setShowPopup(false), showPopup)

  return (
    <span
      ref={containerRef}
      className={`username-hover-container${isInteractive ? '' : ' is-disabled'}`}
      onClick={handleTogglePopup}
    >
      {children ? (
        <span className="username-trigger">
          {children}
        </span>
      ) : (
        <span className={`username-text ${className}`}>{displayName}</span>
      )}
      {isInteractive && showPopup && (
        <div
          className="username-popup"
          onClick={(e) => e.stopPropagation()}
        >
          {canChat ? (
            <button className="username-popup-btn" onClick={handleChatClick}>
              <MessagesSquare size={14} />
              <span>Whisper</span>
            </button>
          ) : currentUserId === userId ? (
            <span className="username-popup-info">You</span>
          ) : (
            <span className="username-popup-info">Sign in to whisper</span>
          )}
        </div>
      )}
    </span>
  )
})
