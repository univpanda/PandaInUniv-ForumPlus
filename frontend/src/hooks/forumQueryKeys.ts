// Query keys factory with typed parameters for forum-related queries
// Centralized to avoid circular dependencies between query modules

// Sort type for thread queries (matches API expectations)
export type ThreadSortBy = 'popular' | 'recent' | 'new'

export const forumKeys = {
  all: ['forum'] as const,
  threadsAll: () => [...forumKeys.all, 'threads'] as const,
  threads: (sortBy: ThreadSortBy) => [...forumKeys.all, 'threads', sortBy] as const,
  threadById: (threadId: number) => [...forumKeys.all, 'thread', threadId] as const,
  paginatedThreads: (
    sortBy: ThreadSortBy,
    page: number,
    pageSize: number,
    authorUsername?: string | null,
    searchText?: string | null,
    isDeleted?: boolean,
    isFlagged?: boolean
  ) =>
    [
      ...forumKeys.all,
      'threads',
      sortBy,
      'page',
      page,
      'size',
      pageSize,
      authorUsername ?? null,
      searchText ?? null,
      isDeleted ?? false,
      isFlagged ?? false,
    ] as const,
  postsAll: () => [...forumKeys.all, 'posts'] as const,
  // Posts for a specific thread/parent - this is a prefix for paginatedPosts, enabling targeted invalidation
  posts: (threadId: number, parentId: number | null) =>
    [...forumKeys.all, 'posts', threadId, parentId === null ? 'root' : parentId] as const,
  paginatedPosts: (
    threadId: number,
    parentId: number | null,
    page: number,
    pageSize: number,
    sort: string = 'popular'
  ) =>
    [
      ...forumKeys.all,
      'posts',
      threadId,
      parentId === null ? 'root' : parentId,
      'page',
      page,
      'size',
      pageSize,
      sort,
    ] as const,
  // Thread view: OP + paginated replies in single query (uses 'posts' prefix for mutation compatibility)
  threadView: (threadId: number, page: number, sort: string = 'popular') =>
    [...forumKeys.all, 'posts', threadId, 'threadView', page, sort] as const,
  flaggedPosts: () => [...forumKeys.all, 'flagged-posts'] as const,
  paginatedFlaggedPosts: (page: number) => [...forumKeys.all, 'flagged-posts', 'page', page] as const,
  authorPostsAll: () => [...forumKeys.all, 'author-posts'] as const,
  authorPosts: (
    username: string,
    page: number,
    searchText?: string | null,
    isDeleted?: boolean,
    isFlagged?: boolean,
    postType?: 'all' | 'op' | 'replies'
  ) =>
    [
      ...forumKeys.all,
      'author-posts',
      username,
      'page',
      page,
      searchText ?? null,
      isDeleted ?? false,
      isFlagged ?? false,
      postType ?? 'all',
    ] as const,
  bookmarks: (userId: string) => [...forumKeys.all, 'bookmarks', userId] as const,
  postBookmarks: (userId: string) => [...forumKeys.all, 'post-bookmarks', userId] as const,
  // Parent key for invalidating all bookmarked posts pages/searches at once
  bookmarkedPostsAll: (userId: string) => [...forumKeys.all, 'bookmarked-posts', userId] as const,
  bookmarkedPosts: (userId: string, page: number, searchText?: string | null) =>
    [...forumKeys.all, 'bookmarked-posts', userId, 'page', page, searchText ?? null] as const,
  // Polls
  poll: (threadId: number) => [...forumKeys.all, 'poll', threadId] as const,
}
