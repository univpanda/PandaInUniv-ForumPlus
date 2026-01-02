// Avatar Registry - dynamically scans available avatars from assets folders
// Uses Vite's import.meta.glob to get all available avatar images

// Import all avatars from kawaii and cartoon folders (WebP for performance)
const kawaiiAvatars = import.meta.glob('../assets/webp/kawaii/*.webp', { eager: true, query: '?url', import: 'default' })
const cartoonAvatars = import.meta.glob('../assets/webp/cartoon/*.webp', { eager: true, query: '?url', import: 'default' })

// Extract avatar names from file paths
// e.g., '../assets/webp/kawaii/chef.webp' -> 'Chef'
const extractName = (path: string): string => {
  const filename = path.split('/').pop()?.replace('.webp', '') || ''
  return filename.charAt(0).toUpperCase() + filename.slice(1)
}

// Build registry of available avatars
interface AvatarEntry {
  name: string // e.g., 'Chef', 'Gamer'
  style: 'kawaii' | 'cartoon'
  path: string // e.g., 'kawaii/chef'
  url: string // actual import URL for display
}

const buildRegistry = (): AvatarEntry[] => {
  const registry: AvatarEntry[] = []

  // Add kawaii avatars
  for (const [filePath, url] of Object.entries(kawaiiAvatars)) {
    const name = extractName(filePath)
    registry.push({
      name,
      style: 'kawaii',
      path: `kawaii/${name.toLowerCase()}`,
      url: url as string,
    })
  }

  // Add cartoon avatars
  for (const [filePath, url] of Object.entries(cartoonAvatars)) {
    const name = extractName(filePath)
    registry.push({
      name,
      style: 'cartoon',
      path: `cartoon/${name.toLowerCase()}`,
      url: url as string,
    })
  }

  return registry
}

// Export the registry
export const avatarRegistry = buildRegistry()

// Get all unique avatar names (for username generation)
export const getAvatarNames = (): string[] => {
  const names = new Set(avatarRegistry.map((a) => a.name))
  return Array.from(names)
}

// Pick a random avatar (returns name, path, and url)
export const pickRandomAvatar = (): AvatarEntry => {
  const index = Math.floor(Math.random() * avatarRegistry.length)
  return avatarRegistry[index]
}

// Generate a random 4-digit number (0000-9999)
const generateRandomDigits = (): string => {
  return Math.floor(Math.random() * 10000)
    .toString()
    .padStart(4, '0')
}

// Generate username from avatar name + 4 digits
// e.g., 'Chef' -> 'Chef3847'
export const generateUsername = (avatarName: string): string => {
  return `${avatarName}${generateRandomDigits()}`
}

// Generate a complete new user identity (username + avatar)
export interface NewUserIdentity {
  username: string
  avatarPath: string
  avatarUrl: string
}

export const generateNewUserIdentity = (): NewUserIdentity => {
  const avatar = pickRandomAvatar()
  return {
    username: generateUsername(avatar.name),
    avatarPath: avatar.path,
    avatarUrl: avatar.url,
  }
}

// Get avatar URL by path (for displaying user avatars)
// e.g., 'kawaii/chef' -> actual URL
export const getAvatarByPath = (path: string | null): string | null => {
  if (!path) return null
  const entry = avatarRegistry.find((a) => a.path === path)
  return entry?.url || null
}
