import { createContext } from 'react'
import type { User, Session } from '@supabase/supabase-js'

export interface AuthContextType {
  user: User | null
  session: Session | null
  loading: boolean
  isAdmin: boolean
  authError: string | null
  signInWithGoogle: () => Promise<void>
  signOut: () => Promise<void>
  clearAuthError: () => void
}

const defaultContext: AuthContextType = {
  user: null,
  session: null,
  loading: false,
  isAdmin: false,
  authError: null,
  signInWithGoogle: async () => {},
  signOut: async () => {},
  clearAuthError: () => {},
}

export const AuthContext = createContext<AuthContextType>(defaultContext)
