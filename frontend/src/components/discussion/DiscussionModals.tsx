import { memo, useState, useEffect, useCallback } from 'react'
import { AlertTriangle } from 'lucide-react'
import { Modal } from '../Modal'
import { ButtonSpinner } from '../ui'
import { canEditContent } from '../../utils/format'
import type { Post } from '../../hooks/useForumQueries'

interface EditModalProps {
  post: Post
  editContent: string
  additionalComment: string
  submitting: boolean
  onEditContentChange: (content: string) => void
  onAdditionalCommentChange: (comment: string) => void
  onSubmit: () => void
  onClose: () => void
}

export const EditModal = memo(function EditModal({
  post,
  editContent,
  additionalComment,
  submitting,
  onEditContentChange,
  onAdditionalCommentChange,
  onSubmit,
  onClose,
}: EditModalProps) {
  // Track canEdit state with re-evaluation
  const [canEdit, setCanEdit] = useState(() => canEditContent(post.created_at))
  const [showExpiredWarning, setShowExpiredWarning] = useState(false)
  const isOriginalPost = post.parent_id === null

  // Handle Shift+Enter / Cmd+Enter / Ctrl+Enter to submit
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
      if (e.key === 'Enter' && (e.shiftKey || e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        const hasContent = canEdit ? editContent.trim() : additionalComment.trim()
        if (!submitting && hasContent) {
          onSubmit()
        }
      }
    },
    [canEdit, editContent, additionalComment, submitting, onSubmit]
  )

  // Re-check edit window every 10 seconds
  useEffect(() => {
    const checkEditWindow = () => {
      const stillCanEdit = canEditContent(post.created_at)
      if (!stillCanEdit && canEdit) {
        // Edit window just expired while modal was open
        setCanEdit(false)
        setShowExpiredWarning(true)
      }
    }

    // Check immediately in case time already expired
    checkEditWindow()

    // Set up interval to check periodically
    const interval = setInterval(checkEditWindow, 10000)
    return () => clearInterval(interval)
  }, [post.created_at, canEdit])

  return (
    <Modal
      title={canEdit ? 'Edit Post' : 'Add Additional Comments'}
      onClose={onClose}
      footer={
        <>
          <button className="cancel-btn" onClick={onClose}>
            Cancel
          </button>
          <button
            className="submit-btn"
            onClick={onSubmit}
            disabled={submitting || (canEdit ? !editContent.trim() : !additionalComment.trim())}
          >
            {submitting ? <ButtonSpinner /> : 'Save'}
          </button>
        </>
      }
    >
      {/* Show warning if edit window expired while editing */}
      {showExpiredWarning && (
        <div className="edit-expired-warning">
          <AlertTriangle size={16} />
          <span>
            {isOriginalPost
              ? 'Edit window expired. Your changes to content/title cannot be saved, but you can add additional comments below.'
              : 'Edit window expired. Your changes cannot be saved.'}
          </span>
        </div>
      )}

      {canEdit ? (
        <>
          <p className="edit-hint">You can edit your post within 15 minutes of posting.</p>
          <textarea
            value={editContent}
            onChange={(e) => onEditContentChange(e.target.value)}
            onKeyDown={handleKeyDown}
            className="edit-textarea"
            rows={5}
            autoFocus
          />
        </>
      ) : isOriginalPost ? (
        <>
          <p className="edit-hint">
            Your post is older than 15 minutes. You can add additional comments to your original
            post.
          </p>
          <textarea
            value={additionalComment}
            onChange={(e) => onAdditionalCommentChange(e.target.value)}
            onKeyDown={handleKeyDown}
            className="edit-textarea"
            placeholder="Add your additional comments..."
            rows={3}
            autoFocus
          />
        </>
      ) : null}
    </Modal>
  )
})

interface DeleteModalProps {
  post: Post
  submitting: boolean
  onConfirm: () => void
  onClose: () => void
}

export const DeleteModal = memo(function DeleteModal({
  post,
  submitting,
  onConfirm,
  onClose,
}: DeleteModalProps) {
  return (
    <Modal
      title={post.is_deleted ? 'Restore Post' : 'Delete Post'}
      onClose={onClose}
      size="small"
      footer={
        <>
          <button className="cancel-btn" onClick={onClose}>
            Cancel
          </button>
          <button
            className={post.is_deleted ? 'undelete-confirm-btn' : 'delete-confirm-btn'}
            onClick={onConfirm}
            disabled={submitting}
          >
            {submitting ? <ButtonSpinner /> : post.is_deleted ? 'Restore' : 'Delete'}
          </button>
        </>
      }
    >
      <p>
        {post.is_deleted
          ? 'Are you sure you want to restore this post? It will become visible to all users again.'
          : 'Are you sure you want to delete this post? The post will be marked as deleted but replies will remain visible.'}
      </p>
    </Modal>
  )
})

interface UserDeletedInfoModalProps {
  onClose: () => void
}

export const UserDeletedInfoModal = memo(function UserDeletedInfoModal({
  onClose,
}: UserDeletedInfoModalProps) {
  return (
    <Modal
      title="Cannot Restore"
      onClose={onClose}
      size="small"
      footer={
        <button className="cancel-btn" onClick={onClose}>
          OK
        </button>
      }
    >
      <p>This post was deleted by the user and cannot be restored.</p>
    </Modal>
  )
})
