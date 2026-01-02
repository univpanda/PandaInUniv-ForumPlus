import { useState, useEffect, useRef } from 'react'
import {
  Shield,
  ShieldOff,
  Ban,
  CheckCircle,
  User,
  MessageSquare,
  FileText,
  Clock,
  MapPin,
  Trash2,
  AlertTriangle,
  ThumbsUp,
  ThumbsDown,
  Mail,
  UserCircle,
  Copy,
} from 'lucide-react'
import { formatDateAbsolute, formatRelativeTime } from '../utils/format'
import { useAuth } from '../hooks/useAuth'
import { usePaginatedUsers, usePrefetchUsers, useToggleAdmin, useToggleBlock, useDeleteUser } from '../hooks/useUserQueries'
import { useToast } from '../contexts/ToastContext'
import {
  LoadingSpinner,
  ButtonSpinner,
  EmptyState,
  SearchInput,
  QueryErrorBanner,
} from '../components/ui'
import { Pagination } from '../components/Pagination'
import { PAGE_SIZE } from '../utils/constants'

interface UserManagementProps {
  isActive?: boolean
}

// Persist page size to localStorage
const PAGE_SIZE_KEY = 'userManagement.pageSize'

// Panda avatar prompt for AI image generation
const PANDA_AVATAR_PROMPT = `2D vector, modern cartoon-style panda avatars at 256×256 pixels.

Nerd Panda
This panda is a fountain of knowledge, always lost in thought or a good book. It's perfect for showing off your intellectual and curious side.
Expression: A thoughtful, focused look with a gentle, intelligent smile. Its eyes are wide with curiosity behind a pair of stylish glasses.
Accessories: A pair of large, round spectacles perched on its nose. It's holding a thick, leather-bound book, with one paw marking a page.
Vibe: Studious, cozy, and endearing. The background could feature a library bookshelf, floating mathematical formulas, or a chalkboard filled with doodles.

Gamer Panda
Intensely focused and lightning-fast, this panda is in the zone and ready to win. It's all about strategy, fun, and a little bit of competitive fire.
Expression: Determined eyes glued to an off-screen monitor, with the glow of the screen reflected in its eyes. Its mouth is slightly open in concentration.
Accessories: A sleek gaming headset with a microphone arm flipped up. Its paws are expertly gripping a video game controller.
Vibe: High-energy, digital, and modern. The background could be a neon-lit gaming setup, pixel art, or abstract glowing data streams.

Chef Panda
A culinary genius whose passion is creating the perfect bamboo dish. This panda represents a love for food, creativity, and simple pleasures.
Expression: A look of pure delight and satisfaction, maybe with its tongue just peeking out to taste something delicious. Its cheeks are full and happy.
Accessories: A tall, white chef's hat (a toque) sits proudly on its head. It might be holding a wooden spoon or expertly balancing a stack of gourmet bamboo shoots.
Vibe: Warm, hearty, and delicious. The background could be a cozy kitchen, a pattern of tasty-looking food, or gentle steam rising.

Grumpy Panda
This panda has had enough of everyone's nonsense. It's comically moody and perfect for those days you just want to be left alone with your bamboo.
Expression: A deep, furrowed brow and a downturned mouth in a permanent pout. Its eyes are narrowed in disapproval.
Pose: Arms crossed firmly over its fluffy chest. It might be glaring slightly to the side, unimpressed by what it sees.
Vibe: Sassy, humorous, and relatable. The background could be a single, dark rain cloud hovering just over its head or a stark, minimalist color to emphasize its mood.

Artist Panda
This panda sees the world as a canvas and isn't afraid to get a little messy for its art. It embodies creativity, imagination, and passion.
Expression: A dreamy, inspired gaze, looking off into the distance as an idea strikes. A small, knowing smile plays on its lips.
Accessories: A jaunty beret tilted to one side and a few colorful paint smudges on its cheek and fur. It's holding a paintbrush dripping with color.
Vibe: Creative, free-spirited, and colorful. The background should be a splash of abstract paint, a half-finished canvas, or a swirl of light colors.

Superhero Panda
Leaping into action, this panda is here to save the day! It's all about courage, strength, and doing the right thing (which probably involves protecting the bamboo forest).
Expression: A brave and determined look, with a confident, heroic grin.
Accessories: A classic superhero mask over its eyes (which comically fits over its natural black patches) and a bold, flowing cape. A custom emblem, like a bamboo leaf or the letter "P," is displayed proudly on its chest.
Vibe: Action-packed, powerful, and fun. The background could be a dynamic "POW!" or "BAM!" comic book effect, a city skyline at night, or dramatic speed lines.

Zen Panda
The master of mindfulness and inner peace. This panda has transcended the need for anything but the present moment and a gentle breeze.
Expression: Eyes are peacefully closed in meditation, with a serene, centered smile. Its entire face exudes calm.
Pose: Sitting in a classic meditative pose (as much as a panda can), with paws resting gently on its knees.
Vibe: Tranquil, balanced, and spiritual. The background could be a serene bamboo forest, a calming zen garden with stacked stones, or a softly glowing aura.`

