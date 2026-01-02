import { useState, useEffect, useCallback } from 'react'
import type { View } from './useDiscussionNavigation'
import { ANIMATION_DURATION } from '../utils/constants'

interface UseDiscussionScrollEffectsProps {
  view: View
  loading: boolean
}

export function useDiscussionScrollEffects({
  view,
  loading,
}: UseDiscussionScrollEffectsProps) {
  // Scroll tracking state
  const [shouldScrollToParent, setShouldScrollToParent] = useState(false)
  const [shouldScrollToNewReply, setShouldScrollToNewReply] = useState(false)
  const [highlightPostId, setHighlightPostId] = useState<number | null>(null)

  // Scroll to parent post when entering replies view
  useEffect(() => {
    if (shouldScrollToParent && view === 'replies' && !loading) {
      const parentPost = document.querySelector('.parent-post')
      if (parentPost) {
        parentPost.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
      setShouldScrollToParent(false)
    }
  }, [shouldScrollToParent, view, loading])

  // Scroll to new reply after posting
  // Waits for loading to complete (important for subreplies which navigate to a new view)
  useEffect(() => {
    if (!shouldScrollToNewReply || loading) return

    // Small delay to let DOM render
    const scrollTimer = setTimeout(() => {
      const firstReply = document.querySelector('.reply-card')
      if (firstReply) {
        firstReply.scrollIntoView({ behavior: 'smooth', block: 'center' })
        firstReply.classList.add('highlight')
      }
    }, 50)

    const highlightTimer = setTimeout(() => {
      const firstReply = document.querySelector('.reply-card')
      if (firstReply) {
        firstReply.classList.remove('highlight')
      }
    }, 50 + ANIMATION_DURATION.HIGHLIGHT)

    setShouldScrollToNewReply(false)

    return () => {
      clearTimeout(scrollTimer)
      clearTimeout(highlightTimer)
    }
  }, [shouldScrollToNewReply, loading])

  // Highlight post when navigating from flagged view
  useEffect(() => {
    if (!highlightPostId || view !== 'thread' || loading) return

    const postElement = document.querySelector(`[data-post-id="${highlightPostId}"]`)
    if (!postElement) {
      setHighlightPostId(null)
      return
    }

    postElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
    postElement.classList.add('highlight')

    const timer = setTimeout(() => {
      postElement.classList.remove('highlight')
      setHighlightPostId(null)
    }, ANIMATION_DURATION.HIGHLIGHT)

    return () => clearTimeout(timer)
  }, [highlightPostId, view, loading])

  // Trigger scroll to parent when opening replies view
  const triggerScrollToParent = useCallback(() => {
    setShouldScrollToParent(true)
  }, [])

  // Trigger scroll to new reply after posting
  const triggerScrollToNewReply = useCallback(() => {
    setShouldScrollToNewReply(true)
  }, [])

  // Set highlight post id (for navigating from flagged view)
  const triggerHighlightPost = useCallback((postId: number) => {
    setHighlightPostId(postId)
  }, [])

  return {
    highlightPostId,
    triggerScrollToParent,
    triggerScrollToNewReply,
    triggerHighlightPost,
  }
}

export type DiscussionScrollEffectsReturn = ReturnType<typeof useDiscussionScrollEffects>
