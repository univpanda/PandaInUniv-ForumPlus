/* eslint-disable react-refresh/only-export-components */
import { createContext, useMemo } from 'react'
import type { Post, Thread, ThreadStub } from '../types'

// Reply sort type
export type ReplySortBy = 'popular' | 'new'

// Pagination state type
export interface PaginationState {
  page: number
  setPage: (page: number) => void
  totalPages: number
  totalCount: number
  pageSize: number
}

// === Grouped Props Types ===

/** Core user/auth data */
export interface DiscussionCoreProps {
  user: { id: string } | null
  isAdmin: boolean
  bookmarks: Set<number>
  postBookmarks: Set<number>
}

/** Core post action callbacks */
export interface DiscussionActionsProps {
  onVote: (postId: number, voteType: 1 | -1, e: React.MouseEvent) => void
  onToggleBookmark: (threadId: number, e: React.MouseEvent) => void
  onTogglePostBookmark: (postId: number, e: React.MouseEvent) => void
  onEdit: (post: Post, e: React.MouseEvent) => void
  onDelete: (post: Post, e: React.MouseEvent) => void
  onUserDeletedClick: (e: React.MouseEvent) => void
  onToggleFlagged: (post: Post, e: React.MouseEvent) => void
}

/** View-specific data (thread/replies views) */
export interface DiscussionViewDataProps {
  thread: Thread | ThreadStub | null
  originalPost?: Post
  selectedPost?: Post | null
  replies?: Post[]
  sortedSubReplies?: Post[]
  replySortBy: ReplySortBy
  replyContent: string
  inlineReplyContent?: string
  replyingToPost?: Post | null
  submitting: boolean
  repliesPagination?: PaginationState | null
  subRepliesPagination?: PaginationState | null
  subRepliesLoading?: boolean
}

/** View-specific action callbacks */
export interface DiscussionViewActionsProps {
  onReplyContentChange: (content: string) => void
  onInlineReplyContentChange?: (content: string) => void
  onAddReply: (threadId: number, parentId: number | null, isInline?: boolean) => void
  onReplySortChange: (sort: ReplySortBy) => void
  onToggleReplyToPost?: (post: Post, e: React.MouseEvent) => void
  onOpenReplies?: (post: Post) => void
  onGoToThread?: (scrollToPostId?: number) => void
}

// === Context Types ===

export interface DiscussionContextType {
  user: { id: string } | null
  isAdmin: boolean
  bookmarks: Set<number>
  postBookmarks: Set<number>
  onVote: (postId: number, voteType: 1 | -1, e: React.MouseEvent) => void
  onToggleBookmark: (threadId: number, e: React.MouseEvent) => void
  onTogglePostBookmark: (postId: number, e: React.MouseEvent) => void
  onEdit: (post: Post, e: React.MouseEvent) => void
  onDelete: (post: Post, e: React.MouseEvent) => void
  onUserDeletedClick: (e: React.MouseEvent) => void
  onToggleFlagged: (post: Post, e: React.MouseEvent) => void
}

export interface DiscussionViewContextType {
  // Data
  thread: Thread | ThreadStub | null
  originalPost: Post | undefined
  selectedPost: Post | null
  replies: Post[]
  sortedSubReplies: Post[]
  replySortBy: ReplySortBy
  replyContent: string
  inlineReplyContent: string
  replyingToPost: Post | null
  submitting: boolean
  repliesPagination: PaginationState | null
  subRepliesPagination: PaginationState | null
  subRepliesLoading: boolean
  // Actions
  onReplyContentChange: (content: string) => void
  onInlineReplyContentChange: (content: string) => void
  onAddReply: (threadId: number, parentId: number | null, isInline?: boolean) => void
  onReplySortChange: (sort: ReplySortBy) => void
  onToggleReplyToPost: (post: Post, e: React.MouseEvent) => void
  onOpenReplies: (post: Post) => void
  onGoToThread: (scrollToPostId?: number) => void
}

