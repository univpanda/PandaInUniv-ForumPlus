import { formatDistanceToNow, parseISO } from 'date-fns'
import { EDIT_WINDOW_MINUTES, MS_PER_MINUTE } from './constants'

// Relative time like "2 hours ago" - used for posts/comments
// Shows seconds for recent times (e.g., "10 seconds ago") instead of "less than a minute ago"
export const formatDateRelative = (dateStr: string) => {
  try {
    const date = parseISO(dateStr)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffSeconds = Math.floor(diffMs / 1000)

    // For times under 60 seconds, show seconds
    if (diffSeconds < 60) {
      if (diffSeconds < 5) return 'just now'
      return `${diffSeconds} seconds ago`
    }

    // For everything else, use date-fns and remove "about" prefix
    const result = formatDistanceToNow(date, { addSuffix: true })
    return result.replace(/^about /, '')
  } catch {
    return dateStr
  }
}

// Keep old name as alias for backward compatibility
export const formatDate = formatDateRelative

// Absolute date like "Dec 22, 2025" - used for join dates, etc.
export const formatDateAbsolute = (dateStr: string | null): string => {
  if (!dateStr) return 'Never'
  return new Date(dateStr).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

// Absolute date with time like "Dec 22, 2025 at 3:45 PM" - used for original posts
export const formatDateTimeAbsolute = (dateStr: string | null): string => {
  if (!dateStr) return 'Never'
  const date = new Date(dateStr)
  const datePart = date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
  const timePart = date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
  })
  return `${datePart} at ${timePart}`
}

// Compact relative time like "10s", "5m", "2h", "3d", "2mo", "1y" - used for thread list, last login
export const formatRelativeTime = (dateStr: string | null): string => {
  if (!dateStr) return 'Never'
  const date = new Date(dateStr)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffSeconds = Math.floor(diffMs / 1000)
  const diffMins = Math.floor(diffMs / 60000)
  const diffHours = Math.floor(diffMs / 3600000)
  const diffDays = Math.floor(diffMs / 86400000)
  const diffMonths = Math.floor(diffDays / 30)
  const diffYears = Math.floor(diffDays / 365)

  if (diffSeconds < 5) return 'now'
  if (diffSeconds < 60) return `${diffSeconds}s`
  if (diffMins < 60) return `${diffMins}m`
  if (diffHours < 24) return `${diffHours}h`
  if (diffDays < 30) return `${diffDays}d`
  if (diffMonths < 12) return `${diffMonths}mo`
  return `${diffYears}y`
}

// Time with seconds like "3:45:22 PM" - used for messages
export const formatTime = (dateStr: string): string => {
  const date = new Date(dateStr)
  return date.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', second: '2-digit' })
}

// Date label like "Today", "Yesterday", "Monday" - used for message separators
export const formatDateLabel = (dateStr: string): string => {
  const date = new Date(dateStr)
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const messageDate = new Date(date.getFullYear(), date.getMonth(), date.getDate())
  const diffDays = Math.floor((today.getTime() - messageDate.getTime()) / 86400000)

  if (diffDays === 0) return 'Today'
  if (diffDays === 1) return 'Yesterday'
  if (diffDays < 7) return date.toLocaleDateString('en-US', { weekday: 'long' })
  return date.toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })
}

// Date key for grouping like "2025-11-22" - used for message grouping
export const getDateKey = (dateStr: string): string => {
  const date = new Date(dateStr)
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

// Allowed avatar URL domains to prevent XSS via malicious URLs
const ALLOWED_AVATAR_DOMAINS = [
  'lh3.googleusercontent.com', // Google profile pictures
  'avatars.githubusercontent.com', // GitHub avatars
  'ui-avatars.com', // Fallback avatar service
]

const isAllowedAvatarUrl = (url: string): boolean => {
  try {
    const parsed = new URL(url)
    return ALLOWED_AVATAR_DOMAINS.some(
      (domain) => parsed.hostname === domain || parsed.hostname.endsWith('.' + domain)
    )
  } catch {
    return false
  }
}

// Generate a deterministic color based on the username
const getAvatarColor = (name: string): string => {
  let hash = 0
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash)
  }
  // Convert to a hex color (without #)
  const color = Math.abs(hash).toString(16).slice(0, 6).padStart(6, '0')
  return color
}

const fallbackAvatar = (name: string) =>
  `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=${getAvatarColor(name)}&color=fff`

export const getAvatarUrl = (avatar: string | null, name: string) => {
  if (!avatar) return fallbackAvatar(name)
  return isAllowedAvatarUrl(avatar) ? avatar : fallbackAvatar(name)
}

// Check if a post can be edited (within EDIT_WINDOW_MINUTES of creation)
export const canEditContent = (createdAt: string): boolean => {
  const created = new Date(createdAt)
  const now = new Date()
  const diffMinutes = (now.getTime() - created.getTime()) / MS_PER_MINUTE
  return diffMinutes <= EDIT_WINDOW_MINUTES
}

// --- Additional Comments Parsing ---

// Parse additional comments string into array of { timestamp, text }
// Format: [ISO_TIMESTAMP]comment text\n[ISO_TIMESTAMP]comment text
export interface ParsedComment {
  timestamp: string
  text: string
}

export const parseAdditionalComments = (comments: string | null): ParsedComment[] => {
  if (!comments) return []

  const result: ParsedComment[] = []
  const lines = comments.split('\n')

  for (const line of lines) {
    // Match [ISO_TIMESTAMP]text pattern - supports with or without milliseconds
    // Examples: [2025-12-25T10:30:45Z] or [2025-12-25T10:30:45.123Z]
    const match = line.match(/^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z)\](.*)$/)
    if (match) {
      result.push({ timestamp: match[1], text: match[2] })
    } else if (line.trim()) {
      // Legacy format without timestamp - use empty timestamp
      result.push({ timestamp: '', text: line })
    }
  }

  return result
}

// --- Array Toggle Utilities ---

// Toggle an item in an array (add if not present, remove if present)
export const toggleArrayItem = <T>(arr: T[], item: T): T[] =>
  arr.includes(item) ? arr.filter((i) => i !== item) : [...arr, item]
