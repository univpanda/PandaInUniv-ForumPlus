import { memo } from 'react'
import pandaTongue from '../../assets/panda-tongue.png'

interface VoteDisplayProps {
  likes: number
  dislikes: number
  size?: 'sm' | 'md'
  className?: string
}

/**
 * Shared vote display showing net score (likes - dislikes) with tongue panda icon.
 * Used in thread cards and anywhere vote counts are shown.
 */
export const VoteDisplay = memo(function VoteDisplay({
  likes,
  dislikes,
  size = 'sm',
  className = '',
}: VoteDisplayProps) {
  const iconSize = size === 'sm' ? 14 : 18
  const score = likes - dislikes

  return (
    <span className={`vote-display ${className}`}>
      <img src={pandaTongue} alt="" className="vote-icon" style={{ width: iconSize, height: iconSize }} />
      <span className="vote-score">{score}</span>
    </span>
  )
})
