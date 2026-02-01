import { PostCard } from './PostCard'
import { Pagination } from './Pagination'
import { ReplyInput, ReplySortOptions } from './discussion'
import {
  useDiscussion,
  useDiscussionView,
  useDiscussionViewActions,
} from '../contexts/DiscussionContext'

export function RepliesView() {
  const { user } = useDiscussion()
  const {
    thread,
    originalPost,
    selectedPost,
    sortedSubReplies,
    replySortBy,
    replyContent,
    submitting,
    subRepliesPagination,
  } = useDiscussionView()
  const { onReplyContentChange, onAddReply, onReplySortChange, onGoToThread } = useDiscussionViewActions()

  if (!thread || !originalPost || !selectedPost) return null

  return (
    <div className="replies-view">
      {/* Original Thread Post - clickable to go back to thread */}
      <div className="op-post-wrapper" onClick={() => onGoToThread?.()} title="Go back to thread">
        <PostCard
          post={originalPost}
          variant="original"
          replyCount={originalPost.reply_count}
          threadId={thread.id}
          threadTitle={thread.title}
        />
      </div>

      {/* Connector between original and reply */}
      <div className="thread-connector" />

      {/* Parent Post (the reply we're viewing sub-replies for) - clickable to go back to thread at this post */}
      <div
        className="parent-post-wrapper"
        onClick={() => onGoToThread(selectedPost.id)}
        title="Go back to thread at this post"
      >
        <PostCard
          post={selectedPost}
          variant="parent"
          threadId={thread.id}
          replyCount={subRepliesPagination?.totalCount ?? selectedPost.reply_count}
        />
      </div>

      {/* Reply Input - for adding level 2 replies */}
      {user && (
        <ReplyInput
          value={replyContent}
          onChange={onReplyContentChange}
          onSubmit={() => onAddReply(thread.id, selectedPost.id)}
          placeholder={`Reply to ${selectedPost.author_name}... (Shift + Enter to submit)`}
          submitting={submitting}
        />
      )}

      {/* Reply Sort Options */}
      <ReplySortOptions
        sortBy={replySortBy}
        onSortChange={onReplySortChange}
        show={sortedSubReplies.length > 1}
      />

      {/* Top Pagination */}
      {subRepliesPagination && subRepliesPagination.totalPages > 1 && (
        <Pagination
          currentPage={subRepliesPagination.page}
          totalPages={subRepliesPagination.totalPages}
          onPageChange={subRepliesPagination.setPage}
          totalItems={subRepliesPagination.totalCount}
          itemsPerPage={subRepliesPagination.pageSize}
          itemName="replies"
        />
      )}

      {sortedSubReplies.length === 0 ? (
        <p className="no-replies">No replies yet</p>
      ) : (
        sortedSubReplies.map((post) => (
          <PostCard key={post.id} post={post} variant="reply" threadId={thread.id} hideReplyCount />
        ))
      )}

      {/* Bottom Reply Input - for adding level 2 replies */}
      {user && (
        <ReplyInput
          value={replyContent}
          onChange={onReplyContentChange}
          onSubmit={() => onAddReply(thread.id, selectedPost.id)}
          placeholder={`Reply to ${selectedPost.author_name}... (Shift + Enter to submit)`}
          submitting={submitting}
        />
      )}

      {/* Bottom Pagination */}
      {subRepliesPagination && subRepliesPagination.totalPages > 1 && (
        <Pagination
          currentPage={subRepliesPagination.page}
          totalPages={subRepliesPagination.totalPages}
          onPageChange={subRepliesPagination.setPage}
          totalItems={subRepliesPagination.totalCount}
          itemsPerPage={subRepliesPagination.pageSize}
          itemName="replies"
        />
      )}
    </div>
  )
}
