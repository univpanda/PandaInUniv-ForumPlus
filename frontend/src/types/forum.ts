// Forum-related types

/**
 * Stub types for navigation - these represent incomplete data
 * that will be resolved by queries before rendering.
 * Using separate types prevents accidental access to missing fields.
 */
export interface ThreadStub {
  id: number
  title?: string  // May be empty when navigating by ID
}

export interface PostStub {
  id: number
  // All other fields are intentionally omitted
  // The stub will be resolved to a full Post by usePostViewData
}

/** Type guard to check if a thread is a stub or full Thread */
export function isThreadStub(thread: Thread | ThreadStub | null): thread is ThreadStub {
  if (!thread) return false
  // A stub has id but missing required fields like author_id
  return !('author_id' in thread)
}

/** Type guard to check if a post is a stub or full Post */
export function isPostStub(post: Post | PostStub | null): post is PostStub {
  if (!post) return false
  // A stub has id but missing required fields like content
  return !('content' in post)
}

/** Type guard to check if a post is a full Post (not a stub) */
export function isFullPost(post: Post | PostStub | null): post is Post {
  if (!post) return false
  return 'content' in post
}

export interface PollOption {
  id: number
  option_text: string
  vote_count: number
  display_order: number
}

export interface Poll {
  id: number
  thread_id: number
  allow_multiple: boolean
  ends_at: string | null // null = no limit
  options: PollOption[]
  user_votes: number[] // Option IDs user voted for
  total_votes: number
}

export interface PollSettings {
  allowMultiple: boolean
  durationHours: number // 0 = no limit, max 72
}

export interface Thread {
  id: number
  title: string
  author_id: string
  author_name: string
  author_avatar: string | null
  author_avatar_path: string | null
  created_at: string
  first_post_content: string
  reply_count: number
  total_likes: number
  total_dislikes: number
  is_op_deleted?: boolean
  has_poll?: boolean
  is_bookmarked?: boolean
}

export interface Post {
  id: number
  thread_id: number
  parent_id: number | null
  content: string
  author_id: string
  author_name: string
  author_avatar: string | null
  author_avatar_path: string | null
  created_at: string
  reply_count: number
  likes: number
  dislikes: number
  user_vote: number | null
  is_bookmarked?: boolean
  first_reply_content: string | null
  first_reply_author: string | null
  first_reply_avatar: string | null
  first_reply_avatar_path: string | null
  first_reply_date: string | null
  is_flagged?: boolean
  flag_reason?: string | null
  is_deleted?: boolean
  deleted_by?: string | null
  additional_comments?: string | null
  edited_at?: string | null
}

export interface FlaggedPost {
  id: number
  thread_id: number
  thread_title: string
  parent_id: number | null
  content: string
  author_id: string
  author_name: string
  author_avatar: string | null
  author_avatar_path: string | null
  created_at: string
  flag_reason: string
  is_thread_op: boolean
}

export interface AuthorPost {
  id: number
  thread_id: number
  thread_title: string
  parent_id: number | null
  content: string
  author_id: string
  author_name: string
  author_avatar: string | null
  author_avatar_path: string | null
  created_at: string
  likes: number
  dislikes: number
  reply_count: number
  is_deleted: boolean
  deleted_by: string | null
  is_flagged: boolean
  is_thread_op: boolean
}

/**
 * BookmarkedPost extends Post with thread_title for display in bookmarks view.
 * Used by get_bookmarked_posts RPC.
 */
export interface BookmarkedPost extends Post {
  thread_title: string
}

/**
 * Converts a FlaggedPost to Post format for use in PostCard.
 * Centralizes the type conversion to prevent scattered hardcoded values.
 */
export function flaggedPostToPost(flaggedPost: FlaggedPost): Post {
  return {
    id: flaggedPost.id,
    thread_id: flaggedPost.thread_id,
    parent_id: flaggedPost.parent_id,
    content: flaggedPost.content,
    author_id: flaggedPost.author_id,
    author_name: flaggedPost.author_name,
    author_avatar: flaggedPost.author_avatar,
    author_avatar_path: flaggedPost.author_avatar_path,
    created_at: flaggedPost.created_at,
    // Voting data not available for flagged posts
    reply_count: 0,
    likes: 0,
    dislikes: 0,
    user_vote: null,
    // Preview data not available
    first_reply_content: null,
    first_reply_author: null,
    first_reply_avatar: null,
    first_reply_avatar_path: null,
    first_reply_date: null,
    // Flag status
    is_flagged: true,
    flag_reason: flaggedPost.flag_reason,
    // Deletion/edit status not tracked in flagged view
    is_deleted: false,
    deleted_by: null,
    edited_at: null,
    additional_comments: null,
  }
}

/**
 * Converts an AuthorPost to Post format for use in PostCard.
 * AuthorPost includes more data than FlaggedPost (votes, reply count, etc).
 */
export function authorPostToPost(authorPost: AuthorPost): Post {
  return {
    id: authorPost.id,
    thread_id: authorPost.thread_id,
    parent_id: authorPost.parent_id,
    content: authorPost.content,
    author_id: authorPost.author_id,
    author_name: authorPost.author_name,
    author_avatar: authorPost.author_avatar,
    author_avatar_path: authorPost.author_avatar_path,
    created_at: authorPost.created_at,
    reply_count: authorPost.reply_count,
    likes: authorPost.likes,
    dislikes: authorPost.dislikes,
    user_vote: null, // Not available in author search
    // Preview data not available
    first_reply_content: null,
    first_reply_author: null,
    first_reply_avatar: null,
    first_reply_avatar_path: null,
    first_reply_date: null,
    // Flag status
    is_flagged: authorPost.is_flagged,
    flag_reason: null,
    // Deletion status
    is_deleted: authorPost.is_deleted,
    deleted_by: authorPost.deleted_by,
    edited_at: null,
    additional_comments: null,
  }
}
