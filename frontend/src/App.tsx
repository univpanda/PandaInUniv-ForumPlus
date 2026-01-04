import { useEffect, useCallback, useMemo } from 'react'
import { QueryClient, QueryClientProvider, focusManager } from '@tanstack/react-query'
import { handleMutationError } from './lib/blockedUserHandler'
import { Header } from './components/Header'
import { Sidebar } from './components/layout/Sidebar'
import { MobileNavigation } from './components/layout/MobileNavigation'
import { Footer } from './components/Footer'
import {
  BrowserRouter,
  Route,
  Routes,
  useNavigate,
  useLocation,
  useSearchParams,
} from 'react-router-dom'
import { ErrorBoundary } from './components/ErrorBoundary'
import { Discussion } from './pages/Discussion'
import { UserManagement } from './pages/UserManagement'
import { Chat } from './pages/Chat'
import { Profile } from './pages/Profile'
import { Notifications } from './pages/Notifications'
import { Terms } from './pages/Terms'
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

// Wrapper Components to bridge Router state to Component props

function DiscussionWrapper() {
  const location = useLocation()
  const [searchParams] = useSearchParams()
  const state = location.state as {
    initialNavigation?: { threadId: number; postId: number; postParentId: number | null }
    resetToList?: boolean
  } | null

  const searchQuery = searchParams.get('q')
  const initialSearch = useMemo(() => (searchQuery ? { searchQuery } : null), [searchQuery])

  return (
    <ErrorBoundary fallbackMessage="Failed to load grove. Please try again.">
      <Discussion
        resetToList={state?.resetToList ? Date.now() : undefined}
        initialSearch={initialSearch}
        onInitialSearchConsumed={() => {}}
        initialNavigation={state?.initialNavigation}
        onInitialNavigationConsumed={() => {}}
      />
    </ErrorBoundary>
  )
}

function ChatWrapper() {
  const location = useLocation()
  const state = location.state as {
    initialPartner?: { id: string; username: string; avatar: string | null }
    resetToList?: boolean
  } | null

  return (
    <ErrorBoundary fallbackMessage="Failed to load chat. Please try again.">
      <Chat
        initialPartner={state?.initialPartner}
        onInitialPartnerConsumed={() => {}}
        resetToList={state?.resetToList ? Date.now() : undefined}
      />
    </ErrorBoundary>
  )
}

function NotificationsWrapper() {
  const navigate = useNavigate()

  const handleNavigateToPost = useCallback(
    (notification: Notification) => {
      navigate('/', {
        state: {
          initialNavigation: {
            threadId: notification.thread_id,
            postId: notification.post_id,
            postParentId: notification.post_parent_id,
          },
        },
      })
    },
    [navigate]
  )

  return (
    <ErrorBoundary fallbackMessage="Failed to load notifications. Please try again.">
      <Notifications onNavigateToPost={handleNavigateToPost} />
    </ErrorBoundary>
  )
}

// Inner component that uses hooks (must be inside QueryClientProvider and BrowserRouter)
function AppContent() {
  const { user, isAdmin, authError, clearAuthError } = useAuth()
  const navigate = useNavigate()

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
  const handleStartChatEvent = useCallback(
    (e: Event) => {
      const customEvent = e as CustomEvent<StartChatEvent>
      const { userId, username, avatar } = customEvent.detail
      navigate('/chat', {
        state: {
          initialPartner: { id: userId, username, avatar },
        },
      })
    },
    [navigate]
  )

  useEffect(() => {
    window.addEventListener('startChatWithUser', handleStartChatEvent)
    return () => {
      window.removeEventListener('startChatWithUser', handleStartChatEvent)
    }
  }, [handleStartChatEvent])

  // Listen for Discussion search events
  const handleSearchDiscussionEvent = useCallback(
    (e: Event) => {
      const customEvent = e as CustomEvent<SearchDiscussionEvent>
      const { searchQuery } = customEvent.detail
      // Use URL search params for search
      navigate(`/?q=${encodeURIComponent(searchQuery)}`)
    },
    [navigate]
  )

  useEffect(() => {
    window.addEventListener('searchDiscussion', handleSearchDiscussionEvent)
    return () => {
      window.removeEventListener('searchDiscussion', handleSearchDiscussionEvent)
    }
  }, [handleSearchDiscussionEvent])

  return (
    <div className="app">
      <Sidebar
        user={user}
        isAdmin={isAdmin}
        chatUnread={chatUnread || 0}
        notificationCount={notificationCount || 0}
        onUsersHover={handleUsersHover}
      />
      <Header
        user={user}
        isAdmin={isAdmin}
        chatUnread={chatUnread || 0}
        notificationCount={notificationCount || 0}
        onUsersHover={handleUsersHover}
      />
      <MobileNavigation
        user={user}
        isAdmin={isAdmin}
        chatUnread={chatUnread || 0}
        notificationCount={notificationCount || 0}
        onUsersHover={handleUsersHover}
      />

      {/* Auth error banner */}
      {authError && (
        <AlertBanner
          message={authError}
          type="error"
          onDismiss={clearAuthError}
          className="auth-error-banner"
        />
      )}

      <main className="main-content">
        <Routes>
          <Route path="/" element={<DiscussionWrapper />} />
          {user && <Route path="/chat" element={<ChatWrapper />} />}
          {isAdmin && (
            <Route
              path="/users"
              element={
                <ErrorBoundary fallbackMessage="Failed to load user management. Please try again.">
                  <UserManagement isActive={true} />
                </ErrorBoundary>
              }
            />
          )}
          {user && (
            <Route
              path="/profile"
              element={
                <ErrorBoundary fallbackMessage="Failed to load profile. Please try again.">
                  <Profile />
                </ErrorBoundary>
              }
            />
          )}
          {user && <Route path="/notifications" element={<NotificationsWrapper />} />}
          <Route path="/terms" element={<Terms />} />
        </Routes>
      </main>

      <Footer />
    </div>
  )
}

function App() {
  return (
    <BrowserRouter>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <Routes>
            <Route path="*" element={<AppContent />} />
          </Routes>
          <ToastContainer />
        </ToastProvider>
      </QueryClientProvider>
    </BrowserRouter>
  )
}

export default App
