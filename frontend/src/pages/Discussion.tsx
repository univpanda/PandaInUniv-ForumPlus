import { useEffect, useMemo, useRef } from 'react'
import { LogIn, EyeOff } from 'lucide-react'
import { useDiscussionPage } from '../hooks/useDiscussionPage'
import { DiscussionProvider } from '../contexts/DiscussionContext'
import { ThreadView } from '../components/ThreadView'
import { RepliesView } from '../components/RepliesView'
import {
  LoadingSpinner,
  QueryErrorBanner,
  EmptyState,
} from '../components/ui'
import {
  EditModal,
  DeleteModal,
  UserDeletedInfoModal,
  NewThreadForm,
  DiscussionHeader,
  ThreadListView,
  PostsSearchView,
  BookmarkedPostsView,
} from '../components/discussion'
import { useClickOutside } from '../hooks/useClickOutside'

interface DiscussionProps {
  resetToList?: number
  isActive?: boolean
  initialSearch?: {
    searchQuery: string
  } | null
  onInitialSearchConsumed?: () => void
  initialNavigation?: {
    threadId: number
    postId: number
    postParentId: number | null
  } | null
  onInitialNavigationConsumed?: () => void
}

export function Discussion({
  resetToList,
  isActive = true,
  initialSearch,
  onInitialSearchConsumed,
  initialNavigation,
  onInitialNavigationConsumed,
}: DiscussionProps) {
  const {
    auth,
    nav,
    threadForm,
    replyForm,
    sort,
    search,
    data,
    status,
    postActions,
    bookmarkActions,
    modalState,
    modalActions,
    handleRetry,
  } = useDiscussionPage({ resetToList })

  const {
    goToList,
    openThreadById,
    openRepliesById,
    triggerHighlightPost,
  } = nav
  const { setSearchQuery } = search

  // Apply initial search when provided from external navigation
  // This handles @username, @bookmarked, @op, @replies, and regular text searches from profile dropdown
  useEffect(() => {
    if (initialSearch) {
      // Navigate back to list view first (in case a thread is open)
      goToList()
      setSearchQuery(initialSearch.searchQuery)
      onInitialSearchConsumed?.()
    }
  }, [initialSearch, onInitialSearchConsumed, goToList, setSearchQuery])

  useEffect(() => {
    if (resetToList) {
      setSearchQuery('')
    }
  }, [resetToList, setSearchQuery])

  // Handle direct navigation to a specific post (from notifications)
  useEffect(() => {
    if (initialNavigation) {
      const { threadId, postId, postParentId } = initialNavigation

      if (postParentId === null) {
        // Post is the OP or a direct reply to OP - open thread view
        openThreadById(threadId)
        triggerHighlightPost(postId)
      } else {
        // Post is a reply (has a parent) - open replies view for that post
        openRepliesById(threadId, postId)
      }
      onInitialNavigationConsumed?.()
    }
  }, [
    initialNavigation,
    onInitialNavigationConsumed,
    openThreadById,
    openRepliesById,
    triggerHighlightPost,
  ])

  // Memoize core props (shared between ThreadView and RepliesView)
  const coreProps = useMemo(
    () => ({
      user: auth.user,
      isAdmin: auth.isAdmin,
      bookmarks: data.bookmarks,
      postBookmarks: data.postBookmarks,
    }),
    [auth.user, auth.isAdmin, data.bookmarks, data.postBookmarks]
  )

  // Memoize action props (shared between ThreadView and RepliesView)
  const actionProps = useMemo(
    () => ({
      onVote: postActions.votePost,
      onToggleBookmark: postActions.toggleBookmark,
      onTogglePostBookmark: postActions.togglePostBookmark,
      onEdit: postActions.handleEditPost,
      onDelete: postActions.handleDeletePost,
      onUserDeletedClick: postActions.handleUserDeletedClick,
      onToggleFlagged: postActions.toggleFlagged,
    }),
    [
      postActions.votePost,
      postActions.toggleBookmark,
      postActions.togglePostBookmark,
      postActions.handleEditPost,
      postActions.handleDeletePost,
      postActions.handleUserDeletedClick,
      postActions.toggleFlagged,
    ]
  )

  // Memoize viewData for ThreadView to prevent unnecessary context updates
  const threadViewData = useMemo(
    () => ({
      thread: nav.selectedThread,
      originalPost: data.originalPost,
      replies: data.replies,
      replySortBy: sort.replySortBy,
      replyContent: replyForm.replyContent,
      inlineReplyContent: replyForm.inlineReplyContent,
      replyingToPost: replyForm.replyingToPost,
      submitting: status.submitting,
      repliesPagination: data.pagination.replies,
    }),
    [
      nav.selectedThread,
      data.originalPost,
      data.replies,
      sort.replySortBy,
      replyForm.replyContent,
      replyForm.inlineReplyContent,
      replyForm.replyingToPost,
      status.submitting,
      data.pagination.replies,
    ]
  )

  // Memoize viewActions for ThreadView
  const threadViewActions = useMemo(
    () => ({
      onReplyContentChange: replyForm.setReplyContent,
      onInlineReplyContentChange: replyForm.setInlineReplyContent,
      onAddReply: replyForm.addReply,
      onReplySortChange: sort.setReplySortBy,
      onToggleReplyToPost: replyForm.toggleReplyToPost,
      onOpenReplies: nav.openReplies,
    }),
    [
      replyForm.setReplyContent,
      replyForm.setInlineReplyContent,
      replyForm.addReply,
      sort.setReplySortBy,
      replyForm.toggleReplyToPost,
      nav.openReplies,
    ]
  )

  // Memoize viewData for RepliesView
  const repliesViewData = useMemo(
    () => ({
      thread: nav.selectedThread,
      originalPost: data.originalPost,
      selectedPost: data.resolvedSelectedPost,
      sortedSubReplies: data.sortedSubReplies,
      replySortBy: sort.replySortBy,
      replyContent: replyForm.replyContent,
      submitting: status.submitting,
      subRepliesPagination: data.pagination.subReplies,
    }),
    [
      nav.selectedThread,
      data.originalPost,
      data.resolvedSelectedPost,
      data.sortedSubReplies,
      sort.replySortBy,
      replyForm.replyContent,
      status.submitting,
      data.pagination.subReplies,
    ]
  )

  // Memoize viewActions for RepliesView
  const repliesViewActions = useMemo(
    () => ({
      onReplyContentChange: replyForm.setReplyContent,
      onAddReply: replyForm.addReply,
      onReplySortChange: sort.setReplySortBy,
      onGoToThread: nav.goToThread,
    }),
    [
      replyForm.setReplyContent,
      replyForm.addReply,
      sort.setReplySortBy,
      nav.goToThread,
    ]
  )

  const newThreadComposerRef = useRef<HTMLDivElement | null>(null)

  useClickOutside(
    newThreadComposerRef,
    () => {
      if (threadForm.showNewThread) {
        threadForm.setShowNewThread(false)
      }
    },
    threadForm.showNewThread
  )

  useEffect(() => {
    if (!isActive && threadForm.showNewThread) {
      threadForm.setShowNewThread(false)
    }
  }, [isActive, threadForm.showNewThread, threadForm.setShowNewThread])

  useEffect(() => {
    if (!threadForm.showNewThread) return

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        threadForm.setShowNewThread(false)
      }
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [threadForm.showNewThread, threadForm.setShowNewThread])

  return (
    <div className="discussion-container no-sidebar">
      {/* Modals */}
      {modalState.editingPost && (
        <EditModal
          post={modalState.editingPost}
          editContent={modalState.editContent}
          additionalComment={modalState.additionalComment}
          submitting={status.submitting}
          onEditContentChange={modalActions.setEditContent}
          onAdditionalCommentChange={modalActions.setAdditionalComment}
          onSubmit={postActions.submitEdit}
          onClose={modalActions.closeEditModal}
        />
      )}
      {modalState.deletingPost && (
        <DeleteModal
          post={modalState.deletingPost}
          submitting={status.submitting}
          onConfirm={postActions.confirmDelete}
          onClose={modalActions.closeDeleteModal}
        />
      )}
      {modalState.showUserDeletedInfo && (
        <UserDeletedInfoModal onClose={modalActions.hideUserDeletedInfo} />
      )}

      {/* Main Content */}
      <main className="discussion-main">
        {/* Header */}
        <DiscussionHeader
          view={nav.view}
          threadTitle={nav.selectedThread?.title}
          onGoToThreadFromTitle={nav.goToThreadFromTitle}
          onGoToList={nav.goToList}
          sortBy={sort.sortBy}
          onSortChange={sort.handleSortChange}
          searchQuery={search.searchQuery}
          onSearchQueryChange={search.setSearchQuery}
          isAdmin={auth.isAdmin}
          user={auth.user}
          pageSizeInput={data.pageSizeControl.pageSizeInput}
          onPageSizeInputChange={data.pageSizeControl.setPageSizeInput}
          onPageSizeBlur={data.pageSizeControl.handlePageSizeBlur}
        />

        {/* New Thread Composer */}
        {auth.user && nav.view === 'list' && (
          <div className="new-thread-composer" ref={newThreadComposerRef}>
            {!threadForm.showNewThread && (
              <button
                type="button"
                className="new-thread-collapsed"
                onClick={() => threadForm.setShowNewThread(true)}
              >
                Take a bite...
              </button>
            )}
            {threadForm.showNewThread && (
              <NewThreadForm
                title={threadForm.newThreadTitle}
                content={threadForm.newThreadContent}
                submitting={status.submitting}
                onTitleChange={threadForm.setNewThreadTitle}
                onContentChange={threadForm.setNewThreadContent}
                onSubmit={threadForm.createThread}
                isPollEnabled={threadForm.isPollEnabled}
                onPollToggle={threadForm.setIsPollEnabled}
                pollOptions={threadForm.pollOptions}
                onPollOptionsChange={threadForm.setPollOptions}
                pollSettings={threadForm.pollSettings}
                onPollSettingsChange={threadForm.setPollSettings}
              />
            )}
          </div>
        )}

        {/* Loading - only show spinner for initial load (no data yet) */}
        {status.loading && <LoadingSpinner className="discussion-loading" />}

        {/* Background fetching indicator - subtle, doesn't block content */}
        {status.isFetching && !status.loading && (
          <div className="discussion-fetching-indicator" />
        )}

        {/* Query Error */}
        {status.queryError && !status.loading && (
          <QueryErrorBanner
            message={
              nav.view === 'list'
                ? 'Failed to load threads. Please try again.'
                : 'Failed to load posts. Please try again.'
            }
            onRetry={handleRetry}
          />
        )}

        {/* Private User Search Message */}
        {status.isSearchingPrivateUser && nav.view === 'list' && (
          <EmptyState
            icon={EyeOff}
            description={`@${status.searchedAuthorUsername}'s profile is private.`}
          />
        )}

        {/* Thread List View (normal mode, not bookmarks) */}
        {nav.view === 'list' && !status.loading && !status.queryError && !status.isPostsSearchView && !status.isSearchingPrivateUser && !status.isBookmarksView && (
          <ThreadListView
            threads={data.threads}
            bookmarks={data.bookmarks}
            user={auth.user}
            threadsPagination={data.pagination.threads}
            onOpenThread={nav.openThread}
            onToggleBookmark={postActions.toggleBookmark}
          />
        )}

        {/* Bookmarked Posts View */}
        {nav.view === 'list' && !status.loading && !status.queryError && status.isBookmarksView && (
          <BookmarkedPostsView
            posts={data.bookmarkedPosts}
            pagination={data.pagination.bookmarks}
            user={auth.user}
            isAdmin={auth.isAdmin}
            onGoToThread={nav.openThread}
            onGoToPost={bookmarkActions.goToSearchedPost}
            onDeletePost={postActions.handleDeletePost}
            onToggleFlagged={postActions.toggleFlagged}
            onUserDeletedClick={postActions.handleUserDeletedClick}
          />
        )}

        {/* Posts Search View */}
        {nav.view === 'list' &&
          status.isPostsSearchView &&
          !status.postsSearchLoading &&
          !status.queryError &&
          !status.isSearchingPrivateUser && (
            <PostsSearchView
              posts={data.postsSearchData}
              pagination={data.pagination.postsSearch}
              user={auth.user}
              isAdmin={auth.isAdmin}
              onGoToThread={nav.openThread}
              onGoToPost={bookmarkActions.goToSearchedPost}
              onDeletePost={postActions.handleDeletePost}
              onToggleFlagged={postActions.toggleFlagged}
              onUserDeletedClick={postActions.handleUserDeletedClick}
            />
          )}

        {/* Thread View */}
        {nav.view === 'thread' && !status.loading && !status.queryError && nav.selectedThread && (
          <DiscussionProvider
            core={coreProps}
            actions={actionProps}
            viewData={threadViewData}
            viewActions={threadViewActions}
          >
            <ThreadView />
          </DiscussionProvider>
        )}

        {/* Replies View */}
        {nav.view === 'replies' &&
          !status.loading &&
          !status.queryError &&
          nav.selectedThread &&
          data.originalPost &&
          data.resolvedSelectedPost && (
            <DiscussionProvider
              core={coreProps}
              actions={actionProps}
              viewData={repliesViewData}
              viewActions={repliesViewActions}
            >
              <RepliesView />
            </DiscussionProvider>
          )}

        {/* Sign in prompt */}
        {!auth.user && nav.view === 'list' && (
          <div className="sign-in-prompt">
            <button className="auth-button auth-sign-in" onClick={auth.signInWithGoogle}>
              <LogIn size={18} />
              <span>Sign in</span>
            </button>
            <span>to create threads and join the discussion</span>
          </div>
        )}
      </main>
    </div>
  )
}
