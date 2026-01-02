/**
 * Query helper utilities for React Query
 */

/**
 * Type for raw paginated response rows that include total_count
 */
type RawPaginatedRow<T> = T & { total_count: number }

/**
 * Paginated response type
 */
export interface PaginatedResponse<T> {
  items: T[]
  totalCount: number
}

/**
 * Extract paginated data from Supabase RPC response.
 * Many RPC functions return rows with a `total_count` field that we need to
 * extract once and strip from individual items.
 *
 * @param rawData - Array of items with total_count field
 * @returns Object with items (without total_count) and totalCount
 *
 * @example
 * const { data } = await supabase.rpc('get_paginated_threads', {...})
 * const { items: threads, totalCount } = extractPaginatedResponse<Thread>(data)
 */
export function extractPaginatedResponse<T>(
  rawData: RawPaginatedRow<T>[] | null
): PaginatedResponse<T> {
  const data = rawData ?? []
  const totalCount = data[0]?.total_count ?? 0
  const items = data.map((row) => {
    const { total_count: _totalCount, ...item } = row
    void _totalCount
    return item as T
  })
  return { items, totalCount }
}
