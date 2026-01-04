import { memo, useState, useRef, useEffect } from 'react'
import { MessagesSquare } from 'lucide-react'

interface UserNameHoverProps {
  userId: string
  username: string
  avatar: string | null
  avatarPath?: string | null
  currentUserId: string | null
  className?: string
}

// Custom event type for starting a chat
export interface StartChatEvent {
  userId: string
  username: string
  avatar: string | null
  avatarPath?: string | null
}

export const UserNameHover = memo(function UserNameHover({
  userId,
  username,
  avatar,
  avatarPath,
  currentUserId,
  className = '',
}: UserNameHoverProps) {
  const [showPopup, setShowPopup] = useState(false)
  const containerRef = useRef<HTMLSpanElement>(null)
  const timeoutRef = useRef<number | null>(null)

  // Don't show chat option for own username or when not logged in
  const canChat = currentUserId && currentUserId !== userId

  const handleMouseEnter = () => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current)
    }
    timeoutRef.current = window.setTimeout(() => {
      setShowPopup(true)
    }, 150) // Small delay to prevent accidental triggers
  }

  const handleMouseLeave = () => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current)
    }
    timeoutRef.current = window.setTimeout(() => {
      setShowPopup(false)
    }, 150) // Small delay to allow moving to popup
  }

  const handleChatClick = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()

    // Dispatch custom event to trigger chat
    const event = new CustomEvent('startChatWithUser', {
      detail: { userId, username, avatar, avatarPath } as StartChatEvent,
    })
    window.dispatchEvent(event)
    setShowPopup(false)
  }

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current)
      }
    }
  }, [])

  return (
    <span
      ref={containerRef}
      className="username-hover-container"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      <span className={`username-text ${className}`}>{username}</span>
      {showPopup && (
        <div
          className="username-popup"
          onMouseEnter={() => {
            if (timeoutRef.current) clearTimeout(timeoutRef.current)
          }}
          onMouseLeave={handleMouseLeave}
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
