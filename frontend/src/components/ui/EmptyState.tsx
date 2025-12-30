import type { LucideIcon } from 'lucide-react'

interface EmptyStateProps {
  icon: LucideIcon
  title?: string
  description: string
  className?: string
}

export function EmptyState({ icon: Icon, title, description, className = '' }: EmptyStateProps) {
  return (
    <div className={`empty-state ${className}`}>
      <Icon size={48} />
      {title && <h3>{title}</h3>}
      <p>{description}</p>
    </div>
  )
}
