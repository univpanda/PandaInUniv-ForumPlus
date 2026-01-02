// User-related types

// Basic user profile (for display purposes)
export interface UserProfile {
  id: string
  username: string
  avatar_url: string | null
  avatar_path: string | null
  is_private?: boolean
}

// Extended user profile with admin stats (for user management)
export interface UserWithStats {
  id: string
  username: string
  email: string
  full_name: string | null
  avatar_url: string | null
  avatar_path: string | null
  role: string
  is_blocked: boolean
  is_deleted: boolean
  created_at: string
  last_login: string | null
  last_ip: string | null
  last_location: string | null
  thread_count: number
  post_count: number
  deleted_count: number
  flagged_count: number
  upvotes_received: number
  downvotes_received: number
  upvotes_given: number
  downvotes_given: number
}
