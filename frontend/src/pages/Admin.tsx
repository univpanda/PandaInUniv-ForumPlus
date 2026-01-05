import { useState, useMemo, useRef, useEffect } from 'react'
import { UserManagement } from './UserManagement'
import {
  useUniversities,
  useCountries,
  useCreateCountry,
  useCreateUniversity,
  useDeleteCountry,
  useDeleteUniversity,
} from '../hooks/usePlacementQueries'
import { useToast } from '../contexts/ToastContext'
import { X } from 'lucide-react'

type AdminSubTab = 'country' | 'university' | 'pandas'
type UniversitySortColumn = 'university' | 'country' | 'rank' | 'top50'
type CountrySortColumn = 'name' | 'code'
type SortDirection = 'asc' | 'desc'

interface AdminProps {
  isActive?: boolean
}

interface UniversityTabState {
  searchQuery: string
  sortColumn: UniversitySortColumn
  sortDirection: SortDirection
}

interface CountryTabState {
  searchQuery: string
  sortColumn: CountrySortColumn
  sortDirection: SortDirection
}

export function Admin({ isActive = true }: AdminProps) {
  const [subTab, setSubTab] = useState<AdminSubTab>('country')

  // Lift tab states to preserve across tab switches
  const [countryState, setCountryState] = useState<CountryTabState>({
    searchQuery: '',
    sortColumn: 'name',
    sortDirection: 'asc',
  })

  const [universityState, setUniversityState] = useState<UniversityTabState>({
    searchQuery: '',
    sortColumn: 'university',
    sortDirection: 'asc',
  })

  return (
    <div className="admin-container">
      {/* Sub-tab navigation */}
      <div className="admin-tabs">
        <button
          className={`admin-tab ${subTab === 'country' ? 'active' : ''}`}
          onClick={() => setSubTab('country')}
        >
          Country
        </button>
        <button
          className={`admin-tab ${subTab === 'university' ? 'active' : ''}`}
          onClick={() => setSubTab('university')}
        >
          University
        </button>
        <button
          className={`admin-tab ${subTab === 'pandas' ? 'active' : ''}`}
          onClick={() => setSubTab('pandas')}
        >
          Pandas
        </button>
      </div>

      {/* Tab content - keep all mounted to preserve state */}
      <div className="admin-content">
        <div className={subTab !== 'country' ? 'hidden' : ''}>
          <CountryTab
            isActive={isActive && subTab === 'country'}
            state={countryState}
            setState={setCountryState}
          />
        </div>
        <div className={subTab !== 'university' ? 'hidden' : ''}>
          <UniversityTab
            isActive={isActive && subTab === 'university'}
            state={universityState}
            setState={setUniversityState}
          />
        </div>
        <div className={subTab !== 'pandas' ? 'hidden' : ''}>
          <UserManagement isActive={isActive && subTab === 'pandas'} />
        </div>
      </div>
    </div>
  )
}

interface CountryTabProps {
  isActive: boolean
  state: CountryTabState
  setState: React.Dispatch<React.SetStateAction<CountryTabState>>
}

