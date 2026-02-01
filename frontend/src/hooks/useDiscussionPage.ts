import { useMemo, useCallback } from 'react'
import { useAuth } from './useAuth'
import { useModalState } from './useDiscussionState'
import { useDiscussionNavigation, type View } from './useDiscussionNavigation'
import { useDiscussionForms } from './useDiscussionForms'
import { useDiscussionFilters, type SortBy, type ReplySortBy } from './useDiscussionFilters'
import { useDiscussionPosts } from './useDiscussionPosts'
import { useDiscussionScrollEffects } from './useDiscussionScrollEffects'
import { useDiscussionActions } from './useDiscussionActions'
import { useUserProfile } from './useUserProfile'

interface UseDiscussionPageProps {
  resetToList?: number
}

export function useDiscussionPage({ resetToList }: UseDiscussionPageProps) {
  const { user, isAdmin, signInWithGoogle } = useAuth()
  const { data: userProfile } = useUserProfile(user?.id ?? null)
  const { state: modalState, actions: modalActions } = useModalState()

  // Compose smaller hooks
  const navigation = useDiscussionNavigation({ resetToList })
  const forms = useDiscussionForms()
  const filters = useDiscussionFilters()

  // Use pre-parsed search from filters (avoids duplicate parsing)
  // Only allow @username filtering for logged-in users
  // @deleted and @flagged only work for admins
  const { authorUsername, searchText, isDeleted, isFlagged, postType } = useMemo(() => {
    if (!filters.deferredSearchQuery.trim()) {
      return {
        authorUsername: null,
        searchText: null,
        isDeleted: false,
        isFlagged: false,
        postType: 'all' as const,
      }
    }

    if (!user) {
      // Non-logged-in users can't use @username filters; drop leading @token.
      const raw = filters.deferredSearchQuery.trim()
      const sanitized = raw.startsWith('@') ? raw.replace(/^@\S+\s*/, '').trim() : raw
      return {
        authorUsername: null,
        searchText: sanitized || null,
        isDeleted: false,
        isFlagged: false,
        postType: 'all' as const,
      }
    }

    // Use the already-parsed search from useDiscussionFilters
    // Only admins can use @deleted and @flagged
    return {
      authorUsername: filters.parsedSearch.authorUsername,
      searchText: filters.parsedSearch.rawSearchText,
      isDeleted: isAdmin && filters.parsedSearch.isDeleted,
      isFlagged: isAdmin && filters.parsedSearch.isFlagged,
      postType: filters.parsedSearch.postType,
    }
  }, [user, isAdmin, filters.deferredSearchQuery, filters.parsedSearch])

  // Privacy check is now done server-side in get_posts_by_author
  // The backend returns is_private=true if searching a private user
  const postsData = useDiscussionPosts({
    view: navigation.view,
    selectedThread: navigation.selectedThread,
    selectedPost: navigation.selectedPost,
    sortBy: filters.sortBy,
    replySortBy: filters.replySortBy,
    isBookmarksView: filters.isBookmarksView,
    userId: user?.id,
    authorUsername,
    searchText,
    searchMode: filters.searchMode,
    isAdmin,
    isDeleted,
    isFlagged,
    postType,
  })

  // Privacy status now comes from the search response (no extra network call)
  const isSearchingPrivateUser = postsData.postsSearchIsPrivate

  // Scroll effects for navigation and new replies
  const scrollEffects = useDiscussionScrollEffects({
    view: navigation.view,
    loading: postsData.loading,
  })

  // All action callbacks (extracted to separate hook)
  const actions = useDiscussionActions({
    user,
    userProfile: userProfile ?? undefined,
    isAdmin,
    navigation,
    forms,
    filters,
    postsData,
    scrollEffects,
    modalState,
    modalActions,
  })

  // Navigate to thread with optional scroll to specific post
  const goToThreadWithScroll = useCallback(
    (scrollToPostId?: number) => {
      navigation.goToThreadFromReplies()
      if (scrollToPostId) {
        scrollEffects.triggerHighlightPost(scrollToPostId)
      }
    },
    [navigation, scrollEffects]
  )

  // Group related state and handlers for cleaner API
  const auth = { user, isAdmin, signInWithGoogle }

  const nav = {
    view: navigation.view,
    selectedThread: navigation.selectedThread,
    selectedPost: navigation.selectedPost,
    openThread: navigation.openThread,
    openThreadById: navigation.openThreadById,
    openReplies: actions.openReplies,
    openRepliesById: navigation.openRepliesById,
    goToThreadFromTitle: navigation.goToList,
    goToThread: goToThreadWithScroll,
    goToList: navigation.goToList,
    triggerHighlightPost: scrollEffects.triggerHighlightPost,
  }

  const threadForm = {
    showNewThread: forms.showNewThread,
    setShowNewThread: forms.setShowNewThread,
    newThreadTitle: forms.newThreadTitle,
    setNewThreadTitle: forms.setNewThreadTitle,
    newThreadContent: forms.newThreadContent,
    setNewThreadContent: forms.setNewThreadContent,
    createThread: actions.createThread,
    // Poll props
    isPollEnabled: forms.isPollEnabled,
    setIsPollEnabled: forms.setIsPollEnabled,
    pollOptions: forms.pollOptions,
    setPollOptions: forms.setPollOptions,
    pollSettings: forms.pollSettings,
    setPollSettings: forms.setPollSettings,
  }

  const replyForm = {
    replyContent: forms.replyContent,
    setReplyContent: forms.setReplyContent,
    inlineReplyContent: forms.inlineReplyContent,
    setInlineReplyContent: forms.setInlineReplyContent,
    replyingToPost: forms.replyingToPost,
    toggleReplyToPost: forms.toggleReplyToPost,
    addReply: actions.addReply,
  }

  const sort = {
    sortBy: filters.sortBy,
    replySortBy: filters.replySortBy,
    setReplySortBy: filters.setReplySortBy,
    handleSortChange: filters.handleSortChange,
  }

  const search = {
    searchQuery: filters.searchQuery,
    setSearchQuery: filters.setSearchQuery,
    deferredSearchQuery: filters.deferredSearchQuery,
    searchMode: filters.searchMode,
    setSearchMode: filters.setSearchMode,
  }

  const data = {
    threads: postsData.threads,
    bookmarks: postsData.bookmarks,
    postBookmarks: postsData.postBookmarks,
    bookmarkedPosts: postsData.bookmarkedPosts,
    originalPost: postsData.originalPost,
    resolvedSelectedPost: postsData.resolvedSelectedPost,
    replies: postsData.replies,
    sortedSubReplies: postsData.sortedSubReplies,
    subRepliesLoading: postsData.subRepliesLoading,
    postsSearchData: postsData.postsSearchData,
    pagination: postsData.pagination,
    pageSizeControl: postsData.pageSizeControl,
  }

  const status = {
    loading: postsData.loading,
    isFetching: postsData.isFetching,
    postsSearchLoading: postsData.postsSearchLoading,
    queryError: postsData.queryError,
    submitting: actions.submitting,
    isBookmarksView: filters.isBookmarksView,
    isPostsSearchView: postsData.isPostsSearchView,
    isSearchingPrivateUser,
    searchedAuthorUsername: authorUsername,
  }

  return {
    auth,
    nav,
    threadForm,
    replyForm,
    sort,
    search,
    data,
    status,
    postActions: actions.postActions,
    bookmarkActions: actions.bookmarkActions,
    toast: actions.toast,
    modalState,
    modalActions,
    handleRetry: postsData.handleRetry,
  }
}

export type { View, SortBy, ReplySortBy }
