import { useState, useEffect, useMemo } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useConversations, useIgnoredUsers, chatKeys } from './useChatQueries'
import { supabase } from '../lib/supabase'
import { PAGE_SIZE } from '../utils/constants'
import { parseSearchQuery, matchesAllWords, matchesUsername } from '../utils/search'
import type { ChatView, ChatMessage, RawConversationMessage } from '../types'

export type ChatTab = 'conversations' | 'ignored'

interface PaginationState {
  page: number
  setPage: (page: number) => void
  totalPages: number
  totalCount: number
  pageSize: number
  setPageSize: (size: number) => void
}

interface MessagesPage {
  messages: ChatMessage[]
  nextCursor: string | null
  hasMore: boolean
}

// Persist page size to localStorage (admin only)
const CHAT_PAGE_SIZE_KEY = 'chat.pageSize'

function getStoredPageSize(): number {
  try {
    const stored = localStorage.getItem(CHAT_PAGE_SIZE_KEY)
    if (stored) {
      const parsed = parseInt(stored, 10)
      if (!isNaN(parsed) && parsed >= 1 && parsed <= 500) {
        return parsed
      }
    }
  } catch {
    // localStorage not available
  }
  return PAGE_SIZE.POSTS
}

interface UseChatConversationsProps {
  userId: string | null
  view: ChatView
  isAdmin: boolean
}

interface UseChatConversationsReturn {
  // Query
  conversationsQuery: ReturnType<typeof useConversations>

  // Tab state
  activeTab: ChatTab
  setActiveTab: (tab: ChatTab) => void
  ignoredCount: number

  // Search
  searchQuery: string
  setSearchQuery: (query: string) => void

  // Paginated data
  conversations: NonNullable<ReturnType<typeof useConversations>['data']>
  pagination: PaginationState
}

