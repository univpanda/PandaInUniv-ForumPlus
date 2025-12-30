import { useCallback } from 'react'
import { useAddReply } from './useForumQueries'
import type { Post, UserProfile } from '../types'
import type { User } from '@supabase/supabase-js'

interface UseReplyCreationProps {
  user: User | null
  userProfile: UserProfile | undefined
  getReplyContent: (isInline: boolean) => string
  replyingToPost: Post | null
  clearInlineReplyForm: () => void
  clearReplyForm: () => void
  setSelectedPost: (post: Post) => void
  openReplies: (post: Post) => void
  triggerScrollToNewReply: () => void
  onError: (message: string) => void
  // Current page/sort for optimistic cache update
  getCurrentPageSort: () => { page: number; sort: 'popular' | 'new' }
}

export function useReplyCreation({
  user,
  userProfile,
  getReplyContent,
  replyingToPost,
  clearInlineReplyForm,
  clearReplyForm,
  setSelectedPost,
  openReplies,
  triggerScrollToNewReply,
  onError,
  getCurrentPageSort,
}: UseReplyCreationProps) {
  const addReplyMutation = useAddReply()

  const addReply = useCallback(
    async (threadId: number, parentId: number | null = null, isInline: boolean = false) => {
      const content = getReplyContent(isInline)
      if (!user || !content.trim()) return

      // Store the parent post before clearing the form (for navigation after inline reply)
      const parentPost = isInline ? replyingToPost : null

      const { page, sort } = getCurrentPageSort()
      // For inline replies (subreplies), always use page 1 since we navigate to a fresh subreplies view
      const targetPage = isInline ? 1 : page
      const optimisticId = -Date.now() // Generate unique negative ID for optimistic update
      addReplyMutation.mutate(
        {
          threadId,
          content: content.trim(),
          parentId,
          userId: user.id,
          userName: userProfile?.username || user.user_metadata?.name || user.email || 'User',
          userAvatar: userProfile?.avatar_url || user.user_metadata?.avatar_url || null,
          page: targetPage,
          sort,
          optimisticId,
        },
        {
          onSuccess: () => {
            if (isInline) {
              clearInlineReplyForm()
              // Navigate to replies view for the parent post
              if (parentPost) {
                setSelectedPost(parentPost)
                openReplies(parentPost)
              }
            } else {
              clearReplyForm()
            }
            // Don't change sort - keep user's current selection
            triggerScrollToNewReply()
          },
          onError: () => onError('Failed to post reply. Please try again.'),
        }
      )
    },
    [
      user,
      userProfile,
      getReplyContent,
      replyingToPost,
      clearInlineReplyForm,
      clearReplyForm,
      setSelectedPost,
      openReplies,
      triggerScrollToNewReply,
      addReplyMutation,
      onError,
      getCurrentPageSort,
    ]
  )

  return {
    addReply,
    isPending: addReplyMutation.isPending,
  }
}
