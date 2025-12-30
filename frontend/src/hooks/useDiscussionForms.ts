import { useState, useCallback } from 'react'
import type { Post, PollSettings } from '../types'

const DEFAULT_POLL_SETTINGS: PollSettings = {
  allowMultiple: false,
  durationHours: 0, // No limit by default
}

export function useDiscussionForms() {
  // New thread form state
  const [showNewThread, setShowNewThread] = useState(false)
  const [newThreadTitle, setNewThreadTitle] = useState('')
  const [newThreadContent, setNewThreadContent] = useState('')

  // Poll state
  const [isPollEnabled, setIsPollEnabled] = useState(false)
  const [pollOptions, setPollOptions] = useState<string[]>(['', ''])
  const [pollSettings, setPollSettings] = useState<PollSettings>(DEFAULT_POLL_SETTINGS)

  // Reply form state
  const [replyContent, setReplyContent] = useState('')

  // Inline reply state (replying to a specific post)
  const [inlineReplyContent, setInlineReplyContent] = useState('')
  const [replyingToPost, setReplyingToPost] = useState<Post | null>(null)

  // Toggle inline reply to a post
  const toggleReplyToPost = useCallback((post: Post, e: React.MouseEvent) => {
    e.stopPropagation()
    setReplyingToPost((current) => {
      if (current?.id === post.id) {
        setInlineReplyContent('')
        return null
      } else {
        setInlineReplyContent('')
        return post
      }
    })
  }, [])

  // Clear new thread form
  const clearNewThreadForm = useCallback(() => {
    setNewThreadTitle('')
    setNewThreadContent('')
    setShowNewThread(false)
    // Reset poll state
    setIsPollEnabled(false)
    setPollOptions(['', ''])
    setPollSettings(DEFAULT_POLL_SETTINGS)
  }, [])

  // Clear reply form
  const clearReplyForm = useCallback(() => {
    setReplyContent('')
  }, [])

  // Clear inline reply form
  const clearInlineReplyForm = useCallback(() => {
    setInlineReplyContent('')
    setReplyingToPost(null)
  }, [])

  // Get content based on whether it's inline or regular reply
  const getReplyContent = useCallback(
    (isInline: boolean) => {
      return isInline ? inlineReplyContent : replyContent
    },
    [inlineReplyContent, replyContent]
  )

  return {
    // New thread form
    showNewThread,
    setShowNewThread,
    newThreadTitle,
    setNewThreadTitle,
    newThreadContent,
    setNewThreadContent,
    clearNewThreadForm,

    // Poll state
    isPollEnabled,
    setIsPollEnabled,
    pollOptions,
    setPollOptions,
    pollSettings,
    setPollSettings,

    // Reply form
    replyContent,
    setReplyContent,
    clearReplyForm,

    // Inline reply
    inlineReplyContent,
    setInlineReplyContent,
    replyingToPost,
    toggleReplyToPost,
    clearInlineReplyForm,

    // Helpers
    getReplyContent,
  }
}

export type DiscussionFormsReturn = ReturnType<typeof useDiscussionForms>
