import { useState, useRef, useEffect, useCallback } from 'react'
import { Pencil, Check, X, Loader2 } from 'lucide-react'
import { useUpdateUsername, useReservedUsernames, isUsernameAvailable, isReservedUsername } from '../../hooks/useUserProfile'

type UsernameStatus = 'idle' | 'checking' | 'available' | 'taken' | 'invalid' | 'same'

interface UsernameEditorProps {
  username: string | undefined
  userId: string
}

export function UsernameEditor({ username, userId }: UsernameEditorProps) {
  const updateUsernameMutation = useUpdateUsername()
  const { data: reservedUsernames } = useReservedUsernames()

  const [editing, setEditing] = useState(false)
  // Only track edited value when in edit mode; display value comes from props
  const [editedUsername, setEditedUsername] = useState('')
  const [error, setError] = useState('')
  const [status, setStatus] = useState<UsernameStatus>('idle')

  const inputRef = useRef<HTMLInputElement>(null)
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const checkingUsernameRef = useRef<string>('')

  // The displayed/edited username depends on mode
  const newUsername = editing ? editedUsername : username || ''

  // Focus input when editing
  useEffect(() => {
    if (editing && inputRef.current) {
      inputRef.current.focus()
      inputRef.current.select()
    }
  }, [editing])

  // Cleanup timeout on unmount to prevent state updates after unmount
  useEffect(() => {
    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current)
      }
    }
  }, [])

  // Validate username format
  const validateUsername = useCallback((value: string): string | null => {
    if (!value.trim()) return 'Username cannot be empty'
    if (value.length < 3) return 'Username must be at least 3 characters'
    if (value.length > 30) return 'Username must be 30 characters or less'
    if (!/^[a-zA-Z0-9_]+$/.test(value)) return 'Only letters, numbers, and underscores'
    // Prevent confusing homograph-like patterns (l/I/1 or O/0 adjacency)
    if (/[lI1]{2,}|[O0]{2,}/.test(value)) return 'Avoid repeating similar-looking characters'
    // Block any username containing "moderator" or "admin"
    if (/moderator|admin/i.test(value)) return 'Username not available'
    // Only exact "PandaKeeper" allowed (no variants)
    if (/pandakeeper/i.test(value) && value.toLowerCase() !== 'pandakeeper') return 'Username not available'
    // Check reserved usernames - use generic message to avoid information leakage
    // If reservedUsernames hasn't loaded yet, skip client check (server will validate)
    if (reservedUsernames && isReservedUsername(value, reservedUsernames)) return 'Username not available'
    return null
  }, [reservedUsernames])

  // Check username availability (debounced)
  const checkUsernameAvailability = useCallback(
    async (value: string) => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current)
      }

      const trimmed = value.trim()

      // Same as current username
      if (trimmed === username) {
        setStatus('same')
        setError('')
        return
      }

      // Validate format first
      const validationError = validateUsername(trimmed)
      if (validationError) {
        setStatus('invalid')
        setError(validationError)
        return
      }

      // Show checking status
      setStatus('checking')
      setError('')
      checkingUsernameRef.current = trimmed

      // Debounce the API call
      debounceRef.current = setTimeout(async () => {
        try {
          const isAvailable = await isUsernameAvailable(trimmed)

          // Only update state if this is still the username we're checking
          if (checkingUsernameRef.current !== trimmed) return

          if (isAvailable) {
            setStatus('available')
            setError('')
          } else {
            setStatus('taken')
            setError('Username not available')
          }
        } catch {
          if (checkingUsernameRef.current === trimmed) {
            setStatus('idle')
            setError('Could not check availability')
          }
        }
      }, 300)
    },
    [username, validateUsername]
  )

  const handleChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value
    setEditedUsername(value)
    checkUsernameAvailability(value)
  }, [checkUsernameAvailability])

  const startEditing = useCallback(() => {
    setEditedUsername(username || '')
    setEditing(true)
    setError('')
    setStatus('same')
  }, [username])

  const cancelEditing = useCallback(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    setEditing(false)
    setEditedUsername('')
    setError('')
    setStatus('idle')
  }, [])

  const save = useCallback(async () => {
    const trimmed = newUsername.trim()

    // Can't save if not available or same as current
    if (status !== 'available') {
      if (status === 'same') {
        setEditing(false)
        return
      }
      if (status === 'checking') {
        setError('Please wait...')
        return
      }
      return
    }

    setEditing(false)

    updateUsernameMutation.mutate(
      { newUsername: trimmed, userId },
      {
        onSuccess: () => {
          setStatus('idle')
        },
        onError: (err) => {
          setEditing(true)
          if (err.message.includes('unique') || err.message.includes('duplicate')) {
            setError('Username already taken')
            setStatus('taken')
          } else {
            setError('Failed to save')
          }
        },
      }
    )
  }, [newUsername, status, userId, updateUsernameMutation])

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      save()
    } else if (e.key === 'Escape') {
      cancelEditing()
    }
  }, [save, cancelEditing])

  const saving = updateUsernameMutation.isPending

  return (
    <>
      <div className="auth-menu-row">
        {editing ? (
          <div className="auth-username-edit">
            <div className="auth-username-input-wrapper">
              <input
                ref={inputRef}
                type="text"
                value={newUsername}
                onChange={handleChange}
                onKeyDown={handleKeyDown}
                className={`auth-username-input ${error ? 'error' : ''} ${status === 'available' ? 'available' : ''}`}
                disabled={saving}
                maxLength={30}
              />
              {status === 'checking' && <Loader2 size={12} className="auth-username-status spin" />}
              {status === 'available' && (
                <Check size={12} className="auth-username-status available" />
              )}
            </div>
            <button
              className="auth-icon-btn save"
              onClick={save}
              disabled={saving || (status !== 'available' && status !== 'same')}
              aria-label={saving ? 'Saving username' : 'Save username'}
            >
              {saving ? <Loader2 size={14} className="spin" /> : <Check size={14} />}
            </button>
            <button className="auth-icon-btn cancel" onClick={cancelEditing} disabled={saving} aria-label="Cancel editing">
              <X size={14} />
            </button>
          </div>
        ) : (
          <div className="auth-username-display">
            <span>{username || 'Loading...'}</span>
            <button className="auth-icon-btn edit" onClick={startEditing} aria-label="Edit username">
              <Pencil size={12} />
            </button>
          </div>
        )}
      </div>
      {error && <div className="auth-username-error">{error}</div>}
    </>
  )
}
