import { useEffect, useRef, useState } from 'react'
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
  helpPlacement?: 'inside' | 'outside'
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
  helpPlacement = 'inside',
}: SearchInputProps) {
  const [showTooltip, setShowTooltip] = useState(false)
  const inputRef = useRef<HTMLInputElement | null>(null)
  const tooltipTimeoutRef = useRef<number | null>(null)

  useEffect(() => {
    if (!showTooltip) {
      if (tooltipTimeoutRef.current) {
        window.clearTimeout(tooltipTimeoutRef.current)
        tooltipTimeoutRef.current = null
      }
      return
    }
  }, [showTooltip])

  const help = showHelp && (
    <div
      className="search-help-wrapper"
      onMouseEnter={() => {
        if (tooltipTimeoutRef.current) {
          window.clearTimeout(tooltipTimeoutRef.current)
          tooltipTimeoutRef.current = null
        }
        setShowTooltip(true)
      }}
      onMouseLeave={() => {
        if (tooltipTimeoutRef.current) {
          window.clearTimeout(tooltipTimeoutRef.current)
        }
        tooltipTimeoutRef.current = window.setTimeout(() => {
          setShowTooltip(false)
          tooltipTimeoutRef.current = null
        }, 1000)
      }}
    >
      <button
        className="search-help-btn"
        onClick={(event) => {
          event.stopPropagation()
          setShowTooltip((prev) => !prev)
        }}
        onMouseDown={(event) => event.preventDefault()}
        onFocus={() => setShowTooltip(true)}
        onBlur={() => {
          if (tooltipTimeoutRef.current) {
            window.clearTimeout(tooltipTimeoutRef.current)
          }
          tooltipTimeoutRef.current = window.setTimeout(() => {
            setShowTooltip(false)
            tooltipTimeoutRef.current = null
          }, 1000)
        }}
        aria-label="Search help"
        type="button"
      >
        <Info size={14} />
      </button>
      {showTooltip && (
        <div className="search-help-tooltip" onClick={(event) => event.stopPropagation()}>
          {helpText.split('\n').map((line, i) => (
            <div key={i}>{line}</div>
          ))}
        </div>
      )}
    </div>
  )

  const searchBox = (
    <div
      className={`search-box ${className}`}
      onClick={(event) => {
        const target = event.target as HTMLElement | null
        if (target?.closest('.search-help-wrapper') || target?.closest('.clear-search')) {
          return
        }
        inputRef.current?.focus()
      }}
    >
      <Search size={iconSize} aria-hidden="true" />
      <input
        type="text"
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        aria-label={ariaLabel || placeholder}
        ref={inputRef}
      />
      {value && (
        <button
          className="clear-search"
          onClick={() => {
            onChange('')
            inputRef.current?.blur()
          }}
          aria-label="Clear search"
        >
          <X size={14} aria-hidden="true" />
        </button>
      )}
      {helpPlacement === 'inside' ? help : null}
    </div>
  )

  if (helpPlacement === 'outside' && help) {
    return (
      <div className="search-input-with-help">
        {searchBox}
        {help}
      </div>
    )
  }

  return searchBox
}
