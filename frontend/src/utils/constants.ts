// Time constants in milliseconds
export const MS_PER_SECOND = 1000
export const MS_PER_MINUTE = 60 * MS_PER_SECOND
export const MS_PER_HOUR = 60 * MS_PER_MINUTE
export const MS_PER_DAY = 24 * MS_PER_HOUR

// Query stale times
export const STALE_TIME = {
  SHORT: 30 * MS_PER_SECOND, // 30 seconds - for frequently changing data
  MEDIUM: 2 * MS_PER_MINUTE, // 2 minutes - for moderately changing data
  LONG: 5 * MS_PER_MINUTE, // 5 minutes - for rarely changing data
  VERY_LONG: 10 * MS_PER_MINUTE, // 10 minutes - for settings/config
  HOUR: MS_PER_HOUR, // 1 hour - for stats/analytics
} as const

// Polling intervals
export const POLL_INTERVAL = {
  NOTIFICATIONS: 30 * MS_PER_SECOND, // 30 seconds
} as const

// Toast/notification durations
export const TOAST_DURATION = {
  SUCCESS: 3 * MS_PER_SECOND, // 3 seconds
  ERROR: 5 * MS_PER_SECOND, // 5 seconds
} as const

// Animation/highlight durations
export const ANIMATION_DURATION = {
  HIGHLIGHT: 2 * MS_PER_SECOND, // 2 seconds for post highlight
} as const

// Edit window duration (how long users can edit their posts)
export const EDIT_WINDOW_MINUTES = 15

// File size constants
export const BYTES_PER_KB = 1024
export const BYTES_PER_MB = BYTES_PER_KB * 1024

// Retry configuration
export const RETRY_CONFIG = {
  MIN_DELAY: 2 * MS_PER_SECOND,
  MAX_DELAY: 30 * MS_PER_SECOND,
} as const

// Pagination defaults (can be overridden by admin settings)
export const PAGE_SIZE = {
  THREADS: 20, // Forum threads per page
  POSTS: 20, // Posts/replies per page
  USERS: 50, // Users in admin panel per page
} as const

// Content length limits
export const CONTENT_LIMITS = {
  THREAD_TITLE_MIN: 3,
  THREAD_TITLE_MAX: 200,
  POST_CONTENT_MIN: 1,
  POST_CONTENT_MAX: 50000, // 50K characters
  POLL_OPTION_MAX: 200,
} as const

// Extension to MIME type mapping for file uploads
export const EXT_TO_MIME: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.pdf': 'application/pdf',
  '.txt': 'text/plain',
  '.doc': 'application/msword',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
}
