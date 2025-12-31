import { useCallback } from 'react'
import { useToast } from '../contexts/ToastContext'
import { useThreadCreation } from './useThreadCreation'
import { useReplyCreation } from './useReplyCreation'
import { usePostModeration } from './usePostModeration'
import { calculateVoteUpdate } from './useForumQueries'
import type { ModalActions, ModalState } from './useDiscussionState'
import type { DiscussionNavigationReturn } from './useDiscussionNavigation'
import type { DiscussionFormsReturn } from './useDiscussionForms'
import type { DiscussionFiltersReturn } from './useDiscussionFilters'
import type { DiscussionPostsReturn } from './useDiscussionPosts'
import type { DiscussionScrollEffectsReturn } from './useDiscussionScrollEffects'
import type { Thread, Post, UserProfile } from '../types'
import type { User } from '@supabase/supabase-js'

interface UseDiscussionActionsProps {
  user: User | null
  userProfile: UserProfile | undefined
  isAdmin: boolean
  navigation: DiscussionNavigationReturn
  forms: DiscussionFormsReturn
  filters: DiscussionFiltersReturn
  postsData: DiscussionPostsReturn
  scrollEffects: DiscussionScrollEffectsReturn
  modalState: ModalState
  modalActions: ModalActions
}

export function useDiscussionActions({
  user,
  userProfile,
  isAdmin,
  navigation,
  forms,
  filters,
  postsData,
  scrollEffects,
  modalState,
  modalActions,
}: UseDiscussionActionsProps) {
  const toast = useToast()

  // ============ Thread Creation ============
  const threadCreation = useThreadCreation({
    user,
    newThreadTitle: forms.newThreadTitle,
    newThreadContent: forms.newThreadContent,
    clearNewThreadForm: forms.clearNewThreadForm,
    navigateToNewThread: navigation.navigateToNewThread,
    onError: toast.showError,
    // Poll props
    isPollEnabled: forms.isPollEnabled,
    pollOptions: forms.pollOptions,
    pollSettings: forms.pollSettings,
  })

  // ============ Reply Creation ============
  // Get current page and sort for optimistic cache update
  const getCurrentPageSort = useCallback(() => {
    // When in 'replies' view (viewing sub-replies of a post), use subReplies pagination
    // Otherwise (in 'thread' view), use replies pagination
    const isSubRepliesView = navigation.view === 'replies'
    const page = isSubRepliesView
      ? postsData.pagination.subReplies.page
      : postsData.pagination.replies.page
    return { page, sort: filters.replySortBy }
  }, [navigation.view, postsData.pagination.replies.page, postsData.pagination.subReplies.page, filters.replySortBy])

  const replyCreation = useReplyCreation({
    user,
    userProfile,
    getReplyContent: forms.getReplyContent,
    replyingToPost: forms.replyingToPost,
    clearInlineReplyForm: forms.clearInlineReplyForm,
    clearReplyForm: forms.clearReplyForm,
    setSelectedPost: navigation.setSelectedPost,
    openReplies: navigation.openReplies,
    triggerScrollToNewReply: scrollEffects.triggerScrollToNewReply,
    onError: toast.showError,
    getCurrentPageSort,
  })

  // ============ Post Moderation (Edit/Delete) ============
  const moderation = usePostModeration({
    userId: user?.id,
    view: navigation.view,
    selectedPost: navigation.selectedPost,
    selectedThread: navigation.selectedThread,
    modalState,
    modalActions,
    goToList: navigation.goToList,
    onSuccess: toast.showSuccess,
    onError: toast.showError,
  })

  // ============ Bookmark Actions ============
  const toggleBookmark = useCallback(
    (threadId: number, e: React.MouseEvent) => {
      e.stopPropagation()
      if (!user) return
      postsData.toggleBookmarkMutation.mutate(threadId, {
        onError: () => toast.showError('Failed to update bookmark'),
      })
    },
    [user, postsData.toggleBookmarkMutation, toast]
  )

  const togglePostBookmark = useCallback(
    (postId: number, e: React.MouseEvent) => {
      e.stopPropagation()
      if (!user) return
      postsData.togglePostBookmarkMutation.mutate(postId, {
        onError: () => toast.showError('Failed to update bookmark'),
      })
    },
    [user, postsData.togglePostBookmarkMutation, toast]
  )

  // ============ Flag Actions ============
  const toggleFlagged = useCallback(
    (post: Post, e: React.MouseEvent) => {
      e.stopPropagation()
      if (!isAdmin) return
      postsData.toggleFlaggedMutation.mutate(
        { postId: post.id, threadId: post.thread_id },
        {
          onError: (err) =>
            toast.showError(err instanceof Error ? err.message : 'Failed to toggle flagged status'),
        }
      )
    },
    [isAdmin, postsData.toggleFlaggedMutation, toast]
  )

  // ============ Vote Actions ============
  const votePost = useCallback(
    (postId: number, voteType: 1 | -1, e: React.MouseEvent) => {
      e.stopPropagation()
      if (!user) return

      // O(1) lookup using cached Map
      const post = postsData.postsById.get(postId)

      if (!post) {
        toast.showError('Post not found')
        return
      }

      const isSelectedPostMatch = navigation.selectedPost?.id === postId

      const prevVote = post.user_vote
      const prevLikes = post.likes
      const prevDislikes = post.dislikes

      // Optimistically update selectedPost state (cache update handled by mutation)
      if (isSelectedPostMatch) {
        const update = calculateVoteUpdate(prevVote, prevLikes, prevDislikes, voteType)
        navigation.updateSelectedPost((p) => ({ ...p, ...update }))
      }

      postsData.voteMutation.mutate(
        {
          postId,
          voteType,
          threadId: post.thread_id,
          isOriginalPost: post.parent_id === null,
          prevVote,
          prevLikes,
          prevDislikes,
        },
        {
          onError: () => {
            // Rollback selectedPost state (cache rollback handled by mutation)
            if (isSelectedPostMatch) {
              navigation.updateSelectedPost((p) => ({
                ...p,
                likes: prevLikes,
                dislikes: prevDislikes,
                user_vote: prevVote,
              }))
            }
            toast.showError('Failed to vote')
          },
        }
      )
    },
    [user, navigation.selectedPost, navigation.updateSelectedPost, postsData.postsById, postsData.voteMutation, toast]
  )

  // ============ Navigation Actions ============
  const openReplies = useCallback(
    (post: Post) => {
      navigation.openReplies(post)
      scrollEffects.triggerScrollToParent()
    },
    [navigation.openReplies, scrollEffects.triggerScrollToParent]
  )

  const handleUserDeletedClick = useCallback(
    (e: React.MouseEvent) => {
      e.stopPropagation()
      modalActions.showUserDeletedInfo()
    },
    [modalActions]
  )

  // Navigate to a post from posts search view
  const goToSearchedPost = useCallback(
    (thread: Thread, post: Post, isThreadOp: boolean) => {
      navigation.setSelectedThread(thread)
      filters.setRecentSort()
      if (isThreadOp) {
        navigation.openThread(thread)
      } else {
        navigation.setSelectedPost(post)
        navigation.openReplies(post)
        scrollEffects.triggerScrollToParent()
      }
    },
    [
      navigation.setSelectedThread,
      navigation.openThread,
      navigation.setSelectedPost,
      navigation.openReplies,
      filters.setRecentSort,
      scrollEffects.triggerScrollToParent,
    ]
  )

  // ============ Computed State ============
  const submitting =
    threadCreation.isPending || replyCreation.isPending || moderation.isPending

  return {
    // Toast for external use
    toast,
    // Submission state
    submitting,
    // Post actions
    postActions: {
      votePost,
      handleEditPost: moderation.handleEditPost,
      submitEdit: moderation.submitEdit,
      handleDeletePost: moderation.handleDeletePost,
      confirmDelete: moderation.confirmDelete,
      toggleBookmark,
      togglePostBookmark,
      toggleFlagged,
      handleUserDeletedClick,
    },
    // Bookmark/search actions
    bookmarkActions: {
      showBookmarksView: filters.showBookmarksView,
      goToSearchedPost,
    },
    // Thread creation
    createThread: threadCreation.createThread,
    // Reply actions
    addReply: replyCreation.addReply,
    // Navigation actions
    openReplies,
  }
}

export type DiscussionActionsReturn = ReturnType<typeof useDiscussionActions>
