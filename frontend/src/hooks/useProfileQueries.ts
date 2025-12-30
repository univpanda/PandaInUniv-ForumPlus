import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME } from '../utils/constants'
import { profileKeys } from './useUserProfile'

// User stats interface
export interface UserProfileStats {
  threadCount: number
  postCount: number
  upvotesReceived: number
  downvotesReceived: number
  upvotesGiven: number
  downvotesGiven: number
}

// Fetch user's cumulative stats via RPC
export function useUserProfileStats(userId: string | null, enabled: boolean = true) {
  return useQuery({
    queryKey: profileKeys.userStats(userId || ''),
    queryFn: async (): Promise<UserProfileStats> => {
      const defaultStats = {
        threadCount: 0,
        postCount: 0,
        upvotesReceived: 0,
        downvotesReceived: 0,
        upvotesGiven: 0,
        downvotesGiven: 0,
      }

      if (!userId) {
        return defaultStats
      }

      const { data, error } = await supabase.rpc('get_my_profile_stats')

      if (error) {
        console.error('Failed to fetch profile stats:', error)
        return defaultStats
      }

      // RPC returns array with single row
      const stats = data?.[0] || {}

      return {
        threadCount: stats.thread_count || 0,
        postCount: stats.post_count || 0,
        upvotesReceived: stats.upvotes_received || 0,
        downvotesReceived: stats.downvotes_received || 0,
        upvotesGiven: stats.upvotes_given || 0,
        downvotesGiven: stats.downvotes_given || 0,
      }
    },
    enabled: !!userId && enabled,
    staleTime: STALE_TIME.MEDIUM,
  })
}

// Public user stats (viewable by anyone, with privacy check)
export interface PublicUserStats {
  isPrivate: boolean
  threadCount: number
  postCount: number
  upvotesReceived: number
  downvotesReceived: number
}

// Fetch any user's public stats via RPC (includes server-side privacy check)
export function usePublicUserStats(userId: string | null, enabled: boolean = true) {
  return useQuery({
    queryKey: profileKeys.publicStats(userId || ''),
    queryFn: async (): Promise<PublicUserStats> => {
      const defaultStats = {
        isPrivate: false,
        threadCount: 0,
        postCount: 0,
        upvotesReceived: 0,
        downvotesReceived: 0,
      }

      if (!userId) return defaultStats

      const { data, error } = await supabase.rpc('get_public_user_stats', {
        p_user_id: userId,
      })

      if (error) {
        console.error('Failed to fetch public user stats:', error)
        return defaultStats
      }

      // RPC returns array with single row
      const stats = data?.[0] || {}

      return {
        isPrivate: stats.is_private || false,
        threadCount: stats.thread_count || 0,
        postCount: stats.post_count || 0,
        upvotesReceived: stats.upvotes_received || 0,
        downvotesReceived: stats.downvotes_received || 0,
      }
    },
    enabled: !!userId && enabled,
    staleTime: STALE_TIME.MEDIUM,
  })
}
