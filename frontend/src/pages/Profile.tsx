import { memo, useCallback } from 'react'
import { FileText, MessageCircle, Eye, EyeOff, Bookmark } from 'lucide-react'
import happyPanda from '../assets/webp/happy-panda.webp'
import sadPanda from '../assets/webp/sad-panda.webp'
import { useAuth } from '../hooks/useAuth'
import { useUserProfile, useTogglePrivate } from '../hooks/useUserProfile'
import { useUserProfileStats } from '../hooks/useProfileQueries'
import { usePostBookmarks } from '../hooks/useBookmarkQueries'
import { useToast } from '../contexts/ToastContext'
import { UsernameEditor } from '../components/auth/UsernameEditor'
import { getAvatarUrl } from '../utils/format'
import { LoadingSpinner, ButtonSpinner } from '../components/ui'
import type { SearchDiscussionEvent } from '../components/AuthButton'

export const Profile = memo(function Profile() {
  const { user } = useAuth()
  const { data: profile } = useUserProfile(user?.id ?? null)
  const { data: stats, isLoading: statsLoading } = useUserProfileStats(user?.id ?? null)
  const { data: bookmarks } = usePostBookmarks(user?.id)
  const togglePrivate = useTogglePrivate()
  const toast = useToast()

  // Handle privacy toggle with feedback
  const handleTogglePrivate = useCallback(() => {
    if (!user) return
    togglePrivate.mutate(user.id, {
      onSuccess: (isNowPrivate) => {
        toast.showSuccess(isNowPrivate ? 'Profile set to private' : 'Profile set to public')
      },
      onError: () => {
        toast.showError('Failed to update privacy setting')
      },
    })
  }, [user, togglePrivate, toast])

  // Navigate to Discussion with search query
  // 'threads' -> @username @op (only thread OPs)
  // 'replies' -> @username @replies (only replies)
  const handleSearchDiscussion = useCallback((filter: 'threads' | 'replies') => {
    if (!profile?.username) return
    const searchQuery = filter === 'threads'
      ? `@${profile.username} @op`
      : `@${profile.username} @replies`
    const event = new CustomEvent<SearchDiscussionEvent>('searchDiscussion', {
      detail: { searchQuery },
    })
    window.dispatchEvent(event)
  }, [profile])

  // Navigate to Discussion with bookmarks view
  const handleBookmarksClick = useCallback(() => {
    const event = new CustomEvent<SearchDiscussionEvent>('searchDiscussion', {
      detail: { searchQuery: '@bookmarked' },
    })
    window.dispatchEvent(event)
  }, [])

  if (!user) {
    return null
  }

  const displayName = profile?.username ?? (profile?.is_private ? 'Private Panda' : null)
  const avatarUrl = getAvatarUrl(
    profile?.avatar_url || null,
    displayName || user.email || 'User',
    profile?.avatar_path
  )

  return (
    <div className="profile-page">
      <div className="profile-container">
        {/* Avatar and Username */}
        <div className="profile-header">
          <img src={avatarUrl} alt="" className="profile-avatar" />
          <div className="profile-username-section">
            <UsernameEditor username={displayName ?? undefined} userId={user.id} />
          </div>
        </div>

        {/* Stats */}
        <div className="profile-stats">
          <h3 className="profile-section-title">Your Stats</h3>
          {statsLoading ? (
            <LoadingSpinner />
          ) : (
            <div className="profile-stats-grid">
              <button className="profile-stat clickable" onClick={() => handleSearchDiscussion('threads')}>
                <FileText size={20} />
                <div className="profile-stat-info">
                  <span className="profile-stat-value">{stats?.threadCount ?? 0}</span>
                  <span className="profile-stat-label">Threads</span>
                </div>
              </button>
              <button className="profile-stat clickable" onClick={() => handleSearchDiscussion('replies')}>
                <MessageCircle size={20} />
                <div className="profile-stat-info">
                  <span className="profile-stat-value">{stats?.postCount ?? 0}</span>
                  <span className="profile-stat-label">Replies</span>
                </div>
              </button>
              <div className="profile-stat">
                <img src={happyPanda} alt="" className="profile-stat-icon" />
                <div className="profile-stat-info">
                  <span className="profile-stat-value">{stats?.upvotesReceived ?? 0}</span>
                  <span className="profile-stat-label">Upvotes</span>
                </div>
              </div>
              <div className="profile-stat">
                <img src={sadPanda} alt="" className="profile-stat-icon" />
                <div className="profile-stat-info">
                  <span className="profile-stat-value">{stats?.downvotesReceived ?? 0}</span>
                  <span className="profile-stat-label">Downvotes</span>
                </div>
              </div>
              <button className="profile-stat clickable" onClick={handleBookmarksClick}>
                <Bookmark size={20} />
                <div className="profile-stat-info">
                  <span className="profile-stat-value">{bookmarks?.size ?? 0}</span>
                  <span className="profile-stat-label">Bookmarks</span>
                </div>
              </button>
            </div>
          )}
        </div>

        {/* Privacy Settings */}
        <div className="profile-privacy">
          <h3 className="profile-section-title">Privacy</h3>
          <button
            className={`profile-privacy-toggle ${profile?.is_private ? 'private' : 'public'}`}
            onClick={handleTogglePrivate}
            disabled={togglePrivate.isPending}
          >
            {togglePrivate.isPending ? (
              <ButtonSpinner size={20} />
            ) : profile?.is_private ? (
              <EyeOff size={20} />
            ) : (
              <Eye size={20} />
            )}
            <div className="profile-privacy-info">
              <span className="profile-privacy-status">
                {profile?.is_private ? 'Private Profile' : 'Public Profile'}
              </span>
              <span className="profile-privacy-desc">
                {profile?.is_private
                  ? 'Other users cannot see your posts and stats'
                  : 'Other users can see your posts and stats'}
              </span>
            </div>
          </button>
        </div>
      </div>
    </div>
  )
})
