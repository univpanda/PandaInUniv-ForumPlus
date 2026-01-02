/* eslint-disable react-hooks/set-state-in-effect */
import { useState, useCallback, useEffect } from 'react'
import type { Thread, Post, ThreadStub, PostStub } from '../types'

export type View = 'list' | 'thread' | 'replies'

/** Thread can be full or stub when navigating by ID */
export type SelectedThread = Thread | ThreadStub | null

/** Post can be full or stub when navigating by ID */
export type SelectedPost = Post | PostStub | null

const STORAGE_KEY = 'discussionNav'

interface StoredNavState {
  view: View
  threadId: number | null
  postId: number | null
}

// Parse stored state from localStorage
const getStoredNavState = (): StoredNavState => {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    if (stored) {
      const parsed = JSON.parse(stored)
      const threadId = typeof parsed.threadId === 'number'
        ? parsed.threadId
        : typeof parsed.thread?.id === 'number'
          ? parsed.thread.id
          : null
      const postId = typeof parsed.postId === 'number'
        ? parsed.postId
        : typeof parsed.post?.id === 'number'
          ? parsed.post.id
          : null
      const view = parsed.view || 'list'
      if (view !== 'list' && threadId === null) {
        return { view: 'list', threadId: null, postId: null }
      }
      return {
        view,
        threadId,
        postId,
      }
    }
  } catch {
    // Ignore parse errors
  }
  return { view: 'list', threadId: null, postId: null }
}

// Save nav state to localStorage
const saveNavState = (view: View, thread: SelectedThread, post: SelectedPost) => {
  const state: StoredNavState = {
    view,
    threadId: thread?.id ?? null,
    postId: post?.id ?? null,
  }
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
  const [selectedThread, setSelectedThread] = useState<SelectedThread>(
    initialized.threadId !== null ? { id: initialized.threadId } : null
  )
  const [selectedPost, setSelectedPost] = useState<SelectedPost>(
    initialized.postId !== null ? { id: initialized.postId } : null
  )

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

  // Navigate to thread by ID (for notifications) - creates stub object
  const openThreadById = useCallback((threadId: number) => {
    // Create a stub - actual data will be fetched and resolved by queries
    const stub: ThreadStub = { id: threadId }
    setSelectedThread(stub)
    setView('thread')
  }, [])

  // Navigate to replies view by IDs (for notifications) - creates stub objects
  const openRepliesById = useCallback((threadId: number, postId: number) => {
    // Create stubs - actual data will be fetched and resolved by queries
    const threadStub: ThreadStub = { id: threadId }
    const postStub: PostStub = { id: postId }
    setSelectedThread(threadStub)
    setSelectedPost(postStub)
    setView('replies')
  }, [])

  // Update selected post optimistically (for voting)
  // Only updates if we have a full Post, not a stub
  const updateSelectedPost = useCallback((updater: (post: Post) => Post) => {
    setSelectedPost((prev) => {
      if (!prev || !('content' in prev)) return prev  // Skip if null or stub
      return updater(prev)
    })
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
