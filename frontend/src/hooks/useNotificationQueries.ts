import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import { STALE_TIME, POLL_INTERVAL, PAGE_SIZE } from '../utils/constants'
import { getPollingIntervalSafe } from '../utils/polling'
import type { Notification } from '../types'

// Query key factory for notifications
export const notificationKeys = {
  all: ['notifications'] as const,
  count: (userId: string) => [...notificationKeys.all, 'count', userId] as const,
  list: (userId: string, page: number) => [...notificationKeys.all, 'list', userId, page] as const,
}

/**
 * Hook to fetch notification count for badge
 */
export function useNotificationCount(userId: string | null) {
  return useQuery<number, Error>({
    queryKey: notificationKeys.count(userId || ''),
    queryFn: async () => {
      if (!userId) return 0
      const { data, error } = await supabase.rpc('get_notification_count')
      if (error) throw error
      return (data as number) || 0
    },
    enabled: !!userId,
    staleTime: STALE_TIME.SHORT,
    refetchInterval: (query) => {
      if (typeof document !== 'undefined' && document.hidden) {
        return false
      }
      return getPollingIntervalSafe(POLL_INTERVAL.NOTIFICATIONS, query)
    },
    refetchIntervalInBackground: false,
  })
}

/**
 * Hook to fetch paginated notifications list
 */
export function useNotifications(
  userId: string | null,
  page: number = 1,
  options?: { enabled?: boolean }
) {
  return useQuery({
    queryKey: notificationKeys.list(userId || '', page),
    queryFn: async () => {
      if (!userId) return { notifications: [] as Notification[], totalCount: 0 }

      const pageSize = PAGE_SIZE.POSTS
      const { data, error } = await supabase.rpc('get_notifications', {
        p_limit: pageSize,
        p_offset: (page - 1) * pageSize,
      })

      if (error) throw error

      const notifications = (data || []) as Notification[]
      const totalCount = notifications[0]?.total_count || 0

      return { notifications, totalCount }
    },
    enabled: !!userId && options?.enabled !== false,
    staleTime: STALE_TIME.SHORT,
    // No polling for list - count badge polls instead
    // List refreshes via invalidation when notifications are dismissed
  })
}

/**
 * Hook to dismiss a single notification
 */
export function useDismissNotification(userId: string | null) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (notificationId: number) => {
      const { error } = await supabase.rpc('dismiss_notification', {
        p_notification_id: notificationId,
      })
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationKeys.count(userId || '') })
      queryClient.invalidateQueries({ queryKey: notificationKeys.all })
    },
  })
}

/**
 * Hook to dismiss all notifications
 */
export function useDismissAllNotifications(userId: string | null) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async () => {
      const { error } = await supabase.rpc('dismiss_all_notifications')
      if (error) throw error
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: notificationKeys.count(userId || '') })
      queryClient.invalidateQueries({ queryKey: notificationKeys.all })
    },
  })
}
