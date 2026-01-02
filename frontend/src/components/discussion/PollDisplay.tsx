import { memo, useState, useCallback, useMemo } from 'react'
import { BarChart3, Check, Clock } from 'lucide-react'
import { usePoll, useVotePoll } from '../../hooks/usePollQueries'
import { ButtonSpinner } from '../ui'

interface PollDisplayProps {
  threadId: number
  userId: string | null
}

function formatTimeRemaining(endsAt: string): string {
  const now = new Date()
  const end = new Date(endsAt)
  const diff = end.getTime() - now.getTime()

  if (diff <= 0) return 'Ended'

  const hours = Math.floor(diff / (1000 * 60 * 60))
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))

  if (hours > 0) return `${hours}h ${minutes}m left`
  return `${minutes}m left`
}

export const PollDisplay = memo(function PollDisplay({ threadId, userId }: PollDisplayProps) {
  const { data: poll, isLoading, isError, refetch } = usePoll(threadId)
  const voteMutation = useVotePoll()

  const [selectedOptions, setSelectedOptions] = useState<number[]>([])

  // Check if user has already voted
  const hasVoted = poll && poll.user_votes && poll.user_votes.length > 0

  // Check if poll has expired
  const pollEndsAt = poll?.ends_at ?? null
  const isPollExpired = useMemo(() => {
    if (!pollEndsAt) return false
    return new Date(pollEndsAt) < new Date()
  }, [pollEndsAt])

  // Determine if results should be shown (always show if voted or expired)
  const showResults = poll && (hasVoted || isPollExpired)

  // Handle option selection
  const toggleOption = useCallback(
    (optionId: number) => {
      if (!poll) return

      if (poll.allow_multiple) {
        setSelectedOptions((prev) =>
          prev.includes(optionId) ? prev.filter((id) => id !== optionId) : [...prev, optionId]
        )
      } else {
        setSelectedOptions([optionId])
      }
    },
    [poll]
  )

  // Handle vote submission
  const submitVote = useCallback(() => {
    if (!poll || selectedOptions.length === 0) return

    voteMutation.mutate(
      { pollId: poll.id, optionIds: selectedOptions, threadId },
      {
        onSuccess: () => {
          setSelectedOptions([])
        },
      }
    )
  }, [poll, selectedOptions, threadId, voteMutation])

  if (isLoading) {
    return (
      <div className="poll-display poll-loading">
        <ButtonSpinner size={20} />
      </div>
    )
  }

  if (isError) {
    return (
      <div className="poll-display poll-error">
        <span>Failed to load poll</span>
        <button className="poll-retry-btn" onClick={() => refetch()}>
          Retry
        </button>
      </div>
    )
  }

  if (!poll) return null

  // Calculate total votes for percentage
  const totalOptionVotes = poll.options.reduce((sum, opt) => sum + opt.vote_count, 0)

  return (
    <div className="poll-display">
      <div className="poll-header">
        <BarChart3 size={16} />
        <span>Poll</span>
        {poll.allow_multiple && <span className="poll-badge">Multiple choice</span>}
        <span className="poll-votes-count">{poll.total_votes} vote{poll.total_votes !== 1 ? 's' : ''}</span>
        {poll.ends_at && (
          <span className={`poll-timer ${isPollExpired ? 'expired' : ''}`}>
            <Clock size={12} />
            {formatTimeRemaining(poll.ends_at)}
          </span>
        )}
      </div>

      <div className="poll-options">
        {poll.options.map((option) => {
          const isSelected = selectedOptions.includes(option.id)
          const wasVotedFor = poll.user_votes?.includes(option.id)
          const percentage = totalOptionVotes > 0 ? Math.round((option.vote_count / totalOptionVotes) * 100) : 0

          return (
            <div key={option.id} className="poll-option-container">
              {showResults ? (
                // Results view
                <div className={`poll-option-result ${wasVotedFor ? 'voted' : ''}`}>
                  <div className="poll-option-bar" style={{ width: `${percentage}%` }} />
                  <div className="poll-option-content">
                    <span className="poll-option-text">
                      {wasVotedFor && <Check size={14} className="voted-check" />}
                      {option.option_text}
                    </span>
                    <span className="poll-option-percentage">{percentage}%</span>
                  </div>
                </div>
              ) : (
                // Voting view
                <label className={`poll-option-vote ${isSelected ? 'selected' : ''}`}>
                  <input
                    type={poll.allow_multiple ? 'checkbox' : 'radio'}
                    name={`poll-${poll.id}`}
                    checked={isSelected}
                    onChange={() => toggleOption(option.id)}
                    disabled={!userId || voteMutation.isPending || isPollExpired}
                  />
                  <span className="poll-option-text">{option.option_text}</span>
                </label>
              )}
            </div>
          )
        })}
      </div>

      {/* Only show actions if there's something to show */}
      {((!hasVoted && !showResults && userId) || !userId) && (
        <div className="poll-actions">
          {!hasVoted && !showResults && userId && (
            <button
              className="poll-vote-btn"
              onClick={submitVote}
              disabled={selectedOptions.length === 0 || voteMutation.isPending}
            >
              {voteMutation.isPending ? <ButtonSpinner size={14} /> : 'Vote'}
            </button>
          )}

          {!userId && (
            <span className="poll-sign-in-hint">Sign in to vote</span>
          )}
        </div>
      )}
    </div>
  )
})
