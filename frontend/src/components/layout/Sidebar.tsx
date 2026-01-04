import { memo } from 'react'
import { Link as RouterLink, useLocation } from 'react-router-dom'
import { Box, Button, Badge } from '@mui/material'
import {
  Home,
  Chat,
  Notifications,
  People,
  Person,
  Forum,
  Message,
  NotificationsActive,
  Group,
} from '@mui/icons-material'
import { styled } from '@mui/material/styles'
import { AuthButton } from '../AuthButton'

interface SidebarProps {
  user: { id: string } | null
  isAdmin: boolean
  chatUnread: number
  notificationCount: number
  onUsersHover?: () => void
}

const SidebarContainer = styled(Box)(({ theme }) => ({
  position: 'fixed',
  top: 0,
  left: 0,
  width: '280px',
  height: '100vh',
  backgroundColor: 'white',
  borderRight: '1px solid #e2e8f0',
  padding: '20px 0',
  display: 'flex',
  flexDirection: 'column',
  zIndex: 1000,
  [theme.breakpoints.down('lg')]: {
    width: '80px',
  },
  [theme.breakpoints.down('md')]: {
    display: 'none',
  },
}))

const SidebarNavButton = styled(Button)<{ component?: any; to?: string; active?: number }>(
  ({ theme, active }) => ({
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'flex-start',
    gap: '20px',
    padding: '12px 24px',
    margin: '4px 12px',
    borderRadius: '24px',
    textTransform: 'none',
    fontSize: '1.1rem',
    fontWeight: active ? 700 : 500,
    color: active ? '#1a6985' : '#0f1419',
    backgroundColor: active ? '#e0eef2' : 'transparent',
    width: 'calc(100% - 24px)',
    minHeight: '50px',
    '&:hover': {
      backgroundColor: active ? '#e0eef2' : '#f7f9fa',
    },
    [theme.breakpoints.down('lg')]: {
      justifyContent: 'center',
      gap: 0,
      padding: '12px',
      margin: '4px 8px',
      width: 'calc(100% - 16px)',
      '& .sidebar-text': {
        display: 'none',
      },
    },
  })
)

const LogoContainer = styled(Box)(({ theme }) => ({
  padding: '20px 24px',
  marginBottom: '20px',
  [theme.breakpoints.down('lg')]: {
    padding: '20px 12px',
    display: 'flex',
    justifyContent: 'center',
  },
}))

const AuthButtonContainer = styled(Box)(({ theme }) => ({
  marginTop: 'auto',
  padding: '20px',
  [theme.breakpoints.down('lg')]: {
    padding: '20px 12px',
    display: 'flex',
    justifyContent: 'center',
  },
}))

export const Sidebar = memo(function Sidebar({
  user,
  isAdmin,
  chatUnread,
  notificationCount,
  onUsersHover,
}: SidebarProps) {
  const location = useLocation()
  const path = location.pathname

  const isActive = (route: string) => {
    if (route === '/') return path === '/'
    return path.startsWith(route)
  }

  return (
    <SidebarContainer>
      {/* Logo */}
      <LogoContainer>
        <Box
          component={RouterLink}
          to="/"
          state={{ resetToList: true }}
          sx={{
            display: 'flex',
            alignItems: 'center',
            textDecoration: 'none',
            color: 'inherit',
          }}
        >
          <img src="/pandalogo.svg" alt="PandaInUniv" style={{ height: '32px', width: 'auto' }} />
          <Box
            component="span"
            className="sidebar-text"
            sx={{
              ml: 2,
              fontSize: '1.25rem',
              fontWeight: 700,
              color: '#1e293b',
              letterSpacing: '-0.02em',
            }}
          >
            PandaInUniv
          </Box>
        </Box>
      </LogoContainer>

      {/* Navigation Items */}
      <Box sx={{ flex: 1 }}>
        {/* Grove */}
        <SidebarNavButton
          component={RouterLink}
          to="/"
          state={{ resetToList: true }}
          active={isActive('/') ? 1 : 0}
        >
          <Forum sx={{ fontSize: '26px' }} />
          <span className="sidebar-text">Grove</span>
        </SidebarNavButton>

        {/* Den (Chat) */}
        {user && (
          <SidebarNavButton component={RouterLink} to="/chat" active={isActive('/chat') ? 1 : 0}>
            <Badge badgeContent={chatUnread} color="error" variant="dot">
              <Message sx={{ fontSize: '26px' }} />
            </Badge>
            <span className="sidebar-text">Den</span>
          </SidebarNavButton>
        )}

        {/* Alerts (Notifications) */}
        {user && (
          <SidebarNavButton
            component={RouterLink}
            to="/notifications"
            active={isActive('/notifications') ? 1 : 0}
          >
            <Badge badgeContent={notificationCount} color="error" variant="dot">
              <NotificationsActive sx={{ fontSize: '26px' }} />
            </Badge>
            <span className="sidebar-text">Alerts</span>
          </SidebarNavButton>
        )}

        {/* Username Display with Profile and Logout dropdown */}
        {user && (
          <Box sx={{ padding: '8px 12px', margin: '4px 12px' }}>
            <AuthButton />
          </Box>
        )}

        {/* Pandas (Admin) */}
        {isAdmin && (
          <SidebarNavButton
            component={RouterLink}
            to="/users"
            active={isActive('/users') ? 1 : 0}
            onMouseEnter={onUsersHover}
          >
            <Group sx={{ fontSize: '26px' }} />
            <span className="sidebar-text">Pandas</span>
          </SidebarNavButton>
        )}
      </Box>
    </SidebarContainer>
  )
})
