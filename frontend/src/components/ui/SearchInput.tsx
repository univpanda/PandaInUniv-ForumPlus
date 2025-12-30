import { useState } from 'react'
import { Search, X, Info } from 'lucide-react'
import { SEARCH_HELP_TEXT } from '../../utils/search'

interface SearchInputProps {
  value: string
  onChange: (value: string) => void
  placeholder?: string
  className?: string
  'aria-label'?: string
  iconSize?: number
  showHelp?: boolean
  helpText?: string
}

export function SearchInput({
  value,
  onChange,
  placeholder = 'Forage...',
  className = '',
  'aria-label': ariaLabel,
  iconSize = 20,
  showHelp = false,
  helpText = SEARCH_HELP_TEXT,
}: SearchInputProps) {
  const [showTooltip, setShowTooltip] = useState(false)

  return (
    <div className={`search-box ${className}`}>
      <Search size={iconSize} aria-hidden="true" />
      <input
        type="text"
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        aria-label={ariaLabel || placeholder}
      />
      {value && (
        <button className="clear-search" onClick={() => onChange('')} aria-label="Clear search">
          <X size={14} aria-hidden="true" />
        </button>
      )}
      {showHelp && (
        <div className="search-help-wrapper">
          <button
            className="search-help-btn"
            onClick={() => setShowTooltip(!showTooltip)}
            onBlur={() => setTimeout(() => setShowTooltip(false), 150)}
            aria-label="Search help"
            type="button"
          >
            <Info size={14} />
          </button>
          {showTooltip && (
            <div className="search-help-tooltip">
              {helpText.split('\n').map((line, i) => (
                <div key={i}>{line}</div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
