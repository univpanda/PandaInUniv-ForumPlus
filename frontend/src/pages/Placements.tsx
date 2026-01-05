import { useState, useMemo, useCallback } from 'react'
import { ChevronDown, X } from 'lucide-react'
import {
  usePlacementFilters,
  usePlacementSearch,
  useReverseSearch,
  useUniversitiesForProgram,
} from '../hooks/usePlacementQueries'
import { LoadingSpinner } from '../components/ui'
import type { PlacementSubTab, Placement, PlacementFilters } from '../types'

interface PlacementsProps {
  isActive?: boolean
}

export function Placements({ isActive = true }: PlacementsProps) {
  const { data: filters, isLoading: filtersLoading } = usePlacementFilters()
  const degree = 'PhD'
  const [fromYear, setFromYear] = useState<number | null>(null)
  const [toYear, setToYear] = useState<number | null>(null)
  const [subTab, setSubTab] = useState<PlacementSubTab>('search')

  const startYearOptions = useMemo(
    () => ['All Years', ...(filters?.years || []).map(String)],
    [filters?.years]
  )

  const endYearOptions = useMemo(() => {
    if (!fromYear) return ['All Years', ...(filters?.years || []).map(String)]
    return ['All Years', ...(filters?.years || []).filter((year) => year >= fromYear).map(String)]
  }, [fromYear, filters?.years])

  const handleFromYearChange = useCallback((value: string | null) => {
    const nextFromYear = value && value !== 'All Years' ? parseInt(value, 10) : null
    setFromYear(nextFromYear)
    if (toYear && nextFromYear && toYear < nextFromYear) {
      setToYear(null)
    }
  }, [toYear])

  const commonFilters = useMemo(() => ({
    degree,
    fromYear,
    toYear,
  }), [degree, fromYear, toYear])

  if (filtersLoading) {
    return <LoadingSpinner className="placements-loading" />
  }

  return (
    <div className="placements-container">
      {/* Common filters */}
      <div className="placement-filters">
        <div className="filter-row">
          <FilterSelect
            value={degree}
            options={['PhD']}
            onChange={() => {}}
            placeholder="PhD"
            disabled
          />
          <FilterSelect
            value={fromYear?.toString() || 'All Years'}
            options={startYearOptions}
            onChange={handleFromYearChange}
            searchPlaceholder="Select start year"
          />
          <FilterSelect
            value={toYear?.toString() || 'All Years'}
            options={endYearOptions}
            onChange={(val) => setToYear(val && val !== 'All Years' ? parseInt(val, 10) : null)}
            searchPlaceholder="Select end year"
          />
        </div>
      </div>

      {/* Sub-tab navigation - centered, outside card */}
      <div className="placements-tabs">
        <button
          className={`placements-tab ${subTab === 'search' ? 'active' : ''}`}
          onClick={() => setSubTab('search')}
        >
          Search
        </button>
        <button
          className={`placements-tab ${subTab === 'compare' ? 'active' : ''}`}
          onClick={() => setSubTab('compare')}
        >
          Compare
        </button>
        <button
          className={`placements-tab ${subTab === 'reverse' ? 'active' : ''}`}
          onClick={() => setSubTab('reverse')}
        >
          Reverse Search
        </button>
      </div>

      {/* Tab content */}
      <div className="placements-content">
        {subTab === 'search' && (
          <SearchTab
            isActive={isActive}
            filters={filters}
            commonFilters={commonFilters}
          />
        )}
        {subTab === 'compare' && (
          <CompareTab
            isActive={isActive}
            filters={filters}
            commonFilters={commonFilters}
          />
        )}
        {subTab === 'reverse' && (
          <ReverseSearchTab
            isActive={isActive}
            filters={filters}
            commonFilters={commonFilters}
          />
        )}
      </div>
    </div>
  )
}

