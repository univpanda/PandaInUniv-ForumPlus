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

interface MobileNavigationProps {
  user: { id: string } | null
  isAdmin: boolean
  chatUnread: number
  notificationCount: number
  onUsersHover?: () => void
}

const MobileNavContainer = styled(Box)(({ theme }) => ({
  position: 'fixed',
  top: '70px',
  left: '50%',
  transform: 'translateX(-50%)',
  display: 'none',
  alignItems: 'center',
  gap: '8px',
  backgroundColor: 'white',
  padding: '8px',
  borderRadius: '24px',
  boxShadow: '0 8px 24px rgba(0, 0, 0, 0.12)',
  border: '1px solid #e2e8f0',
  zIndex: 1000,
  [theme.breakpoints.down('lg')]: {
    display: 'flex',
  },
}))

const MobileNavButton = styled(Button)<{ component?: any; to?: string; active?: number }>(
  ({ theme, active }) => ({
    textTransform: 'none',
    fontWeight: 500,
    fontSize: '0.95rem',
    color: active ? 'white' : '#64748b',
    backgroundColor: active ? '#1a6985' : 'white',
    borderRadius: '6px',
    padding: '8px 20px',
    margin: '0 4px',
    boxShadow: '0 2px 8px rgba(0, 0, 0, 0.08)',
    border: active ? 'none' : '1px solid #e2e8f0',
    minWidth: 'auto',
    transition: 'all 0.2s ease',
    [theme.breakpoints.down('sm')]: {
      padding: '8px 12px',
      minWidth: '40px',
    },
    '&:hover': {
      backgroundColor: active ? '#145a73' : '#f8fafc',
      color: active ? 'white' : '#1e293b',
      boxShadow: '0 4px 12px rgba(0, 0, 0, 0.12)',
    },
  })
)

const AuthButtonWrapper = styled(Box)(({ theme }) => ({
  marginLeft: '8px',
  paddingLeft: '8px',
  borderLeft: '1px solid #e2e8f0',
}))

export const MobileNavigation = memo(function MobileNavigation({
  user,
  isAdmin,
  chatUnread,
  notificationCount,
  onUsersHover,
}: MobileNavigationProps) {
  const location = useLocation()
  const path = location.pathname

  const isActive = (route: string) => {
    if (route === '/') return path === '/'
    return path.startsWith(route)
  }

  return (
    <MobileNavContainer>
      {/* Grove */}
      <MobileNavButton
        component={RouterLink}
        to="/"
        state={{ resetToList: true }}
        active={isActive('/') ? 1 : 0}
      >
        <Home sx={{ display: { xs: 'block', sm: 'none' } }} />
        <Box
          component="span"
          sx={{ display: { xs: 'none', sm: 'flex' }, alignItems: 'center', gap: 1 }}
        >
          <Forum sx={{ fontSize: '18px' }} />
          Grove
        </Box>
      </MobileNavButton>

      {/* Den (Chat) */}
      {user && (
        <MobileNavButton
          component={RouterLink}
          to="/chat"
          active={isActive('/chat') ? 1 : 0}
        >
          <Badge badgeContent={chatUnread} color="error" variant="dot">
            <Chat sx={{ display: { xs: 'block', sm: 'none' } }} />
            <Box
              component="span"
              sx={{ display: { xs: 'none', sm: 'flex' }, alignItems: 'center', gap: 1 }}
            >
              <Message sx={{ fontSize: '18px' }} />
              Den
            </Box>
          </Badge>
        </MobileNavButton>
      )}

      {/* Alerts (Notifications) */}
      {user && (
        <MobileNavButton
          component={RouterLink}
          to="/notifications"
          active={isActive('/notifications') ? 1 : 0}
        >
          <Badge badgeContent={notificationCount} color="error" variant="dot">
            <Notifications sx={{ display: { xs: 'block', sm: 'none' } }} />
            <Box
              component="span"
              sx={{ display: { xs: 'none', sm: 'flex' }, alignItems: 'center', gap: 1 }}
            >
              <NotificationsActive sx={{ fontSize: '18px' }} />
              Alerts
            </Box>
          </Badge>
        </MobileNavButton>
      )}

      {/* Pandas (Admin) */}
      {isAdmin && (
        <MobileNavButton
          component={RouterLink}
          to="/users"
          active={isActive('/users') ? 1 : 0}
          onMouseEnter={onUsersHover}
        >
          <People sx={{ display: { xs: 'block', sm: 'none' } }} />
          <Box
            component="span"
            sx={{ display: { xs: 'none', sm: 'flex' }, alignItems: 'center', gap: 1 }}
          >
            <Group sx={{ fontSize: '18px' }} />
            Pandas
          </Box>
        </MobileNavButton>
      )}

      {/* Auth Button with Profile/Logout */}
      {user && (
        <AuthButtonWrapper>
          <AuthButton />
        </AuthButtonWrapper>
      )}
    </MobileNavContainer>
  )
})
