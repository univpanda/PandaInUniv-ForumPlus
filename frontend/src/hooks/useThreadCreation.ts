import { useCallback } from 'react'
import { useCreateThread } from './useForumQueries'
import { useCreatePollThread } from './usePollQueries'
import type { Thread, PollSettings } from '../types'
import type { User } from '@supabase/supabase-js'

interface UseThreadCreationProps {
  user: User | null
  newThreadTitle: string
  newThreadContent: string
  clearNewThreadForm: () => void
  navigateToNewThread: (thread: Thread) => void
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

    // Check if creating a poll thread
    if (isPollEnabled) {
      // Filter and validate poll options (discard empty ones)
      const validOptions = pollOptions.filter((opt) => opt.trim()).map((opt) => opt.trim())
      if (validOptions.length < 2) {
        onError('Please add at least 2 poll options.')
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
            if (threadId) {
              const newThread: Thread = {
                id: threadId,
                title,
                author_id: user.id,
                author_name: user.user_metadata?.name || user.email || 'User',
                author_avatar: user.user_metadata?.avatar_url || null,
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
            if (threadId) {
              const newThread: Thread = {
                id: threadId,
                title,
                author_id: user.id,
                author_name: user.user_metadata?.name || user.email || 'User',
                author_avatar: user.user_metadata?.avatar_url || null,
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
