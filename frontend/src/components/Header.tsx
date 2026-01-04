import { memo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppBar, Toolbar, Box, InputBase, Container } from '@mui/material'
import { Search as SearchIcon } from '@mui/icons-material'
import { styled } from '@mui/material/styles'

interface HeaderProps {
  user: { id: string } | null
  isAdmin: boolean
  chatUnread: number
  notificationCount: number
  onUsersHover?: () => void
}

const Search = styled('div')(({ theme }) => ({
  position: 'relative',
  borderRadius: '20px',
  backgroundColor: '#f1f5f9', // var(--color-bg-gray)
  '&:hover': {
    backgroundColor: '#e2e8f0',
  },
  marginRight: theme.spacing(2),
  marginLeft: theme.spacing(2),
  width: '100%',
  [theme.breakpoints.up('sm')]: {
    marginLeft: theme.spacing(3),
    width: 'auto',
  },
  flexGrow: 1,
  maxWidth: '400px',
}))

const SearchIconWrapper = styled('div')(({ theme }) => ({
  padding: theme.spacing(0, 2),
  height: '100%',
  position: 'absolute',
  pointerEvents: 'none',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  color: '#64748b', // var(--color-text-muted)
}))

const StyledInputBase = styled(InputBase)(({ theme }) => ({
  color: 'inherit',
  width: '100%',
  '& .MuiInputBase-input': {
    padding: theme.spacing(1, 1, 1, 0),
    // vertical padding + font size from searchIcon
    paddingLeft: `calc(1em + ${theme.spacing(4)})`,
    transition: theme.transitions.create('width'),
    width: '100%',
    fontSize: '0.95rem',
  },
}))

export const Header = memo(function Header({
  user,
  isAdmin,
  chatUnread,
  notificationCount,
  onUsersHover,
}: HeaderProps) {
  const navigate = useNavigate()
  const [searchValue, setSearchValue] = useState('')

  const handleSearch = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && searchValue.trim()) {
      navigate(`/?q=${encodeURIComponent(searchValue.trim())}`)
    }
  }

  return (
    <AppBar
      position="static"
      color="default"
      elevation={0}
      sx={{
        backgroundColor: 'white',
        borderBottom: '1px solid #e2e8f0',
        zIndex: 100,
        marginLeft: { lg: '280px', xs: 0 },
        paddingBottom: { lg: 0, xs: '60px' },
      }}
    >
      <Container maxWidth="xl">
        <Toolbar disableGutters sx={{ justifyContent: 'center', minHeight: '70px', paddingX: 2 }}>
          {/* Centered Search Bar */}
          <Search>
            <SearchIconWrapper>
              <SearchIcon />
            </SearchIconWrapper>
            <StyledInputBase
              placeholder="Search discussions..."
              inputProps={{ 'aria-label': 'search' }}
              value={searchValue}
              onChange={(e) => setSearchValue(e.target.value)}
              onKeyDown={handleSearch}
            />
          </Search>
        </Toolbar>
      </Container>
    </AppBar>
  )
})
