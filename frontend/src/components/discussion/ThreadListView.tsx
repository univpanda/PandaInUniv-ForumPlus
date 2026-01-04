import { ThreadList } from '../ThreadList'
import { Pagination } from '../Pagination'
import type { Thread } from '../../types'
import type { PaginationState } from '../../hooks/useDiscussionPagination'

interface ThreadListViewProps {
  threads: Thread[]
  bookmarks: Set<number>
  user: { id: string } | null
  threadsPagination: PaginationState
  onOpenThread: (thread: Thread) => void
  onToggleBookmark: (threadId: number, e: React.MouseEvent) => void
}

export function ThreadListView({
  threads,
  bookmarks,
  user,
  threadsPagination,
  onOpenThread,
  onToggleBookmark,
}: ThreadListViewProps) {
  return (
    <>
      <ThreadList
        threads={threads}
        bookmarks={bookmarks}
        user={user}
        onOpenThread={onOpenThread}
        onToggleBookmark={onToggleBookmark}
      />

      {/* Bottom Pagination */}
      {threadsPagination.totalPages > 1 && (
        <Pagination
          currentPage={threadsPagination.page}
          totalPages={threadsPagination.totalPages}
          onPageChange={threadsPagination.setPage}
          totalItems={threadsPagination.totalCount}
          itemsPerPage={threadsPagination.pageSize}
          itemName="threads"
        />
      )}
    </>
  )
}
