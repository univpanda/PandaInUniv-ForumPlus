import { useState, useCallback, useEffect } from 'react'
import type { Thread, Post } from '../types'

export type View = 'list' | 'thread' | 'replies'

const STORAGE_KEY = 'discussionNav'

interface StoredNavState {
  view: View
  thread: Thread | null
  post: Post | null
}

// Parse stored state from localStorage
const getStoredNavState = (): StoredNavState => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored) {
      const parsed = JSON.parse(stored)
      return {
        view: parsed.view || 'list',
        thread: parsed.thread || null,
        post: parsed.post || null,
      }
    }
  } catch {
    // Ignore parse errors
  }
  return { view: 'list', thread: null, post: null }
}

// Save nav state to localStorage
const saveNavState = (view: View, thread: Thread | null, post: Post | null) => {
  const state: StoredNavState = { view, thread, post }
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
}

interface UseDiscussionNavigationProps {
  resetToList?: number
}

export function useDiscussionNavigation({
  resetToList,
}: UseDiscussionNavigationProps = {}) {
  // Initialize from stored state
  const [initialized] = useState(() => getStoredNavState())
  const [view, setView] = useState<View>(initialized.view)
  const [selectedThread, setSelectedThread] = useState<Thread | null>(initialized.thread)
  const [selectedPost, setSelectedPost] = useState<Post | null>(initialized.post)

  // Persist state changes to localStorage
  useEffect(() => {
    saveNavState(view, selectedThread, selectedPost)
  }, [view, selectedThread, selectedPost])

  // Reset to list when resetToList prop changes (e.g., clicking Discussion tab)
  // This is an intentional "command" pattern - the prop change triggers navigation
  useEffect(() => {
    if (resetToList) {
      setView('list')
      setSelectedThread(null)
      setSelectedPost(null)
    }
  }, [resetToList])

  const openThread = useCallback((thread: Thread) => {
    setSelectedThread(thread)
    setView('thread')
  }, [])

  const openReplies = useCallback((post: Post) => {
    setSelectedPost(post)
    setView('replies')
  }, [])

  const goToList = useCallback(() => {
    setView('list')
    setSelectedThread(null)
    setSelectedPost(null)
  }, [])

  const goToThreadFromReplies = useCallback(() => {
    setView('thread')
    setSelectedPost(null)
  }, [])

  // Navigate to a thread after creating it
  const navigateToNewThread = useCallback((thread: Thread) => {
    setSelectedThread(thread)
    setView('thread')
  }, [])

  // Navigate to thread by ID (for notifications) - creates minimal thread object
  const openThreadById = useCallback((threadId: number) => {
    // Create a minimal thread object - the actual data will be fetched by queries
    setSelectedThread({ id: threadId, title: '' } as Thread)
    setView('thread')
  }, [])

  // Navigate to replies view by IDs (for notifications) - creates minimal objects
  const openRepliesById = useCallback((threadId: number, postId: number) => {
    // Create minimal objects - actual data will be fetched by queries
    setSelectedThread({ id: threadId, title: '' } as Thread)
    setSelectedPost({ id: postId } as Post)
    setView('replies')
  }, [])

  // Update selected post optimistically (for voting)
  const updateSelectedPost = useCallback((updater: (post: Post) => Post) => {
    setSelectedPost((prev) => (prev ? updater(prev) : null))
  }, [])

  return {
    // State
    view,
    selectedThread,
    selectedPost,

    // Actions
    openThread,
    openThreadById,
    openReplies,
    openRepliesById,
    goToList,
    goToThreadFromReplies,
    navigateToNewThread,
    updateSelectedPost,

    // Raw setters (for complex operations)
    setSelectedThread,
    setSelectedPost,
  }
}

export type DiscussionNavigationReturn = ReturnType<typeof useDiscussionNavigation>