// ==================== SEARCH TAB ====================
function SearchTab({
  isActive,
  filters,
  commonFilters,
}: {
  isActive: boolean
  filters: PlacementFilters | undefined
  commonFilters: { degree: string; fromYear: number | null; toYear: number | null }
}) {
  const [program, setProgram] = useState<string | null>(null)
  const [university, setUniversity] = useState<string | null>(null)
  const [searchTriggered, setSearchTriggered] = useState(false)
  const [page, setPage] = useState(0)
  const pageSize = 50

  // Get universities for selected program
  const { data: filteredUniversities } = useUniversitiesForProgram(program)

  const searchParams = useMemo(() => ({
    degree: commonFilters.degree,
    program,
    university,
    fromYear: commonFilters.fromYear,
    toYear: commonFilters.toYear,
    limit: pageSize,
    offset: page * pageSize,
  }), [commonFilters, program, university, page])

  const { data: searchResult, isLoading, isFetching } = usePlacementSearch(
    searchParams,
    searchTriggered && isActive
  )

  const handleSearch = useCallback(() => {
    setPage(0)
    setSearchTriggered(true)
  }, [])

  const handleReset = useCallback(() => {
    setProgram(null)
    setUniversity(null)
    setSearchTriggered(false)
    setPage(0)
  }, [])

  const universityOptions = program ? (filteredUniversities || []) : (filters?.universities || [])
  const totalPages = Math.ceil((searchResult?.totalCount || 0) / pageSize)

  return (
    <div className="placement-search">
      <div className="placement-filters">
        <div className="filter-row">
          <FilterSelect
            value={program}
            options={filters?.programs || []}
            onChange={(val) => {
              setProgram(val)
              setUniversity(null) // Reset university when program changes
            }}
            placeholder="All programs"
            searchPlaceholder="Select program"
          />
          <FilterSelect
            value={university}
            options={universityOptions}
            onChange={setUniversity}
            placeholder="All universities"
            searchPlaceholder="Select university"
          />
        </div>
        <div className="filter-actions">
          <button className="btn-primary" onClick={handleSearch}>
            Search
          </button>
          <button className="btn-secondary" onClick={handleReset}>
            Reset
          </button>
        </div>
      </div>

      {/* Results */}
      {searchTriggered && (
        <div className="placement-results">
          {isLoading ? (
            <LoadingSpinner className="placements-loading" />
          ) : (
            <>
              <div className="results-header">
                <span className="results-count">
                  {searchResult?.totalCount || 0} placements found
                </span>
                {isFetching && <span className="fetching-indicator">Updating...</span>}
              </div>
              <PlacementTable placements={searchResult?.placements || []} />
              {totalPages > 1 && (
                <Pagination
                  page={page}
                  totalPages={totalPages}
                  onPageChange={setPage}
                />
              )}
            </>
          )}
        </div>
      )}
    </div>
  )
}

// ==================== COMPARE TAB ====================
interface CompareEntry {
  program: string | null
  university: string | null
}

