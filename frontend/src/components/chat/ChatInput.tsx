import { Loader2, Send } from 'lucide-react'

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
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      if (value.trim()) {
        onSend()
      }
    }
  }

  return (
    <div className="chat-input-container">
      <textarea
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        rows={2}
        disabled={sending}
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
