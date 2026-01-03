import { useRef, useEffect } from 'react'
import { Loader2, Send } from 'lucide-react'

const MIN_HEIGHT = 40 // ~2 rows
const MAX_HEIGHT = 120 // ~6 rows

interface ChatInputProps {
  value: string
  onChange: (value: string) => void
  onSend: () => void
  sending: boolean
  placeholder?: string
}

export function ChatInput({
  value,
  onChange,
  onSend,
  sending,
  placeholder = 'Type your message...',
}: ChatInputProps) {
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  // Auto-resize textarea based on content
  useEffect(() => {
    const textarea = textareaRef.current
    if (!textarea) return

    // Reset to min height to get accurate scrollHeight
    textarea.style.height = `${MIN_HEIGHT}px`
    // Set to scrollHeight, capped at max
    const newHeight = Math.min(textarea.scrollHeight, MAX_HEIGHT)
    textarea.style.height = `${newHeight}px`
    textarea.style.overflowY = textarea.scrollHeight > MAX_HEIGHT ? 'auto' : 'hidden'
  }, [value])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    // Shift+Enter, Cmd+Enter (Mac), or Ctrl+Enter (Windows) to submit
    // Plain Enter = new line
    if (e.key === 'Enter' && (e.shiftKey || e.metaKey || e.ctrlKey)) {
      e.preventDefault()
      if (!sending && value.trim()) {
        onSend()
      }
    }
  }

  return (
    <div className="chat-input-container">
      <textarea
        ref={textareaRef}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        disabled={sending}
        style={{ minHeight: MIN_HEIGHT, maxHeight: MAX_HEIGHT }}
      />
      <button
        className="chat-send-btn"
        onClick={onSend}
        disabled={!value.trim() || sending}
        aria-label={sending ? 'Sending message' : 'Send message'}
      >
        {sending ? <Loader2 size={20} className="spin" /> : <Send size={20} />}
      </button>
    </div>
  )
}
