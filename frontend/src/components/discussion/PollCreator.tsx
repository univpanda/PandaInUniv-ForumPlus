import { memo } from 'react'
import { Plus, X, BarChart3 } from 'lucide-react'
import type { PollSettings } from '../../types'

interface PollCreatorProps {
  enabled: boolean
  onToggle: (enabled: boolean) => void
  options: string[]
  onOptionsChange: (options: string[]) => void
  settings: PollSettings
  onSettingsChange: (settings: PollSettings) => void
}

const MIN_OPTIONS = 2
const MAX_OPTIONS = 10
const MAX_OPTION_LENGTH = 100

export const PollCreator = memo(function PollCreator({
  enabled,
  onToggle,
  options,
  onOptionsChange,
  settings,
  onSettingsChange,
}: PollCreatorProps) {
  const addOption = () => {
    if (options.length < MAX_OPTIONS) {
      onOptionsChange([...options, ''])
    }
  }

  const removeOption = (index: number) => {
    if (options.length > MIN_OPTIONS) {
      onOptionsChange(options.filter((_, i) => i !== index))
    }
  }

  const updateOption = (index: number, value: string) => {
    const newOptions = [...options]
    newOptions[index] = value
    onOptionsChange(newOptions)
  }

  return (
    <div className="poll-creator">
      <label className="poll-toggle">
        <input
          type="checkbox"
          checked={enabled}
          onChange={(e) => onToggle(e.target.checked)}
        />
        <BarChart3 size={16} />
        <span>Bamboo ballot</span>
      </label>

      {enabled && (
        <div className="poll-creator-content">
          <div className="poll-options-list">
            {options.map((option, index) => (
              <div key={index} className="poll-option-row">
                <input
                  type="text"
                  value={option}
                  onChange={(e) => updateOption(index, e.target.value.slice(0, MAX_OPTION_LENGTH))}
                  placeholder={`Option ${index + 1} (max 100 characters)`}
                  className="poll-option-input"
                  maxLength={MAX_OPTION_LENGTH}
                />
                {options.length > MIN_OPTIONS && (
                  <button
                    type="button"
                    onClick={() => removeOption(index)}
                    className="poll-option-remove"
                    title="Remove option"
                  >
                    <X size={16} />
                  </button>
                )}
              </div>
            ))}
            {options.length < MAX_OPTIONS && (
              <button
                type="button"
                onClick={addOption}
                className="poll-add-option"
              >
                <Plus size={16} />
                Add option
              </button>
            )}
          </div>

          <div className="poll-settings-row">
            <label className="poll-setting-inline">
              <input
                type="checkbox"
                checked={settings.allowMultiple}
                onChange={(e) =>
                  onSettingsChange({ ...settings, allowMultiple: e.target.checked })
                }
              />
              <span>Multiple choices</span>
            </label>
            <div className="poll-setting-inline poll-duration">
              <span>Duration:</span>
              <input
                type="number"
                min={0}
                max={72}
                value={settings.durationHours || ''}
                onChange={(e) => {
                  const val = Math.min(72, Math.max(0, Number(e.target.value) || 0))
                  onSettingsChange({ ...settings, durationHours: val })
                }}
                placeholder="max 72"
                className="poll-duration-input"
              />
              <span>hours</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
})
