/* eslint-disable react-hooks/set-state-in-effect */
import { useState, useEffect, useCallback, useMemo } from 'react'
import { useAuth } from './useAuth'
import { useUserProfile } from './useUserProfile'
import { chatKeys } from './useChatQueries'
import { useChatConversations } from './useChatConversations'
import { useChatMessages } from './useChatMessages'
import { useQueryClient } from '@tanstack/react-query'
import type { ChatView, UserConversation } from '../types'

interface UseChatPageStateOptions {
  resetToList?: number
}

export function useChatPageState({ resetToList }: UseChatPageStateOptions = {}) {
  const { user, isAdmin } = useAuth()
  const { data: userProfile } = useUserProfile(user?.id ?? null)
  const queryClient = useQueryClient()

  // ============ Sender Info for Optimistic Updates ============
  const senderInfo = useMemo(() => {
    if (!user) return null
    return {
      username: userProfile?.username || user.user_metadata?.name || user.email || 'User',
      avatar: userProfile?.avatar_url || user.user_metadata?.avatar_url || null,
    }
  }, [user, userProfile])

  // ============ Navigation State ============
  const [view, setView] = useState<ChatView>('conversations')
  const [selectedPartner, setSelectedPartner] = useState<{
    id: string
    username: string | null
    avatar: string | null
    avatarPath?: string | null
  } | null>(null)

  // Reset to conversations list when resetToList changes
  useEffect(() => {
    if (resetToList) {
      setView('conversations')
      setSelectedPartner(null)
    }
  }, [resetToList])

  // ============ Conversations (extracted hook) ============
  const conversationsData = useChatConversations({
    userId: user?.id || null,
    view,
    isAdmin,
  })

  // ============ Messages (extracted hook) ============
  const messagesData = useChatMessages({
    userId: user?.id || null,
    selectedPartner,
    senderInfo,
    view,
  })

  const { setSearchQuery } = conversationsData
  const { clearMessage } = messagesData

  // Reset search and message form when view changes via resetToList
  useEffect(() => {
    if (resetToList) {
      setSearchQuery('')
      clearMessage()
    }
  }, [resetToList, setSearchQuery, clearMessage])

  // ============ Computed Values ============
  const loading =
    view === 'conversations' ? conversationsData.conversationsQuery.isLoading : messagesData.isLoading

  // ============ Navigation Handlers ============
  const openConversation = useCallback(
    (partner: UserConversation) => {
      setSelectedPartner({
        id: partner.conversation_partner_id,
        username: partner.partner_username,
        avatar: partner.partner_avatar,
        avatarPath: partner.partner_avatar_path,
      })
      setView('chat')
      conversationsData.setSearchQuery('')
    },
    [conversationsData]
  )

  // Used by Discussion username hover to start a new chat
  const startNewChat = useCallback(
    (partnerId: string, partnerUsername: string | null, partnerAvatar: string | null, partnerAvatarPath?: string | null) => {
      setSelectedPartner({
        id: partnerId,
        username: partnerUsername,
        avatar: partnerAvatar,
        avatarPath: partnerAvatarPath,
      })
      setView('chat')
      conversationsData.setSearchQuery('')
    },
    [conversationsData]
  )

  const backToList = useCallback(() => {
    setSelectedPartner(null)
    setView('conversations')
    // Force refetch conversations to update unread counts immediately
    queryClient.refetchQueries({ queryKey: chatKeys.conversations(user?.id || '') })
  }, [queryClient, user?.id])

  return {
    // Auth
    user,
    isAdmin,

    // View state
    view,
    selectedPartner,

    // Form state
    newMessage: messagesData.newMessage,
    setNewMessage: messagesData.setNewMessage,
    searchQuery: conversationsData.searchQuery,
    setSearchQuery: conversationsData.setSearchQuery,

    // Tab state
    activeTab: conversationsData.activeTab,
    setActiveTab: conversationsData.setActiveTab,
    ignoredCount: conversationsData.ignoredCount,

    // Data
    messages: messagesData.messages,
    conversations: conversationsData.conversations,

    // Pagination
    pagination: {
      conversations: conversationsData.pagination,
    },

    // Infinite scroll for messages
    hasMoreMessages: messagesData.hasMoreMessages,
    loadMoreMessages: messagesData.loadMoreMessages,
    isLoadingMoreMessages: messagesData.isLoadingMoreMessages,

    // Loading states
    loading,
    sending: messagesData.isSending,

    // Error state
    sendError: messagesData.sendError,
    clearSendError: messagesData.clearSendError,

    // Handlers
    handleSendMessage: messagesData.handleSendMessage,
    openConversation,
    startNewChat,
    backToList,
  }
}