function CompareTab({
  isActive,
  filters,
  commonFilters,
}: {
  isActive: boolean
  filters: PlacementFilters | undefined
  commonFilters: { degree: string; fromYear: number | null; toYear: number | null }
}) {
  const [entries, setEntries] = useState<CompareEntry[]>([
    { program: null, university: null },
    { program: null, university: null },
  ])
  const [searchTriggered, setSearchTriggered] = useState(false)

  // Get filtered universities for each entry's program
  const { data: filteredUniversities1 } = useUniversitiesForProgram(entries[0]?.program)
  const { data: filteredUniversities2 } = useUniversitiesForProgram(entries[1]?.program)
  const { data: filteredUniversities3 } = useUniversitiesForProgram(entries[2]?.program)

  // Search for each entry
  const search1 = usePlacementSearch(
    {
      degree: commonFilters.degree,
      program: entries[0]?.program,
      university: entries[0]?.university,
      fromYear: commonFilters.fromYear,
      toYear: commonFilters.toYear,
      limit: 200,
    },
    searchTriggered && isActive && !!entries[0]?.program && !!entries[0]?.university
  )
  const search2 = usePlacementSearch(
    {
      degree: commonFilters.degree,
      program: entries[1]?.program,
      university: entries[1]?.university,
      fromYear: commonFilters.fromYear,
      toYear: commonFilters.toYear,
      limit: 200,
    },
    searchTriggered && isActive && !!entries[1]?.program && !!entries[1]?.university
  )
  const search3 = usePlacementSearch(
    {
      degree: commonFilters.degree,
      program: entries[2]?.program || null,
      university: entries[2]?.university || null,
      fromYear: commonFilters.fromYear,
      toYear: commonFilters.toYear,
      limit: 200,
    },
    searchTriggered && isActive && !!entries[2]?.program && !!entries[2]?.university
  )

  const handleCompare = useCallback(() => {
    const validEntries = entries.filter(e => e.program && e.university)
    if (validEntries.length >= 2) {
      setSearchTriggered(true)
    }
  }, [entries])

  const handleReset = useCallback(() => {
    setEntries([
      { program: null, university: null },
      { program: null, university: null },
    ])
    setSearchTriggered(false)
  }, [])

  const addEntry = useCallback(() => {
    if (entries.length < 3) {
      setEntries([...entries, { program: null, university: null }])
    }
  }, [entries])

  const removeEntry = useCallback((index: number) => {
    if (entries.length > 2) {
      setEntries(entries.filter((_, i) => i !== index))
    }
  }, [entries])

  const updateEntry = useCallback((index: number, field: keyof CompareEntry, value: string | null) => {
    setEntries(prev => {
      const newEntries = [...prev]
      newEntries[index] = { ...newEntries[index], [field]: value }
      // Reset university when program changes
      if (field === 'program') {
        newEntries[index].university = null
      }
      return newEntries
    })
  }, [])

  const getUniversityOptions = (index: number) => {
    const program = entries[index]?.program
    if (!program) return filters?.universities || []
    if (index === 0) return filteredUniversities1 || []
    if (index === 1) return filteredUniversities2 || []
    if (index === 2) return filteredUniversities3 || []
    return filters?.universities || []
  }

  const isLoading = search1.isLoading || search2.isLoading || search3.isLoading
  const validEntriesCount = entries.filter(e => e.program && e.university).length

  return (
    <div className="placement-compare">
      <div className="placement-filters">
        <div className="compare-entries">
          <label>Programs & Universities to Compare</label>
          <div className="compare-selects">
            {entries.map((entry, idx) => (
              <div key={idx} className="compare-select-row">
                <FilterSelect
                  value={entry.program}
                  options={filters?.programs || []}
                  onChange={(val) => updateEntry(idx, 'program', val)}
                  placeholder={`Program ${idx + 1}`}
                  searchPlaceholder="Select program"
                      />
                <FilterSelect
                  value={entry.university}
                  options={getUniversityOptions(idx)}
                  onChange={(val) => updateEntry(idx, 'university', val)}
                  placeholder={`University ${idx + 1}`}
                  searchPlaceholder="Select university"
                      />
                {entries.length > 2 && (
                  <button
                    className="btn-icon"
                    onClick={() => removeEntry(idx)}
                    title="Remove"
                  >
                    <X size={16} />
                  </button>
                )}
              </div>
            ))}
            {entries.length < 3 && (
              <button className="btn-secondary btn-small" onClick={addEntry}>
                + Add Entry
              </button>
            )}
          </div>
        </div>
        <div className="filter-actions">
          <button
            className="btn-primary"
            onClick={handleCompare}
            disabled={validEntriesCount < 2}
          >
            Compare
          </button>
          <button className="btn-secondary" onClick={handleReset}>
            Reset
          </button>
        </div>
      </div>

      {/* Comparison Results */}
      {searchTriggered && (
        <div className="placement-results">
          {isLoading ? (
            <LoadingSpinner className="placements-loading" />
          ) : (
            <ComparisonTable
              results={[
                { label: entries[0]?.program && entries[0]?.university ? `${entries[0].program} - ${entries[0].university}` : null, placements: search1.data?.placements || [] },
                { label: entries[1]?.program && entries[1]?.university ? `${entries[1].program} - ${entries[1].university}` : null, placements: search2.data?.placements || [] },
                ...(entries[2]?.program && entries[2]?.university ? [{ label: `${entries[2].program} - ${entries[2].university}`, placements: search3.data?.placements || [] }] : []),
              ].filter(r => r.label)}
            />
          )}
        </div>
      )}
    </div>
  )
}

