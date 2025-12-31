import { MessageCircle, FileText, EyeOff, UserX, UserCheck } from 'lucide-react'
import happyPanda from '../../assets/webp/happy-panda.webp'
import sadPanda from '../../assets/webp/sad-panda.webp'
import { ChatMessageList } from './ChatMessageList'
import { ChatInput } from './ChatInput'
import { usePublicUserStats, useIsUserIgnored, useToggleIgnore } from '../../hooks'
import { getAvatarUrl } from '../../utils/format'
import type { ChatMessage } from '../../types'

interface ChatConversationProps {
  partner: {
    id: string
    username: string
    avatar: string | null
  }
  messages: ChatMessage[]
  loading: boolean
  currentUserId: string
  newMessage: string
  sending: boolean
  onBack: () => void
  onMessageChange: (value: string) => void
  onSend: () => void
  hasMoreMessages?: boolean
  onLoadMoreMessages?: () => void
  isLoadingMoreMessages?: boolean
  onIgnoreToggled?: (username: string, isNowIgnored: boolean) => void
}

export function ChatConversation({
  partner,
  messages,
  loading,
  currentUserId,
  newMessage,
  sending,
  onBack,
  onMessageChange,
  onSend,
  hasMoreMessages,
  onLoadMoreMessages,
  isLoadingMoreMessages,
  onIgnoreToggled,
}: ChatConversationProps) {
  const { data: partnerStats } = usePublicUserStats(partner.id)
  const { data: isIgnored } = useIsUserIgnored(currentUserId, partner.id)
  const toggleIgnore = useToggleIgnore(currentUserId)

  const handleToggleIgnore = () => {
    toggleIgnore.mutate(partner.id, {
      onSuccess: (isNowIgnored) => {
        onIgnoreToggled?.(partner.username, isNowIgnored)
      },
    })
  }

  return (
    <div className="chat-conversation">
      {/* Header */}
      <div className="chat-conv-header-bar">
        <div className="chat-partner-info">
          <button className="chat-partner-back" onClick={onBack} title="Back to whispers">
            <div className="chat-partner-avatar">
              <img src={getAvatarUrl(partner.avatar, partner.username)} alt="" />
            </div>
            <span className="chat-partner-name">{partner.username}</span>
          </button>
          <button
            className={`chat-ignore-btn ${isIgnored ? 'ignored' : ''}`}
            onClick={handleToggleIgnore}
            disabled={toggleIgnore.isPending}
            title={isIgnored ? 'Unignore user' : 'Ignore user'}
          >
            {isIgnored ? <UserCheck size={18} /> : <UserX size={18} />}
          </button>
        </div>
        {partnerStats?.isPrivate ? (
          <div className="chat-partner-private">
            <EyeOff size={14} />
            <span>Profile is private</span>
          </div>
        ) : partnerStats ? (
          <div className="chat-partner-stats">
            <button
              className="chat-stat chat-stat-link"
              onClick={() => {
                window.dispatchEvent(new CustomEvent('searchDiscussion', {
                  detail: { searchQuery: `@${partner.username} @op` }
                }))
              }}
              title={`View ${partner.username}'s threads`}
            >
              <FileText size={14} />
              {partnerStats.threadCount}
            </button>
            <button
              className="chat-stat chat-stat-link"
              onClick={() => {
                window.dispatchEvent(new CustomEvent('searchDiscussion', {
                  detail: { searchQuery: `@${partner.username} @replies` }
                }))
              }}
              title={`View ${partner.username}'s replies`}
            >
              <MessageCircle size={14} />
              {partnerStats.postCount}
            </button>
            <span className="chat-stat chat-stat-upvote">
              <img src={happyPanda} alt="" className="vote-icon-small" />
              {partnerStats.upvotesReceived}
            </span>
            <span className="chat-stat chat-stat-downvote">
              <img src={sadPanda} alt="" className="vote-icon-small" />
              {partnerStats.downvotesReceived}
            </span>
          </div>
        ) : null}
      </div>

      {/* Messages */}
      <ChatMessageList
        messages={messages}
        loading={loading}
        currentUserId={currentUserId}
        partnerAvatar={partner.avatar}
        partnerUsername={partner.username}
        hasMore={hasMoreMessages}
        onLoadMore={onLoadMoreMessages}
        isLoadingMore={isLoadingMoreMessages}
      />

      {/* Input */}
      <ChatInput
        value={newMessage}
        onChange={onMessageChange}
        onSend={onSend}
        sending={sending}
        placeholder={`Message ${partner.username}...`}
      />
    </div>
  )
}
