export interface Notification {
  id: number
  post_id: number
  thread_id: number
  thread_title: string
  post_content: string
  post_parent_id: number | null
  reply_count: number
  upvotes: number
  downvotes: number
  created_at: string
  updated_at: string
  total_count: number
}
