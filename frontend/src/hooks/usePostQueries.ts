import { useQuery, useQueryClient, useMutation } from '@tanstack/react-query'
import { supabase, supabasePublic } from '../lib/supabase'
import { STALE_TIME, PAGE_SIZE } from '../utils/constants'
import {
  getCachedThreadView,
  invalidateThreadCache,
  invalidateThreadsCache,
  isCacheEnabled,
} from '../lib/cacheApi'
import { extractPaginatedResponse } from '../utils/queryHelpers'

import { forumKeys } from './forumQueryKeys'
import { profileKeys } from './useUserProfile'
import { useAuth } from './useAuth'
import type { Post, Thread, GetPaginatedPostsResponse } from '../types'

// Fetch a single post by ID (used to resolve stub posts in replies view)
export function usePostById(postId: number, enabled: boolean = true) {
  const { session } = useAuth()
  const client = session?.access_token ? supabase : supabasePublic

  return useQuery({
    queryKey: ['forum', 'post', postId],
    networkMode: 'always',
    queryFn: async (): Promise<Post | null> => {
      const { data, error } = await client.rpc('get_post_by_id', {
        p_post_id: postId,
      })
      if (error) throw error
      const rows = (data ?? []) as Post[]
      return rows[0] ?? null
    },
    enabled,
    staleTime: STALE_TIME.SHORT,
  })
}

// Paginated posts query with server-side sorting
export function usePaginatedPosts(
  threadId: number,
  parentId: number | null,
  page: number,
  pageSize: number = PAGE_SIZE.POSTS,
  sort: 'popular' | 'new' = 'popular',
  enabled: boolean = true
) {
  const { session } = useAuth()
  const client = session?.access_token ? supabase : supabasePublic

  return useQuery({
    queryKey: forumKeys.paginatedPosts(threadId, parentId, page, sort),
    networkMode: 'always',
    queryFn: async (): Promise<GetPaginatedPostsResponse> => {
      const { data, error } = await client.rpc('get_paginated_thread_posts', {
        p_thread_id: threadId,
        p_parent_id: parentId,
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
        p_sort: sort,
      })
      if (error) throw error
      const { items: posts, totalCount } = extractPaginatedResponse<Post>(data)
      return { posts, totalCount }
    },
    enabled,
    staleTime: STALE_TIME.SHORT,
    placeholderData: (prev) => prev,
  })
}

// Thread view response type (OP + paginated replies in single query)
export interface ThreadViewResponse {
  originalPost: Post | undefined
  replies: Post[]
  totalCount: number
}

// Thread view query - fetches OP + paginated replies in a single query (eliminates waterfall)
export function useThreadView(
  threadId: number,
  page: number,
  pageSize: number = PAGE_SIZE.POSTS,
  sort: 'popular' | 'new' = 'popular',
  enabled: boolean = true
) {
  const { session, isAdmin } = useAuth()
  const client = session?.access_token ? supabase : supabasePublic

  return useQuery({
    queryKey: forumKeys.threadView(threadId, page, sort),
    networkMode: 'always',
    queryFn: async (): Promise<ThreadViewResponse> => {
      let rows: Array<Post & { is_op: boolean; total_count: number }> = []

      if (!isAdmin && isCacheEnabled()) {
        const cached = await getCachedThreadView(threadId, pageSize, (page - 1) * pageSize, sort)
        if (cached) {
          rows = cached as Array<Post & { is_op: boolean; total_count: number }>
        }
      }

      if (rows.length === 0) {
        const { data, error } = await client.rpc('get_thread_view', {
          p_thread_id: threadId,
          p_limit: pageSize,
          p_offset: (page - 1) * pageSize,
          p_sort: sort,
        })
        if (error) throw error
        rows = (data ?? []) as Array<Post & { is_op: boolean; total_count: number }>
      }

      if (session?.access_token && rows.length > 0) {
        try {
          const postIds = Array.from(new Set(rows.map((row) => row.id)))
          const { data, error } = await supabase.rpc('get_user_post_overlays', {
            p_post_ids: postIds,
          })

          if (!error) {
            const overlayMap = new Map<
              number,
              { vote_type: number | null; is_bookmarked: boolean }
            >(
              (
                data as Array<{
                  post_id: number
                  vote_type: number | null
                  is_bookmarked: boolean
                }> | null
              )?.map((row) => [
                row.post_id,
                { vote_type: row.vote_type ?? null, is_bookmarked: row.is_bookmarked },
              ]) || []
            )

            rows = rows.map((row) => {
              const overlay = overlayMap.get(row.id)
              if (!overlay) return row
              return {
                ...row,
                user_vote: overlay.vote_type ?? null,
                is_bookmarked: overlay.is_bookmarked,
              }
            })
          }
        } catch {
          // If overlay fails, fall back to base data
        }
      }
      const opRow = rows.find((r) => r.is_op)
      const replyRows = rows.filter((r) => !r.is_op)
      const totalCount = rows[0]?.total_count ?? 0

      // Convert to Post type (remove is_op and total_count fields)
      const toPost = (row: Post & { is_op: boolean; total_count: number }): Post => {
        const { is_op: _isOp, total_count: _totalCount, ...post } = row
        void _isOp
        void _totalCount
        return post as Post
      }

      return {
        originalPost: opRow ? toPost(opRow) : undefined,
        replies: replyRows.map(toPost),
        totalCount,
      }
    },
    enabled,
    staleTime: STALE_TIME.SHORT,
    placeholderData: (prev) => prev,
  })
}