function getStoredPageSize(): number {
  try {
    const stored = localStorage.getItem(PAGE_SIZE_KEY)
    if (stored) {
      const parsed = parseInt(stored, 10)
      if (!isNaN(parsed) && parsed >= 1 && parsed <= 500) {
        return parsed
      }
    }
  } catch {
    // localStorage not available
  }
  return PAGE_SIZE.USERS
}

export function UserManagement({ isActive = true }: UserManagementProps) {
  const { isAdmin } = useAuth()
  const [searchQuery, setSearchQuery] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')
  const [currentPage, setCurrentPage] = useState(1)
  const initialPageSize = getStoredPageSize()
  const [pageSize, setPageSize] = useState<number>(initialPageSize)
  const [pageSizeInput, setPageSizeInput] = useState<string>(String(initialPageSize))
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const toast = useToast()
  const prefetchUsers = usePrefetchUsers()

  // Debounce search input for server-side search
  useEffect(() => {
    if (debounceRef.current) {
      clearTimeout(debounceRef.current)
    }
    debounceRef.current = setTimeout(() => {
      setDebouncedSearch(searchQuery)
      setCurrentPage(1) // Reset to first page on search
    }, 300)

    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current)
      }
    }
  }, [searchQuery])

  // Server-side pagination - require isAdmin for defense-in-depth
  const { data, isLoading, isFetching, isError, refetch } = usePaginatedUsers(
    isAdmin,
    currentPage,
    pageSize,
    debouncedSearch,
    { enabled: isActive }
  )

  // Extract users and total count from response
  const users = data?.users ?? []
  const totalCount = data?.totalCount ?? 0
  const totalPages = Math.ceil(totalCount / pageSize)

  // Auto-navigate to last page if current page exceeds total (e.g., after deletion)
  useEffect(() => {
    if (totalPages > 0 && currentPage > totalPages) {
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setCurrentPage(totalPages)
    }
  }, [totalPages, currentPage])

  // Prefetch page 2 on initial load (when on page 1 and data loads)
  const hasPrefetchedInitial = useRef(false)
  useEffect(() => {
    if (!hasPrefetchedInitial.current && !isLoading && totalPages > 1 && currentPage === 1) {
      hasPrefetchedInitial.current = true
      prefetchUsers(2, pageSize, debouncedSearch)
    }
  }, [isLoading, totalPages, currentPage, pageSize, debouncedSearch, prefetchUsers])

  const handlePageSizeChange = (newSize: number) => {
    setPageSize(newSize)
    setPageSizeInput(String(newSize))
    setCurrentPage(1) // Reset to first page when changing page size
    // Persist to localStorage
    try {
      localStorage.setItem(PAGE_SIZE_KEY, String(newSize))
    } catch {
      // localStorage not available
    }
  }

  const handlePageSizeBlur = () => {
    const val = parseInt(pageSizeInput, 10)
    if (!isNaN(val) && val >= 1 && val <= 500) {
      if (val !== pageSize) {
        handlePageSizeChange(val)
      }
    } else {
      // Reset input to current valid value
      setPageSizeInput(String(pageSize))
    }
  }

  const toggleAdminMutation = useToggleAdmin()
  const toggleBlockMutation = useToggleBlock()
  const deleteUserMutation = useDeleteUser()

  // Track which user has an action in progress
  const actionLoading =
    toggleAdminMutation.variables?.userId ||
    toggleBlockMutation.variables?.userId ||
    deleteUserMutation.variables?.userId ||
    null

  const handleToggleAdmin = (userId: string, currentRole: string, username: string) => {
    const isCurrentlyAdmin = currentRole === 'admin'
    const action = isCurrentlyAdmin ? 'remove admin privileges from' : 'grant admin privileges to'
    if (!confirm(`Are you sure you want to ${action} "${username}"?`)) {
      return
    }
    toggleAdminMutation.mutate(
      { userId, currentRole },
      {
        onSuccess: () => {
          toast.showSuccess(
            isCurrentlyAdmin
              ? `Removed admin privileges from ${username}`
              : `Granted admin privileges to ${username}`
          )
        },
        onError: (error) => {
          toast.showError(
            `Failed to update role: ${error instanceof Error ? error.message : 'Unknown error'}`
          )
        },
      }
    )
  }

  const handleToggleBlock = (userId: string, currentlyBlocked: boolean, username: string) => {
    const action = currentlyBlocked ? 'unblock' : 'block'
    if (!confirm(`Are you sure you want to ${action} "${username}"?`)) {
      return
    }
    toggleBlockMutation.mutate(
      { userId, currentlyBlocked },
      {
        onSuccess: () => {
          toast.showSuccess(
            currentlyBlocked ? `Unblocked ${username}` : `Blocked ${username}`
          )
        },
        onError: (error) => {
          toast.showError(
            `Failed to ${action} user: ${error instanceof Error ? error.message : 'Unknown error'}`
          )
        },
      }
    )
  }

  const handleDeleteUser = (userId: string, username: string) => {
    if (
      !confirm(
        `Are you sure you want to delete "${username}"? This will remove their login access but keep their posts.`
      )
    ) {
      return
    }
    deleteUserMutation.mutate(
      { userId },
      {
        onSuccess: () => {
          toast.showSuccess(`Deleted user ${username}`)
        },
        onError: (error) => {
          toast.showError(
            `Failed to delete user: ${error instanceof Error ? error.message : 'Unknown error'}`
          )
        },
      }
    )
  }

  const handlePageChange = (page: number) => {
    const prevPage = currentPage
    setCurrentPage(page)
    // Prefetch the adjacent page in the direction of navigation
    // (the other adjacent page was likely the one we came from)
    if (page > prevPage && page < totalPages) {
      // Moving forward - prefetch next
      prefetchUsers(page + 1, pageSize, debouncedSearch)
    } else if (page < prevPage && page > 1) {
      // Moving backward - prefetch previous
      prefetchUsers(page - 1, pageSize, debouncedSearch)
    } else {
      // Jump (e.g., first/last page click) - prefetch both adjacent
      if (page > 1) {
        prefetchUsers(page - 1, pageSize, debouncedSearch)
      }
      if (page < totalPages) {
        prefetchUsers(page + 1, pageSize, debouncedSearch)
      }
    }
  }

  return (
    <div className="user-management">
      <div className="user-management-header">
        <SearchInput
          value={searchQuery}
          onChange={setSearchQuery}
          placeholder="Search username or email..."
          className="user-management-search"
        />
        <input
          type="number"
          min="1"
          max="500"
          className="page-size-input"
          value={pageSizeInput}
          onChange={(e) => setPageSizeInput(e.target.value)}
          onBlur={handlePageSizeBlur}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              handlePageSizeBlur()
              e.currentTarget.blur()
            }
          }}
          title="Users per page"
        />
      </div>
      {totalPages > 1 && (
        <Pagination
          currentPage={currentPage}
          totalPages={totalPages}
          onPageChange={handlePageChange}
          totalItems={totalCount}
          itemsPerPage={pageSize}
          itemName="users"
        />
      )}

      {isLoading ? (
        <LoadingSpinner className="user-management-loading" />
      ) : isError ? (
        <QueryErrorBanner
          message="Failed to load users. Please try again."
          onRetry={() => refetch()}
        />
      ) : users.length === 0 ? (
        <EmptyState icon={User} description="No users found" className="user-management-empty" />
      ) : (
        <>
          <div className={`user-list ${isFetching ? 'loading' : ''}`}>
            <div className="user-list-header">
              <span className="user-col-avatar">
                <button
                  className="copy-prompt-btn"
                  title="Copy panda avatar prompt"
                  onClick={() => {
                    navigator.clipboard.writeText(PANDA_AVATAR_PROMPT)
                    toast.showSuccess('Avatar prompt copied to clipboard')
                  }}
                >
                  <Copy size={14} />
                </button>
              </span>
              <span className="user-col-name">User</span>
              <span className="user-col-info">Information</span>
              <span className="user-col-engagement">Engagement</span>
              <span className="user-col-votes-recv">Votes Recv</span>
              <span className="user-col-activity">Last Activity</span>
              <span className="user-col-status">Status</span>
              <span className="user-col-actions">Actions</span>
            </div>
            {users.map((user) => (
              <div
                key={user.id}
                className={`user-row ${user.is_blocked ? 'blocked' : ''} ${user.is_deleted ? 'deleted' : ''}`}
              >
                <div className="user-col-avatar">
                  {user.avatar_url ? (
                    <img
                      src={user.avatar_url}
                      alt=""
                      className="user-avatar"
                      onError={(e) => {
                        e.currentTarget.style.display = 'none'
                        e.currentTarget.nextElementSibling?.classList.remove('hidden')
                      }}
                    />
                  ) : null}
                  <div className={`user-avatar-placeholder ${user.avatar_url ? 'hidden' : ''}`}>
                    <User size={18} />
                  </div>
                </div>
                <div className="user-col-name">
                  <span className="user-username">{user.username}</span>
                  <span className="user-joined">Joined {formatDateAbsolute(user.created_at)}</span>
                </div>
                <div className="user-col-info">
                  <span className="user-email" title={user.email || 'No email'}>
                    <Mail size={13} />
                    {user.email || '—'}
                  </span>
                  <span className="user-fullname" title={user.full_name || 'No name'}>
                    <UserCircle size={13} />
                    {user.full_name || '—'}
                  </span>
                </div>
                <div className="user-col-engagement">
                  <div className="engagement-row">
                    <span className="engagement-stat" title="Threads created">
                      <FileText size={14} />
                      {user.thread_count}
                    </span>
                    <span className="engagement-stat" title="Total posts (threads + replies)">
                      <MessageSquare size={14} />
                      {user.post_count}
                    </span>
                    {user.deleted_count > 0 && (
                      <span className="engagement-stat deleted" title="Deleted posts">
                        <Trash2 size={14} />
                        {user.deleted_count}
                      </span>
                    )}
                    {user.flagged_count > 0 && (
                      <button
                        className="engagement-stat flagged clickable"
                        title="View flagged posts"
                        onClick={() => {
                          window.dispatchEvent(new CustomEvent('searchDiscussion', {
                            detail: { searchQuery: `@${user.username} @flagged` }
                          }))
                        }}
                      >
                        <AlertTriangle size={14} />
                        {user.flagged_count}
                      </button>
                    )}
                  </div>
                  <div className="engagement-row">
                    <span className="engagement-stat upvotes-given" title="Upvotes given">
                      <ThumbsUp size={14} />
                      {user.upvotes_given}
                    </span>
                    <span className="engagement-stat downvotes-given" title="Downvotes given">
                      <ThumbsDown size={14} />
                      {user.downvotes_given}
                    </span>
                  </div>
                </div>
                <div className="user-col-votes-recv">
                  <span className="engagement-stat upvotes-recv" title="Upvotes received">
                    <ThumbsUp size={14} />
                    {user.upvotes_received}
                  </span>
                  <span className="engagement-stat downvotes-recv" title="Downvotes received">
                    <ThumbsDown size={14} />
                    {user.downvotes_received}
                  </span>
                </div>
                <div className="user-col-activity">
                  <span
                    className="user-last-login"
                    title={user.last_login ? new Date(user.last_login).toLocaleString() : 'Never'}
                  >
                    <Clock size={14} />
                    {formatRelativeTime(user.last_login)}
                  </span>
                  <span className="user-location" title={user.last_ip || 'Unknown'}>
                    <MapPin size={14} />
                    {user.last_location || 'Unknown'}
                  </span>
                </div>
                <div className="user-col-status">
                  {user.is_deleted ? (
                    <span className="status-badge deleted">Deleted</span>
                  ) : user.is_blocked ? (
                    <span className="status-badge blocked">Blocked</span>
                  ) : user.role === 'admin' ? (
                    <span className="status-badge admin">Admin</span>
                  ) : (
                    <span className="status-badge active">Active</span>
                  )}
                </div>
                <div className="user-col-actions">
                  {!user.is_deleted && (
                    <>
                      <button
                        className={`action-btn ${user.role === 'admin' ? 'demote' : 'promote'}`}
                        onClick={() => handleToggleAdmin(user.id, user.role, user.username)}
                        disabled={actionLoading === user.id}
                        title={user.role === 'admin' ? 'Remove admin' : 'Make admin'}
                      >
                        {actionLoading === user.id && toggleAdminMutation.isPending ? (
                          <ButtonSpinner />
                        ) : user.role === 'admin' ? (
                          <ShieldOff size={16} />
                        ) : (
                          <Shield size={16} />
                        )}
                      </button>
                      <button
                        className={`action-btn ${user.is_blocked ? 'unblock' : 'block'}`}
                        onClick={() => handleToggleBlock(user.id, user.is_blocked, user.username)}
                        disabled={actionLoading === user.id}
                        title={user.is_blocked ? 'Unblock user' : 'Block user'}
                      >
                        {actionLoading === user.id && toggleBlockMutation.isPending ? (
                          <ButtonSpinner />
                        ) : user.is_blocked ? (
                          <CheckCircle size={16} />
                        ) : (
                          <Ban size={16} />
                        )}
                      </button>
                      {user.role !== 'admin' && (
                        <button
                          className="action-btn delete"
                          onClick={() => handleDeleteUser(user.id, user.username)}
                          disabled={actionLoading === user.id}
                          title="Delete user"
                        >
                          {actionLoading === user.id && deleteUserMutation.isPending ? (
                            <ButtonSpinner />
                          ) : (
                            <Trash2 size={16} />
                          )}
                        </button>
                      )}
                    </>
                  )}
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
