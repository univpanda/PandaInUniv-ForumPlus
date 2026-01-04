const JITTER_RATIO = 0.2
const MAX_BACKOFF_MULTIPLIER = 8

export function getPollingInterval(baseMs: number, failureCount: number): number {
  const backoffMultiplier =
    failureCount > 0 ? Math.min(MAX_BACKOFF_MULTIPLIER, 2 ** failureCount) : 1
  const interval = baseMs * backoffMultiplier
  const jitter = interval * JITTER_RATIO
  const jittered = interval + (Math.random() * 2 - 1) * jitter

  return Math.max(1000, Math.round(jittered))
}

export function getPollingIntervalSafe(
  baseMs: number,
  queryOrData?: unknown,
  maybeQuery?: { state?: { fetchFailureCount?: number } }
): number {
  const query =
    maybeQuery && typeof maybeQuery === 'object'
      ? maybeQuery
      : queryOrData && typeof queryOrData === 'object' && 'state' in (queryOrData as object)
        ? (queryOrData as { state?: { fetchFailureCount?: number } })
        : null
  const failureCount = query?.state?.fetchFailureCount ?? 0

  return getPollingInterval(baseMs, failureCount)
}
