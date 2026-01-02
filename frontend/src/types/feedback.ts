/**
 * Chat/messaging related types
 */

// Storage bucket name
export const STORAGE_BUCKET = 'feedback-attachments'

/**
 * Chat message type
 */
export interface ChatMessage {
  id: string
  user_id: string
  recipient_id: string
  content: string
  is_read: boolean
  created_at: string
  sender_username?: string
  sender_avatar?: string | null
}

/**
 * Conversation with another user (from get_user_conversations function)
 */
export interface UserConversation {
  conversation_partner_id: string
  partner_username: string
  partner_avatar: string | null
  partner_avatar_path: string | null
  last_message: string
  last_message_at: string
  last_message_is_from_me: boolean
  unread_count: number
}

export type ChatView = 'conversations' | 'chat'

/**
 * Raw conversation message from get_conversation_messages function
 */
export interface RawConversationMessage {
  id: string
  user_id: string
  recipient_id: string
  content: string
  is_read: boolean
  created_at: string
  sender_username: string
  sender_avatar: string | null
}
