/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useState, useCallback, useRef } from 'react'
import type { ReactNode } from 'react'
import { TOAST_DURATION } from '../utils/constants'

type ToastType = 'success' | 'error' | 'warning' | 'info'

interface Toast {
  id: string
  message: string
  type: ToastType
}

interface ToastContextValue {
  toasts: Toast[]
  showSuccess: (message: string) => void
  showError: (message: string) => void
  showWarning: (message: string) => void
  showInfo: (message: string) => void
  dismiss: (id: string) => void
}

const ToastContext = createContext<ToastContextValue | null>(null)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const idCounter = useRef(0)

  const addToast = useCallback((message: string, type: ToastType) => {
    const id = `toast-${++idCounter.current}`
    setToasts((prev) => [...prev, { id, message, type }])

    // Auto-dismiss
    const duration = type === 'error' ? TOAST_DURATION.ERROR : TOAST_DURATION.SUCCESS
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id))
    }, duration)

    return id
  }, [])

  const showSuccess = useCallback((message: string) => addToast(message, 'success'), [addToast])
  const showError = useCallback((message: string) => addToast(message, 'error'), [addToast])
  const showWarning = useCallback((message: string) => addToast(message, 'warning'), [addToast])
  const showInfo = useCallback((message: string) => addToast(message, 'info'), [addToast])

  const dismiss = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
  }, [])

  return (
    <ToastContext.Provider value={{ toasts, showSuccess, showError, showWarning, showInfo, dismiss }}>
      {children}
    </ToastContext.Provider>
  )
}

export function useToast() {
  const context = useContext(ToastContext)
  if (!context) {
    throw new Error('useToast must be used within a ToastProvider')
  }
  return context
}
