import { Bookmark } from 'lucide-react'
import { PostCard } from '../PostCard'
import { Pagination } from '../Pagination'
import { EmptyState } from '../ui'
import type { BookmarkedPost, Thread, Post } from '../../types'
import type { PaginationState } from '../../hooks/useDiscussionPagination'

interface BookmarkedPostsViewProps {
  posts: BookmarkedPost[]
  pagination: PaginationState
  user: { id: string } | null
  isAdmin: boolean
  onGoToThread: (thread: Thread) => void
  onGoToPost: (thread: Thread, post: Post, isThreadOp: boolean) => void
  onDeletePost: (post: Post, e: React.MouseEvent) => void
  onToggleFlagged: (post: Post, e: React.MouseEvent) => void
  onUserDeletedClick: (e: React.MouseEvent) => void
}

export function BookmarkedPostsView({
  posts,
  pagination,
  user,
  isAdmin,
  onGoToThread,
  onGoToPost,
  onDeletePost,
  onToggleFlagged,
  onUserDeletedClick,
}: BookmarkedPostsViewProps) {
  return (
    <div className="author-posts-list">
      {/* Top Pagination */}
      {pagination.totalPages > 1 && (
        <Pagination
          currentPage={pagination.page}
          totalPages={pagination.totalPages}
          onPageChange={pagination.setPage}
          totalItems={pagination.totalCount}
          itemsPerPage={pagination.pageSize}
          itemName="bookmarked posts"
        />
      )}

      {!posts || posts.length === 0 ? (
        <EmptyState
          icon={Bookmark}
          description="No bookmarked posts yet. Bookmark posts to save them here."
        />
      ) : (
        posts.map((bookmarkedPost: BookmarkedPost) => {
          const isThreadOp = bookmarkedPost.parent_id === null
          const thread: Thread = {
            id: bookmarkedPost.thread_id,
            title: bookmarkedPost.thread_title,
            author_id: '',
            author_name: '',
            author_avatar: null,
            author_avatar_path: null,
            created_at: '',
            first_post_content: '',
            reply_count: 0,
            total_likes: 0,
            total_dislikes: 0,
          }

          // Thread link always goes to thread view
          const handleGoToThread = () => onGoToThread(thread)

          // Post click goes to replies page (thread view for OP, sub-replies for others)
          const handleGoToPost = () => onGoToPost(thread, bookmarkedPost, isThreadOp)

          return (
            <div key={bookmarkedPost.id} className="author-post-item">
              <div className="author-post-thread-info">
                <button className="thread-link-btn" onClick={handleGoToThread}>
                  In thread: {bookmarkedPost.thread_title}
                </button>
                {isThreadOp && <span className="op-badge">OP</span>}
              </div>
              <div className="author-post-card-wrapper" onClick={handleGoToPost}>
                <PostCard
                  post={bookmarkedPost}
                  user={user}
                  isAdmin={isAdmin}
                  variant="reply"
                  onDelete={onDeletePost}
                  onToggleFlagged={onToggleFlagged}
                  onUserDeletedClick={onUserDeletedClick}
                />
              </div>
            </div>
          )
        })
      )}

      {/* Bottom Pagination */}
      {pagination.totalPages > 1 && (
        <Pagination
          currentPage={pagination.page}
          totalPages={pagination.totalPages}
          onPageChange={pagination.setPage}
          totalItems={pagination.totalCount}
          itemsPerPage={pagination.pageSize}
          itemName="bookmarked posts"
        />
      )}
    </div>
  )
}
