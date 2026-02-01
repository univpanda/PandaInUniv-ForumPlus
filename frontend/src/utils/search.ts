/**
 * Shared search utilities for Discussion and Chat
 */

export interface ParsedSearchQuery {
  authorUsername: string | null
  searchTerms: string[] // Can be words or quoted phrases
  rawSearchText: string | null
  isBookmarked: boolean // @bookmarked filter
  isDeleted: boolean // @deleted filter (admin only)
  isFlagged: boolean // @flagged filter (admin only)
  postType: 'all' | 'op' | 'replies' // @op = thread OPs only, @replies = replies only
}

/**
 * Extract search terms from text, handling quoted phrases
 * "hello world" foo bar -> ["hello world", "foo", "bar"]
 * Handles unclosed quotes gracefully: "cute panda -> ["cute panda"]
 */
function extractSearchTerms(text: string): string[] {
  // Count quotes - if odd number, add closing quote at end
  const quoteCount = (text.match(/"/g) || []).length
  let processedText = text
  if (quoteCount % 2 === 1) {
    processedText = text + '"'
  }

  const terms: string[] = []
  // Match: "quoted phrase" OR regular word
  const regex = /"([^"]*)"|(\S+)/g
  let match

  while ((match = regex.exec(processedText)) !== null) {
    // match[1] = quoted phrase content, match[2] = unquoted word
    const term = match[1] !== undefined ? match[1] : match[2]

    if (term && term.trim()) {
      terms.push(term.toLowerCase().trim())
    }
  }

  return terms
}

// Base result with all flags false
const emptyResult: ParsedSearchQuery = {
  authorUsername: null,
  searchTerms: [],
  rawSearchText: null,
  isBookmarked: false,
  isDeleted: false,
  isFlagged: false,
  postType: 'all',
}

// Special keywords that trigger filters (without username prefix)
const SPECIAL_KEYWORDS = ['bookmarked', 'deleted', 'flagged'] as const

// Post type keywords (can be combined with @username)
const POST_TYPE_KEYWORDS = ['op', 'replies'] as const

/**
 * Parse a search query string into structured components
 * Supports:
 * - word1 word2 — finds all words (anywhere in text)
 * - "exact phrase" — finds exact phrase
 * - @user — filter by author/username (all posts)
 * - @user @op — thread OPs by user only
 * - @user @replies — replies by user only
 * - @user text1 text2 — author + text search
 * - @user @op text — thread OPs by user + text search
 * - @user @deleted — deleted posts by user (admin only)
 * - @user @flagged — flagged posts by user (admin only)
 * - @bookmarked — show bookmarked posts
 * - @bookmarked text1 text2 — bookmarked + text search
 * - @deleted — show deleted posts (admin only)
 * - @flagged — show flagged posts (admin only)
 * - @op — show all thread OPs
 * - @replies — show all replies
 */