// ==================== REVERSE SEARCH TAB ====================
function ReverseSearchTab({
  isActive,
  filters,
  commonFilters,
}: {
  isActive: boolean
  filters: PlacementFilters | undefined
  commonFilters: { degree: string; fromYear: number | null; toYear: number | null }
}) {
  const [placementUniv, setPlacementUniv] = useState('')
  const [program, setProgram] = useState<string | null>(null)
  const [searchTriggered, setSearchTriggered] = useState(false)
  const [page, setPage] = useState(0)
  const pageSize = 50

  const searchParams = useMemo(() => ({
    placementUniv,
    degree: commonFilters.degree,
    program,
    fromYear: commonFilters.fromYear,
    toYear: commonFilters.toYear,
    limit: pageSize,
    offset: page * pageSize,
  }), [placementUniv, commonFilters, program, page])

  const { data: searchResult, isLoading, isFetching } = useReverseSearch(
    searchParams,
    searchTriggered && isActive && !!placementUniv
  )

  const handleSearch = useCallback(() => {
    if (placementUniv.trim() && program) {
      setPage(0)
      setSearchTriggered(true)
    }
  }, [placementUniv, program])

  const handleReset = useCallback(() => {
    setPlacementUniv('')
    setProgram(null)
    setSearchTriggered(false)
    setPage(0)
  }, [])

  const totalPages = Math.ceil((searchResult?.totalCount || 0) / pageSize)

  return (
    <div className="placement-reverse">
      <div className="placement-filters">
        <p className="reverse-description">
          Find PhD graduates who were placed at a specific institution
        </p>
        <div className="filter-row">
          <div className="filter-group">
            <label>Placement University</label>
            <input
              type="text"
              value={placementUniv}
              onChange={(e) => setPlacementUniv(e.target.value)}
              placeholder="e.g., Harvard, Google, Federal Reserve"
              className="filter-input"
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
            />
          </div>
        </div>
        <div className="filter-row">
          <FilterSelect
            value={program}
            options={filters?.programs || []}
            onChange={setProgram}
            placeholder="All programs"
            searchPlaceholder="Select program"
          />
        </div>
        <div className="filter-actions">
          <button
            className="btn-primary"
            onClick={handleSearch}
            disabled={!placementUniv.trim() || !program}
          >
            Search
          </button>
          <button className="btn-secondary" onClick={handleReset}>
            Reset
          </button>
        </div>
      </div>

      {/* Results */}
      {searchTriggered && (
        <div className="placement-results">
          {isLoading ? (
            <LoadingSpinner className="placements-loading" />
          ) : (
            <>
              <div className="results-header">
                <span className="results-count">
                  {searchResult?.totalCount || 0} graduates found at "{placementUniv}"
                </span>
                {isFetching && <span className="fetching-indicator">Updating...</span>}
              </div>
              <PlacementTable placements={searchResult?.placements || []} showUniversity />
              {totalPages > 1 && (
                <Pagination
                  page={page}
                  totalPages={totalPages}
                  onPageChange={setPage}
                />
              )}
            </>
          )}
        </div>
      )}
    </div>
  )
}

// ==================== SHARED COMPONENTS ====================

interface FilterSelectProps {
  label?: string
  value: string | null
  options: string[]
  onChange: (value: string | null) => void
  placeholder?: string
  searchPlaceholder?: string
  disabled?: boolean
}

