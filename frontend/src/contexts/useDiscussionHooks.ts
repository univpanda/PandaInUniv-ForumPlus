import { useContext } from 'react'
import {
  DiscussionContext,
  DiscussionViewContext,
  type DiscussionContextType,
  type DiscussionViewContextType,
  type DiscussionViewActionsContextType,
} from './DiscussionContext'

// Combined hook for accessing core discussion context (user, isAdmin, bookmarks, actions)
export function useDiscussion(): DiscussionContextType {
  const context = useContext(DiscussionContext)
  if (!context) {
    throw new Error('useDiscussion must be used within a DiscussionProvider')
  }
  return context
}

// Optional hook that returns null if outside context (for components used in multiple contexts)
export function useDiscussionOptional(): DiscussionContextType | null {
  return useContext(DiscussionContext)
}

// Hook to access view-specific data (thread, replies, form state, pagination)
export function useDiscussionView(): DiscussionViewContextType {
  const context = useContext(DiscussionViewContext)
  if (!context) {
    throw new Error('useDiscussionView must be used within a DiscussionProvider with view props')
  }
  return context
}

// Hook to access view-specific actions (for backward compatibility)
// Returns only the action subset of DiscussionViewContext
export function useDiscussionViewActions(): DiscussionViewActionsContextType {
  const context = useContext(DiscussionViewContext)
  if (!context) {
    throw new Error(
      'useDiscussionViewActions must be used within a DiscussionProvider with view action props'
    )
  }
  return {
    onReplyContentChange: context.onReplyContentChange,
    onInlineReplyContentChange: context.onInlineReplyContentChange,
    onAddReply: context.onAddReply,
    onReplySortChange: context.onReplySortChange,
    onToggleReplyToPost: context.onToggleReplyToPost,
    onOpenReplies: context.onOpenReplies,
    onGoToThread: context.onGoToThread,
  }
}
