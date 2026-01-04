import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { forumKeys } from './forumQueryKeys'
import { profileKeys } from './useUserProfile'
import { STALE_TIME } from '../utils/constants'
import type { Poll, PollSettings } from '../types'

// Fetch poll data for a thread
export function usePoll(threadId: number, enabled: boolean = true) {
  return useQuery({
    queryKey: forumKeys.poll(threadId),
    queryFn: async (): Promise<Poll | null> => {
      const { data, error } = await supabase.rpc('get_poll_data', {
        p_thread_id: threadId,
      })
      if (error) throw error
      return data as Poll | null
    },
    enabled,
    staleTime: STALE_TIME.SHORT,
  })
}

// Vote mutation variables
interface VotePollVariables {
  pollId: number
  optionIds: number[]
  threadId: number
}

// Vote on a poll with optimistic updates
export function useVotePoll() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ pollId, optionIds }: VotePollVariables): Promise<Poll> => {
      const { data, error } = await supabase.rpc('vote_poll', {
        p_poll_id: pollId,
        p_option_ids: optionIds,
      })
      if (error) throw error
      return data as Poll
    },
    onMutate: async ({ optionIds, threadId }) => {
      const queryKey = forumKeys.poll(threadId)

      // Cancel any outgoing refetches
      await queryClient.cancelQueries({ queryKey })

      // Snapshot previous data for rollback
      const previousPoll = queryClient.getQueryData<Poll>(queryKey)

      // Optimistically update the poll
      if (previousPoll) {
        const previousUserVotes = previousPoll.user_votes || []
        const isChangingVote = previousUserVotes.length > 0

        // Calculate new option vote counts
        const updatedOptions = previousPoll.options.map((option) => {
          let newVoteCount = option.vote_count

          // Remove previous vote if changing vote
          if (isChangingVote && previousUserVotes.includes(option.id)) {
            newVoteCount--
          }

          // Add new vote
          if (optionIds.includes(option.id)) {
            newVoteCount++
          }

          return { ...option, vote_count: newVoteCount }
        })

        // Calculate total votes change
        const previousVoteCount = previousUserVotes.length
        const newVoteCount = optionIds.length
        const totalVotesChange = newVoteCount - previousVoteCount

        queryClient.setQueryData<Poll>(queryKey, {
          ...previousPoll,
          options: updatedOptions,
          user_votes: optionIds,
          total_votes: previousPoll.total_votes + totalVotesChange,
        })
      }

      return { previousPoll }
    },
    onError: (_err, { threadId }, context) => {
      // Rollback on error
      if (context?.previousPoll) {
        queryClient.setQueryData(forumKeys.poll(threadId), context.previousPoll)
      }
    },
    onSuccess: (newPollData, { threadId }) => {
      // Update the poll cache with server data (ensures consistency)
      queryClient.setQueryData(forumKeys.poll(threadId), newPollData)
    },
  })
}

// Create poll thread variables
export interface CreatePollThreadVariables {
  title: string
  content: string
  pollOptions: string[]
  pollSettings: PollSettings
  userId: string
}

// Create a thread with a poll
export function useCreatePollThread() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({
      title,
      content,
      pollOptions,
      pollSettings,
    }: CreatePollThreadVariables): Promise<number> => {
      const { data, error } = await supabase.rpc('create_poll_thread', {
        p_title: title,
        p_content: content,
        p_poll_options: pollOptions,
        p_allow_multiple: pollSettings.allowMultiple,
        p_duration_hours: pollSettings.durationHours,
      })
      if (error) throw error
      return data as number
    },
    onSuccess: (_, { userId }) => {
      // Invalidate all thread lists (including paginated)
      queryClient.invalidateQueries({ queryKey: forumKeys.threadsAll() })
      // Update profile stats
      queryClient.invalidateQueries({ queryKey: profileKeys.userStats(userId) })
    },
  })
}
