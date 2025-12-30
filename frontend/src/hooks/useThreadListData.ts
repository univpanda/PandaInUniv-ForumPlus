import { usePaginatedThreads, type ThreadSortBy } from './useForumQueries'
import type { SortBy } from './useDiscussionFilters'
import type { Thread } from '../types'

interface UseThreadListDataProps {
  enabled: boolean
  sortBy: SortBy
  threadsPage: number
  threadsPageSize: number
  authorUsername?: string | null
  searchText?: string | null
  isDeleted?: boolean
  isFlagged?: boolean
}

export interface ThreadListDataReturn {
  threads: Thread[]
  isLoading: boolean
  isFetching: boolean
  isPlaceholderData: boolean
  isError: boolean
  refetch: () => void
  totalCount: number
}

export function useThreadListData({
  enabled,
  sortBy,
  threadsPage,
  threadsPageSize,
  authorUsername,
  searchText,
  isDeleted = false,
  isFlagged = false,
}: UseThreadListDataProps): ThreadListDataReturn {
  // Paginated threads query
  const paginatedThreadsQuery = usePaginatedThreads(
    sortBy as ThreadSortBy,
    threadsPage,
    threadsPageSize,
    enabled,
    authorUsername,
    searchText,
    isDeleted,
    isFlagged
  )

  return {
    threads: paginatedThreadsQuery.data?.threads ?? [],
    isLoading: paginatedThreadsQuery.isLoading,
    isFetching: paginatedThreadsQuery.isFetching,
    isPlaceholderData: paginatedThreadsQuery.isPlaceholderData,
    isError: paginatedThreadsQuery.isError,
    refetch: paginatedThreadsQuery.refetch,
    totalCount: paginatedThreadsQuery.data?.totalCount ?? 0,
  }
}
