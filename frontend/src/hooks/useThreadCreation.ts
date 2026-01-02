import { useCallback } from 'react'
import { useCreateThread } from './useForumQueries'
import { useCreatePollThread } from './usePollQueries'
import { CONTENT_LIMITS } from '../utils/constants'
import type { Thread, PollSettings } from '../types'
import type { User } from '@supabase/supabase-js'

interface UseThreadCreationProps {
  user: User | null
  newThreadTitle: string
  newThreadContent: string
  clearNewThreadForm: () => void
  navigateToNewThread: (thread: Thread) => void
  onSuccess: (message: string) => void
  onError: (message: string) => void
  // Poll props
  isPollEnabled: boolean
  pollOptions: string[]
  pollSettings: PollSettings
}

export function useThreadCreation({
  user,
  newThreadTitle,
  newThreadContent,
  clearNewThreadForm,
  navigateToNewThread,
  onSuccess,
  onError,
  isPollEnabled,
  pollOptions,
  pollSettings,
}: UseThreadCreationProps) {
  const createThreadMutation = useCreateThread()
  const createPollThreadMutation = useCreatePollThread()

  const createThread = useCallback(async () => {
    if (!user || !newThreadTitle.trim()) return

    const title = newThreadTitle.trim()
    const content = newThreadContent.trim()

    // Validate title length
    if (title.length < CONTENT_LIMITS.THREAD_TITLE_MIN) {
      onError(`Title must be at least ${CONTENT_LIMITS.THREAD_TITLE_MIN} characters.`)
      return
    }
    if (title.length > CONTENT_LIMITS.THREAD_TITLE_MAX) {
      onError(`Title is too long (max ${CONTENT_LIMITS.THREAD_TITLE_MAX} characters).`)
      return
    }

    // Validate content length (if provided)
    if (content && content.length > CONTENT_LIMITS.POST_CONTENT_MAX) {
      onError(`Content is too long (max ${CONTENT_LIMITS.POST_CONTENT_MAX.toLocaleString()} characters).`)
      return
    }

    // Check if creating a poll thread
    if (isPollEnabled) {
      // Filter and validate poll options (discard empty ones)
      const validOptions = pollOptions.filter((opt) => opt.trim()).map((opt) => opt.trim())
      if (validOptions.length < 2) {
        onError('Please add at least 2 poll options.')
        return
      }

      // Validate poll option lengths
      const tooLongOption = validOptions.find((opt) => opt.length > CONTENT_LIMITS.POLL_OPTION_MAX)
      if (tooLongOption) {
        onError(`Poll option is too long (max ${CONTENT_LIMITS.POLL_OPTION_MAX} characters).`)
        return
      }

      createPollThreadMutation.mutate(
        {
          title,
          content: content || '', // Allow empty content for polls
          pollOptions: validOptions,
          pollSettings,
          userId: user.id,
        },
        {
          onSuccess: (threadId) => {
            clearNewThreadForm()
            onSuccess('Thread created')
            if (threadId) {
              const newThread: Thread = {
                id: threadId,
                title,
                author_id: user.id,
                author_name: user.user_metadata?.name || user.email || 'User',
                author_avatar: user.user_metadata?.avatar_url || null,
                author_avatar_path: null,
                created_at: new Date().toISOString(),
                first_post_content: content,
                reply_count: 0,
                total_likes: 0,
                total_dislikes: 0,
                has_poll: true,
              }
              navigateToNewThread(newThread)
            }
          },
          onError: () => onError('Failed to create poll. Please try again.'),
        }
      )
    } else {
      // Regular thread creation - content is required
      if (!content) return

      createThreadMutation.mutate(
        { title, content, userId: user.id },
        {
          onSuccess: (threadId) => {
            clearNewThreadForm()
            onSuccess('Thread created')
            if (threadId) {
              const newThread: Thread = {
                id: threadId,
                title,
                author_id: user.id,
                author_name: user.user_metadata?.name || user.email || 'User',
                author_avatar: user.user_metadata?.avatar_url || null,
                author_avatar_path: null,
                created_at: new Date().toISOString(),
                first_post_content: content,
                reply_count: 0,
                total_likes: 0,
                total_dislikes: 0,
              }
              navigateToNewThread(newThread)
            }
          },
          onError: () => onError('Failed to create thread. Please try again.'),
        }
      )
    }
  }, [
    user,
    newThreadTitle,
    newThreadContent,
    clearNewThreadForm,
    navigateToNewThread,
    createThreadMutation,
    createPollThreadMutation,
    onSuccess,
    onError,
    isPollEnabled,
    pollOptions,
    pollSettings,
  ])

  return {
    createThread,
    isPending: createThreadMutation.isPending || createPollThreadMutation.isPending,
  }
}