// Legacy type export for backward compatibility
export type DiscussionViewActionsContextType = Pick<
  DiscussionViewContextType,
  | 'onReplyContentChange'
  | 'onInlineReplyContentChange'
  | 'onAddReply'
  | 'onReplySortChange'
  | 'onToggleReplyToPost'
  | 'onOpenReplies'
  | 'onGoToThread'
>

// Create contexts
export const DiscussionContext = createContext<DiscussionContextType | null>(null)
export const DiscussionViewContext = createContext<DiscussionViewContextType | null>(null)

// Legacy context exports for backward compatibility (map to new contexts)
export const DiscussionDataContext = DiscussionContext
export const DiscussionActionsContext = DiscussionContext
export const DiscussionViewActionsContext = DiscussionViewContext

// === Provider Props (grouped) ===

interface DiscussionProviderProps {
  children: React.ReactNode
  /** Core user/auth data */
  core: DiscussionCoreProps
  /** Core post action callbacks */
  actions: DiscussionActionsProps
  /** View-specific data (optional - for thread/replies views) */
  viewData?: DiscussionViewDataProps
  /** View-specific action callbacks (optional) */
  viewActions?: DiscussionViewActionsProps
}

export function DiscussionProvider({
  children,
  core,
  actions,
  viewData,
  viewActions,
}: DiscussionProviderProps) {
  // Core context value - data + actions
  // Actions are already memoized in useDiscussionActions, so we use them directly
  const coreValue = useMemo<DiscussionContextType>(
    () => ({
      user: core.user,
      isAdmin: core.isAdmin,
      bookmarks: core.bookmarks,
      postBookmarks: core.postBookmarks,
      onVote: actions.onVote,
      onToggleBookmark: actions.onToggleBookmark,
      onTogglePostBookmark: actions.onTogglePostBookmark,
      onEdit: actions.onEdit,
      onDelete: actions.onDelete,
      onUserDeletedClick: actions.onUserDeletedClick,
      onToggleFlagged: actions.onToggleFlagged,
    }),
    [
      core.user,
      core.isAdmin,
      core.bookmarks,
      core.postBookmarks,
      actions.onVote,
      actions.onToggleBookmark,
      actions.onTogglePostBookmark,
      actions.onEdit,
      actions.onDelete,
      actions.onUserDeletedClick,
      actions.onToggleFlagged,
    ]
  )

  // View context value - only provided when view data exists
  const viewValue = useMemo<DiscussionViewContextType | null>(() => {
    // Only provide view context if we have view-specific data and actions
    if (!viewData || !viewActions) return null

    return {
      // Data
      thread: viewData.thread,
      originalPost: viewData.originalPost,
      selectedPost: viewData.selectedPost ?? null,
      replies: viewData.replies ?? [],
      sortedSubReplies: viewData.sortedSubReplies ?? [],
      replySortBy: viewData.replySortBy,
      replyContent: viewData.replyContent,
      inlineReplyContent: viewData.inlineReplyContent ?? '',
      replyingToPost: viewData.replyingToPost ?? null,
      submitting: viewData.submitting,
      repliesPagination: viewData.repliesPagination ?? null,
      subRepliesPagination: viewData.subRepliesPagination ?? null,
      subRepliesLoading: viewData.subRepliesLoading ?? false,
      // Actions
      onReplyContentChange: viewActions.onReplyContentChange,
      onInlineReplyContentChange: viewActions.onInlineReplyContentChange ?? (() => {}),
      onAddReply: viewActions.onAddReply,
      onReplySortChange: viewActions.onReplySortChange,
      onToggleReplyToPost: viewActions.onToggleReplyToPost ?? (() => {}),
      onOpenReplies: viewActions.onOpenReplies ?? (() => {}),
      onGoToThread: viewActions.onGoToThread ?? (() => {}),
    }
  }, [viewData, viewActions])

  return (
    <DiscussionContext.Provider value={coreValue}>
      <DiscussionViewContext.Provider value={viewValue}>
        {children}
      </DiscussionViewContext.Provider>
    </DiscussionContext.Provider>
  )
}

// Re-export hooks from separate file for fast refresh compatibility
export {
  useDiscussion,
  useDiscussionOptional,
  useDiscussionView,
  useDiscussionViewActions,
} from './useDiscussionHooks'
