import { useState, useEffect, useCallback, useMemo } from 'react'
import {
  useConversationMessages,
  useSendChatMessage,
  useMarkConversationRead,
} from './useChatQueries'
import type { ChatView } from '../types'

interface SelectedPartner {
  id: string
  username: string
  avatar: string | null
}

interface SenderInfo {
  username: string
  avatar: string | null
}

interface UseChatMessagesOptions {
  userId: string | null
  selectedPartner: SelectedPartner | null
  senderInfo: SenderInfo | null
  view: ChatView
}

/**
 * Hook for managing chat messages state and operations
 * Handles messages query, sending, and mark-as-read functionality
 */
export function useChatMessages({ userId, selectedPartner, senderInfo, view }: UseChatMessagesOptions) {
  // ============ Form State ============
  const [newMessage, setNewMessage] = useState('')
  const [sendError, setSendError] = useState<string | null>(null)
  const [includeOlder, setIncludeOlder] = useState(false)

  // ============ Messages Query ============
  const messagesQuery = useConversationMessages(userId, selectedPartner?.id || null, {
    enabled: view === 'chat' && !!selectedPartner,
    includeOlder,
  })

  // ============ Mutations ============
  const sendMessageMutation = useSendChatMessage()
  const markReadMutation = useMarkConversationRead()

  // ============ Computed Values ============
  // Flatten infinite query pages and reverse to show oldest first
  const messages = useMemo(() => {
    if (!messagesQuery.data?.pages) return []
    const allMessages = messagesQuery.data.pages.flatMap((page) => page.messages)
    // Reverse so oldest messages are at the top (chronological order)
    return allMessages.reverse()
  }, [messagesQuery.data])

  const hasMoreMessages = messagesQuery.hasNextPage ?? false
  const loadMoreMessages = messagesQuery.fetchNextPage
  const isLoadingMoreMessages = messagesQuery.isFetchingNextPage
  const isLoading = messagesQuery.isLoading
  const isSending = sendMessageMutation.isPending

  useEffect(() => {
    setIncludeOlder(false)
  }, [selectedPartner?.id])

  // Mark messages as read when viewing a conversation
  useEffect(() => {
    if (!userId || !selectedPartner || view !== 'chat') return
    if (messages.length === 0) return

    // Check if there are unread messages from the partner
    const hasUnreadFromPartner = messages.some(
      (m) => m.user_id === selectedPartner.id && !m.is_read
    )

    if (hasUnreadFromPartner) {
      markReadMutation.mutate({
        userId,
        partnerId: selectedPartner.id,
      })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- markReadMutation.mutate is stable
  }, [messages, userId, selectedPartner, view])

  // ============ Handlers ============
  const handleSendMessage = useCallback(async () => {
    if (!newMessage.trim() || !userId || !selectedPartner) return

    setSendError(null)
    try {
      await sendMessageMutation.mutateAsync({
        senderId: userId,
        recipientId: selectedPartner.id,
        content: newMessage,
        senderUsername: senderInfo?.username,
        senderAvatar: senderInfo?.avatar,
      })
      setNewMessage('')
    } catch {
      setSendError('Failed to send message. Please try again.')
    }
  }, [newMessage, userId, selectedPartner, senderInfo, sendMessageMutation])

  const clearSendError = useCallback(() => {
    setSendError(null)
  }, [])

  const clearMessage = useCallback(() => {
    setNewMessage('')
  }, [])

  return {
    // Form state
    newMessage,
    setNewMessage,
    clearMessage,

    // Data
    messages,

    // Infinite scroll
    hasMoreMessages,
    loadMoreMessages,
    isLoadingMoreMessages,

    // Loading states
    isLoading,
    isSending,
    includeOlder,
    setIncludeOlder,

    // Error state
    sendError,
    clearSendError,

    // Handlers
    handleSendMessage,
  }
}

export type ChatMessagesReturn = ReturnType<typeof useChatMessages>
