import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME, POLL_INTERVAL, PAGE_SIZE } from '../utils/constants'
import type {
  ChatMessage,
  UserConversation,
  RawConversationMessage,
} from '../types'

// Query key factory for chat
export const chatKeys = {
  all: ['chat'] as const,
  conversations: (userId: string) => [...chatKeys.all, 'conversations', userId] as const,
  messagesInfinite: (userId: string, partnerId: string) =>
    [...chatKeys.all, 'messages', 'infinite', userId, partnerId] as const,
  messagesPrefetch: (userId: string, partnerId: string) =>
    [...chatKeys.all, 'messages', 'prefetch', userId, partnerId] as const,
  unreadCount: (userId: string) => [...chatKeys.all, 'unread', userId] as const,
  ignoredUsers: (userId: string) => [...chatKeys.all, 'ignored', userId] as const,
  isUserIgnored: (userId: string, targetId: string) =>
    [...chatKeys.all, 'ignored', userId, targetId] as const,
}

/**
 * Hook to fetch user's conversations list
 */
export function useConversations(userId: string | null, options?: { enabled?: boolean }) {
  return useQuery({
    queryKey: chatKeys.conversations(userId || ''),
    queryFn: async () => {
      if (!userId) return []

      const { data, error } = await supabase.rpc('get_user_conversations', {
        p_user_id: userId,
      })

      if (error) throw error
      return (data || []) as UserConversation[]
    },
    enabled: !!userId && options?.enabled !== false,
    staleTime: STALE_TIME.MEDIUM,
    refetchInterval: POLL_INTERVAL.NOTIFICATIONS,
    refetchIntervalInBackground: false,
  })
}

/**
 * Transform raw conversation message to ChatMessage format
 */
function transformConversationMessage(msg: RawConversationMessage): ChatMessage {
  return {
    id: msg.id,
    user_id: msg.user_id,
    recipient_id: msg.recipient_id,
    content: msg.content,
    is_read: msg.is_read,
    created_at: msg.created_at,
    sender_username: msg.sender_username,
    sender_avatar: msg.sender_avatar,
  }
}

/**
 * Hook to fetch messages with a specific user (infinite scroll)
 */
export function useConversationMessages(
  userId: string | null,
  partnerId: string | null,
  options?: { enabled?: boolean }
) {
  return useInfiniteQuery({
    queryKey: chatKeys.messagesInfinite(userId || '', partnerId || '') as const,
    queryFn: async ({ pageParam }) => {
      if (!userId || !partnerId) return { messages: [], nextCursor: null, hasMore: false }

      const { data, error } = await supabase.rpc('get_conversation_messages', {
        p_user_id: userId,
        p_partner_id: partnerId,
        p_limit: PAGE_SIZE.POSTS,
        p_before_cursor: pageParam || null,
      })

      if (error) throw error

      const rawMessages = (data || []) as RawConversationMessage[]
      const messages = rawMessages.map(transformConversationMessage)
      const hasMore = messages.length === PAGE_SIZE.POSTS
      const nextCursor = hasMore ? messages[messages.length - 1]?.created_at : null

      return { messages, nextCursor, hasMore }
    },
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => (lastPage.hasMore ? lastPage.nextCursor : undefined),
    enabled: !!userId && !!partnerId && options?.enabled !== false,
    staleTime: STALE_TIME.SHORT,
    maxPages: 20, // Limit cached pages to prevent memory bloat
  })
}

/**
 * Hook to get total unread message count
 */
export function useUnreadMessageCount(userId: string | null, options?: { enabled?: boolean }) {
  return useQuery({
    queryKey: chatKeys.unreadCount(userId || ''),
    queryFn: async () => {
      if (!userId) return 0

      const { data, error } = await supabase.rpc('get_unread_message_count', {
        p_user_id: userId,
      })

      if (error) throw error
      return (data as number) || 0
    },
    enabled: !!userId && options?.enabled !== false,
    staleTime: STALE_TIME.SHORT,
    refetchInterval: POLL_INTERVAL.NOTIFICATIONS,
    refetchIntervalInBackground: false,
  })
}

// Re-export mutations for backward compatibility
export {
  useSendChatMessage,
  useMarkConversationRead,
  type SendChatMessageVariables,
  type MarkConversationReadVariables,
} from './useChatMutations'

/**
 * Hook to fetch list of ignored user IDs
 */
export function useIgnoredUsers(userId: string | null) {
  return useQuery({
    queryKey: chatKeys.ignoredUsers(userId || ''),
    queryFn: async (): Promise<Set<string>> => {
      if (!userId) return new Set()

      const { data, error } = await supabase.rpc('get_ignored_users')

      if (error) {
        console.error('Failed to fetch ignored users:', error)
        return new Set()
      }

      return new Set((data || []).map((row: { ignored_user_id: string }) => row.ignored_user_id))
    },
    enabled: !!userId,
    staleTime: STALE_TIME.MEDIUM,
  })
}

/**
 * Hook to check if a specific user is ignored
 */
export function useIsUserIgnored(userId: string | null, targetUserId: string | null) {
  return useQuery({
    queryKey: chatKeys.isUserIgnored(userId || '', targetUserId || ''),
    queryFn: async (): Promise<boolean> => {
      if (!userId || !targetUserId) return false

      const { data, error } = await supabase.rpc('is_user_ignored', {
        p_user_id: targetUserId,
      })

      if (error) {
        console.error('Failed to check if user is ignored:', error)
        return false
      }

      return data as boolean
    },
    enabled: !!userId && !!targetUserId,
    staleTime: STALE_TIME.MEDIUM,
  })
}

/**
 * Hook to toggle ignore status for a user
 */
export function useToggleIgnore(currentUserId: string | null) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (targetUserId: string): Promise<boolean> => {
      const { data, error } = await supabase.rpc('toggle_ignore_user', {
        p_ignored_user_id: targetUserId,
      })

      if (error) throw error
      return data as boolean // true = now ignored, false = now unignored
    },
    onSuccess: (isNowIgnored, targetUserId) => {
      // Update the ignored users set
      queryClient.setQueryData<Set<string>>(
        chatKeys.ignoredUsers(currentUserId || ''),
        (old) => {
          const newSet = new Set(old || [])
          if (isNowIgnored) {
            newSet.add(targetUserId)
          } else {
            newSet.delete(targetUserId)
          }
          return newSet
        }
      )
      // Update the specific user check
      queryClient.setQueryData(
        chatKeys.isUserIgnored(currentUserId || '', targetUserId),
        isNowIgnored
      )
      // Invalidate conversations to refresh the list
      queryClient.invalidateQueries({
        queryKey: chatKeys.conversations(currentUserId || ''),
      })
    },
  })
}
