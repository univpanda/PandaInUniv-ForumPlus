/**
 * API Response Types
 *
 * Centralized types for Supabase RPC responses to replace `as` assertions.
 * These types mirror the actual database function return types.
 */

import type { Thread, Post, FlaggedPost, AuthorPost } from './forum'
import type { UserWithStats } from './user'

// ============ Forum RPC Responses ============

/** Response from get_forum_threads RPC (legacy, no pagination) */
export type GetForumThreadsResponse = Thread[]

/** Response from get_paginated_forum_threads RPC */
export interface GetPaginatedThreadsResponse {
  threads: Thread[]
  totalCount: number
}

/** Response from get_paginated_thread_posts RPC */
export interface GetPaginatedPostsResponse {
  posts: Post[]
  totalCount: number
}

/** Response from get_flagged_posts RPC */
export type GetFlaggedPostsResponse = FlaggedPost[]

/** Response from get_flagged_posts RPC with pagination */
export interface GetPaginatedFlaggedPostsResponse {
  posts: FlaggedPost[]
  totalCount: number
}

/** Response from get_posts_by_author RPC with pagination */
export interface GetPaginatedAuthorPostsResponse {
  posts: AuthorPost[]
  totalCount: number
  isPrivate: boolean // true if searching a private user (and not admin/self)
}

/** Response from create_thread RPC - returns the new thread ID */
export type CreateThreadResponse = number

/** Response from vote_post RPC */
export interface VotePostResponse {
  likes: number
  dislikes: number
  user_vote: number | null
}

/** Response from edit_post RPC */
export interface EditPostResponse {
  success: boolean
  can_edit_content: boolean
  message: string
}

/** Response from delete_post RPC */
export interface DeletePostResponse {
  success: boolean
  message: string
}

/** Response from toggle_post_flagged RPC */
export interface ToggleFlaggedResponse {
  success: boolean
  is_flagged: boolean
  message: string
}

// ============ User RPC Responses ============

/** Response from get_users_with_stats RPC */
export type GetUsersWithStatsResponse = UserWithStats[]

/** Response from update_username RPC */
export interface UpdateUsernameResponse {
  success: boolean
  message: string
}


// ============ Helper Type for RPC Result Extraction ============

/**
 * Helper to extract single result from RPC that returns an array with one item.
 * Many Supabase RPCs return `data` as an array even for single results.
 */
export function extractSingleResult<T>(data: T[] | null | undefined): T | undefined {
  return data?.[0]
}
