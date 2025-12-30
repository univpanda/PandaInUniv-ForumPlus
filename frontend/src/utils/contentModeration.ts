// List of inappropriate words/patterns to flag
// This is a basic list - expand as needed
const FLAGGED_PATTERNS = [
  // Profanity (common variations)
  /\b(f+u+c+k+|f+[*@#$%]ck|fuk|fck)\b/i,
  /\b(s+h+i+t+|sh[*@#$%]t|sht)\b/i,
  /\b(a+s+s+h+o+l+e+|a+s+s+)\b/i,
  /\b(b+i+t+c+h+|b[*@#$%]tch)\b/i,
  /\b(d+a+m+n+)\b/i,
  /\b(c+u+n+t+)\b/i,
  /\b(d+i+c+k+|d[*@#$%]ck)\b/i,
  /\b(p+u+s+s+y+)\b/i,
  /\b(c+o+c+k+)\b/i,
  /\b(w+h+o+r+e+)\b/i,
  /\b(s+l+u+t+)\b/i,

  // Slurs (abbreviated patterns)
  /\b(n+[i1]+g+[g4]+[e3a]+r*|n[*@#$%]gg[*@#$%]r)\b/i,
  /\b(f+[a4]+g+[o0]+t*|f[*@#$%]gg[*@#$%]t)\b/i,
  /\b(r+[e3]+t+[a4]+r+d+)\b/i,

  // Threats/violence
  /\b(kill\s+(you|yourself|him|her|them))\b/i,
  /\b(i('ll|will)\s+murder)\b/i,
  /\b(death\s+threat)\b/i,

  // Spam patterns
  /\b(buy\s+now|click\s+here|free\s+money)\b/i,
  /(https?:\/\/[^\s]+){3,}/i, // Multiple URLs

  // All caps screaming (more than 50 chars)
  /[A-Z\s!]{50,}/,
]

// Words that might be false positives - for context
const CONTEXT_WORDS = [
  'assessment',
  'class',
  'assume',
  'bass',
  'pass',
  'mass',
  'assistance',
  'associate',
  'assassin',
  'cockpit',
  'cocktail',
  'peacock',
  'hancock',
  'scunthorpe',
  'dickens',
  'dickerson',
]

/**
 * Check if content contains inappropriate words
 * @returns Object with flagged status and matched patterns
 */
export function checkContent(content: string): {
  isFlagged: boolean
  reasons: string[]
} {
  const reasons: string[] = []
  const lowerContent = content.toLowerCase()

  // Skip if content matches known false positive patterns
  const hasFalsePositive = CONTEXT_WORDS.some((word) => lowerContent.includes(word.toLowerCase()))

  for (const pattern of FLAGGED_PATTERNS) {
    if (pattern.test(content)) {
      // Check if it might be a false positive
      const match = content.match(pattern)
      if (match && hasFalsePositive) {
        // Do more specific check
        const matchedWord = match[0].toLowerCase()
        const isFalsePositive = CONTEXT_WORDS.some(
          (fp) => fp.toLowerCase().includes(matchedWord) || matchedWord.includes(fp.toLowerCase())
        )
        if (isFalsePositive) continue
      }

      reasons.push(getReasonDescription(pattern))
    }
  }

  return {
    isFlagged: reasons.length > 0,
    reasons: [...new Set(reasons)], // Remove duplicates
  }
}

function getReasonDescription(pattern: RegExp): string {
  const source = pattern.source.toLowerCase()

  if (source.includes('kill') || source.includes('murder') || source.includes('threat')) {
    return 'Potential threat/violence'
  }
  if (source.includes('buy') || source.includes('click') || source.includes('https')) {
    return 'Potential spam'
  }
  if (source.includes('[a-z')) {
    return 'Excessive caps'
  }
  return 'Inappropriate language'
}

/**
 * Check both title and content for a new thread
 */
export function checkThreadContent(
  title: string,
  content: string
): {
  isFlagged: boolean
  reasons: string[]
} {
  const titleCheck = checkContent(title)
  const contentCheck = checkContent(content)

  return {
    isFlagged: titleCheck.isFlagged || contentCheck.isFlagged,
    reasons: [...new Set([...titleCheck.reasons, ...contentCheck.reasons])],
  }
}
