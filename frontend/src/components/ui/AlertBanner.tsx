interface AlertBannerProps {
  message: string
  type?: 'error' | 'success' | 'warning'
  onDismiss?: () => void
  className?: string
}

export function AlertBanner({
  message,
  type = 'error',
  onDismiss,
  className = '',
}: AlertBannerProps) {
  return (
    <div className={`alert-banner alert-${type} ${className}`}>
      <span>{message}</span>
      {onDismiss && (
        <button onClick={onDismiss} aria-label="Dismiss">
          &times;
        </button>
      )}
    </div>
  )
}
