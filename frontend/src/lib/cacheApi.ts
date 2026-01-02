// Cache API client for DynamoDB-backed user cache

import type { UserWithStats } from '../types'

const CACHE_API_URL = import.meta.env.VITE_CACHE_API_URL

export interface CachedUserProfile {
  id: string
  role: string
  is_blocked: boolean
  username: string
  avatar_url: string | null
  avatar_path: string | null
  is_private: boolean
  _cached?: boolean
}

export interface PaginatedUsersResponse {
  users: UserWithStats[]
  totalCount: number
  _cached: boolean
}

// Get user profile from cache (with fallback to Supabase on miss)
export async function getCachedUserProfile(
  userId: string,
  authToken?: string
): Promise<CachedUserProfile | null> {
  if (!CACHE_API_URL) {
    console.warn('Cache API URL not configured, skipping cache')
    return null
  }
  if (!authToken) {
    return null
  }

  const controller = new AbortController()
  const timeout = setTimeout(() => controller.abort(), 2000)

  try {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }
    headers['Authorization'] = `Bearer ${authToken}`

    const response = await fetch(`${CACHE_API_URL}/user/${userId}`, {
      method: 'GET',
      headers,
      signal: controller.signal,
    })

    if (!response.ok) {
      if (response.status === 404) {
        return null // User not found
      }
      throw new Error(`Cache API error: ${response.status}`)
    }

    return await response.json()
  } catch (error) {
    console.warn('Cache API fetch failed, will fallback to Supabase:', error)
    return null
  } finally {
    clearTimeout(timeout)
  }
}

// Invalidate user cache (call after profile updates)
export async function invalidateUserCache(
  userId: string,
  authToken: string
): Promise<boolean> {
  if (!CACHE_API_URL) {
    return false
  }

  try {
    const response = await fetch(`${CACHE_API_URL}/cache/user/${userId}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${authToken}`,
      },
    })

    return response.ok
  } catch (error) {
    console.warn('Cache invalidation failed:', error)
    return false
  }
}

// Get paginated users from cache (admin only)
export async function getCachedPaginatedUsers(
  authToken: string,
  limit: number,
  offset: number,
  search?: string
): Promise<PaginatedUsersResponse | null> {
  if (!CACHE_API_URL) {
    return null
  }

  try {
    const params = new URLSearchParams({
      limit: String(limit),
      offset: String(offset),
    })
    if (search) {
      params.set('search', search)
    }

    const response = await fetch(`${CACHE_API_URL}/users?${params}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${authToken}`,
      },
    })

    if (!response.ok) {
      throw new Error(`Cache API error: ${response.status}`)
    }

    return await response.json()
  } catch (error) {
    console.warn('Cache API fetch failed for paginated users:', error)
    return null
  }
}

// Check if cache API is available
export function isCacheEnabled(): boolean {
  return !!CACHE_API_URL
}
