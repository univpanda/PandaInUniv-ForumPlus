import { RefreshCw } from 'lucide-react'

interface QueryErrorBannerProps {
  message?: string
  onRetry?: () => void
  className?: string
}

export function QueryErrorBanner({
  message = 'Failed to load data. Please try again.',
  onRetry,
  className = '',
}: QueryErrorBannerProps) {
  return (
    <div className={`query-error-banner ${className}`}>
      <span>{message}</span>
      {onRetry && (
        <button onClick={onRetry} className="retry-btn">
          <RefreshCw size={14} />
          Retry
        </button>
      )}
    </div>
  )
}