// Prefetch posts for a thread (call on hover to preload data)
export function usePrefetchPosts() {
  const queryClient = useQueryClient()

  return (threadId: number) => {
    queryClient.prefetchQuery({
      queryKey: forumKeys.threadView(threadId, 1, 'popular'),
      queryFn: async (): Promise<ThreadViewResponse> => {
        const { data, error } = await supabase.rpc('get_thread_view', {
          p_thread_id: threadId,
          p_limit: PAGE_SIZE.POSTS,
          p_offset: 0,
          p_sort: 'popular',
        })
        if (error) throw error
        const rows = (data ?? []) as Array<Post & { is_op: boolean; total_count: number }>
        const totalCount = rows[0]?.total_count ?? 0
        const opRow = rows.find((row) => row.is_op)
        const replyRows = rows.filter((row) => !row.is_op)

        const toPost = (row: Post & { is_op: boolean; total_count: number }): Post => {
          const { is_op: _isOp, total_count: _totalCount, ...post } = row
          void _isOp
          void _totalCount
          return post as Post
        }

        return {
          originalPost: opRow ? toPost(opRow) : undefined,
          replies: replyRows.map(toPost),
          totalCount,
        }
      },
      staleTime: STALE_TIME.SHORT,
    })
  }
}

// Add reply variables - includes user info for optimistic update
export interface AddReplyVariables {
  threadId: number
  content: string
  parentId: number | null
  // User info for optimistic reply creation
  userId: string
  userName: string
  userAvatar: string | null
  // Current page/sort for optimistic cache update
  page: number
  sort: 'popular' | 'new'
  // Optimistic ID for updating with real ID after success
  optimisticId: number
}

// Helper to create optimistic reply object
function createOptimisticReply(variables: AddReplyVariables): Post {
  return {
    id: variables.optimisticId, // Temporary negative ID, will be replaced with real ID on success
    thread_id: variables.threadId,
    parent_id: variables.parentId,
    content: variables.content,
    author_id: variables.userId,
    author_name: variables.userName,
    author_avatar: variables.userAvatar,
    author_avatar_path: null, // Will be fetched on refetch
    created_at: new Date().toISOString(),
    likes: 1, // Auto-upvoted
    dislikes: 0,
    reply_count: 0,
    user_vote: 1, // Author auto-upvotes their own post
    first_reply_content: null,
    first_reply_author: null,
    first_reply_avatar: null,
    first_reply_avatar_path: null,
    first_reply_date: null,
    is_deleted: false,
    deleted_by: null,
    additional_comments: null,
    is_flagged: false,
    flag_reason: null,
  }
}

// Helper to prepend optimistic reply to paginated posts
function prependOptimisticReply(
  old: GetPaginatedPostsResponse | undefined,
  variables: AddReplyVariables
): GetPaginatedPostsResponse {
  const optimisticReply = createOptimisticReply(variables)
  if (!old) return { posts: [optimisticReply], totalCount: 1 }
  return { posts: [optimisticReply, ...old.posts], totalCount: old.totalCount + 1 }
}

// Helper to prepend optimistic reply to threadView cache (level-1 replies only)
function prependOptimisticReplyToThreadView(
  old: ThreadViewResponse | undefined,
  variables: AddReplyVariables
): ThreadViewResponse {
  const optimisticReply = createOptimisticReply(variables)
  if (!old) return { originalPost: undefined, replies: [optimisticReply], totalCount: 1 }
  return { ...old, replies: [optimisticReply, ...old.replies], totalCount: old.totalCount + 1 }
}

// Helper to find all threadView queries for a thread
function findThreadViewQueries(queryClient: ReturnType<typeof useQueryClient>, threadId: number) {
  return queryClient.getQueryCache().findAll({
    predicate: (query) => {
      const key = query.queryKey
      return (
        key[0] === 'forum' && key[1] === 'posts' && key[2] === threadId && key[3] === 'threadView'
      )
    },
  })
}

