import { useState, useRef, useCallback, memo } from 'react'
import { LogIn, LogOut, User, ChevronDown, Loader2 } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import { useUserProfile } from '../hooks/useUserProfile'
import { useClickOutside } from '../hooks/useClickOutside'
import { cleanOAuthHash } from '../utils/url'
import { getAvatarUrl } from '../utils/format'

// Custom event type for searching Discussion
export interface SearchDiscussionEvent {
  searchQuery: string
}

export const AuthButton = memo(function AuthButton() {
  const { user, loading, signInWithGoogle, signOut } = useAuth()
  const { data: profile } = useUserProfile(user?.id ?? null)

  const [dropdownOpen, setDropdownOpen] = useState(false)
  const [signingIn, setSigningIn] = useState(false)
  const [signInError, setSignInError] = useState<string | null>(null)
  const [avatarError, setAvatarError] = useState(false)

  const dropdownRef = useRef<HTMLDivElement>(null)

  // Close dropdown on outside click
  useClickOutside(dropdownRef, () => setDropdownOpen(false), dropdownOpen)

  const handleSignIn = useCallback(async () => {
    setSigningIn(true)
    setSignInError(null)
    try {
      await signInWithGoogle()
    } catch {
      setSignInError('Failed to sign in. Please try again.')
      setTimeout(() => setSignInError(null), 5000)
    } finally {
      setSigningIn(false)
    }
  }, [signInWithGoogle])

  const handleSignOut = useCallback(async () => {
    setDropdownOpen(false)
    await signOut()
    cleanOAuthHash()
  }, [signOut])

  if (loading) {
    return (
      <div className="auth-button auth-loading">
        <div className="auth-spinner" />
      </div>
    )
  }

  if (!user) {
    return (
      <div className="auth-sign-in-container">
        {signInError && <div className="auth-sign-in-error">{signInError}</div>}
        <button className="auth-button auth-sign-in" onClick={handleSignIn} disabled={signingIn}>
          <LogIn size={18} />
          <span>{signingIn ? 'Signing in...' : 'Sign in'}</span>
        </button>
      </div>
    )
  }

  const displayName = profile?.username ?? (profile?.is_private ? 'Private Panda' : null)
  const avatarUrl = getAvatarUrl(
    profile?.avatar_url || null,
    displayName || user.email || 'User',
    profile?.avatar_path
  )

  return (
    <div className="auth-dropdown" ref={dropdownRef}>
      <button className="auth-button auth-user" onClick={() => setDropdownOpen(!dropdownOpen)}>
        {!avatarError ? (
          <img
            src={avatarUrl}
            alt=""
            className="auth-avatar"
            onError={() => setAvatarError(true)}
          />
        ) : (
          <User size={18} />
        )}
        {displayName ? (
          <span className="auth-name">{displayName}</span>
        ) : (
          <Loader2 size={14} className="spin" />
        )}
        <ChevronDown size={14} className={`auth-chevron ${dropdownOpen ? 'open' : ''}`} />
      </button>

      {dropdownOpen && (
        <div className="auth-menu">
          <button className="auth-menu-item" onClick={handleSignOut}>
            <LogOut size={16} />
            <span>Sign out</span>
          </button>
        </div>
      )}
    </div>
  )
})
