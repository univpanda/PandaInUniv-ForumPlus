import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { forumKeys } from './forumQueryKeys'
import { useOptimisticMutation } from './useOptimisticMutation'
import {
  extractSingleResult,
  type Post,
  type Thread,
  type VotePostResponse,
  type EditPostResponse,
  type DeletePostResponse,
  type GetPaginatedPostsResponse,
} from '../types'

// ============================================================================
// SHARED HELPERS
// ============================================================================

/**
 * Calculate new vote counts based on previous and new vote.
 * Handles toggle behavior (clicking same vote removes it).
 */
export function calculateVoteUpdate(
  prevVote: number | null,
  prevLikes: number,
  prevDislikes: number,
  voteType: 1 | -1
): { likes: number; dislikes: number; user_vote: number | null } {
  let likes = prevLikes
  let dislikes = prevDislikes
  let user_vote: number | null = voteType

  // Remove previous vote first
  if (prevVote === 1) likes--
  if (prevVote === -1) dislikes--

  // Toggle off if same vote, otherwise apply new vote
  if (prevVote === voteType) {
    user_vote = null
  } else {
    if (voteType === 1) likes++
    if (voteType === -1) dislikes++
  }

  return { likes, dislikes, user_vote }
}

/**
 * Helper to update a single post's vote data.
 * Returns the same object reference if postId doesn't match (for React optimization).
 */
function updatePostVote(
  post: Post,
  postId: number,
  update: { likes: number; dislikes: number; user_vote: number | null }
): Post {
  if (post.id !== postId) return post
  return { ...post, ...update }
}

/**
 * Helper to update a post's content/comments in an array.
 */
function updatePostContent(
  post: Post,
  postId: number,
  content?: string,
  additionalComments?: string
): Post {
  if (post.id !== postId) return post
  return {
    ...post,
    content: content ?? post.content,
    additional_comments: additionalComments
      ? post.additional_comments
        ? post.additional_comments + '\n' + `[${new Date().toISOString()}]${additionalComments}`
        : `[${new Date().toISOString()}]${additionalComments}`
      : post.additional_comments,
    edited_at: content ? new Date().toISOString() : post.edited_at,
  }
}

/**
 * Generic helper to update posts across all cache formats.
 * Handles both legacy (Post[]) and paginated ({ posts: Post[], totalCount }) formats.
 *
 * @param queryClient - React Query client
 * @param threadId - Thread ID to scope the cache search
 * @param postId - Post ID to update
 * @param updater - Function to update a single post
 * @param previousData - Map to store previous data for rollback
 */
function updatePostInAllCaches(
  queryClient: ReturnType<typeof useQueryClient>,
  threadId: number,
  postId: number,
  updater: (post: Post) => Post,
  previousData: Map<string, unknown>
): void {
  const cache = queryClient.getQueryCache()

  // Find all post-related caches for this thread
  // This matches both legacy and paginated formats
  const queries = cache.findAll({ queryKey: ['forum', 'posts', threadId] })

  for (const query of queries) {
    const key = query.queryKey
    const data = query.state.data

    if (!data) continue

    // Handle paginated format: { posts: Post[], totalCount: number }
    if (typeof data === 'object' && 'posts' in data && Array.isArray((data as GetPaginatedPostsResponse).posts)) {
      const paginatedData = data as GetPaginatedPostsResponse
      const postIndex = paginatedData.posts.findIndex((p) => p.id === postId)

      if (postIndex !== -1) {
        previousData.set(JSON.stringify(key), paginatedData)
        queryClient.setQueryData<GetPaginatedPostsResponse>(key, {
          ...paginatedData,
          posts: paginatedData.posts.map((p) => (p.id === postId ? updater(p) : p)),
        })
      }
    }
    // Handle legacy format: Post[]
    else if (Array.isArray(data)) {
      const posts = data as Post[]
      const postIndex = posts.findIndex((p) => p.id === postId)

      if (postIndex !== -1) {
        previousData.set(JSON.stringify(key), posts)
        queryClient.setQueryData<Post[]>(key, posts.map((p) => (p.id === postId ? updater(p) : p)))
      }
    }
  }
}

/**
 * Update thread vote counts in all thread caches (for OP votes).
 */
function updateThreadVotesInAllCaches(
  queryClient: ReturnType<typeof useQueryClient>,
  threadId: number,
  likes: number,
  dislikes: number,
  previousData: Map<string, unknown>
): void {
  const cache = queryClient.getQueryCache()
  const threadQueries = cache.findAll({ queryKey: forumKeys.threadsAll() })

  for (const query of threadQueries) {
    const key = query.queryKey
    const data = query.state.data

    if (!data) continue

    // Handle paginated format: { threads: Thread[], totalCount: number }
    if (typeof data === 'object' && 'threads' in data && Array.isArray((data as { threads: Thread[] }).threads)) {
      const paginatedData = data as { threads: Thread[]; totalCount: number }
      const hasThread = paginatedData.threads.some((t) => t.id === threadId)

      if (hasThread) {
        previousData.set(JSON.stringify(key), paginatedData)
        queryClient.setQueryData(key, {
          ...paginatedData,
          threads: paginatedData.threads.map((t) =>
            t.id === threadId ? { ...t, total_likes: likes, total_dislikes: dislikes } : t
          ),
        })
      }
    }
    // Handle legacy format: Thread[]
    else if (Array.isArray(data)) {
      const threads = data as Thread[]
      const hasThread = threads.some((t) => t.id === threadId)

      if (hasThread) {
        previousData.set(JSON.stringify(key), threads)
        queryClient.setQueryData<Thread[]>(key, threads.map((t) =>
          t.id === threadId ? { ...t, total_likes: likes, total_dislikes: dislikes } : t
        ))
      }
    }
  }
}

