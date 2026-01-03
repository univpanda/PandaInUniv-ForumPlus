// Auth
export { useAuth } from './useAuth'
export { useDeleteOwnAccount } from './useAccountActions'

// Discussion
export { useDiscussionPage } from './useDiscussionPage'
export { useModalState, type ModalState, type ModalAction, type ModalActions } from './useDiscussionState'
export { useDiscussionNavigation, type View } from './useDiscussionNavigation'
export { useDiscussionForms } from './useDiscussionForms'
export { useDiscussionFilters, type SortBy, type ReplySortBy } from './useDiscussionFilters'
export { useDiscussionPosts } from './useDiscussionPosts'
export { useDiscussionPagination } from './useDiscussionPagination'
export { useDiscussionScrollEffects } from './useDiscussionScrollEffects'
export { useDiscussionActions } from './useDiscussionActions'

// Forum queries
export {
  usePaginatedThreads,
  usePaginatedPosts,
  usePrefetchPosts,
  useCreateThread,
  useAddReply,
  usePaginatedFlaggedPosts,
  useVotePost,
  useEditPost,
  useDeletePost,
  useBookmarks,
  useToggleBookmark,
  useToggleFlagged,
  forumKeys,
  calculateVoteUpdate,
  type ThreadSortBy,
} from './useForumQueries'

// User queries
export { useToggleAdmin, useToggleBlock, useDeleteUser, userKeys } from './useUserQueries'
export {
  useUserProfile,
  isUsernameAvailable,
  useUpdateUsername,
  profileKeys,
} from './useUserProfile'
export { usePublicUserStats, type PublicUserStats } from './useProfileQueries'


// Poll queries
export { usePoll, useVotePoll, useCreatePollThread } from './usePollQueries'

// Chat queries
export {
  useConversations,
  useConversationMessages,
  useUnreadMessageCount,
  useSendChatMessage,
  useMarkConversationRead,
  useIgnoredUsers,
  useIsUserIgnored,
  useToggleIgnore,
  chatKeys,
} from './useChatQueries'
export { useChatPageState } from './useChatPageState'

// Notification queries
export {
  useNotificationCount,
  useNotifications,
  useDismissNotification,
  useDismissAllNotifications,
  notificationKeys,
} from './useNotificationQueries'

// Utilities
export { useOptimisticMutation } from './useOptimisticMutation'
export { useClickOutside } from './useClickOutside'
export { usePrefetchUserData } from './usePrefetchUserData'
