import { memo, useState, useCallback, useRef } from 'react'
import { Upload } from 'lucide-react'
import happyPanda from '../../assets/webp/happy-panda.webp'
import sadPanda from '../../assets/webp/sad-panda.webp'
import type { Post } from '../../types'
import { useDiscussionOptional } from '../../contexts/DiscussionContext'
import { useClickOutside } from '../../hooks/useClickOutside'
import { BookmarkButton, ReplyCount } from '../ui'

// Separate component for share button
const ShareButton = memo(function ShareButton({
  threadId,
  postId,
  threadTitle,
}: {
  threadId: number
  postId?: number
  threadTitle?: string
}) {
  const [showMenu, setShowMenu] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  // Close menu when clicking outside
  useClickOutside(menuRef, () => setShowMenu(false), showMenu)

  const getShareData = useCallback(() => {
    const baseUrl = window.location.origin
    // If postId is provided, link to specific post, otherwise link to thread
    const url = postId
      ? `${baseUrl}/?thread=${threadId}&post=${postId}`
      : `${baseUrl}/?thread=${threadId}`
    const title = threadTitle || 'Check out this discussion'
    return { url, title }
  }, [threadId, postId, threadTitle])

  const shareToTwitter = useCallback((e: React.MouseEvent) => {
    e.stopPropagation()
    const { url, title } = getShareData()
    const twitterUrl = `https://twitter.com/intent/tweet?text=${encodeURIComponent(title)}&url=${encodeURIComponent(url)}`
    window.open(twitterUrl, '_blank', 'noopener,noreferrer')
    setShowMenu(false)
  }, [getShareData])

  const shareToWhatsApp = useCallback((e: React.MouseEvent) => {
    e.stopPropagation()
    const { url, title } = getShareData()
    const whatsappUrl = `https://wa.me/?text=${encodeURIComponent(`${title} ${url}`)}`
    window.open(whatsappUrl, '_blank', 'noopener,noreferrer')
    setShowMenu(false)
  }, [getShareData])

  return (
    <div className="share-container" ref={menuRef}>
      <button
        className="share-btn"
        onClick={(e) => {
          e.stopPropagation()
          setShowMenu(!showMenu)
        }}
        title="Share"
      >
        <Upload size={14} />
      </button>
      {showMenu && (
        <div className="share-menu">
          <button className="share-menu-item" onClick={shareToTwitter}>
            <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
            </svg>
            <span>Twitter</span>
          </button>
          <button className="share-menu-item" onClick={shareToWhatsApp}>
            <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
            </svg>
            <span>WhatsApp</span>
          </button>
        </div>
      )}
    </div>
  )
})

interface PostCardActionsProps {
  post: Post
  variant: 'original' | 'reply' | 'parent'
  displayReplyCount?: number
  hideReplyCount?: boolean
  onReplyClick?: (e: React.MouseEvent) => void
  // Thread bookmark props (original posts)
  threadId?: number
  threadTitle?: string
  isBookmarked?: boolean
  // Post bookmark props (optional override)
  isPostBookmarked?: boolean
  // Optional context overrides
  user?: { id: string } | null
  onVote?: (postId: number, voteType: 1 | -1, e: React.MouseEvent) => void
  onBookmarkToggle?: (threadId: number, e: React.MouseEvent) => void
  onPostBookmarkToggle?: (postId: number, e: React.MouseEvent) => void
}

export const PostCardActions = memo(function PostCardActions({
  post,
  variant,
  displayReplyCount: displayReplyCountProp,
  hideReplyCount = false,
  onReplyClick,
  threadId,
  threadTitle,
  isBookmarked: isBookmarkedProp,
  isPostBookmarked: isPostBookmarkedProp,
  // Optional overrides
  user: userProp,
  onVote: onVoteProp,
  onBookmarkToggle: onBookmarkToggleProp,
  onPostBookmarkToggle: onPostBookmarkToggleProp,
}: PostCardActionsProps) {
  // Use context values with prop fallbacks
  const ctx = useDiscussionOptional()

  const user = userProp ?? ctx?.user ?? null
  const onVote = onVoteProp ?? ctx?.onVote
  const onBookmarkToggle = onBookmarkToggleProp ?? ctx?.onToggleBookmark
  const onPostBookmarkToggle = onPostBookmarkToggleProp ?? ctx?.onTogglePostBookmark
  // When user is signed out, bookmarks should always be false
  const isBookmarked = user
    ? (isBookmarkedProp ?? (threadId ? ctx?.bookmarks.has(threadId) : false) ?? false)
    : false
  const isPostBookmarked = user
    ? (isPostBookmarkedProp ?? post.is_bookmarked ?? ctx?.postBookmarks?.has(post.id) ?? false)
    : false

  // Compute derived values from post
  const displayReplyCount = displayReplyCountProp ?? post.reply_count
  const isDeleted = post.is_deleted ?? false

  // Calculate aggregate score
  const score = post.likes - post.dislikes

  return (
    <div className="post-actions">
      {/* Vote buttons with aggregate score */}
      <div className="vote-group">
        <button
          className={`vote-btn like ${post.user_vote === 1 ? 'active' : ''}`}
          onClick={(e) => onVote?.(post.id, 1, e)}
          disabled={!user || isDeleted || !onVote}
          aria-label="Upvote"
        >
          <img src={happyPanda} alt="Upvote" className="vote-icon" />
        </button>
        <span className={`vote-score ${score > 0 ? 'positive' : score < 0 ? 'negative' : ''}`}>
          {score}
        </span>
        <button
          className={`vote-btn dislike ${post.user_vote === -1 ? 'active' : ''}`}
          onClick={(e) => onVote?.(post.id, -1, e)}
          disabled={!user || isDeleted || !onVote}
          aria-label="Downvote"
        >
          <img src={sadPanda} alt="Downvote" className="vote-icon" />
        </button>
      </div>

      {/* Reply count - hide for sub-replies since they can't have further replies */}
      {!hideReplyCount && (
        <ReplyCount
          count={displayReplyCount}
          onClick={onReplyClick && user && !isDeleted ? onReplyClick : undefined}
          disabled={!user || isDeleted || !onReplyClick}
        />
      )}

      {/* Bookmark button - thread bookmark for original, post bookmark for replies */}
      {user && variant === 'original' && threadId && onBookmarkToggle && (
        <BookmarkButton
          isBookmarked={isBookmarked}
          onClick={(e) => onBookmarkToggle(threadId, e)}
          title={isBookmarked ? 'Remove bookmark' : 'Bookmark thread'}
          size={14}
        />
      )}
      {user && variant !== 'original' && onPostBookmarkToggle && (
        <BookmarkButton
          isBookmarked={isPostBookmarked}
          onClick={(e) => onPostBookmarkToggle(post.id, e)}
          title={isPostBookmarked ? 'Remove bookmark' : 'Bookmark post'}
          size={14}
        />
      )}

      {/* Share button - for all posts */}
      {threadId && (
        <ShareButton
          threadId={threadId}
          postId={variant !== 'original' ? post.id : undefined}
          threadTitle={threadTitle}
        />
      )}
    </div>
  )
})
