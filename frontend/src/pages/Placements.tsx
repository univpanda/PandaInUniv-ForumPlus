import { useState, useMemo, useCallback } from 'react'
import { ChevronDown } from 'lucide-react'
import {
  usePlacementFilters,
  usePlacementSearch,
  useReverseSearch,
  useProgramsForYearRange,
  useUniversitiesForProgramYearRange,
} from '../hooks/usePlacementQueries'
import { LoadingSpinner } from '../components/ui'
import type { PlacementSubTab, Placement, PlacementFilters } from '../types'

interface PlacementsProps {
  isActive?: boolean
}

const CURRENT_YEAR = new Date().getFullYear()
const MAX_YEAR = CURRENT_YEAR - 1
const MIN_YEAR = CURRENT_YEAR - 3

export function Placements({ isActive = true }: PlacementsProps) {
  const { data: filters, isLoading: filtersLoading } = usePlacementFilters()
  const degree = 'PhD'
  const [fromYear, setFromYear] = useState<number>(MAX_YEAR)
  const [toYear, setToYear] = useState<number>(MAX_YEAR)
  const [subTab, setSubTab] = useState<PlacementSubTab>('search')

  // Generate year options from 2023 to (current year - 1) (descending)
  const yearOptions = useMemo(() => {
    const years: number[] = []
    for (let y = MAX_YEAR; y >= MIN_YEAR; y--) {
      years.push(y)
    }
    return years
  }, [])

  const startYearOptions = useMemo(
    () => yearOptions.map(String),
    [yearOptions]
  )

  const endYearOptions = useMemo(
    () => yearOptions.filter((year) => year >= fromYear).map(String),
    [yearOptions, fromYear]
  )

  const handleFromYearChange = useCallback((value: string | null) => {
    if (!value) return
    const nextFromYear = parseInt(value, 10)
    setFromYear(nextFromYear)
    if (toYear < nextFromYear) {
      setToYear(nextFromYear)
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
            value={fromYear.toString()}
            options={startYearOptions}
            onChange={handleFromYearChange}
            searchPlaceholder="Select start year"
          />
          <FilterSelect
            value={toYear.toString()}
            options={endYearOptions}
            onChange={(val) => val && setToYear(parseInt(val, 10))}
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

      {/* Tab content - keep all mounted to preserve state */}
      <div className="placements-content">
        <div className={subTab !== 'search' ? 'hidden' : ''}>
          <SearchTab
            isActive={isActive && subTab === 'search'}
            filters={filters}
            commonFilters={commonFilters}
          />
        </div>
        <div className={subTab !== 'compare' ? 'hidden' : ''}>
          <CompareTab
            isActive={isActive && subTab === 'compare'}
            filters={filters}
            commonFilters={commonFilters}
          />
        </div>
        <div className={subTab !== 'reverse' ? 'hidden' : ''}>
          <ReverseSearchTab
            isActive={isActive && subTab === 'reverse'}
            filters={filters}
            commonFilters={commonFilters}
          />
        </div>
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

  // Get programs with placements for year range (no university filter)
  const { data: filteredPrograms } = useProgramsForYearRange(
    commonFilters.fromYear,
    commonFilters.toYear
  )

  // Get universities with placements for selected program and year range
  const { data: filteredUniversities } = useUniversitiesForProgramYearRange(
    program,
    commonFilters.fromYear,
    commonFilters.toYear
  )

  const searchParams = useMemo(() => ({
    degree: commonFilters.degree,
    program,
    university,
    fromYear: commonFilters.fromYear,
    toYear: commonFilters.toYear,
    limit: pageSize,
    offset: page * pageSize,
  }), [commonFilters, program, university, page])

  const canSearch = !!program && !!university

  const { data: searchResult, isLoading, isFetching } = usePlacementSearch(
    searchParams,
    searchTriggered && isActive && canSearch
  )

  const handleSearch = useCallback(() => {
    if (program && university) {
      setPage(0)
      setSearchTriggered(true)
    }
  }, [program, university])

  const handleReset = useCallback(() => {
    setProgram(null)
    setUniversity(null)
    setSearchTriggered(false)
    setPage(0)
  }, [])

  // Program options: only show programs with placements for year range
  const programOptions = filteredPrograms || []
  // University options: only show universities with placements for selected program + year range
  const universityOptions = program ? (filteredUniversities || []) : []
  const totalPages = Math.ceil((searchResult?.totalCount || 0) / pageSize)

  return (
    <div className="placement-search">
      <div className="placement-filters">
        <div className="filter-row">
          <FilterSelect
            value={program}
            options={programOptions}
            onChange={(val) => {
              setProgram(val)
              setUniversity(null) // Reset university when program changes
            }}
            placeholder="Select discipline"
            searchPlaceholder="Select discipline"
          />
          <FilterSelect
            value={university}
            options={universityOptions}
            onChange={setUniversity}
            placeholder="Select university"
            searchPlaceholder="Select university"
            disabled={!program}
          />
        </div>
        <div className="filter-actions">
          <button className="btn-primary" onClick={handleSearch} disabled={!canSearch}>
            Search
          </button>
          <button className="btn-secondary" onClick={handleReset}>
            Reset
          </button>
        </div>
      </div>

      {/* Results */}
      {searchTriggered && canSearch && (
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
  const [entry1, setEntry1] = useState<CompareEntry>({ program: null, university: null })
  const [entry2, setEntry2] = useState<CompareEntry>({ program: null, university: null })
  const [searchTriggered, setSearchTriggered] = useState(false)

  // Get programs with placements for year range
  const { data: filteredPrograms } = useProgramsForYearRange(
    commonFilters.fromYear,
    commonFilters.toYear
  )

  // Get universities for each entry's program and year range
  const { data: filteredUniversities1 } = useUniversitiesForProgramYearRange(
    entry1.program,
    commonFilters.fromYear,
    commonFilters.toYear
  )
  const { data: filteredUniversities2 } = useUniversitiesForProgramYearRange(
    entry2.program,
    commonFilters.fromYear,
    commonFilters.toYear
  )

  // Search for each entry
  const search1 = usePlacementSearch(
    {
      degree: commonFilters.degree,
      program: entry1.program,
      university: entry1.university,
      fromYear: commonFilters.fromYear,
      toYear: commonFilters.toYear,
      limit: 200,
    },
    searchTriggered && isActive && !!entry1.program && !!entry1.university
  )
  const search2 = usePlacementSearch(
    {
      degree: commonFilters.degree,
      program: entry2.program,
      university: entry2.university,
      fromYear: commonFilters.fromYear,
      toYear: commonFilters.toYear,
      limit: 200,
    },
    searchTriggered && isActive && !!entry2.program && !!entry2.university
  )

  const handleCompare = useCallback(() => {
    if (entry1.program && entry1.university && entry2.program && entry2.university) {
      setSearchTriggered(true)
    }
  }, [entry1, entry2])

  const handleReset = useCallback(() => {
    setEntry1({ program: null, university: null })
    setEntry2({ program: null, university: null })
    setSearchTriggered(false)
  }, [])

  // Program options: only show programs with placements for year range
  const programOptions = filteredPrograms || []

  // Get university options for each entry, filtering out duplicates when same program is selected
  const getUniversityOptions1 = () => {
    const options = entry1.program ? (filteredUniversities1 || []) : []
    // If same program, exclude the university selected in entry2
    if (entry1.program === entry2.program && entry2.university) {
      return options.filter(u => u !== entry2.university)
    }
    return options
  }

  const getUniversityOptions2 = () => {
    const options = entry2.program ? (filteredUniversities2 || []) : []
    // If same program, exclude the university selected in entry1
    if (entry1.program === entry2.program && entry1.university) {
      return options.filter(u => u !== entry1.university)
    }
    return options
  }

  const isLoading = search1.isLoading || search2.isLoading
  const canCompare = entry1.program && entry1.university && entry2.program && entry2.university

  return (
    <div className="placement-compare">
      <div className="placement-filters">
        <div className="compare-entries">
          <div className="compare-selects">
            <div className="compare-select-row">
              <FilterSelect
                value={entry1.program}
                options={programOptions}
                onChange={(val) => setEntry1({ program: val, university: null })}
                placeholder="Select discipline"
                searchPlaceholder="Select discipline"
              />
              <FilterSelect
                value={entry1.university}
                options={getUniversityOptions1()}
                onChange={(val) => setEntry1(prev => ({ ...prev, university: val }))}
                placeholder="Select university"
                searchPlaceholder="Select university"
                disabled={!entry1.program}
              />
            </div>
            <div className="compare-select-row">
              <FilterSelect
                value={entry2.program}
                options={programOptions}
                onChange={(val) => setEntry2({ program: val, university: null })}
                placeholder="Select discipline"
                searchPlaceholder="Select discipline"
              />
              <FilterSelect
                value={entry2.university}
                options={getUniversityOptions2()}
                onChange={(val) => setEntry2(prev => ({ ...prev, university: val }))}
                placeholder="Select university"
                searchPlaceholder="Select university"
                disabled={!entry2.program}
              />
            </div>
          </div>
        </div>
        <div className="filter-actions">
          <button
            className="btn-primary"
            onClick={handleCompare}
            disabled={!canCompare}
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
                { label: `${search1.data?.placements?.[0]?.program || entry1.program} - ${entry1.university}`, placements: search1.data?.placements || [] },
                { label: `${search2.data?.placements?.[0]?.program || entry2.program} - ${entry2.university}`, placements: search2.data?.placements || [] },
              ]}
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
        <div className="filter-row">
          <FilterSelect
            value={program}
            options={filters?.programs || []}
            onChange={setProgram}
            placeholder="Select discipline"
            searchPlaceholder="Select discipline"
          />
          <div className="filter-group">
            <input
              type="text"
              value={placementUniv}
              onChange={(e) => setPlacementUniv(e.target.value)}
              placeholder="Enter placement institution (e.g., Harvard, Google)"
              className="filter-input"
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
            />
          </div>
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
    <>
      {/* Desktop table view */}
      <div className="placement-table-wrapper placement-desktop">
        <table className="placement-table">
          <thead>
            <tr>
              {showUniversity && <th>University</th>}
              <th className="col-program">Program</th>
              <th>Year</th>
              <th>Name</th>
              <th>Placement</th>
              <th>Designation</th>
            </tr>
          </thead>
          <tbody>
            {placements.map(p => (
              <tr key={p.id}>
                {showUniversity && <td>{p.university || '-'}</td>}
                <td className="col-program">{p.program || '-'}</td>
                <td>{p.year || '-'}</td>
                <td>{p.name || '-'}</td>
                <td>{p.placementUniv || '-'}</td>
                <td>{p.role || '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile card view */}
      <div className="placement-cards placement-mobile">
        {placements.map(p => (
          <div key={p.id} className="placement-card">
            <div className="placement-card-header">
              <span className="placement-card-name">{p.name || '-'}</span>
              <span className="placement-card-year">{p.year || '-'}</span>
            </div>
            <div className="placement-card-placement">{p.placementUniv || '-'}</div>
            {p.role && <div className="placement-card-role">{p.role}</div>}
            <div className="placement-card-meta">
              {p.program && <span className="placement-card-program">{p.program}</span>}
              {p.university && <span className="placement-card-university">{p.university}</span>}
            </div>
          </div>
        ))}
      </div>
    </>
  )
}

interface ComparisonTableProps {
  results: { label: string; placements: Placement[] }[]
}

function ComparisonTable({ results }: ComparisonTableProps) {
  const [expandedRows, setExpandedRows] = useState<Set<string>>(new Set())

  // Get all unique years across both results, sorted descending
  const years = [...new Set(
    results.flatMap(r => r.placements.map(p => p.year)).filter(Boolean)
  )].sort((a, b) => (b || 0) - (a || 0)) as number[]

  if (results.every(r => r.placements.length === 0)) {
    return <div className="no-results">No placements found for comparison</div>
  }

  // Group placements by placement institution for a given result and year
  const groupByInstitution = (placements: Placement[]) => {
    const grouped: Record<string, Placement[]> = {}
    placements.forEach(p => {
      const inst = p.placementUniv || 'Unknown'
      if (!grouped[inst]) grouped[inst] = []
      grouped[inst].push(p)
    })
    return Object.entries(grouped).sort((a, b) => a[0].localeCompare(b[0]))
  }

  const toggleRow = (rowKey: string) => {
    setExpandedRows(prev => {
      const next = new Set(prev)
      if (next.has(rowKey)) {
        next.delete(rowKey)
      } else {
        next.add(rowKey)
      }
      return next
    })
  }

  return (
    <div className="comparison-container">
      {years.map(year => (
        <div key={year} className="comparison-year-section">
          <div className="comparison-year-header">{year}</div>
          <div className="comparison-columns">
            {results.map((r, idx) => {
              const yearPlacements = r.placements.filter(p => p.year === year)
              const grouped = groupByInstitution(yearPlacements)
              return (
                <div key={idx} className="comparison-column">
                  <div className="comparison-column-header">
                    <div className="comparison-label">{r.label}</div>
                  </div>
                  <div className="comparison-count">
                    <span className="count-number">{yearPlacements.length}</span>
                    <span className="count-label">PLACEMENTS</span>
                  </div>
                  <div className="comparison-institutions">
                    {grouped.length > 0 ? (
                      grouped.map(([inst, placements]) => {
                        const rowKey = `${year}-${idx}-${inst}`
                        const isExpanded = expandedRows.has(rowKey)
                        return (
                          <div key={inst} className="institution-row">
                            <button
                              className="institution-name"
                              onClick={() => toggleRow(rowKey)}
                            >
                              <span>{inst} ({placements.length})</span>
                              <span className={`expand-icon ${isExpanded ? 'expanded' : ''}`}>+</span>
                            </button>
                            {isExpanded && (
                              <div className="institution-details">
                                {placements.map(p => (
                                  <div key={p.id} className="placement-detail">
                                    {p.role || 'Unknown designation'}
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        )
                      })
                    ) : (
                      <div className="no-placements">No placements</div>
                    )}
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      ))}
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