// Add reply mutation with optimistic update for both paginatedPosts and threadView
export function useAddReply() {
  const queryClient = useQueryClient()
  const { session } = useAuth()

  return useMutation<number, Error, AddReplyVariables, { previousData: Map<string, unknown> }>({
    mutationFn: async ({ threadId, content, parentId }): Promise<number> => {
      const { data, error } = await supabase.rpc('add_reply', {
        p_thread_id: threadId,
        p_content: content,
        p_parent_id: parentId,
      })
      if (error) throw error
      return data as number // Returns the new post ID
    },

    onMutate: async (variables) => {
      // Cancel outgoing queries
      await queryClient.cancelQueries({ queryKey: ['forum', 'posts', variables.threadId] })

      // Store previous data for ALL caches (unified rollback)
      const previousData = new Map<string, unknown>()

      // Optimistically update paginatedPosts cache
      const paginatedKey = forumKeys.paginatedPosts(
        variables.threadId,
        variables.parentId,
        variables.page,
        variables.sort
      )
      const oldPaginated = queryClient.getQueryData<GetPaginatedPostsResponse>(paginatedKey)
      if (oldPaginated) {
        previousData.set(JSON.stringify(paginatedKey), oldPaginated)
      }
      queryClient.setQueryData<GetPaginatedPostsResponse>(paginatedKey, (old) =>
        prependOptimisticReply(old, variables)
      )

      // Only update threadView for level-1 replies (direct replies to OP)
      // Level-1 replies have parentId = OP's ID, sub-replies have parentId = some reply's ID
      // We detect level-1 replies by checking if parentId matches the OP's ID in the cache
      const threadViewQueries = findThreadViewQueries(queryClient, variables.threadId)
      for (const query of threadViewQueries) {
        const oldData = queryClient.getQueryData<ThreadViewResponse>(query.queryKey)
        if (!oldData) continue

        // Check if this is a level-1 reply (parentId === OP's ID)
        const opId = oldData.originalPost?.id
        const isLevel1Reply = opId !== undefined && variables.parentId === opId

        if (isLevel1Reply) {
          const keyStr = JSON.stringify(query.queryKey)
          previousData.set(keyStr, oldData)
          queryClient.setQueryData<ThreadViewResponse>(query.queryKey, (old) =>
            prependOptimisticReplyToThreadView(old, variables)
          )
        }
      }

      return { previousData }
    },

    onError: (_error, _variables, context) => {
      // Rollback ALL caches
      if (context?.previousData) {
        for (const [keyStr, data] of context.previousData) {
          queryClient.setQueryData(JSON.parse(keyStr), data)
        }
      }
    },

    onSuccess: (realPostId, variables) => {
      // Replace optimistic ID with real ID in paginatedPosts cache
      const paginatedKey = forumKeys.paginatedPosts(
        variables.threadId,
        variables.parentId,
        variables.page,
        variables.sort
      )
      queryClient.setQueryData<GetPaginatedPostsResponse>(paginatedKey, (old) => {
        if (!old) return old
        return {
          ...old,
          posts: old.posts.map((p) =>
            p.id === variables.optimisticId ? { ...p, id: realPostId } : p
          ),
        }
      })

      // Single pass over threadView queries: replace optimistic ID + update reply_count
      const threadViewQueries = findThreadViewQueries(queryClient, variables.threadId)
      for (const query of threadViewQueries) {
        const data = queryClient.getQueryData<ThreadViewResponse>(query.queryKey)
        if (!data) continue

        const opId = data.originalPost?.id
        const isLevel1Reply = opId !== undefined && variables.parentId === opId

        queryClient.setQueryData<ThreadViewResponse>(query.queryKey, (old) => {
          if (!old) return old
          return {
            ...old,
            replies: old.replies.map((p) => {
              // Replace optimistic ID (level-1 replies only)
              if (isLevel1Reply && p.id === variables.optimisticId) {
                return { ...p, id: realPostId }
              }
              // Update parent's reply_count (sub-replies only)
              if (p.id === variables.parentId) {
                return { ...p, reply_count: p.reply_count + 1 }
              }
              return p
            }),
          }
        })
      }

      // Update reply_count in paginated and legacy caches (for sub-replies)
      if (variables.parentId !== null) {
        const updateParentReplyCount = (
          oldData: GetPaginatedPostsResponse | Post[] | undefined
        ) => {
          if (!oldData) return oldData

          // Paginated format: { posts: Post[], totalCount: number }
          if (typeof oldData === 'object' && 'posts' in oldData) {
            return {
              ...oldData,
              posts: oldData.posts.map((p) =>
                p.id === variables.parentId ? { ...p, reply_count: p.reply_count + 1 } : p
              ),
            }
          }

          // Legacy format: Post[]
          if (Array.isArray(oldData)) {
            return oldData.map((p) =>
              p.id === variables.parentId ? { ...p, reply_count: p.reply_count + 1 } : p
            )
          }

          return oldData
        }
        queryClient.setQueriesData(
          { queryKey: forumKeys.posts(variables.threadId, null) },
          updateParentReplyCount
        )
      }

      // Surgically update reply_count in all paginated thread caches
      const updatePaginatedThreadReplyCount = (
        oldData: { threads: Thread[]; totalCount: number } | undefined
      ) => {
        if (!oldData) return oldData
        return {
          ...oldData,
          threads: oldData.threads.map((thread) =>
            thread.id === variables.threadId
              ? { ...thread, reply_count: thread.reply_count + 1 }
              : thread
          ),
        }
      }
      queryClient.setQueriesData(
        { queryKey: forumKeys.threadsAll() },
        updatePaginatedThreadReplyCount
      )

      // Update profile stats (post count increased)
      queryClient.invalidateQueries({ queryKey: profileKeys.userStats(variables.userId) })

      if (session?.access_token) {
        invalidateThreadCache(variables.threadId, session.access_token)
        invalidateThreadsCache(session.access_token)
      }
    },
  })
}
