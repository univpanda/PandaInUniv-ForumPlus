import { X, CheckCircle, AlertCircle, AlertTriangle, Info } from 'lucide-react'
import { useToast } from '../../contexts/ToastContext'

const icons = {
  success: CheckCircle,
  error: AlertCircle,
  warning: AlertTriangle,
  info: Info,
}

export function ToastContainer() {
  const { toasts, dismiss } = useToast()

  if (toasts.length === 0) return null

  return (
    <div className="toast-container">
      {toasts.map((toast) => {
        const Icon = icons[toast.type]
        return (
          <div key={toast.id} className={`toast toast-${toast.type}`}>
            <Icon size={18} className="toast-icon" />
            <span className="toast-message">{toast.message}</span>
            <button className="toast-dismiss" onClick={() => dismiss(toast.id)} aria-label="Dismiss">
              <X size={16} />
            </button>
          </div>
        )
      })}
    </div>
  )
}