function FilterSelect({
  label,
  value,
  options,
  onChange,
  placeholder,
  searchPlaceholder,
  disabled,
}: FilterSelectProps) {
  const [isOpen, setIsOpen] = useState(false)
  const [search, setSearch] = useState('')

  const filteredOptions = options.filter(opt =>
    opt.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="filter-group">
      {label && <label>{label}</label>}
      <div className="filter-select">
        <button
          className="filter-select-trigger"
          onClick={() => {
            if (!disabled) {
              setIsOpen(!isOpen)
            }
          }}
          type="button"
          disabled={disabled}
        >
          <span className={value ? '' : 'placeholder'}>
            {value || placeholder || 'Select...'}
          </span>
          <ChevronDown size={16} className={isOpen ? 'rotated' : ''} />
        </button>
        {isOpen && (
          <>
            <div className="filter-select-backdrop" onClick={() => setIsOpen(false)} />
            <div className="filter-select-dropdown">
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={searchPlaceholder || "Search..."}
                className="filter-select-search"
                autoFocus
              />
              <div className="filter-select-options">
                {filteredOptions.map(opt => (
                  <button
                    key={opt}
                    className={`filter-select-option ${opt === value ? 'selected' : ''}`}
                    onClick={() => {
                      onChange(opt)
                      setIsOpen(false)
                      setSearch('')
                    }}
                  >
                    {opt}
                  </button>
                ))}
                {filteredOptions.length === 0 && (
                  <div className="filter-select-empty">No options found</div>
                )}
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

interface PlacementTableProps {
  placements: Placement[]
  showUniversity?: boolean
}

function PlacementTable({ placements, showUniversity = false }: PlacementTableProps) {
  if (placements.length === 0) {
    return <div className="no-results">No placements found</div>
  }

  return (
    <div className="placement-table-wrapper">
      <table className="placement-table">
        <thead>
          <tr>
            <th>Year</th>
            <th>Name</th>
            <th>Placement</th>
            <th>School</th>
            <th>Department</th>
            <th>Designation</th>
            {showUniversity && <th>Graduating University</th>}
          </tr>
        </thead>
        <tbody>
          {placements.map(p => (
            <tr key={p.id}>
              <td>{p.year || '-'}</td>
              <td>{p.name || '-'}</td>
              <td>{p.placementUniv || '-'}</td>
              <td>{p.school || '-'}</td>
              <td>{p.department || '-'}</td>
              <td>{p.role || '-'}</td>
              {showUniversity && <td>{p.university || '-'}</td>}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

interface ComparisonTableProps {
  results: { label: string | null; placements: Placement[] }[]
}

function ComparisonTable({ results }: ComparisonTableProps) {
  // Group placements by year for comparison
  const years = [...new Set(
    results.flatMap(r => r.placements.map(p => p.year)).filter(Boolean)
  )].sort((a, b) => (b || 0) - (a || 0))

  if (results.every(r => r.placements.length === 0)) {
    return <div className="no-results">No placements found for comparison</div>
  }

  return (
    <div className="comparison-wrapper">
      <div className="comparison-header">
        <div className="comparison-cell header-cell">Year</div>
        {results.map((r, idx) => (
          <div key={idx} className="comparison-cell header-cell">
            {r.label}
            <span className="placement-count">({r.placements.length})</span>
          </div>
        ))}
      </div>
      <div className="comparison-body">
        {years.map(year => (
          <div key={year} className="comparison-row">
            <div className="comparison-cell year-cell">{year}</div>
            {results.map((r, idx) => {
              const yearPlacements = r.placements.filter(p => p.year === year)
              return (
                <div key={idx} className="comparison-cell">
                  {yearPlacements.length > 0 ? (
                    <ul className="placement-list">
                      {yearPlacements.map(p => (
                        <li key={p.id}>
                          <span className="placement-name">{p.name}</span>
                          <span className="placement-inst">{p.placementUniv}</span>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <span className="no-data">-</span>
                  )}
                </div>
              )
            })}
          </div>
        ))}
      </div>
    </div>
  )
}

interface PaginationProps {
  page: number
  totalPages: number
  onPageChange: (page: number) => void
}

function Pagination({ page, totalPages, onPageChange }: PaginationProps) {
  return (
    <div className="pagination">
      <button
        className="btn-secondary btn-small"
        onClick={() => onPageChange(page - 1)}
        disabled={page === 0}
      >
        Previous
      </button>
      <span className="page-info">
        Page {page + 1} of {totalPages}
      </span>
      <button
        className="btn-secondary btn-small"
        onClick={() => onPageChange(page + 1)}
        disabled={page >= totalPages - 1}
      >
        Next
      </button>
    </div>
  )
}
