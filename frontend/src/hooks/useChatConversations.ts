import { useState, useEffect, useMemo } from 'react'
import { useConversations, useIgnoredUsers } from './useChatQueries'
import { PAGE_SIZE } from '../utils/constants'
import { parseSearchQuery, matchesAllWords, matchesUsername } from '../utils/search'
import type { ChatView } from '../types'

export type ChatTab = 'conversations' | 'ignored'

interface PaginationState {
  page: number
  setPage: (page: number) => void
  totalPages: number
  totalCount: number
  pageSize: number
  setPageSize: (size: number) => void
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

  // Query
  const conversationsQuery = useConversations(userId, {
    enabled: view === 'conversations',
  })

  // Get ignored users
  const { data: ignoredUsers } = useIgnoredUsers(userId)

  const allConversations = useMemo(
    () => conversationsQuery.data ?? [],
    [conversationsQuery.data]
  )

  // Split conversations into ignored and non-ignored
  const { nonIgnoredConversations, ignoredConversations } = useMemo(() => {
    if (!ignoredUsers || ignoredUsers.size === 0) {
      return { nonIgnoredConversations: allConversations, ignoredConversations: [] }
    }
    const nonIgnored: typeof allConversations = []
    const ignored: typeof allConversations = []
    for (const conv of allConversations) {
      if (ignoredUsers.has(conv.conversation_partner_id)) {
        ignored.push(conv)
      } else {
        nonIgnored.push(conv)
      }
    }
    return { nonIgnoredConversations: nonIgnored, ignoredConversations: ignored }
  }, [allConversations, ignoredUsers])

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
