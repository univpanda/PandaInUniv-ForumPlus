// Centralized type exports

// Notification types
export type { Notification } from './notification'

// Placement types
export type {
  Placement,
  PlacementFilters,
  PlacementSearchParams,
  ReverseSearchParams,
  PlacementSearchResult,
  PlacementSubTab,
} from './placement'

// Forum types
export type { Thread, Post, FlaggedPost, AuthorPost, BookmarkedPost, Poll, PollOption, PollSettings, ThreadStub, PostStub } from './forum'
export { flaggedPostToPost, authorPostToPost, isThreadStub, isPostStub, isFullPost } from './forum'

// User types
export type { UserProfile, UserWithStats } from './user'


// Chat types
export type {
  ChatMessage,
  UserConversation,
  ChatView,
  RawConversationMessage,
} from './feedback'
export { STORAGE_BUCKET } from './feedback'

// API response types
export type {
  GetForumThreadsResponse,
  GetPaginatedThreadsResponse,
  GetPaginatedPostsResponse,
  GetFlaggedPostsResponse,
  GetPaginatedFlaggedPostsResponse,
  GetPaginatedAuthorPostsResponse,
  CreateThreadResponse,
  VotePostResponse,
  EditPostResponse,
  DeletePostResponse,
  ToggleFlaggedResponse,
  GetUsersWithStatsResponse,
  UpdateUsernameResponse,
} from './api'
export { extractSingleResult } from './api'
