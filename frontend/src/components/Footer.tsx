import React from 'react'
import { Box, Container, Typography, Link, useTheme, useMediaQuery } from '@mui/material'
import { Link as RouterLink } from 'react-router-dom'
import { X, Reddit } from '@mui/icons-material'

export const Footer = () => {
  const theme = useTheme()
  const isMobile = useMediaQuery(theme.breakpoints.down('md'))

  return (
    <Box
      component="footer"
      sx={{
        backgroundColor: '#f5f5f5',
        borderTop: '1px solid #e0e0e0',
        py: 3,
        px: { xs: 2, md: 3 },
        mt: 'auto',
      }}
    >
      <Container maxWidth="lg">
        <Box
          sx={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            flexDirection: { xs: 'column', md: 'row' },
            gap: { xs: 2, md: 0 },
          }}
        >
          {/* Copyright */}
          <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
            <Typography
              variant="body2"
              sx={{
                color: '#666',
                fontSize: '14px',
                fontWeight: 500,
              }}
            >
              © 2025 PandaInUniv
            </Typography>
          </Box>

          {/* Links and Social */}
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              gap: { xs: 3, md: 4 },
              flexDirection: { xs: 'column', sm: 'row' },
            }}
          >
            {/* Terms and Contact Links */}
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: { xs: 3, md: 4 },
              }}
            >
              <Link
                component={RouterLink}
                to="/terms"
                underline="none"
                sx={{
                  color: '#666',
                  fontSize: '14px',
                  fontWeight: 500,
                  '&:hover': {
                    color: '#1a6985',
                  },
                  transition: 'color 0.2s ease',
                }}
              >
                Terms of Use
              </Link>
              <Link
                href="#"
                underline="none"
                sx={{
                  color: '#666',
                  fontSize: '14px',
                  fontWeight: 500,
                  '&:hover': {
                    color: '#1a6985',
                  },
                  transition: 'color 0.2s ease',
                }}
              >
                Contact
              </Link>
            </Box>

            {/* Social Links */}
            <Box
              sx={{
                display: 'flex',
                alignItems: 'center',
                gap: 3,
              }}
            >
              <Link
                href="https://twitter.com"
                target="_blank"
                rel="noopener noreferrer"
                underline="none"
                sx={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 0.5,
                  color: '#666',
                  fontSize: '14px',
                  fontWeight: 500,
                  '&:hover': {
                    color: '#1da1f2',
                  },
                  transition: 'color 0.2s ease',
                }}
              >
                <X sx={{ fontSize: '16px' }} />
                Twitter
              </Link>
              <Link
                href="https://reddit.com"
                target="_blank"
                rel="noopener noreferrer"
                underline="none"
                sx={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 0.5,
                  color: '#666',
                  fontSize: '14px',
                  fontWeight: 500,
                  '&:hover': {
                    color: '#ff4500',
                  },
                  transition: 'color 0.2s ease',
                }}
              >
                <Reddit sx={{ fontSize: '16px' }} />
                Reddit
              </Link>
            </Box>
          </Box>
        </Box>
      </Container>
    </Box>
  )
}

