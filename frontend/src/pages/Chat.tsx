import { useState, useEffect, useCallback } from 'react'
import { useChatPageState } from '../hooks/useChatPageState'
import { useToast } from '../contexts/ToastContext'
import { Pagination } from '../components/Pagination'
import { AlertBanner } from '../components/ui'
import { ChatConversationList, ChatConversation } from '../components/chat'

interface ChatProps {
  initialPartner?: { id: string; username: string | null; avatar: string | null; avatarPath?: string | null } | null
  onInitialPartnerConsumed?: () => void
  resetToList?: number
}

// Persist page size to localStorage (admin only)
const CHAT_PAGE_SIZE_KEY = 'chat.pageSize'

export function Chat({ initialPartner, onInitialPartnerConsumed, resetToList }: ChatProps) {
  // Page size input is controlled locally, actual page size comes from hook
  const [pageSizeInput, setPageSizeInput] = useState<string>('')

  const {
    user,
    isAdmin,
    view,
    selectedPartner,
    newMessage,
    setNewMessage,
    searchQuery,
    setSearchQuery,
    activeTab,
    setActiveTab,
    ignoredCount,
    messages,
    conversations,
    pagination,
    hasMoreMessages,
    loadMoreMessages,
    isLoadingMoreMessages,
    loading,
    sending,
    sendError,
    clearSendError,
    handleSendMessage,
    openConversation,
    startNewChat,
  } = useChatPageState({ resetToList })

  // Sync pageSizeInput with the actual page size from hook
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setPageSizeInput(String(pagination.conversations.pageSize))
  }, [pagination.conversations.pageSize])

  const handlePageSizeBlur = () => {
    const val = parseInt(pageSizeInput, 10)
    if (!isNaN(val) && val >= 1 && val <= 500) {
      if (val !== pagination.conversations.pageSize) {
        pagination.conversations.setPageSize(val)
        // Persist to localStorage
        try {
          localStorage.setItem(CHAT_PAGE_SIZE_KEY, String(val))
        } catch {
          // localStorage not available
        }
      }
    } else {
      // Reset input to current valid value
      setPageSizeInput(String(pagination.conversations.pageSize))
    }
  }

  const toast = useToast()

  const handleIgnoreToggled = useCallback((username: string, isNowIgnored: boolean) => {
    if (isNowIgnored) {
      toast.showSuccess(`${username} has been shushed`)
    } else {
      toast.showSuccess(`${username} has been unshushed`)
    }
  }, [toast])

  // Handle initial partner from Discussion username hover
  useEffect(() => {
    if (initialPartner && user) {
      startNewChat(initialPartner.id, initialPartner.username, initialPartner.avatar, initialPartner.avatarPath)
      onInitialPartnerConsumed?.()
    }
  }, [initialPartner, user, startNewChat, onInitialPartnerConsumed])

  // Not logged in
  if (!user) {
    return (
      <div className="chat-container">
        <div className="chat-sign-in-prompt">
          Please sign in to use chat.
        </div>
      </div>
    )
  }

  // Conversation list view
  if (view === 'conversations') {
    return (
      <div className="chat-container">
        <div className="chat-list-header">
          <ChatConversationList
            conversations={conversations}
            loading={loading}
            onOpenConversation={openConversation}
            searchQuery={searchQuery}
            onSearchChange={setSearchQuery}
            activeTab={activeTab}
            onTabChange={setActiveTab}
            ignoredCount={ignoredCount}
            isAdmin={isAdmin}
            pageSizeInput={pageSizeInput}
            onPageSizeInputChange={setPageSizeInput}
            onPageSizeBlur={handlePageSizeBlur}
          />
        </div>
        {pagination.conversations.totalPages > 1 && (
          <Pagination
            currentPage={pagination.conversations.page}
            totalPages={pagination.conversations.totalPages}
            onPageChange={pagination.conversations.setPage}
            totalItems={pagination.conversations.totalCount}
            itemsPerPage={pagination.conversations.pageSize}
            itemName="conversations"
          />
        )}
      </div>
    )
  }

  // Chat view
  if (view === 'chat' && selectedPartner) {
    return (
      <div className="chat-container">
        {sendError && (
          <AlertBanner
            message={sendError}
            type="error"
            onDismiss={clearSendError}
            className="chat-toast"
          />
        )}
        <ChatConversation
          partner={selectedPartner}
          messages={messages}
          loading={loading}
          currentUserId={user.id}
          newMessage={newMessage}
          sending={sending}
          onMessageChange={setNewMessage}
          onSend={handleSendMessage}
          hasMoreMessages={hasMoreMessages}
          onLoadMoreMessages={() => loadMoreMessages()}
          isLoadingMoreMessages={isLoadingMoreMessages}
          onIgnoreToggled={handleIgnoreToggled}
        />
      </div>
    )
  }

  return null
}
