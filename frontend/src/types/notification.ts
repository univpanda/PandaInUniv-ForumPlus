export interface Notification {
  id: number
  post_id: number
  thread_id: number
  thread_title: string
  post_content: string
  post_parent_id: number | null
  post_author_id: string
  post_author_name: string
  post_author_avatar: string | null
  post_author_avatar_path: string | null
  post_created_at: string
  post_likes: number
  post_dislikes: number
  post_reply_count: number
  // Delta counts - new activity since last dismissal
  new_reply_count: number
  new_upvotes: number
  new_downvotes: number
  created_at: string
  updated_at: string
  total_count: number
}