export function parseSearchQuery(query: string): ParsedSearchQuery {
  const trimmed = query.trim()

  if (!trimmed) {
    return { ...emptyResult }
  }

  const lowerTrimmed = trimmed.toLowerCase()

  // Check for standalone filters (@bookmarked, @deleted, @flagged, @op, @replies)
  // These can be combined: @op @deleted, @deleted @replies, etc.
  const startsWithFilter =
    SPECIAL_KEYWORDS.some(k => lowerTrimmed.startsWith(`@${k}`)) ||
    POST_TYPE_KEYWORDS.some(k => lowerTrimmed.startsWith(`@${k}`))

  if (startsWithFilter) {
    let isBookmarked = false
    let isDeleted = false
    let isFlagged = false
    let postType: 'all' | 'op' | 'replies' = 'all'
    let remaining = trimmed

    // Parse all @ modifiers at the start
    while (remaining.startsWith('@')) {
      const spaceIndex = remaining.indexOf(' ')
      const modifier = spaceIndex === -1
        ? remaining.slice(1).toLowerCase()
        : remaining.slice(1, spaceIndex).toLowerCase()

      if (modifier === 'bookmarked') {
        isBookmarked = true
        remaining = spaceIndex === -1 ? '' : remaining.slice(spaceIndex + 1).trim()
      } else if (modifier === 'deleted') {
        isDeleted = true
        remaining = spaceIndex === -1 ? '' : remaining.slice(spaceIndex + 1).trim()
      } else if (modifier === 'flagged') {
        isFlagged = true
        remaining = spaceIndex === -1 ? '' : remaining.slice(spaceIndex + 1).trim()
      } else if (modifier === 'op') {
        postType = 'op'
        remaining = spaceIndex === -1 ? '' : remaining.slice(spaceIndex + 1).trim()
      } else if (modifier === 'replies') {
        postType = 'replies'
        remaining = spaceIndex === -1 ? '' : remaining.slice(spaceIndex + 1).trim()
      } else {
        // Unknown modifier - could be a username, break out
        break
      }
    }

    // If we consumed at least one known filter, return the result
    if (isBookmarked || isDeleted || isFlagged || postType !== 'all') {
      const terms = remaining ? extractSearchTerms(remaining) : []
      const searchText = terms.length > 0 ? terms.join(' ') : null

      return {
        ...emptyResult,
        searchTerms: terms,
        rawSearchText: searchText,
        isBookmarked,
        isDeleted,
        isFlagged,
        postType,
      }
    }
  }

  // @username or @username text1 text2... syntax
  if (trimmed.startsWith('@') && trimmed.length > 1) {
    const afterAt = trimmed.slice(1)
    const spaceIndex = afterAt.indexOf(' ')

    if (spaceIndex === -1) {
      // @username only
      return {
        ...emptyResult,
        authorUsername: afterAt.toLowerCase(),
      }
    } else {
      // @username followed by something
      const username = afterAt.slice(0, spaceIndex).toLowerCase()
      const rest = afterAt.slice(spaceIndex + 1).trim()

      // Check for modifier keywords after username
      let isDeleted = false
      let isFlagged = false
      let postType: 'all' | 'op' | 'replies' = 'all'
      let textAfterFlags = rest

      // Parse all @ modifiers after the username
      while (textAfterFlags.startsWith('@')) {
        const nextSpace = textAfterFlags.indexOf(' ')
        const modifier = nextSpace === -1
          ? textAfterFlags.slice(1).toLowerCase()
          : textAfterFlags.slice(1, nextSpace).toLowerCase()

        if (modifier === 'deleted') {
          isDeleted = true
          textAfterFlags = nextSpace === -1 ? '' : textAfterFlags.slice(nextSpace + 1).trim()
        } else if (modifier === 'flagged') {
          isFlagged = true
          textAfterFlags = nextSpace === -1 ? '' : textAfterFlags.slice(nextSpace + 1).trim()
        } else if (modifier === 'op') {
          postType = 'op'
          textAfterFlags = nextSpace === -1 ? '' : textAfterFlags.slice(nextSpace + 1).trim()
        } else if (modifier === 'replies') {
          postType = 'replies'
          textAfterFlags = nextSpace === -1 ? '' : textAfterFlags.slice(nextSpace + 1).trim()
        } else {
          // Unknown modifier, treat as search text
          break
        }
      }

      const terms = textAfterFlags ? extractSearchTerms(textAfterFlags) : []
      const searchText = terms.length > 0 ? terms.join(' ') : null

      return {
        ...emptyResult,
        authorUsername: username,
        searchTerms: terms,
        rawSearchText: searchText,
        isDeleted,
        isFlagged,
        postType,
      }
    }
  }

  // Regular text search - extract terms (words and quoted phrases)
  const terms = extractSearchTerms(trimmed)
  const searchText = terms.length > 0 ? terms.join(' ') : null
  return {
    ...emptyResult,
    searchTerms: terms,
    rawSearchText: searchText,
  }
}

/**
 * Check if text contains all the given terms (words or phrases)
 */
export function matchesAllTerms(text: string, terms: string[]): boolean {
  if (terms.length === 0) return true
  const lowerText = text.toLowerCase()
  return terms.every((term) => lowerText.includes(term))
}

// Alias for backwards compatibility
export const matchesAllWords = matchesAllTerms

/**
 * Check if a username matches the filter
 */
export function matchesUsername(username: string, filter: string): boolean {
  return username.toLowerCase().includes(filter)
}

/**
 * Base search help text (text search only - for non-logged-in users)
 */
export const SEARCH_HELP_TEXT_BASE = `• word1 word2 — finds both words
• "exact phrase" — finds exact phrase`

/**
 * Search help text for logged-in users (includes @ filters)
 */
export const SEARCH_HELP_TEXT_USER = `${SEARCH_HELP_TEXT_BASE}
• @user — all posts by username
• @user @op — thread starters only
• @user @replies — replies only
• @bookmarked — show your bookmarks
• @op — all thread starters
• @replies — all replies`

/**
 * Search help text for admins (includes @deleted and @flagged)
 */
export const SEARCH_HELP_TEXT_ADMIN = `${SEARCH_HELP_TEXT_USER}
• @deleted — deleted posts
• @flagged — flagged posts
• @op @deleted — deleted thread starters
• @user @deleted — deleted posts by user`

/**
 * Get appropriate search help text based on user status
 */
export function getSearchHelpText(isLoggedIn: boolean, isAdmin: boolean): string {
  if (isAdmin) return SEARCH_HELP_TEXT_ADMIN
  if (isLoggedIn) return SEARCH_HELP_TEXT_USER
  return SEARCH_HELP_TEXT_BASE
}

// Legacy exports for backwards compatibility
export const SEARCH_HELP_TEXT = SEARCH_HELP_TEXT_USER
export const DISCUSSION_SEARCH_HELP_TEXT = SEARCH_HELP_TEXT_ADMIN

/**
 * Chat search help text (simple username filter)
 */
export const CHAT_SEARCH_HELP_TEXT = `• Type to filter by username`
