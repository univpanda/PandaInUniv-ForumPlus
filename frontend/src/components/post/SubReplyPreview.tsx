import { memo } from 'react'
import type { Post } from '../../types'
import { formatDate, getAvatarUrl } from '../../utils/format'

interface SubReplyPreviewProps {
  post: Post
  displayReplyCount: number
  onClick?: () => void
}

export const SubReplyPreview = memo(function SubReplyPreview({
  post,
  displayReplyCount,
  onClick,
}: SubReplyPreviewProps) {
  if (!post.first_reply_content) return null

  return (
    <div
      className="sub-reply-preview"
      onClick={(e) => {
        e.stopPropagation()
        onClick?.()
      }}
    >
      <div className="sub-reply-content">{post.first_reply_content}</div>
      <div className="sub-reply-meta">
        <img
          src={getAvatarUrl(post.first_reply_avatar, post.first_reply_author || 'User', post.first_reply_avatar_path)}
          alt=""
          className="avatar-tiny"
        />
        <span className="sub-reply-author">{post.first_reply_author}</span>
        {post.first_reply_date && (
          <span className="sub-reply-date">{formatDate(post.first_reply_date)}</span>
        )}
        {displayReplyCount > 1 && (
          <span className="sub-reply-more">+{displayReplyCount - 1} more</span>
        )}
      </div>
    </div>
  )
})
