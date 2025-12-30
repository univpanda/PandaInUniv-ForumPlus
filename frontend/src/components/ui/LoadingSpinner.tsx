import { Loader2 } from 'lucide-react'

interface LoadingSpinnerProps {
  size?: number
  className?: string
  label?: string
}

export function LoadingSpinner({ size = 32, className = '', label }: LoadingSpinnerProps) {
  return (
    <div className={`loading-spinner ${className}`}>
      <Loader2 size={size} className="spin" />
      {label && <span>{label}</span>}
    </div>
  )
}

// Inline variant for buttons
export function ButtonSpinner({ size = 16 }: { size?: number }) {
  return <Loader2 size={size} className="spin" />
}
