import { memo, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import rehypeRaw from 'rehype-raw'
import katex from 'katex'
import 'katex/dist/katex.min.css'
import type { Post } from '../types'
import { formatDate, parseAdditionalComments } from '../utils/format'
import { useDiscussionOptional } from '../contexts/DiscussionContext'
import { PostCardActions, PostCardHeader, SubReplyPreview } from './post'
import { ReplyCount } from './ui'

// Preprocess content to render <latex> tags as KaTeX HTML
// Each call resets equation numbering for the post
function processLatexTags(content: string): string {
  let equationCounter = 0

  return content.replace(/<latex>([\s\S]*?)<\/latex>/g, (_match, latex) => {
    try {
      // Check for $$ delimiters or block-level environments
      const hasDoubleDollar = /^\$\$[\s\S]*\$\$$/.test(latex.trim())
      const hasBlockEnv = /\\begin\{(equation\*?|align\*?|gather\*?|multline\*?|split|matrix|pmatrix|bmatrix|vmatrix|Vmatrix|smallmatrix|array|cases|subequations)\}/.test(latex)
      const isDisplayMode = hasDoubleDollar || hasBlockEnv

      // Strip $$ if present
      let processedLatex = latex
      if (hasDoubleDollar) {
        processedLatex = latex.trim().slice(2, -2)
      }

      // Inject custom \tag for equation numbering per post (only for numbered equations)
      if (/\\begin\{equation\}/.test(processedLatex) && !/\\tag\{/.test(processedLatex)) {
        equationCounter++
        // Insert \tag{n} before \end{equation}
        processedLatex = processedLatex.replace(/\\end\{equation\}/, `\\tag{${equationCounter}}\\end{equation}`)
      }

      return katex.renderToString(processedLatex, {
        throwOnError: false,
        displayMode: isDisplayMode,
      })
    } catch {
      return `<span class="latex-error">${latex}</span>`
    }
  })
}

interface PostCardProps {
  post: Post
  variant?: 'original' | 'reply' | 'parent'
  replyCount?: number // Override for original post to show thread reply count
  onClick?: () => void
  onReplyClick?: (e: React.MouseEvent) => void
  showSubReplyPreview?: boolean
  // Bookmark/Share props (only used for original posts)
  threadId?: number
  threadTitle?: string
  isBookmarked?: boolean
  // Optional overrides (if not using context)
  user?: { id: string } | null
  isAdmin?: boolean
  onDelete?: (post: Post, e: React.MouseEvent) => void
  onToggleFlagged?: (post: Post, e: React.MouseEvent) => void
  onUserDeletedClick?: (e: React.MouseEvent) => void
  // Children rendered between content and footer (e.g., poll)
  children?: React.ReactNode
}

export const PostCard = memo(function PostCard({
  post,
  variant = 'reply',
  replyCount,
  onClick,
  onReplyClick,
  showSubReplyPreview = false,
  threadId,
  threadTitle,
  isBookmarked,
  // Optional overrides
  user: userProp,
  isAdmin: isAdminProp,
  onDelete: onDeleteProp,
  onToggleFlagged: onToggleFlaggedProp,
  onUserDeletedClick: onUserDeletedClickProp,
  children,
}: PostCardProps) {
  // Use context values with prop fallbacks
  const ctx = useDiscussionOptional()

  const user = userProp ?? ctx?.user ?? null
  const isAdmin = isAdminProp ?? ctx?.isAdmin ?? false
  const onToggleFlagged = onToggleFlaggedProp ?? ctx?.onToggleFlagged
  const onDelete = onDeleteProp ?? ctx?.onDelete
  const onUserDeletedClick = onUserDeletedClickProp ?? ctx?.onUserDeletedClick
  const onEdit = ctx?.onEdit

  const displayReplyCount = replyCount ?? post.reply_count
  const hasReplies = displayReplyCount > 0
  const isDeleted = post.is_deleted ?? false
  const isUserDeleted = post.deleted_by === post.author_id
  const isOwner = Boolean(user?.id && post.author_id && user.id === post.author_id)

  // Get CSS class for post variant
  const variantClass =
    variant === 'original' ? 'original-post' : variant === 'parent' ? 'parent-post' : 'reply-card'

  // Deleted posts: hide from non-admins if no replies, show placeholder for users
  if (isDeleted && !isAdmin) {
    if (!hasReplies) return null
    // User view: show "deleted" placeholder (only shown if has replies)
    return (
      <div
        className={`post-card ${variantClass} compact deleted-post`}
        onClick={onClick}
        style={onClick ? { cursor: 'pointer' } : undefined}
      >
        {/* Header with date */}
        <div className="post-header">
          <div className="post-author">
            <span className="post-date">{formatDate(post.created_at)}</span>
          </div>
        </div>
        {/* Deleted content */}
        <div className="post-content deleted-content">
          <em>This post has been deleted.</em>
        </div>
        {/* Footer with reply count */}
        <div className="post-footer">
          <div className="post-actions">
            <ReplyCount count={displayReplyCount} />
          </div>
        </div>
      </div>
    )
  }

  // Deleted post styling for admin view
  const deletedClass = isDeleted && isAdmin ? 'deleted-post admin-view' : ''
  // Highlight optimistic posts (negative IDs) or recently edited posts (within 3 seconds)
  const isRecentlyEdited = post.edited_at && (Date.now() - new Date(post.edited_at).getTime()) < 3000
  const highlightClass = post.id < 0 || isRecentlyEdited ? 'highlight' : ''

  const isOriginal = variant === 'original'

  // Show more/less for long content
  const CONTENT_LIMIT = 2000
  const safeContent = post.content ?? ''
  const isLongContent = safeContent.length > CONTENT_LIMIT
  const [isExpanded, setIsExpanded] = useState(false)
  const displayContent = isLongContent && !isExpanded
    ? safeContent.slice(0, CONTENT_LIMIT) + '...'
    : safeContent

  return (
    <div
      className={`post-card ${variantClass} compact ${hasReplies && variant === 'reply' ? 'has-replies' : ''} ${deletedClass} ${highlightClass}`}
      onClick={onClick}
      style={onClick ? { cursor: 'pointer' } : undefined}
      data-post-id={post.id}
    >
      {/* Post Header */}
      <PostCardHeader
        post={post}
        isOriginal={isOriginal}
        isDeleted={isDeleted}
        isUserDeleted={isUserDeleted}
        isOwner={isOwner}
        isAdmin={isAdmin}
        user={user}
        onEdit={onEdit}
        onDelete={onDelete}
        onToggleFlagged={onToggleFlagged}
        onUserDeletedClick={onUserDeletedClick}
      />

      {/* Post Content */}
      <div className="post-content markdown-content">
        {/* Show edited indicator only if someone has interacted (replied or voted) */}
        {post.edited_at && (post.reply_count > 0 || post.likes > 0 || post.dislikes > 0) && (
          <><span className="edited-indicator">(edited)</span><br /></>
        )}
        <ReactMarkdown rehypePlugins={[rehypeRaw]}>{processLatexTags(displayContent)}</ReactMarkdown>
        {isLongContent && (
          <button
            className="show-more-btn"
            onClick={(e) => {
              e.stopPropagation()
              setIsExpanded(!isExpanded)
            }}
          >
            {isExpanded ? 'Show less' : 'Show more'}
          </button>
        )}
        {post.additional_comments && (
          <div className="additional-comments">
            <strong>Additional comments (oldest first):</strong>
            {parseAdditionalComments(post.additional_comments).map((comment, idx) => (
              <div key={idx} className="additional-comment-item">
                {comment.timestamp && (
                  <>
                    <strong className="comment-timestamp">{formatDate(comment.timestamp)}:</strong>
                    <br />
                  </>
                )}
                {comment.text}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Children (e.g., poll) - rendered between content and footer */}
      {children}

      {/* Post Footer - Actions only */}
      <div className="post-footer">
        <PostCardActions
          post={post}
          variant={variant}
          displayReplyCount={displayReplyCount}
          onReplyClick={onReplyClick}
          threadId={threadId}
          threadTitle={threadTitle}
          isBookmarked={isBookmarked}
          user={userProp}
        />
      </div>

      {/* Sub-reply Preview */}
      {showSubReplyPreview && (
        <SubReplyPreview post={post} displayReplyCount={displayReplyCount} onClick={onClick} />
      )}
    </div>
  )
})