export function useChatConversations({
  userId,
  view,
  isAdmin,
}: UseChatConversationsProps): UseChatConversationsReturn {
  // Tab state
  const [activeTab, setActiveTab] = useState<ChatTab>('conversations')

  // Search state
  const [searchQuery, setSearchQuery] = useState('')

  // Pagination state - only admins can use stored page size
  const [conversationsPage, setConversationsPage] = useState(1)
  const initialPageSize = isAdmin ? getStoredPageSize() : PAGE_SIZE.POSTS
  const [pageSize, setPageSize] = useState(initialPageSize)
  const queryClient = useQueryClient()

  // Query
  const conversationsQuery = useConversations(userId, {
    enabled: view === 'conversations',
  })

  // Get ignored users
  const { data: ignoredUsers } = useIgnoredUsers(userId)

  const ignoredUsersSet = useMemo(
    () => new Set(ignoredUsers || []),
    [ignoredUsers]
  )

  const allConversations = useMemo(
    () => conversationsQuery.data ?? [],
    [conversationsQuery.data]
  )

  useEffect(() => {
    if (!userId || view !== 'conversations') return
    if (!conversationsQuery.data || conversationsQuery.data.length === 0) return

    const topConversations = conversationsQuery.data.slice(0, 5)

    const prefetchMessages = async (partnerId: string) => {
      const queryKey = chatKeys.messagesInfinite(userId, partnerId)
      const prefetchKey = chatKeys.messagesPrefetch(userId, partnerId)
      const existing = queryClient.getQueryData(queryKey)
      if (existing) return

      const { data, error } = await supabase.rpc('get_conversation_messages', {
        p_user_id: userId,
        p_partner_id: partnerId,
        p_limit: 50,
        p_before_cursor: null,
      })

      if (error) return

      const rawMessages = (data || []) as RawConversationMessage[]
      const messages = rawMessages.map((msg) => ({
        id: msg.id,
        user_id: msg.user_id,
        recipient_id: msg.recipient_id,
        content: msg.content,
        is_read: msg.is_read,
        created_at: msg.created_at,
        sender_username: msg.sender_username,
        sender_avatar: msg.sender_avatar,
      }))

      if (messages.length === 0) return

      const firstPageMessages = messages.slice(0, PAGE_SIZE.POSTS)
      const remaining = messages.slice(PAGE_SIZE.POSTS)
      const nextCursor = firstPageMessages[firstPageMessages.length - 1]?.created_at ?? null
      const assumeMore = messages.length === 50

      const pages: MessagesPage[] = [
        {
          messages: firstPageMessages,
          nextCursor,
          hasMore: remaining.length > 0 || assumeMore,
        },
      ]

      queryClient.setQueryData(queryKey, {
        pages,
        pageParams: [null],
      })

      if (remaining.length > 0) {
        queryClient.setQueryData(prefetchKey, { messages: remaining, assumeMore })
      }
    }

    for (const convo of topConversations) {
      if (!convo?.conversation_partner_id) continue
      void prefetchMessages(convo.conversation_partner_id)
    }
  }, [conversationsQuery.data, queryClient, userId, view])

  // Split conversations into ignored and non-ignored
  const { nonIgnoredConversations, ignoredConversations } = useMemo(() => {
    if (!ignoredUsersSet || ignoredUsersSet.size === 0) {
      return { nonIgnoredConversations: allConversations, ignoredConversations: [] }
    }
    const nonIgnored: typeof allConversations = []
    const ignored: typeof allConversations = []
    for (const conv of allConversations) {
      if (ignoredUsersSet.has(conv.conversation_partner_id)) {
        ignored.push(conv)
      } else {
        nonIgnored.push(conv)
      }
    }
    return { nonIgnoredConversations: nonIgnored, ignoredConversations: ignored }
  }, [allConversations, ignoredUsersSet])

  // Select base list based on active tab
  const baseConversations = activeTab === 'ignored' ? ignoredConversations : nonIgnoredConversations

  // Filter conversations by search query (username or message content)
  const filteredConversations = useMemo(() => {
    if (!searchQuery.trim()) return baseConversations

    const { authorUsername, searchTerms } = parseSearchQuery(searchQuery)

    return baseConversations.filter((conv) => {
      // If @username filter, require username match
      if (authorUsername) {
        if (!matchesUsername(conv.partner_username, authorUsername)) return false
        // If no additional text, username match is enough
        if (searchTerms.length === 0) return true
        // Otherwise require text match too
        return matchesAllWords(conv.last_message, searchTerms)
      }

      // Regular search: match username or all terms in message
      const usernameMatch = matchesUsername(conv.partner_username, searchQuery.toLowerCase())
      const messageMatch = matchesAllWords(conv.last_message, searchTerms)
      return usernameMatch || messageMatch
    })
  }, [baseConversations, searchQuery])

  // Client-side pagination for filtered conversations
  const conversationsTotalCount = filteredConversations.length
  const conversationsTotalPages = Math.ceil(conversationsTotalCount / pageSize)

  const conversations = useMemo(() => {
    const startIdx = (conversationsPage - 1) * pageSize
    const endIdx = startIdx + pageSize
    return filteredConversations.slice(startIdx, endIdx)
  }, [filteredConversations, conversationsPage, pageSize])

  // Reset pagination when search query or tab changes
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setConversationsPage(1)
  }, [searchQuery, activeTab])

  // Reset pagination when entering conversations view
  useEffect(() => {
    if (view === 'conversations') {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setConversationsPage(1)
    }
  }, [view])

  // Reset pagination when page size changes
  const handleSetPageSize = (newSize: number) => {
    setPageSize(newSize)
    setConversationsPage(1)
  }

  return {
    conversationsQuery,
    activeTab,
    setActiveTab,
    ignoredCount: ignoredConversations.length,
    searchQuery,
    setSearchQuery,
    conversations,
    pagination: {
      page: conversationsPage,
      setPage: setConversationsPage,
      totalPages: conversationsTotalPages,
      totalCount: conversationsTotalCount,
      pageSize,
      setPageSize: handleSetPageSize,
    },
  }
}

export type { PaginationState }
