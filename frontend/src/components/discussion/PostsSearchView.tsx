import { MessageSquare } from 'lucide-react'
import { PostCard } from '../PostCard'
import { Pagination } from '../Pagination'
import { EmptyState } from '../ui'
import { authorPostToPost, type Thread, type AuthorPost, type Post } from '../../types'
import type { PaginationState } from '../../hooks/useDiscussionPagination'

interface PostsSearchViewProps {
  posts: AuthorPost[]
  pagination: PaginationState
  user: { id: string } | null
  isAdmin: boolean
  onGoToThread: (thread: Thread) => void
  onGoToPost: (thread: Thread, post: Post, isThreadOp: boolean) => void
  onDeletePost: (post: Post, e: React.MouseEvent) => void
  onToggleFlagged: (post: Post, e: React.MouseEvent) => void
  onUserDeletedClick: (e: React.MouseEvent) => void
}

export function PostsSearchView({
  posts,
  pagination,
  user,
  isAdmin,
  onGoToThread,
  onGoToPost,
  onDeletePost,
  onToggleFlagged,
  onUserDeletedClick,
}: PostsSearchViewProps) {
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
          itemName="posts"
        />
      )}

      {!posts || posts.length === 0 ? (
        <EmptyState icon={MessageSquare} description="No posts found for this user." />
      ) : (
        posts.map((authorPost: AuthorPost) => {
          const postData = authorPostToPost(authorPost)
          const thread: Thread = {
            id: authorPost.thread_id,
            title: authorPost.thread_title,
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
          const handleGoToPost = () => onGoToPost(thread, postData, authorPost.is_thread_op)

          return (
            <div key={authorPost.id} className="author-post-item">
              <div className="author-post-thread-info">
                <button className="thread-link-btn" onClick={handleGoToThread}>
                  In thread: {authorPost.thread_title}
                </button>
                {authorPost.is_thread_op && <span className="op-badge">OP</span>}
              </div>
              <div className="author-post-card-wrapper" onClick={handleGoToPost}>
                <PostCard
                  post={postData}
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
          itemName="posts"
        />
      )}
    </div>
  )
}
