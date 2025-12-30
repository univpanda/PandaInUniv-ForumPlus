import { MessageSquare, Search, UserX } from 'lucide-react'
import { formatTime, getAvatarUrl } from '../../utils/format'
import type { UserConversation } from '../../types'
import type { ChatTab } from '../../hooks/useChatConversations'
import { LoadingSpinner, EmptyState, SearchInput } from '../ui'

interface ChatConversationListProps {
  conversations: UserConversation[]
  loading: boolean
  onOpenConversation: (conversation: UserConversation) => void
  searchQuery: string
  onSearchChange: (query: string) => void
  activeTab: ChatTab
  onTabChange: (tab: ChatTab) => void
  ignoredCount: number
  // Admin page size control
  isAdmin?: boolean
  pageSizeInput?: string
  onPageSizeInputChange?: (value: string) => void
  onPageSizeBlur?: () => void
}

export function ChatConversationList({
  conversations,
  loading,
  onOpenConversation,
  searchQuery,
  onSearchChange,
  activeTab,
  onTabChange,
  ignoredCount,
  isAdmin,
  pageSizeInput,
  onPageSizeInputChange,
  onPageSizeBlur,
}: ChatConversationListProps) {
  return (
    <>
      <div className="chat-header">
        <div className="chat-tabs">
          <button
            className={`chat-tab ${activeTab === 'conversations' ? 'active' : ''}`}
            onClick={() => onTabChange('conversations')}
          >
            Whispers
          </button>
          <button
            className={`chat-tab ${activeTab === 'ignored' ? 'active' : ''}`}
            onClick={() => onTabChange('ignored')}
          >
            Shushed {ignoredCount > 0 && <span className="chat-tab-count">{ignoredCount}</span>}
          </button>
        </div>
        <SearchInput
          value={searchQuery}
          onChange={onSearchChange}
          placeholder={activeTab === 'ignored' ? 'Forage shushed...' : 'Forage whispers...'}
          className="chat-search"
          showHelp
        />
        {isAdmin && onPageSizeInputChange && onPageSizeBlur && (
          <input
            type="number"
            min="1"
            max="500"
            className="page-size-input"
            value={pageSizeInput}
            onChange={(e) => onPageSizeInputChange(e.target.value)}
            onBlur={onPageSizeBlur}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                onPageSizeBlur()
                e.currentTarget.blur()
              }
            }}
            title="Whispers per page"
          />
        )}
      </div>

      {loading ? (
        <LoadingSpinner className="chat-loading" />
      ) : conversations.length === 0 ? (
        searchQuery.trim() ? (
          <EmptyState
            icon={Search}
            description={activeTab === 'ignored' ? 'No shushed pandas match your search.' : 'No whispers match your search.'}
            className="chat-empty"
          />
        ) : activeTab === 'ignored' ? (
          <EmptyState
            icon={UserX}
            description="No shushed pandas."
            className="chat-empty"
          />
        ) : (
          <EmptyState
            icon={MessageSquare}
            description="No whispers yet. Start chatting from the Grove!"
            className="chat-empty"
          />
        )
      ) : (
        <div className="chat-conversations">
          {conversations.map((conv) => (
            <button
              key={conv.conversation_partner_id}
              className="chat-conversation-item"
              onClick={() => onOpenConversation(conv)}
            >
              <div className="chat-conv-avatar">
                <img src={getAvatarUrl(conv.partner_avatar, conv.partner_username)} alt="" />
              </div>
              <div className="chat-conv-content">
                <div className="chat-conv-header">
                  <span className="chat-conv-name">{conv.partner_username}</span>
                  <span className="chat-conv-time">{formatTime(conv.last_message_at)}</span>
                </div>
                <p className="chat-conv-preview">
                  {conv.last_message_is_from_me && (
                    <span className="chat-conv-you">You: </span>
                  )}
                  {conv.last_message}
                </p>
              </div>
              {conv.unread_count > 0 && (
                <span className="chat-unread-badge">{conv.unread_count}</span>
              )}
            </button>
          ))}
        </div>
      )}
    </>
  )
}
