import { useState, useMemo, useEffect, useCallback } from 'react'
import { QueryClient, QueryClientProvider, focusManager } from '@tanstack/react-query'
import { handleMutationError } from './lib/blockedUserHandler'
import { Header, type Tab } from './components/Header'
import { Footer } from './components/Footer'
import { ErrorBoundary } from './components/ErrorBoundary'
import { Discussion } from './pages/Discussion'
import { UserManagement } from './pages/UserManagement'
import { Chat } from './pages/Chat'
import { Profile } from './pages/Profile'
import { Notifications } from './pages/Notifications'
import { Terms } from './pages/Terms'
import { Placements } from './pages/Placements'
import { AlertBanner, ToastContainer } from './components/ui'
import { useAuth } from './hooks/useAuth'
import { ToastProvider } from './contexts/ToastContext'
import { useUnreadMessageCount } from './hooks/useChatQueries'
import { useNotificationCount } from './hooks/useNotificationQueries'
import { usePrefetchUsers } from './hooks/useUserQueries'
import { usePrefetchUserData } from './hooks/usePrefetchUserData'
import type { StartChatEvent } from './components/UserNameHover'
import type { SearchDiscussionEvent } from './components/AuthButton'
import type { Notification } from './types'
import { TreePine, Users, MessagesSquare, User, Bell, GraduationCap } from 'lucide-react'
import './styles/index.css'

// Configure React Query to use page visibility for focus detection
// This pauses polling when the browser tab is hidden
focusManager.setEventListener((handleFocus) => {
  const onVisibilityChange = () => {
    handleFocus(document.visibilityState === 'visible')
  }
  const onFocus = () => handleFocus(true)
  const onBlur = () => handleFocus(false)

  document.addEventListener('visibilitychange', onVisibilityChange)
  window.addEventListener('focus', onFocus)
  window.addEventListener('blur', onBlur)

  return () => {
    document.removeEventListener('visibilitychange', onVisibilityChange)
    window.removeEventListener('focus', onFocus)
    window.removeEventListener('blur', onBlur)
  }
})

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30 * 1000, // 30 seconds
      gcTime: 10 * 60 * 1000, // 10 minutes - increased for better cache retention
      refetchOnWindowFocus: false,
      retry: 2, // Limit retries to prevent excessive requests
    },
    mutations: {
      // Global mutation error handler - check if user is blocked on RLS errors
      onError: (error: Error) => {
        handleMutationError(error)
      },
    },
  },
})

const TAB_STORAGE_KEY = 'activeTab'

// Get initial tab from localStorage - called once at module load time
const getStoredTab = (): Tab => {
  try {
    const stored = localStorage.getItem(TAB_STORAGE_KEY)
    if (stored && ['discussion', 'chat', 'users', 'profile', 'notifications', 'placements'].includes(stored)) {
      return stored as Tab
    }
  } catch {
    // localStorage not available
  }
  return 'discussion'
}

// Compute initial tab at module load (before React renders)
const INITIAL_TAB = getStoredTab()

