import { useMutation, useQueryClient, type InfiniteData } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { useOptimisticMutation } from './useOptimisticMutation'
import { chatKeys } from './useChatQueries'
import type { ChatMessage, UserConversation } from '../types'

// Type for infinite query page data
interface MessagesPage {
  messages: ChatMessage[]
  nextCursor: string | null
  hasMore: boolean
}

/**
 * Helper to invalidate chat-related queries after mutations
 */
function invalidateChatQueries(
  queryClient: ReturnType<typeof useQueryClient>,
  userId: string,
  partnerId?: string
) {
  queryClient.invalidateQueries({ queryKey: chatKeys.conversations(userId) })
  queryClient.invalidateQueries({ queryKey: chatKeys.unreadCount(userId) })
  if (partnerId) {
    queryClient.invalidateQueries({ queryKey: chatKeys.messagesInfinite(userId, partnerId) })
  }
}

/**
 * Mutation to send a message to another user
 */
export interface SendChatMessageVariables {
  senderId: string
  recipientId: string
  content: string
  // User info for optimistic message
  senderUsername?: string
  senderAvatar?: string | null
}

export function useSendChatMessage() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ senderId, recipientId, content }: SendChatMessageVariables) => {
      const { data, error } = await supabase
        .from('feedback_messages')
        .insert({
          user_id: senderId,
          recipient_id: recipientId,
          content: content.trim(),
        })
        .select()
        .single()

      if (error) throw error
      return data as { id: string; created_at: string }
    },
    onMutate: async (variables) => {
      const { senderId, recipientId, content, senderUsername, senderAvatar } = variables
      const queryKeyBase = chatKeys.messagesInfinite(senderId, recipientId)

      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: queryKeyBase })

      // Snapshot previous data for rollback
      const previousData = queryClient.getQueryData<InfiniteData<MessagesPage>>(queryKeyBase)

      // Create optimistic message with temp ID
      const optimisticMessage: ChatMessage = {
        id: `temp-${Date.now()}`,
        user_id: senderId,
        recipient_id: recipientId,
        content: content.trim(),
        is_read: false,
        created_at: new Date().toISOString(),
        sender_username: senderUsername,
        sender_avatar: senderAvatar,
      }

      // Optimistically prepend message to first page
      const matchingQueries = queryClient.getQueryCache().findAll({ queryKey: queryKeyBase })
      for (const query of matchingQueries) {
        queryClient.setQueryData<InfiniteData<MessagesPage>>(query.queryKey, (old) => {
          if (!old) return old
          return {
            ...old,
            pages: old.pages.map((page, index) =>
              index === 0
                ? { ...page, messages: [optimisticMessage, ...page.messages] }
                : page
            ),
          }
        })
      }

      return { previousData, optimisticId: optimisticMessage.id }
    },
    onError: (_err, variables, context) => {
      // Rollback on error
      if (context?.previousData) {
        const queryKeyBase = chatKeys.messagesInfinite(variables.senderId, variables.recipientId)
        const matchingQueries = queryClient.getQueryCache().findAll({ queryKey: queryKeyBase })
        for (const query of matchingQueries) {
          queryClient.setQueryData(query.queryKey, context.previousData)
        }
      }
    },
    onSuccess: (data, variables, context) => {
      // Replace optimistic ID with real ID
      const queryKeyBase = chatKeys.messagesInfinite(variables.senderId, variables.recipientId)
      const matchingQueries = queryClient.getQueryCache().findAll({ queryKey: queryKeyBase })
      for (const query of matchingQueries) {
        queryClient.setQueryData<InfiniteData<MessagesPage>>(query.queryKey, (old) => {
          if (!old) return old
          return {
            ...old,
            pages: old.pages.map((page) => ({
              ...page,
              messages: page.messages.map((msg) =>
                msg.id === context?.optimisticId
                  ? { ...msg, id: data.id, created_at: data.created_at }
                  : msg
              ),
            })),
          }
        })
      }

      // Invalidate conversations list (to update last message preview)
      queryClient.invalidateQueries({ queryKey: chatKeys.conversations(variables.senderId) })
      // Also invalidate recipient's unread count
      queryClient.invalidateQueries({ queryKey: chatKeys.unreadCount(variables.recipientId) })
    },
  })
}

/**
 * Mutation to mark conversation as read
 */
export interface MarkConversationReadVariables {
  userId: string
  partnerId: string
}

export function useMarkConversationRead() {
  const queryClient = useQueryClient()

  return useOptimisticMutation<never, MarkConversationReadVariables, void>({
    mutationFn: async ({ userId, partnerId }) => {
      const { error } = await supabase.rpc('mark_conversation_read', {
        p_user_id: userId,
        p_partner_id: partnerId,
      })

      if (error) throw error
    },
    cacheUpdates: [],
    invalidateOnSettled: false,
    onSuccess: (_, variables) => {
      // Optimistically update conversations cache to clear unread badge immediately
      const convoQueries = queryClient.getQueryCache().findAll({
        queryKey: chatKeys.conversations(variables.userId),
      })
      for (const query of convoQueries) {
        queryClient.setQueryData<UserConversation[]>(query.queryKey, (old) => {
          if (!old) return old
          return old.map((conv) =>
            conv.conversation_partner_id === variables.partnerId
              ? { ...conv, unread_count: 0 }
              : conv
          )
        })
      }
      // Still invalidate to ensure fresh data when query re-enables
      invalidateChatQueries(queryClient, variables.userId, variables.partnerId)
    },
  })
}
