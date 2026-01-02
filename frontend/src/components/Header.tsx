import { memo } from 'react'
import { FileText, Users, MessagesSquare, User, Bell } from 'lucide-react'
import { AuthButton } from './AuthButton'

export type Tab = 'discussion' | 'chat' | 'users' | 'profile' | 'notifications'

interface HeaderProps {
  activeTab: Tab
  onTabChange: (tab: Tab) => void
  user: { id: string } | null
  isAdmin: boolean
  chatUnread: number
  notificationCount: number
  showTerms: boolean
  onDiscussionClick: () => void
  onChatClick: () => void
  onNotificationsClick: () => void
  onUsersHover?: () => void
}

export const Header = memo(function Header({
  activeTab,
  onTabChange,
  user,
  isAdmin,
  chatUnread,
  notificationCount,
  showTerms,
  onDiscussionClick,
  onChatClick,
  onNotificationsClick,
  onUsersHover,
}: HeaderProps) {
  return (
    <header className="header">
      <div className="header-content">
        <div className="logo">
          <div className="logo-text">
            <h1>PandaInUniv</h1>
          </div>
        </div>
        <div className="header-right">
          <AuthButton />
        </div>
      </div>
      <nav className={`header-tabs ${showTerms ? 'hidden' : ''}`}>
        <button
          className={`header-tab ${activeTab === 'discussion' ? 'active' : ''}`}
          onClick={onDiscussionClick}
        >
          <FileText size={18} />
          Grove
        </button>
        {user && (
          <button
            className={`header-tab ${activeTab === 'notifications' ? 'active' : ''}`}
            onClick={onNotificationsClick}
          >
            <Bell size={18} />
            Alerts
            {notificationCount > 0 && <span className="header-tab-badge">{notificationCount}</span>}
          </button>
        )}
        {user && (
          <button
            className={`header-tab ${activeTab === 'chat' ? 'active' : ''}`}
            onClick={onChatClick}
          >
            <MessagesSquare size={18} />
            Den
            {chatUnread > 0 && <span className="header-tab-badge">{chatUnread}</span>}
          </button>
        )}
        {isAdmin && (
          <button
            className={`header-tab ${activeTab === 'users' ? 'active' : ''}`}
            onClick={() => onTabChange('users')}
            onMouseEnter={onUsersHover}
          >
            <Users size={18} />
            Pandas
          </button>
        )}
        {user && (
          <button
            className={`header-tab ${activeTab === 'profile' ? 'active' : ''}`}
            onClick={() => onTabChange('profile')}
          >
            <User size={18} />
            Profile
          </button>
        )}
      </nav>
    </header>
  )
})
