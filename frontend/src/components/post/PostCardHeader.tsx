import { memo } from 'react'
import { AlertCircle, Trash2, Undo2, User, Edit2 } from 'lucide-react'
import type { Post } from '../../types'
import { formatDate, formatDateTimeAbsolute, getAvatarUrl, canEditContent } from '../../utils/format'
import { UserNameHover } from '../UserNameHover'

interface PostCardHeaderProps {
  post: Post
  isOriginal: boolean
  isDeleted: boolean
  isUserDeleted: boolean
  isOwner: boolean
  isAdmin: boolean
  user: { id: string } | null
  onEdit?: (post: Post, e: React.MouseEvent) => void
  onDelete?: (post: Post, e: React.MouseEvent) => void
  onToggleFlagged?: (post: Post, e: React.MouseEvent) => void
  onUserDeletedClick?: (e: React.MouseEvent) => void
}

export const PostCardHeader = memo(function PostCardHeader({
  post,
  isOriginal,
  isDeleted,
  isUserDeleted,
  isOwner,
  isAdmin,
  user,
  onEdit,
  onDelete,
  onToggleFlagged,
  onUserDeletedClick,
}: PostCardHeaderProps) {
  const canEdit = canEditContent(post.created_at)

  return (
    <div className="post-header">
      <div className="post-author">
        <img
          src={getAvatarUrl(post.author_avatar, post.author_name, post.author_avatar_path)}
          alt=""
          className="avatar-small"
        />
        <UserNameHover
          userId={post.author_id}
          username={post.author_name}
          avatar={post.author_avatar}
          avatarPath={post.author_avatar_path}
          currentUserId={user?.id || null}
          className="author-name"
        />
        <span className="post-date">
          {isOriginal ? formatDateTimeAbsolute(post.created_at) : formatDate(post.created_at)}
        </span>
        {/* Edit button - next to time */}
        {!isDeleted && isOwner && onEdit && (isOriginal || canEdit) && (
          <button
            className="edit-btn"
            onClick={(e) => {
              e.stopPropagation()
              onEdit(post, e)
            }}
            title={canEdit ? 'Edit post' : 'Add additional comments'}
          >
            <Edit2 size={14} />
          </button>
        )}
      </div>
      <div className="post-header-actions">
        {isAdmin && onToggleFlagged && (
          <button
            className={`flag-indicator ${post.is_flagged ? 'flagged' : ''}`}
            onClick={(e) => {
              e.stopPropagation()
              onToggleFlagged(post, e)
            }}
            title={
              post.is_flagged
                ? `Flagged: ${post.flag_reason} (click to unflag)`
                : 'Click to flag this post'
            }
          >
            <AlertCircle size={14} />
          </button>
        )}
        {/* Delete button */}
        {!isDeleted && (isOwner || isAdmin) && onDelete && (
          <button
            className="delete-btn"
            onClick={(e) => {
              e.stopPropagation()
              onDelete(post, e)
            }}
            title="Delete post"
            aria-label="Delete post"
          >
            <Trash2 size={14} />
          </button>
        )}
        {/* Undelete button for admin on admin-deleted posts only */}
        {isDeleted && isAdmin && !isUserDeleted && onDelete && (
          <button
            className="undelete-btn"
            onClick={(e) => {
              e.stopPropagation()
              onDelete(post, e)
            }}
            title="Restore post"
            aria-label="Restore post"
          >
            <Undo2 size={14} />
          </button>
        )}
        {/* User icon indicator for user-deleted posts (admin view) */}
        {isDeleted && isAdmin && isUserDeleted && (
          <button
            className="user-deleted-indicator"
            title="Deleted by user"
            onClick={(e) => {
              e.stopPropagation()
              onUserDeletedClick?.(e)
            }}
          >
            <User size={14} />
          </button>
        )}
      </div>
    </div>
  )
})
