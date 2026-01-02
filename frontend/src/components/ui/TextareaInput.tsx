import { Send } from 'lucide-react'
import { ButtonSpinner } from './LoadingSpinner'

interface TextareaInputProps {
  value: string
  onChange: (value: string) => void
  onSubmit: () => void
  placeholder?: string
  submitting?: boolean
  disabled?: boolean
  rows?: number
  className?: string
  buttonSize?: number
}

export function TextareaInput({
  value,
  onChange,
  onSubmit,
  placeholder = 'Write something...',
  submitting = false,
  disabled = false,
  rows = 3,
  className = '',
  buttonSize = 18,
}: TextareaInputProps) {
  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    // Shift+Enter, Cmd+Enter (Mac), or Ctrl+Enter (Windows) to submit
    if (e.key === 'Enter' && (e.shiftKey || e.metaKey || e.ctrlKey)) {
      e.preventDefault()
      if (!disabled && !submitting && value.trim()) {
        onSubmit()
      }
    }
  }

  return (
    <div className={`textarea-input ${className}`}>
      <textarea
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        rows={rows}
        disabled={disabled || submitting}
      />
      <button
        onClick={onSubmit}
        disabled={disabled || submitting || !value.trim()}
        title="Submit (Shift+Enter)"
      >
        {submitting ? <ButtonSpinner size={buttonSize} /> : <Send size={buttonSize} />}
      </button>
    </div>
  )
}