function CountryTab({ isActive, state, setState }: CountryTabProps) {
  const { data: countries = [], isLoading, error } = useCountries()
  const createCountry = useCreateCountry()
  const deleteCountry = useDeleteCountry()
  const toast = useToast()
  const { searchQuery, sortColumn, sortDirection } = state

  const [isAdding, setIsAdding] = useState(false)
  const [newName, setNewName] = useState('')
  const [newCode, setNewCode] = useState('')
  const [pinnedCountryIds, setPinnedCountryIds] = useState<string[]>([])
  const nameInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (isAdding && nameInputRef.current) {
      nameInputRef.current.focus()
    }
  }, [isAdding])

  const setSearchQuery = (query: string) => {
    setState(prev => ({ ...prev, searchQuery: query }))
  }

  const handleSort = (column: CountrySortColumn) => {
    setState(prev => {
      if (prev.sortColumn === column) {
        return { ...prev, sortDirection: prev.sortDirection === 'asc' ? 'desc' : 'asc' }
      } else {
        return { ...prev, sortColumn: column, sortDirection: 'asc' }
      }
    })
  }

  const handleAddClick = () => {
    setIsAdding(true)
    setNewName('')
    setNewCode('')
  }

  const handleCancelAdd = () => {
    setIsAdding(false)
    setNewName('')
    setNewCode('')
  }

  const handleDelete = (countryId: string, name: string) => {
    if (!window.confirm(`Delete "${name}"? This cannot be undone.`)) return
    deleteCountry.mutate(countryId, {
      onSuccess: () => {
        toast.showSuccess('Country deleted')
        setPinnedCountryIds((prev) => prev.filter((id) => id !== countryId))
      },
      onError: () => {
        toast.showError('Failed to delete country')
      },
    })
  }

  const handleSaveNew = () => {
    if (newName.trim() && newCode.trim()) {
      createCountry.mutate(
        { name: newName.trim(), code: newCode.trim() },
        {
          onSuccess: (country) => {
            setIsAdding(false)
            setNewName('')
            setNewCode('')
            setPinnedCountryIds((prev) => [...prev, country.id])
            toast.showSuccess('Country added')
          },
          onError: (error: { code?: string; message?: string }) => {
            const message = error?.message?.toLowerCase() || ''
            if (error?.code === '23505' || message.includes('duplicate') || message.includes('unique')) {
              toast.showError('Country already exists')
              return
            }
            toast.showError('Failed to add country')
          },
        }
      )
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSaveNew()
    } else if (e.key === 'Escape') {
      handleCancelAdd()
    }
  }

  const sortedCountries = useMemo(() => {
    const filtered = countries.filter((c) =>
      c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      c.code.toLowerCase().includes(searchQuery.toLowerCase())
    )

    const pinnedSet = new Set(pinnedCountryIds)
    const pinned = pinnedCountryIds
      .map((id) => filtered.find((country) => country.id === id))
      .filter((country): country is typeof filtered[number] => Boolean(country))

    const temps = filtered.filter((country) => country.id.startsWith('temp-') && !pinnedSet.has(country.id))

    const rest = filtered.filter((country) => !pinnedSet.has(country.id) && !country.id.startsWith('temp-'))

    const sortedRest = [...rest].sort((a, b) => {
      const aVal = sortColumn === 'name' ? a.name : a.code
      const bVal = sortColumn === 'name' ? b.name : b.code

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1
      return 0
    })

    return [...pinned, ...temps, ...sortedRest]
  }, [countries, searchQuery, sortColumn, sortDirection, pinnedCountryIds])

  return (
    <div className="university-admin">
      <div className="admin-section">
        <div className="admin-toolbar">
          <p className="admin-description">
            {sortedCountries.length} of {countries.length} countries
          </p>
          <input
            type="text"
            placeholder="Search countries..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="admin-search-input"
          />
          {isAdding ? (
            <div className="admin-actions">
              <button className="admin-add-btn" onClick={handleSaveNew}>
                Save
              </button>
              <button className="admin-cancel-btn" onClick={handleCancelAdd}>
                Cancel
              </button>
            </div>
          ) : (
            <button className="admin-add-btn" onClick={handleAddClick}>
              + Add
            </button>
          )}
        </div>

        {isLoading && <div className="admin-placeholder">Loading countries...</div>}

        {error && (
          <div className="admin-placeholder" style={{ color: 'var(--color-error)' }}>
            Failed to load countries.
          </div>
        )}

        {!isLoading && !error && (sortedCountries.length > 0 || isAdding) && (
          <div className="university-table-wrapper country-table-wrapper">
            <table className="university-table country-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th className="sortable" onClick={() => handleSort('name')}>
                    Country {sortColumn === 'name' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="sortable" onClick={() => handleSort('code')}>
                    Code {sortColumn === 'code' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {isAdding && (
                  <tr className="adding-row">
                    <td>-</td>
                    <td>
                      <input
                        ref={nameInputRef}
                        type="text"
                        value={newName}
                        onChange={(e) => setNewName(e.target.value)}
                        onKeyDown={handleKeyDown}
                        placeholder="Country name"
                        className="inline-input"
                      />
                    </td>
                    <td>
                      <input
                        type="text"
                        value={newCode}
                        onChange={(e) => setNewCode(e.target.value.toUpperCase())}
                        onKeyDown={handleKeyDown}
                        placeholder="Code"
                        maxLength={3}
                        className="inline-input"
                      />
                    </td>
                    <td />
                  </tr>
                )}
                {sortedCountries.map((country, index) => (
                  <tr key={country.id}>
                    <td>{index + 1}</td>
                    <td>{country.name}</td>
                    <td>{country.code}</td>
                    <td>
                      <button
                        className="admin-delete-btn"
                        onClick={() => handleDelete(country.id, country.name)}
                        title="Delete"
                      >
                        <X size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {!isLoading && !error && sortedCountries.length === 0 && !isAdding && (
          <div className="admin-placeholder">
            {searchQuery ? 'No countries match your search.' : 'No countries found.'}
          </div>
        )}
      </div>
    </div>
  )
}

interface UniversityTabProps {
  isActive: boolean
  state: UniversityTabState
  setState: React.Dispatch<React.SetStateAction<UniversityTabState>>
}

function UniversityTab({ isActive, state, setState }: UniversityTabProps) {
  const { data: universities = [], isLoading, error } = useUniversities()
  const { data: countries = [] } = useCountries()
  const createUniversity = useCreateUniversity()
  const deleteUniversity = useDeleteUniversity()
  const toast = useToast()
  const { searchQuery, sortColumn, sortDirection } = state

  const [isAdding, setIsAdding] = useState(false)
  const [newUniversity, setNewUniversity] = useState('')
  const [newCountryId, setNewCountryId] = useState<string>('')
  const [newRank, setNewRank] = useState('')
  const [newTop50, setNewTop50] = useState(false)
  const [newUrl, setNewUrl] = useState('')
  const [pinnedUniversityIds, setPinnedUniversityIds] = useState<string[]>([])
  const universityInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (isAdding && universityInputRef.current) {
      universityInputRef.current.focus()
    }
  }, [isAdding])

  const setSearchQuery = (query: string) => {
    setState(prev => ({ ...prev, searchQuery: query }))
  }

  const handleSort = (column: UniversitySortColumn) => {
    setState(prev => {
      if (prev.sortColumn === column) {
        return { ...prev, sortDirection: prev.sortDirection === 'asc' ? 'desc' : 'asc' }
      } else {
        return { ...prev, sortColumn: column, sortDirection: 'asc' }
      }
    })
  }

  const handleAddClick = () => {
    setIsAdding(true)
    setNewUniversity('')
    setNewCountryId('')
    setNewRank('')
    setNewTop50(false)
    setNewUrl('')
  }

  const handleCancelAdd = () => {
    setIsAdding(false)
    setNewUniversity('')
    setNewCountryId('')
    setNewRank('')
    setNewTop50(false)
    setNewUrl('')
  }

  const handleDelete = (universityId: string, name: string) => {
    if (!window.confirm(`Delete "${name}"? This cannot be undone.`)) return
    deleteUniversity.mutate(universityId, {
      onSuccess: () => {
        toast.showSuccess('University deleted')
        setPinnedUniversityIds((prev) => prev.filter((id) => id !== universityId))
      },
      onError: () => {
        toast.showError('Failed to delete university')
      },
    })
  }

  const handleSaveNew = () => {
    if (newUniversity.trim()) {
      createUniversity.mutate(
        {
          university: newUniversity.trim(),
          country_id: newCountryId || null,
          rank: newRank ? parseInt(newRank, 10) : null,
          top50: newTop50 ? 1 : 0,
          university_url: newUrl.trim() || null,
        },
        {
          onSuccess: (university) => {
            setIsAdding(false)
            setNewUniversity('')
            setNewCountryId('')
            setNewRank('')
            setNewTop50(false)
            setNewUrl('')
            setPinnedUniversityIds((prev) => [...prev, university.id])
            toast.showSuccess('University added')
          },
          onError: (error: { code?: string; message?: string }) => {
            const message = error?.message?.toLowerCase() || ''
            if (error?.code === '23505' || message.includes('duplicate') || message.includes('unique')) {
              toast.showError('University already exists')
              return
            }
            toast.showError('Failed to add university')
          },
        }
      )
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSaveNew()
    } else if (e.key === 'Escape') {
      handleCancelAdd()
    }
  }

  const sortedUniversities = useMemo(() => {
    const filtered = universities.filter((uni) =>
      uni.university.toLowerCase().includes(searchQuery.toLowerCase())
    )

    const pinnedSet = new Set(pinnedUniversityIds)
    const pinned = pinnedUniversityIds
      .map((id) => filtered.find((university) => university.id === id))
      .filter((university): university is typeof filtered[number] => Boolean(university))

    const temps = filtered.filter((university) => university.id.startsWith('temp-') && !pinnedSet.has(university.id))

    const rest = filtered.filter((university) => !pinnedSet.has(university.id) && !university.id.startsWith('temp-'))

    const sortedRest = [...rest].sort((a, b) => {
      let aVal: string | number | boolean | null
      let bVal: string | number | boolean | null

      switch (sortColumn) {
        case 'university':
          aVal = a.university
          bVal = b.university
          break
        case 'country':
          aVal = a.country?.name || ''
          bVal = b.country?.name || ''
          break
        case 'rank':
          aVal = a.rank ?? Infinity
          bVal = b.rank ?? Infinity
          break
        case 'top50':
          aVal = a.top50 ? 1 : 0
          bVal = b.top50 ? 1 : 0
          break
        default:
          return 0
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1
      return 0
    })

    return [...pinned, ...temps, ...sortedRest]
  }, [universities, searchQuery, sortColumn, sortDirection, pinnedUniversityIds])

  return (
    <div className="university-admin">
      <div className="admin-section">
        <div className="admin-toolbar">
          <p className="admin-description">
            {sortedUniversities.length} of {universities.length} universities
          </p>
          <input
            type="text"
            placeholder="Search universities..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="admin-search-input"
          />
          {isAdding ? (
            <div className="admin-actions">
              <button className="admin-add-btn" onClick={handleSaveNew}>
                Save
              </button>
              <button className="admin-cancel-btn" onClick={handleCancelAdd}>
                Cancel
              </button>
            </div>
          ) : (
            <button className="admin-add-btn" onClick={handleAddClick}>
              + Add
            </button>
          )}
        </div>

        {isLoading && <div className="admin-placeholder">Loading universities...</div>}

        {error && (
          <div className="admin-placeholder" style={{ color: 'var(--color-error)' }}>
            Failed to load universities.
          </div>
        )}

        {!isLoading && !error && (sortedUniversities.length > 0 || isAdding) && (
          <div className="university-table-wrapper">
            <table className="university-table">
              <thead>
                <tr>
                  <th>#</th>
                  <th className="sortable" onClick={() => handleSort('university')}>
                    University {sortColumn === 'university' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="sortable" onClick={() => handleSort('country')}>
                    Country {sortColumn === 'country' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="sortable" onClick={() => handleSort('rank')}>
                    Rank {sortColumn === 'rank' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="sortable" onClick={() => handleSort('top50')}>
                    Top 50 {sortColumn === 'top50' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {isAdding && (
                  <tr className="adding-row">
                    <td>-</td>
                    <td>
                      <input
                        ref={universityInputRef}
                        type="text"
                        value={newUniversity}
                        onChange={(e) => setNewUniversity(e.target.value)}
                        onKeyDown={handleKeyDown}
                        placeholder="University name"
                        className="inline-input"
                      />
                    </td>
                    <td>
                      <select
                        value={newCountryId}
                        onChange={(e) => setNewCountryId(e.target.value)}
                        onKeyDown={handleKeyDown}
                        className="inline-input"
                      >
                        <option value="">Select country</option>
                        {countries.map((c) => (
                          <option key={c.id} value={c.id}>
                            {c.name}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td>
                      <input
                        type="number"
                        value={newRank}
                        onChange={(e) => setNewRank(e.target.value)}
                        onKeyDown={handleKeyDown}
                        placeholder="Rank"
                        className="inline-input"
                      />
                    </td>
                    <td>
                      <input
                        type="checkbox"
                        checked={newTop50}
                        onChange={(e) => setNewTop50(e.target.checked)}
                        onKeyDown={handleKeyDown}
                      />
                    </td>
                    <td />
                  </tr>
                )}
                {sortedUniversities.map((uni, index) => (
                  <tr key={uni.id}>
                    <td>{index + 1}</td>
                    <td>
                      {uni.university_url ? (
                        <a href={uni.university_url} target="_blank" rel="noopener noreferrer">
                          {uni.university}
                        </a>
                      ) : (
                        uni.university
                      )}
                    </td>
                    <td>{uni.country?.name || '-'}</td>
                    <td>{uni.rank || '-'}</td>
                    <td>{uni.top50 ? 'Yes' : 'No'}</td>
                    <td>
                      <button
                        className="admin-delete-btn"
                        onClick={() => handleDelete(uni.id, uni.university)}
                        title="Delete"
                      >
                        <X size={16} />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {!isLoading && !error && sortedUniversities.length === 0 && !isAdding && (
          <div className="admin-placeholder">
            {searchQuery ? 'No universities match your search.' : 'No universities found.'}
          </div>
        )}
      </div>
    </div>
  )
}
