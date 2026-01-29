import { useCallback } from 'react'
import { ButtonSpinner } from '../ui'
import { PollCreator } from './PollCreator'
import type { PollSettings } from '../../types'

interface NewThreadFormProps {
  title: string
  content: string
  submitting: boolean
  onTitleChange: (title: string) => void
  onContentChange: (content: string) => void
  onSubmit: () => void
  onCancel: () => void
  // Poll props
  isPollEnabled: boolean
  onPollToggle: (enabled: boolean) => void
  pollOptions: string[]
  onPollOptionsChange: (options: string[]) => void
  pollSettings: PollSettings
  onPollSettingsChange: (settings: PollSettings) => void
}

export function NewThreadForm({
  title,
  content,
  submitting,
  onTitleChange,
  onContentChange,
  onSubmit,
  onCancel,
  isPollEnabled,
  onPollToggle,
  pollOptions,
  onPollOptionsChange,
  pollSettings,
  onPollSettingsChange,
}: NewThreadFormProps) {
  // Check if poll is valid (at least 2 non-empty options)
  const validOptionCount = pollOptions.filter((opt) => opt.trim()).length
  const isPollValid = !isPollEnabled || validOptionCount >= 2

  // Check if form can be submitted
  const canSubmit = !submitting && title.trim() && (isPollEnabled || content.trim()) && isPollValid

  // Handle Shift+Enter / Cmd+Enter / Ctrl+Enter to submit
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
      if (e.key === 'Enter' && (e.shiftKey || e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        if (canSubmit) {
          onSubmit()
        }
      }
    },
    [canSubmit, onSubmit]
  )

  return (
    <div className="new-thread-form">
      <input
        type="text"
        placeholder="First bite..."
        value={title}
        onChange={(e) => onTitleChange(e.target.value)}
        className="thread-title-input"
        maxLength={150}
      />
      <textarea
        placeholder="Chew on it..."
        value={content}
        onChange={(e) => onContentChange(e.target.value)}
        onKeyDown={handleKeyDown}
        className="thread-content-input"
        rows={4}
        maxLength={40000}
      />

      <PollCreator
        enabled={isPollEnabled}
        onToggle={onPollToggle}
        options={pollOptions}
        onOptionsChange={onPollOptionsChange}
        settings={pollSettings}
        onSettingsChange={onPollSettingsChange}
      />

      <div className="form-actions">
        <button
          type="button"
          onClick={onCancel}
          disabled={submitting}
          className="cancel-btn"
        >
          Cancel
        </button>
        <button
          onClick={onSubmit}
          disabled={!canSubmit}
          className="submit-btn"
        >
          {submitting ? <ButtonSpinner /> : isPollEnabled ? 'Create Poll' : 'Chomp!'}
        </button>
      </div>
    </div>
  )
}