/**
 * Rollback cache changes using stored previous data.
 */
function rollbackCacheChanges(
  queryClient: ReturnType<typeof useQueryClient>,
  previousData: Map<string, unknown>
): void {
  for (const [keyStr, data] of previousData) {
    queryClient.setQueryData(JSON.parse(keyStr), data)
  }
}

// ============================================================================
// VOTE MUTATION
// ============================================================================

export interface VotePostVariables {
  postId: number
  voteType: 1 | -1
  threadId: number
  isOriginalPost: boolean
  // Previous values for optimistic update calculation
  prevVote: number | null
  prevLikes: number
  prevDislikes: number
}

export function useVotePost() {
  const queryClient = useQueryClient()

  return useMutation<VotePostResponse | undefined, Error, VotePostVariables, { previousData: Map<string, unknown> }>({
    mutationFn: async ({ postId, voteType }): Promise<VotePostResponse | undefined> => {
      const { data, error } = await supabase.rpc('vote_post', {
        p_post_id: postId,
        p_vote_type: voteType,
      })
      if (error) throw error
      return extractSingleResult(data as VotePostResponse[])
    },

    onMutate: async ({ postId, threadId, isOriginalPost, prevVote, prevLikes, prevDislikes, voteType }) => {
      // Cancel any outgoing refetches to prevent race conditions
      await queryClient.cancelQueries({ queryKey: forumKeys.postsAll() })

      const previousData = new Map<string, unknown>()
      const update = calculateVoteUpdate(prevVote, prevLikes, prevDislikes, voteType)

      // Update the post in all caches (legacy and paginated)
      updatePostInAllCaches(
        queryClient,
        threadId,
        postId,
        (post) => updatePostVote(post, postId, update),
        previousData
      )

      // For original posts, also update thread list caches
      if (isOriginalPost) {
        updateThreadVotesInAllCaches(queryClient, threadId, update.likes, update.dislikes, previousData)
      }

      return { previousData }
    },

    onError: (_err, _variables, context) => {
      if (context?.previousData) {
        rollbackCacheChanges(queryClient, context.previousData)
      }
    },
  })
}

// ============================================================================
// EDIT MUTATION
// ============================================================================

export interface EditPostVariables {
  postId: number
  content?: string
  additionalComments?: string
  threadId: number
}

export function useEditPost() {
  const queryClient = useQueryClient()

  return useMutation<EditPostResponse, Error, EditPostVariables, { previousData: Map<string, unknown> }>({
    mutationFn: async ({ postId, content, additionalComments }) => {
      const { data, error } = await supabase.rpc('edit_post', {
        p_post_id: postId,
        p_content: content || null,
        p_additional_comments: additionalComments || null,
      })
      if (error) throw error
      const result = extractSingleResult(data as EditPostResponse[])
      if (!result?.success) {
        throw new Error(result?.message || 'Failed to edit post')
      }
      return result
    },

    onMutate: async ({ postId, content, additionalComments, threadId }) => {
      await queryClient.cancelQueries({ queryKey: forumKeys.postsAll() })

      const previousData = new Map<string, unknown>()

      updatePostInAllCaches(
        queryClient,
        threadId,
        postId,
        (post) => updatePostContent(post, postId, content, additionalComments),
        previousData
      )

      return { previousData }
    },

    onError: (_err, _variables, context) => {
      if (context?.previousData) {
        rollbackCacheChanges(queryClient, context.previousData)
      }
    },
  })
}

// ============================================================================
// DELETE MUTATION
// ============================================================================

interface DeletePostVariables {
  postId: number
  threadId: number
  parentId: number | null
  userId?: string
}

export function useDeletePost() {
  return useOptimisticMutation<Post[], DeletePostVariables, DeletePostResponse>({
    mutationFn: async ({ postId }): Promise<DeletePostResponse> => {
      const { data, error } = await supabase.rpc('delete_post', {
        p_post_id: postId,
      })
      if (error) throw error
      const result = extractSingleResult(data as DeletePostResponse[])
      if (!result?.success) {
        throw new Error(result?.message || 'Failed to delete post')
      }
      return result
    },
    cacheUpdates: [
      {
        queryKey: ({ threadId, parentId }) => forumKeys.posts(threadId, parentId),
        updater: (posts, { postId, userId }) => {
          if (!posts) return posts
          return posts.map((post) => {
            if (post.id !== postId) return post
            const willBeDeleted = !post.is_deleted
            return {
              ...post,
              is_deleted: willBeDeleted,
              deleted_by: willBeDeleted ? userId : null,
            }
          })
        },
      },
    ],
    invalidateOnSettled: true,
    invalidateKeys: [forumKeys.authorPostsAll(), forumKeys.postsAll()],
  })
}
