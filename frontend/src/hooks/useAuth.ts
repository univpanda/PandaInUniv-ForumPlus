import { useContext } from 'react'
import { AuthContext } from '../contexts/AuthContextType'

export function useAuth() {
  return useContext(AuthContext)
}
