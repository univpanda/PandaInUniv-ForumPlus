import { useCallback } from 'react'
import { PostCard } from './PostCard'
import { Pagination } from './Pagination'
import { ReplyInput, ReplySortOptions, PollDisplay } from './discussion'
import {
  useDiscussion,
  useDiscussionView,
  useDiscussionViewActions,
} from '../contexts/DiscussionContext'
import type { Post } from '../types'

export function ThreadView() {
  const { user } = useDiscussion()
  const {
    thread,
    originalPost,
    replies,
    replySortBy,
    replyContent,
    inlineReplyContent,
    replyingToPost,
    submitting,
    repliesPagination,
  } = useDiscussionView()
  const {
    onReplyContentChange,
    onInlineReplyContentChange,
    onAddReply,
    onReplySortChange,
    onToggleReplyToPost,
    onOpenReplies,
  } = useDiscussionViewActions()

  // Memoized handlers to prevent breaking PostCard's memo()
  const handlePostClick = useCallback(
    (post: Post) => onOpenReplies(post),
    [onOpenReplies]
  )

  const handleReplyClick = useCallback(
    (post: Post, e: React.MouseEvent) => onToggleReplyToPost(post, e),
    [onToggleReplyToPost]
  )

  if (!thread) return null

  return (
    <div className="thread-view">
      {/* Original Post */}
      {originalPost && originalPost.content !== undefined && (
        <PostCard
          key={originalPost.id}
          post={originalPost}
          variant="original"
          replyCount={replies.length}
          threadId={thread.id}
          threadTitle={thread.title}
        >
          {/* Poll embedded within the original post card */}
          {'has_poll' in thread && thread.has_poll !== false && (
            <PollDisplay threadId={thread.id} userId={user?.id ?? null} />
          )}
        </PostCard>
      )}

      {/* Reply Input */}
      {user && (
        <ReplyInput
          value={replyContent}
          onChange={onReplyContentChange}
          onSubmit={() => onAddReply(thread.id, originalPost?.id ?? null)}
          placeholder="Write a reply... (Shift + Enter to submit)"
          submitting={submitting}
        />
      )}

      {/* Reply Sort Options */}
      <ReplySortOptions
        sortBy={replySortBy}
        onSortChange={onReplySortChange}
        show={replies.length > 1}
      />

      {/* Top Pagination */}
      {repliesPagination && repliesPagination.totalPages > 1 && (
        <Pagination
          currentPage={repliesPagination.page}
          totalPages={repliesPagination.totalPages}
          onPageChange={repliesPagination.setPage}
          totalItems={repliesPagination.totalCount}
          itemsPerPage={repliesPagination.pageSize}
          itemName="replies"
        />
      )}

      {replies.length === 0 ? (
        <p className="no-replies">No replies yet</p>
      ) : (
        replies.map((post) => (
          <div key={post.id}>
            <PostCard
              post={post}
              variant="reply"
              threadId={thread.id}
              onClick={handlePostClick}
              onReplyClick={handleReplyClick}
              showSubReplyPreview={true}
            />
            {/* Inline reply form */}
            {replyingToPost?.id === post.id && (
              <ReplyInput
                value={inlineReplyContent}
                onChange={onInlineReplyContentChange}
                onSubmit={() => onAddReply(thread.id, post.id, true)}
                placeholder={`Reply to ${post.author_name}... (Shift + Enter to submit)`}
                submitting={submitting}
                size="small"
                autoFocus
              />
            )}
          </div>
        ))
      )}

      {/* Bottom Pagination */}
      {repliesPagination && repliesPagination.totalPages > 1 && (
        <Pagination
          currentPage={repliesPagination.page}
          totalPages={repliesPagination.totalPages}
          onPageChange={repliesPagination.setPage}
          totalItems={repliesPagination.totalCount}
          itemsPerPage={repliesPagination.pageSize}
          itemName="replies"
        />
      )}

      {/* Bottom Reply Input */}
      {user && replies.length > 0 && (
        <ReplyInput
          value={replyContent}
          onChange={onReplyContentChange}
          onSubmit={() => onAddReply(thread.id, originalPost?.id ?? null)}
          placeholder="Write a reply... (Shift + Enter to submit)"
          submitting={submitting}
        />
      )}
    </div>
  )
}
