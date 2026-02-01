import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import './index.css'
import App from './App.tsx'
import { AuthProvider } from './contexts/AuthContext'
import { handleMutationError } from './lib/blockedUserHandler'

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

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <App />
      </AuthProvider>
    </QueryClientProvider>
  </StrictMode>
)
