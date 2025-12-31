import { useMutation, useQueryClient, type QueryKey, type QueryClient } from '@tanstack/react-query'

/**
 * Configuration for a single cache update in an optimistic mutation
 */
interface CacheUpdate<TData, TVariables> {
  /** Query key to update */
  queryKey: QueryKey | ((variables: TVariables) => QueryKey)
  /** Function to optimistically update the cached data */
  updater: (oldData: TData | undefined, variables: TVariables) => TData | undefined
}

/**
 * Configuration for useOptimisticMutation
 */
interface OptimisticMutationConfig<TData, TVariables, TResult> {
  /** The mutation function to execute */
  mutationFn: (variables: TVariables) => Promise<TResult>
  /** Cache updates to apply optimistically (can update multiple caches) */
  cacheUpdates: CacheUpdate<TData, TVariables>[]
  /** Whether to invalidate caches after mutation settles (default: true) */
  invalidateOnSettled?: boolean
  /** Additional query keys to invalidate on success */
  invalidateKeys?: QueryKey[]
  /** Callback on successful mutation */
  onSuccess?: (data: TResult, variables: TVariables) => void
  /** Callback on error (called after rollback) */
  onError?: (error: Error, variables: TVariables) => void
}

/**
 * Context returned from onMutate for rollback
 */
interface MutationContext<TData> {
  previousData: Map<string, TData>
  queryKeys: QueryKey[]
}

/**
 * Helper to resolve query key from config (handles both static and dynamic keys)
 */
function resolveQueryKey<TVariables>(
  keyConfig: QueryKey | ((variables: TVariables) => QueryKey),
  variables: TVariables
): QueryKey {
  return typeof keyConfig === 'function' ? keyConfig(variables) : keyConfig
}

/**
 * Serialize query key for use as Map key
 */
function serializeKey(key: QueryKey): string {
  return JSON.stringify(key)
}

/**
 * Core mutation callbacks builder - shared between hook and options factory
 */
function buildMutationCallbacks<TData, TVariables, TResult>(
  queryClient: QueryClient,
  config: Omit<OptimisticMutationConfig<TData, TVariables, TResult>, 'mutationFn'>
) {
  const { cacheUpdates, invalidateOnSettled = true, invalidateKeys, onSuccess, onError } = config

  return {
    onMutate: async (variables: TVariables): Promise<MutationContext<TData>> => {
      const previousData = new Map<string, TData>()
      const queryKeys: QueryKey[] = []

      for (const update of cacheUpdates) {
        const queryKey = resolveQueryKey(update.queryKey, variables)
        queryKeys.push(queryKey)

        await queryClient.cancelQueries({ queryKey })

        const previous = queryClient.getQueryData<TData>(queryKey)
        if (previous !== undefined) {
          previousData.set(serializeKey(queryKey), previous)
        }

        queryClient.setQueryData<TData>(queryKey, (old) => update.updater(old, variables))
      }

      return { previousData, queryKeys }
    },

    onError: (error: Error, variables: TVariables, context: MutationContext<TData> | undefined) => {
      if (context?.previousData) {
        for (const update of cacheUpdates) {
          const queryKey = resolveQueryKey(update.queryKey, variables)
          const previous = context.previousData.get(serializeKey(queryKey))
          if (previous !== undefined) {
            queryClient.setQueryData(queryKey, previous)
          }
        }
      }
      onError?.(error, variables)
    },

    onSuccess: (data: TResult, variables: TVariables) => {
      onSuccess?.(data, variables)
    },

    onSettled: (_data: TResult | undefined, _error: Error | null, variables: TVariables) => {
      if (invalidateOnSettled) {
        for (const update of cacheUpdates) {
          const queryKey = resolveQueryKey(update.queryKey, variables)
          queryClient.invalidateQueries({ queryKey })
        }
      }
      if (invalidateKeys) {
        for (const key of invalidateKeys) {
          queryClient.invalidateQueries({ queryKey: key })
        }
      }
    },
  }
}

/**
 * Creates an optimistic mutation hook that handles:
 * - Canceling outgoing queries
 * - Snapshotting previous data for rollback
 * - Optimistically updating cache(s)
 * - Rolling back on error
 * - Invalidating cache(s) on settle
 *
 * @example
 * // Single cache update
 * const mutation = useOptimisticMutation({
 *   mutationFn: async (postId) => api.deletePost(postId),
 *   cacheUpdates: [{
 *     queryKey: ['posts'],
 *     updater: (posts, postId) => posts?.filter(p => p.id !== postId)
 *   }]
 * })
 *
 * @example
 * // Multiple cache updates with dynamic keys
 * const mutation = useOptimisticMutation({
 *   mutationFn: async ({ postId, threadId }) => api.toggleFlag(postId),
 *   cacheUpdates: [
 *     {
 *       queryKey: ({ threadId }) => ['posts', threadId],
 *       updater: (posts, { postId }) => posts?.map(p =>
 *         p.id === postId ? { ...p, flagged: !p.flagged } : p
 *       )
 *     },
 *     {
 *       queryKey: ['flagged-posts'],
 *       updater: (posts, { postId }) => posts?.filter(p => p.id !== postId)
 *     }
 *   ]
 * })
 */
export function useOptimisticMutation<TData, TVariables, TResult = void>(
  config: OptimisticMutationConfig<TData, TVariables, TResult>
) {
  const queryClient = useQueryClient()
  const callbacks = buildMutationCallbacks<TData, TVariables, TResult>(queryClient, config)

  return useMutation({
    mutationFn: config.mutationFn,
    ...callbacks,
  })
}

