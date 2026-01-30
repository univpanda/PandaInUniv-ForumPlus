import { useCallback } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useEditPost, useDeletePost } from './useForumQueries'
import { forumKeys } from './forumQueryKeys'
import { canEditContent } from '../utils/format'
import { PAGE_SIZE } from '../utils/constants'
import type { Post, Thread, ThreadStub, GetPaginatedPostsResponse } from '../types'

interface ModalState {
  editingPost: Post | null
  editContent: string
  additionalComment: string
  deletingPost: Post | null
}

interface ModalActions {
  startEdit: (post: Post, canEdit: boolean) => void
  submitEdit: () => void
  closeEditModal: () => void
  startDelete: (post: Post) => void
  confirmDelete: () => void
}

interface UsePostModerationProps {
  userId?: string
  selectedThread: Thread | ThreadStub | null
  modalState: ModalState
  modalActions: ModalActions
  goToList: () => void
  onSuccess: (message: string) => void
  onError: (message: string) => void
}

// Helper to find real post ID from cache when editing an optimistic post
function findRealPostId(
  queryClient: ReturnType<typeof useQueryClient>,
  optimisticPost: Post
): number | null {
  // If already a real ID, return it
  if (optimisticPost.id > 0) return optimisticPost.id

  // Look in paginated posts cache for a post matching author and created_at
  const sorts = ['popular', 'new'] as const
  for (const sort of sorts) {
    const key = forumKeys.paginatedPosts(
      optimisticPost.thread_id,
      optimisticPost.parent_id,
      1,
      PAGE_SIZE.POSTS,
      sort
    )
    const data = queryClient.getQueryData<GetPaginatedPostsResponse>(key)
    if (data?.posts) {
      const realPost = data.posts.find(
        (p) =>
          p.id > 0 &&
          p.author_id === optimisticPost.author_id &&
          p.created_at === optimisticPost.created_at
      )
      if (realPost) return realPost.id
    }
  }
  return null
}

export function usePostModeration({
  userId,
  selectedThread,
  modalState,
  modalActions,
  goToList,
  onSuccess,
  onError,
}: UsePostModerationProps) {
  const queryClient = useQueryClient()
  const editPostMutation = useEditPost()
  const deletePostMutation = useDeletePost()

  const handleEditPost = useCallback(
    (post: Post, e: React.MouseEvent) => {
      e.stopPropagation()
      modalActions.startEdit(post, canEditContent(post.created_at))
    },
    [modalActions]
  )

  const submitEdit = useCallback(() => {
    if (!modalState.editingPost) return
    const canEdit = canEditContent(modalState.editingPost.created_at)
    const isOriginalPost = modalState.editingPost.parent_id === null

    if (!isOriginalPost && !canEdit) {
      onError('Edit window has expired (15 minutes). Please close and try again.')
      modalActions.closeEditModal()
      return
    }

    const postToEdit = modalState.editingPost
    const editContent = modalState.editContent.trim()
    const additionalComment = modalState.additionalComment.trim()
    const isAddingComment = !canEdit && isOriginalPost

    // Check if content has actually changed
    if (canEdit && editContent === postToEdit.content) {
      // No changes - just close the modal
      modalActions.closeEditModal()
      return
    }

    // Check if additional comment is empty
    if (isAddingComment && !additionalComment) {
      modalActions.closeEditModal()
      return
    }

    // For optimistic posts, find the real ID from cache
    const realPostId = findRealPostId(queryClient, postToEdit)
    if (realPostId === null) {
      onError('Post not yet saved. Please try again in a moment.')
      return
    }

    modalActions.submitEdit()

    editPostMutation.mutate(
      {
        postId: realPostId,
        content: canEdit ? editContent : undefined,
        additionalComments: isAddingComment ? additionalComment : undefined,
        threadId: postToEdit.thread_id,
      },
      {
        onSuccess: () => {
          onSuccess(isAddingComment ? 'Comment has been added' : 'Post has been edited')
        },
        onError: (err: Error) => onError(err.message || 'Failed to edit post'),
      }
    )
  }, [
    queryClient,
    modalState.editingPost,
    modalState.editContent,
    modalState.additionalComment,
    modalActions,
    editPostMutation,
    onError,
    onSuccess,
  ])

  const handleDeletePost = useCallback(
    (post: Post, e: React.MouseEvent) => {
      e.stopPropagation()
      modalActions.startDelete(post)
    },
    [modalActions]
  )

  const confirmDelete = useCallback(() => {
    if (!modalState.deletingPost) return

    const postToDelete = modalState.deletingPost
    const isRestoring = postToDelete.is_deleted === true
    modalActions.confirmDelete()

    const isOP = postToDelete.parent_id === null
    // Check if thread has no replies - only full Thread has reply_count
    const threadHasNoReplies = selectedThread && 'reply_count' in selectedThread && selectedThread.reply_count === 0

    deletePostMutation.mutate(
      {
        postId: postToDelete.id,
        threadId: postToDelete.thread_id,
        userId,
        isDeleted: postToDelete.is_deleted ?? false,
      },
      {
        onSuccess: () => {
          onSuccess(isRestoring ? 'Post has been restored' : 'Post has been deleted')
          if (isOP && threadHasNoReplies) {
            goToList()
          }
        },
        onError: (err) => onError(err instanceof Error ? err.message : 'Failed to delete post'),
      }
    )
  }, [
    modalState.deletingPost,
    modalActions,
    userId,
    selectedThread,
    goToList,
    deletePostMutation,
    onSuccess,
    onError,
  ])

  return {
    handleEditPost,
    submitEdit,
    handleDeletePost,
    confirmDelete,
    isPending: editPostMutation.isPending || deletePostMutation.isPending,
  }
}