// Inner component that uses hooks (must be inside QueryClientProvider)
function AppContent() {
  const { user, isAdmin, loading: authLoading, authError, clearAuthError } = useAuth()
  const [activeTab, setActiveTab] = useState<Tab>(INITIAL_TAB)
  const [discussionResetKey, setDiscussionResetKey] = useState(0)
  const [chatResetKey, setChatResetKey] = useState(0)
  const [showTerms, setShowTerms] = useState(false)
  const [initialChatPartner, setInitialChatPartner] = useState<{
    id: string
    username: string
    avatar: string | null
    avatarPath?: string | null
  } | null>(null)
  const [initialDiscussionSearch, setInitialDiscussionSearch] = useState<{
    searchQuery: string
  } | null>(null)
  const [initialDiscussionNavigation, setInitialDiscussionNavigation] = useState<{
    threadId: number
    postId: number
    postParentId: number | null
  } | null>(null)

  // Persist tab to localStorage
  useEffect(() => {
    localStorage.setItem(TAB_STORAGE_KEY, activeTab)
  }, [activeTab])

  // React Query hooks for unread counts
  const { data: chatUnread } = useUnreadMessageCount(user?.id || null)
  const { data: notificationCount } = useNotificationCount(user?.id || null)
  const prefetchUsers = usePrefetchUsers()
  const prefetchUserData = usePrefetchUserData()

  // Prefetch user data on login (bookmarks, conversations, profile)
  useEffect(() => {
    if (user?.id) {
      prefetchUserData(user.id)
    }
  }, [user?.id, prefetchUserData])

  // Prefetch users on hover over Users tab
  const handleUsersHover = useCallback(() => {
    if (isAdmin) {
      prefetchUsers(1, 50, '') // Prefetch first page with default settings
    }
  }, [isAdmin, prefetchUsers])

  // Listen for chat start events from username hover
  const handleStartChatEvent = useCallback((e: Event) => {
    const customEvent = e as CustomEvent<StartChatEvent>
    const { userId, username, avatar, avatarPath } = customEvent.detail
    setInitialChatPartner({ id: userId, username, avatar, avatarPath })
    setActiveTab('chat')
    setShowTerms(false)
  }, [])

  useEffect(() => {
    window.addEventListener('startChatWithUser', handleStartChatEvent)
    return () => {
      window.removeEventListener('startChatWithUser', handleStartChatEvent)
    }
  }, [handleStartChatEvent])

  // Clear initial chat partner after Chat component consumes it
  const clearInitialChatPartner = useCallback(() => {
    setInitialChatPartner(null)
  }, [])

  // Listen for Discussion search events
  const handleSearchDiscussionEvent = useCallback((e: Event) => {
    const customEvent = e as CustomEvent<SearchDiscussionEvent>
    const { searchQuery } = customEvent.detail
    setInitialDiscussionSearch({ searchQuery })
    setActiveTab('discussion')
    setShowTerms(false)
  }, [])

  useEffect(() => {
    window.addEventListener('searchDiscussion', handleSearchDiscussionEvent)
    return () => {
      window.removeEventListener('searchDiscussion', handleSearchDiscussionEvent)
    }
  }, [handleSearchDiscussionEvent])

  // Clear initial search after Discussion component consumes it
  const clearInitialDiscussionSearch = useCallback(() => {
    setInitialDiscussionSearch(null)
  }, [])

  // Clear initial navigation after Discussion component consumes it
  const clearInitialDiscussionNavigation = useCallback(() => {
    setInitialDiscussionNavigation(null)
  }, [])

  // Track if initial load is complete (active tab has loaded)
  const [initialLoadComplete, setInitialLoadComplete] = useState(false)

  // Compute effective tab - use stored tab if logged in, else discussion
  const effectiveTab = useMemo(() => {
    // While auth is loading, allow public tabs (discussion/placements)
    if (authLoading) {
      return activeTab === 'placements' ? 'placements' : 'discussion'
    }
    // If logged in, use the active tab (with admin check for users tab)
    if (user) {
      if (activeTab === 'users' && !isAdmin) {
        return 'discussion'
      }
      return activeTab
    }
    // Not logged in - allow public tabs only
    return activeTab === 'placements' ? 'placements' : 'discussion'
  }, [user, isAdmin, activeTab, authLoading])

  // After a short delay, allow background tabs to mount
  // This ensures the active tab gets network priority first
  useEffect(() => {
    const timer = setTimeout(() => {
      setInitialLoadComplete(true)
    }, 500) // Wait 500ms for active tab to start loading
    return () => clearTimeout(timer)
  }, [])

  // Helper to check if a tab should be mounted
  // Active tab mounts immediately, others wait for initial load
  const shouldMountTab = (tab: Tab) => tab === effectiveTab || initialLoadComplete

  const handleDiscussionClick = () => {
    // Only reset to list if already on discussion tab (acts as "go home")
    if (activeTab === 'discussion') {
      setDiscussionResetKey((k) => k + 1)
    }
    setActiveTab('discussion')
  }

  const handleChatClick = () => {
    setChatResetKey((k) => k + 1)
    setActiveTab('chat')
    // Note: Badge clears automatically when Chat component marks messages as read
  }

  const handleNotificationsClick = () => {
    setActiveTab('notifications')
  }

  // Handle navigation from notification to post
  const handleNavigateToPost = useCallback((notification: Notification) => {
    // Navigate to the post - post_parent_id determines view:
    // null = Thread View (OP or direct reply), non-null = Replies View
    setInitialDiscussionNavigation({
      threadId: notification.thread_id,
      postId: notification.post_id,
      postParentId: notification.post_parent_id,
    })
    setActiveTab('discussion')
    setShowTerms(false)
  }, [])

  const tabsNav = (className: string) => (
    <nav className={`side-tabs ${className} ${showTerms ? 'hidden' : ''}`}>
      <button
        className={`side-tab ${activeTab === 'discussion' ? 'active' : ''}`}
        onClick={handleDiscussionClick}
      >
        <TreePine size={18} />
        <span className="side-tab-label">Grove</span>
      </button>
      <button
        className={`side-tab ${activeTab === 'placements' ? 'active' : ''}`}
        onClick={() => setActiveTab('placements')}
      >
        <GraduationCap size={18} />
        <span className="side-tab-label">Jobs</span>
      </button>
      {user && (
        <button
          className={`side-tab ${activeTab === 'notifications' ? 'active' : ''}`}
          onClick={handleNotificationsClick}
        >
          <Bell size={18} />
          <span className="side-tab-label">Alerts</span>
          {notificationCount > 0 && <span className="side-tab-badge">{notificationCount}</span>}
        </button>
      )}
      {user && (
        <button
          className={`side-tab ${activeTab === 'chat' ? 'active' : ''}`}
          onClick={handleChatClick}
        >
          <MessagesSquare size={18} />
          <span className="side-tab-label">Den</span>
          {chatUnread > 0 && <span className="side-tab-badge">{chatUnread}</span>}
        </button>
      )}
      {isAdmin && (
        <button
          className={`side-tab ${activeTab === 'users' ? 'active' : ''}`}
          onClick={() => setActiveTab('users')}
          onMouseEnter={handleUsersHover}
        >
          <Users size={18} />
          <span className="side-tab-label">Pandas</span>
        </button>
      )}
      {user && (
        <button
          className={`side-tab ${activeTab === 'profile' ? 'active' : ''}`}
          onClick={() => setActiveTab('profile')}
        >
          <User size={18} />
          <span className="side-tab-label">Profile</span>
        </button>
      )}
    </nav>
  )

  return (
    <div className="app">
      <Header />

      {/* Auth error banner */}
      {authError && (
        <AlertBanner
          message={authError}
          type="error"
          onDismiss={clearAuthError}
          className="auth-error-banner"
        />
      )}

      <div className="app-body">
        {tabsNav('side-tabs-desktop')}

        <div className="app-content">
          {/* Only mount tabs when they've been visited - prioritizes active tab's network requests */}
          {shouldMountTab('discussion') && (
            <div className={`tab-content ${effectiveTab !== 'discussion' || showTerms ? 'hidden' : ''}`}>
              <ErrorBoundary fallbackMessage="Failed to load grove. Please try again.">
                <Discussion
                  resetToList={discussionResetKey > 0 ? discussionResetKey : undefined}
                  isActive={effectiveTab === 'discussion' && !showTerms}
                  initialSearch={initialDiscussionSearch}
                  onInitialSearchConsumed={clearInitialDiscussionSearch}
                  initialNavigation={initialDiscussionNavigation}
                  onInitialNavigationConsumed={clearInitialDiscussionNavigation}
                />
              </ErrorBoundary>
            </div>
          )}

          {user && shouldMountTab('chat') && (
            <div className={`tab-content ${effectiveTab !== 'chat' || showTerms ? 'hidden' : ''}`}>
              <ErrorBoundary fallbackMessage="Failed to load chat. Please try again.">
                <Chat
                  initialPartner={initialChatPartner}
                  onInitialPartnerConsumed={clearInitialChatPartner}
                  resetToList={chatResetKey > 0 ? chatResetKey : undefined}
                />
              </ErrorBoundary>
            </div>
          )}

          {isAdmin && shouldMountTab('users') && (
            <div className={`tab-content ${effectiveTab !== 'users' || showTerms ? 'hidden' : ''}`}>
              <ErrorBoundary fallbackMessage="Failed to load user management. Please try again.">
                <UserManagement
                  isActive={effectiveTab === 'users' && !showTerms}
                />
              </ErrorBoundary>
            </div>
          )}

          {user && shouldMountTab('profile') && (
            <div className={`tab-content ${effectiveTab !== 'profile' || showTerms ? 'hidden' : ''}`}>
              <ErrorBoundary fallbackMessage="Failed to load profile. Please try again.">
                <Profile />
              </ErrorBoundary>
            </div>
          )}

          {user && shouldMountTab('notifications') && (
            <div className={`tab-content ${effectiveTab !== 'notifications' || showTerms ? 'hidden' : ''}`}>
              <ErrorBoundary fallbackMessage="Failed to load notifications. Please try again.">
                <Notifications onNavigateToPost={handleNavigateToPost} />
              </ErrorBoundary>
            </div>
          )}

          {shouldMountTab('placements') && (
            <div className={`tab-content ${effectiveTab !== 'placements' || showTerms ? 'hidden' : ''}`}>
              <ErrorBoundary fallbackMessage="Failed to load placements. Please try again.">
                <Placements isActive={effectiveTab === 'placements' && !showTerms} />
              </ErrorBoundary>
            </div>
          )}

          {showTerms && (
            <div className="tab-content">
              <Terms onBack={() => setShowTerms(false)} />
            </div>
          )}

        </div>
      </div>

      <Footer showTerms={showTerms} onShowTerms={() => setShowTerms(true)} />
    </div>
  )
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <AppContent />
        <ToastContainer />
      </ToastProvider>
    </QueryClientProvider>
  )
}

export default App
