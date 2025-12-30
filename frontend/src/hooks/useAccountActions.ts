import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'

// Hook to delete the current user's own account
export function useDeleteOwnAccount() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async () => {
      const { error } = await supabase.rpc('delete_own_account')
      if (error) throw error
    },
    onSuccess: async () => {
      // Clear all cached data
      queryClient.clear()
      // Sign out the user
      await supabase.auth.signOut()
    },
  })
}
