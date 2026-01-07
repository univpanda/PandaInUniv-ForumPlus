import { useState, useMemo, useRef, useEffect } from 'react'
import { UserManagement } from './UserManagement'
import {
  useUniversities,
  useCountries,
  useSchoolsByUniversity,
  useDepartmentsBySchool,
  useCreateCountry,
  useCreateUniversity,
  useCreateSchool,
  useCreateDepartment,
  useDeleteCountry,
  useDeleteUniversity,
  useDeleteSchool,
  useDeleteDepartment,
  useUpdateCountry,
  useUpdateUniversity,
  useUpdateSchool,
  useUpdateDepartment,
} from '../hooks/usePlacementQueries'
import type { SchoolType, University, School, Department } from '../hooks/usePlacementQueries'
import { useToast } from '../contexts/ToastContext'
import { SearchInput } from '../components/ui'
import { Plus, X } from 'lucide-react'

type AdminSubTab = 'country' | 'university' | 'school' | 'department' | 'pandas'
type UniversitySortColumn = 'university' | 'country' | 'us_news_2025_rank' | 'school_count'
type CountrySortColumn = 'name' | 'code' | 'university_count'
type SchoolSortColumn = 'school' | 'university' | 'type' | 'department_count'
type DepartmentSortColumn = 'department'
type SortDirection = 'asc' | 'desc'

interface AdminProps {
  isActive?: boolean
}

interface UniversityTabState {
  searchQuery: string
  sortColumn: UniversitySortColumn
  sortDirection: SortDirection
  page: number
}

interface SchoolTabState {
  selectedUniversityId: string | null
  searchQuery: string
  sortColumn: SchoolSortColumn
  sortDirection: SortDirection
  page: number
}

interface DepartmentTabState {
  selectedSchoolId: string | null
  searchQuery: string
  sortColumn: DepartmentSortColumn
  sortDirection: SortDirection
  page: number
}

interface CountryTabState {
  searchQuery: string
  sortColumn: CountrySortColumn
  sortDirection: SortDirection
  page: number
}

export function Admin({ isActive = true }: AdminProps) {
  const [subTab, setSubTab] = useState<AdminSubTab>('country')

  // Lift tab states to preserve across tab switches
  const [countryState, setCountryState] = useState<CountryTabState>({
    searchQuery: '',
    sortColumn: 'name',
    sortDirection: 'asc',
    page: 1,
  })

  const [universityState, setUniversityState] = useState<UniversityTabState>({
    searchQuery: '',
    sortColumn: 'university',
    sortDirection: 'asc',
    page: 1,
  })

  const [schoolState, setSchoolState] = useState<SchoolTabState>({
    selectedUniversityId: null,
    searchQuery: '',
    sortColumn: 'school',
    sortDirection: 'asc',
    page: 1,
  })

  const [departmentState, setDepartmentState] = useState<DepartmentTabState>({
    selectedSchoolId: null,
    searchQuery: '',
    sortColumn: 'department',
    sortDirection: 'asc',
    page: 1,
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
          className={`admin-tab ${subTab === 'school' ? 'active' : ''}`}
          onClick={() => setSubTab('school')}
        >
          School
        </button>
        <button
          className={`admin-tab ${subTab === 'department' ? 'active' : ''}`}
          onClick={() => setSubTab('department')}
        >
          Department
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
        <div className={subTab !== 'school' ? 'hidden' : ''}>
          <SchoolTab
            isActive={isActive && subTab === 'school'}
            state={schoolState}
            setState={setSchoolState}
          />
        </div>
        <div className={subTab !== 'department' ? 'hidden' : ''}>
          <DepartmentTab
            isActive={isActive && subTab === 'department'}
            state={departmentState}
            setState={setDepartmentState}
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

const COUNTRIES_PER_PAGE = 20
const UNIVERSITIES_PER_PAGE = 20
const SCHOOLS_PER_PAGE = 20
const DEPARTMENTS_PER_PAGE = 20

interface EditingCountry {
  id: string
  name: string
  code: string
  originalName: string
  originalCode: string
}

interface EditingUniversity {
  id: string
  university: string
  country_id: string | null
  us_news_2025_rank: string
  originalUniversity: string
  originalCountryId: string | null
  originalRank: string
}

interface EditingSchool {
  id: string
  school: string
  type: SchoolType
  originalSchool: string
  originalType: SchoolType
}

interface EditingDepartment {
  id: string
  department: string
  originalDepartment: string
}

function CountryTab({ isActive, state, setState }: CountryTabProps) {
  const { data: countries = [], isLoading, error } = useCountries()
  const createCountry = useCreateCountry()
  const deleteCountry = useDeleteCountry()
  const updateCountry = useUpdateCountry()
  const toast = useToast()
  const { searchQuery, sortColumn, sortDirection, page } = state

  const [isAdding, setIsAdding] = useState(false)
  const [newName, setNewName] = useState('')
  const [newCode, setNewCode] = useState('')
  const [pinnedCountryIds, setPinnedCountryIds] = useState<string[]>([])
  const [editingCountry, setEditingCountry] = useState<EditingCountry | null>(null)
  const nameInputRef = useRef<HTMLInputElement>(null)
  const editNameInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (isAdding && nameInputRef.current) {
      nameInputRef.current.focus()
    }
  }, [isAdding])

  const setSearchQuery = (query: string) => {
    setState(prev => ({ ...prev, searchQuery: query, page: 1 }))
  }

  const setPage = (newPage: number) => {
    setState(prev => ({ ...prev, page: newPage }))
  }

  const handleSort = (column: CountrySortColumn) => {
    setState(prev => {
      if (prev.sortColumn === column) {
        return { ...prev, sortDirection: prev.sortDirection === 'asc' ? 'desc' : 'asc', page: 1 }
      } else {
        return { ...prev, sortColumn: column, sortDirection: 'asc', page: 1 }
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

  // Inline editing handlers
  const handleStartEdit = (country: { id: string; name: string; code: string }) => {
    setEditingCountry({
      id: country.id,
      name: country.name,
      code: country.code,
      originalName: country.name,
      originalCode: country.code,
    })
  }

  const handleCancelEdit = () => {
    setEditingCountry(null)
  }

  const handleSaveEdit = () => {
    if (!editingCountry) return

    const nameChanged = editingCountry.name.trim().toLowerCase() !== editingCountry.originalName.toLowerCase()
    const codeChanged = editingCountry.code.trim().toUpperCase() !== editingCountry.originalCode.toUpperCase()

    // No changes, just cancel
    if (!nameChanged && !codeChanged) {
      setEditingCountry(null)
      return
    }

    if (!editingCountry.name.trim() || !editingCountry.code.trim()) {
      toast.showError('Name and code are required')
      return
    }

    updateCountry.mutate(
      {
        id: editingCountry.id,
        name: editingCountry.name.trim(),
        code: editingCountry.code.trim(),
      },
      {
        onSuccess: () => {
          setEditingCountry(null)
          toast.showSuccess('Country updated')
        },
        onError: (error: { code?: string; message?: string }) => {
          const message = error?.message?.toLowerCase() || ''
          if (error?.code === '23505' || message.includes('duplicate') || message.includes('unique')) {
            toast.showError('Country name or code already exists')
            return
          }
          toast.showError('Failed to update country')
        },
      }
    )
  }

  const handleEditKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSaveEdit()
    } else if (e.key === 'Escape') {
      handleCancelEdit()
    }
  }

  // Focus the edit input when editing starts
  useEffect(() => {
    if (editingCountry && editNameInputRef.current) {
      editNameInputRef.current.focus()
    }
  }, [editingCountry?.id])

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
      let aVal: string | number
      let bVal: string | number

      switch (sortColumn) {
        case 'name':
          aVal = a.name
          bVal = b.name
          break
        case 'code':
          aVal = a.code
          bVal = b.code
          break
        case 'university_count':
          aVal = a.university_count ?? 0
          bVal = b.university_count ?? 0
          break
        default:
          return 0
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1
      return 0
    })

    return [...pinned, ...temps, ...sortedRest]
  }, [countries, searchQuery, sortColumn, sortDirection, pinnedCountryIds])

  // Pagination
  const totalPages = Math.ceil(sortedCountries.length / COUNTRIES_PER_PAGE)
  const startIndex = (page - 1) * COUNTRIES_PER_PAGE
  const paginatedCountries = sortedCountries.slice(startIndex, startIndex + COUNTRIES_PER_PAGE)

  return (
    <div className="university-admin">
      <div className="admin-section country-tab-content">
        <div className="admin-toolbar">
          <p className="admin-description">
            {sortedCountries.length} of {countries.length} countries
          </p>
          <SearchInput
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder="Search countries..."
            className="admin-search-input"
          />
        </div>

        {isLoading && <div className="admin-placeholder">Loading countries...</div>}

        {error && (
          <div className="admin-placeholder" style={{ color: 'var(--color-error)' }}>
            Failed to load countries.
          </div>
        )}

        {!isLoading && !error && (sortedCountries.length > 0 || isAdding) && (
          <>
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
                  <th className="sortable" onClick={() => handleSort('university_count')}>
                    Universities {sortColumn === 'university_count' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="table-header-action-cell">
                    {!isAdding && (
                      <button
                        className="admin-delete-btn table-header-action"
                        onClick={handleAddClick}
                        title="Add country"
                        type="button"
                      >
                        <Plus size={16} />
                      </button>
                    )}
                  </th>
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
                    <td>-</td>
                    <td>
                      <button className="admin-delete-btn" onClick={handleCancelAdd} title="Cancel">
                        <X size={16} />
                      </button>
                    </td>
                  </tr>
                )}
                {paginatedCountries.map((country, index) => {
                  const isEditing = editingCountry?.id === country.id
                  return (
                    <tr key={country.id} className={isEditing ? 'editing-row' : ''}>
                      <td>{startIndex + index + 1}</td>
                      <td
                        className={!isEditing ? 'editable-cell' : ''}
                        onDoubleClick={() => !isEditing && handleStartEdit(country)}
                      >
                        {isEditing ? (
                          <input
                            ref={editNameInputRef}
                            type="text"
                            value={editingCountry.name}
                            onChange={(e) => setEditingCountry({ ...editingCountry, name: e.target.value })}
                            onKeyDown={handleEditKeyDown}
                            onBlur={handleSaveEdit}
                            className="inline-input"
                          />
                        ) : (
                          country.name
                        )}
                      </td>
                      <td
                        className={!isEditing ? 'editable-cell' : ''}
                        onDoubleClick={() => !isEditing && handleStartEdit(country)}
                      >
                        {isEditing ? (
                          <input
                            type="text"
                            value={editingCountry.code}
                            onChange={(e) => setEditingCountry({ ...editingCountry, code: e.target.value.toUpperCase() })}
                            onKeyDown={handleEditKeyDown}
                            onBlur={handleSaveEdit}
                            maxLength={3}
                            className="inline-input"
                          />
                        ) : (
                          country.code
                        )}
                      </td>
                      <td>{country.university_count || 0}</td>
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
                  )
                })}
              </tbody>
            </table>
            {totalPages > 1 && (
              <div className="admin-pagination">
                <button
                  className="btn-secondary btn-small"
                  onClick={() => setPage(page - 1)}
                  disabled={page === 1}
                >
                  Previous
                </button>
                <span className="page-info">
                  Page {page} of {totalPages}
                </span>
                <button
                  className="btn-secondary btn-small"
                  onClick={() => setPage(page + 1)}
                  disabled={page >= totalPages}
                >
                  Next
                </button>
              </div>
            )}
          </>
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
  const updateUniversity = useUpdateUniversity()
  const toast = useToast()
  const { searchQuery, sortColumn, sortDirection, page } = state

  const [isAdding, setIsAdding] = useState(false)
  const [newUniversity, setNewUniversity] = useState('')
  const [newCountryId, setNewCountryId] = useState<string>('')
  const [newRank, setNewRank] = useState('')
  const [pinnedUniversityIds, setPinnedUniversityIds] = useState<string[]>([])
  const universityInputRef = useRef<HTMLInputElement>(null)
  const editUniversityInputRef = useRef<HTMLInputElement>(null)
  const [editingUniversity, setEditingUniversity] = useState<EditingUniversity | null>(null)

  useEffect(() => {
    if (isAdding && universityInputRef.current) {
      universityInputRef.current.focus()
    }
  }, [isAdding])

  useEffect(() => {
    if (editingUniversity && editUniversityInputRef.current) {
      editUniversityInputRef.current.focus()
    }
  }, [editingUniversity])

  const setSearchQuery = (query: string) => {
    setState(prev => ({ ...prev, searchQuery: query, page: 1 }))
  }

  const setPage = (newPage: number) => {
    setState(prev => ({ ...prev, page: newPage }))
  }

  const handleSort = (column: UniversitySortColumn) => {
    setState(prev => {
      if (prev.sortColumn === column) {
        return { ...prev, sortDirection: prev.sortDirection === 'asc' ? 'desc' : 'asc', page: 1 }
      } else {
        return { ...prev, sortColumn: column, sortDirection: 'asc', page: 1 }
      }
    })
  }

  const handleAddClick = () => {
    setIsAdding(true)
    setNewUniversity('')
    setNewCountryId('')
    setNewRank('')
  }

  const handleCancelAdd = () => {
    setIsAdding(false)
    setNewUniversity('')
    setNewCountryId('')
    setNewRank('')
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
          us_news_2025_rank: newRank ? parseInt(newRank, 10) : null,
        },
        {
          onSuccess: (university) => {
            setIsAdding(false)
            setNewUniversity('')
            setNewCountryId('')
            setNewRank('')
            setPinnedUniversityIds((prev) => [...prev, university.id])
            toast.showSuccess('University added')
          },
          onError: (error: { code?: string; message?: string }) => {
            const message = error?.message?.toLowerCase() || ''
            if (error?.code === '23505' || message.includes('duplicate') || message.includes('unique')) {
              toast.showError('University already exists in this country')
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
      let aVal: string | number
      let bVal: string | number

      switch (sortColumn) {
        case 'university':
          aVal = a.university
          bVal = b.university
          break
        case 'country':
          aVal = a.country?.name || ''
          bVal = b.country?.name || ''
          break
        case 'us_news_2025_rank':
          aVal = a.us_news_2025_rank ?? Infinity
          bVal = b.us_news_2025_rank ?? Infinity
          break
        case 'school_count':
          aVal = a.school_count ?? 0
          bVal = b.school_count ?? 0
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

  const startIndex = (page - 1) * UNIVERSITIES_PER_PAGE
  const totalPages = Math.ceil(sortedUniversities.length / UNIVERSITIES_PER_PAGE)
  const paginatedUniversities = sortedUniversities.slice(startIndex, startIndex + UNIVERSITIES_PER_PAGE)

  useEffect(() => {
    if (totalPages > 0 && page > totalPages) {
      setPage(totalPages)
    }
  }, [page, totalPages])

  const handleStartEdit = (uni: typeof universities[number]) => {
    setEditingUniversity({
      id: uni.id,
      university: uni.university,
      country_id: uni.country_id || null,
      us_news_2025_rank: uni.us_news_2025_rank !== null && uni.us_news_2025_rank !== undefined ? String(uni.us_news_2025_rank) : '',
      originalUniversity: uni.university,
      originalCountryId: uni.country_id || null,
      originalRank: uni.us_news_2025_rank !== null && uni.us_news_2025_rank !== undefined ? String(uni.us_news_2025_rank) : '',
    })
  }

  const handleCancelEdit = () => {
    setEditingUniversity(null)
  }

  const handleSaveEdit = () => {
    if (!editingUniversity) return

    const trimmedName = editingUniversity.university.trim()
    if (!trimmedName) {
      toast.showError('University name cannot be empty.')
      return
    }

    const rankValue = editingUniversity.us_news_2025_rank.trim() === ''
      ? null
      : Number(editingUniversity.us_news_2025_rank)

    if (rankValue !== null && Number.isNaN(rankValue)) {
      toast.showError('Rank must be a valid number.')
      return
    }

    const hasChanges =
      trimmedName !== editingUniversity.originalUniversity ||
      (editingUniversity.country_id || null) !== editingUniversity.originalCountryId ||
      (editingUniversity.us_news_2025_rank.trim() || '') !== (editingUniversity.originalRank || '')

    if (!hasChanges) {
      setEditingUniversity(null)
      return
    }

    updateUniversity.mutate(
      {
        id: editingUniversity.id,
        university: trimmedName,
        country_id: editingUniversity.country_id || null,
        us_news_2025_rank: rankValue,
      },
      {
        onSuccess: () => {
          toast.showSuccess('University updated.')
          setEditingUniversity(null)
        },
        onError: () => {
          toast.showError('Failed to update university.')
        },
      }
    )
  }

  const handleEditKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      handleSaveEdit()
    }
    if (e.key === 'Escape') {
      e.preventDefault()
      handleCancelEdit()
    }
  }

  return (
    <div className="university-admin">
      <div className="admin-section university-tab-content">
        <div className="admin-toolbar">
          <p className="admin-description">
            {sortedUniversities.length} of {universities.length} universities
          </p>
          <SearchInput
            value={searchQuery}
            onChange={setSearchQuery}
            placeholder="Search universities..."
            className="admin-search-input"
          />
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
                  <th className="sortable" onClick={() => handleSort('us_news_2025_rank')}>
                    US News 2025 {sortColumn === 'us_news_2025_rank' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="sortable" onClick={() => handleSort('school_count')}>
                    Schools {sortColumn === 'school_count' && (sortDirection === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="table-header-action-cell">
                    {!isAdding && (
                      <button
                        className="admin-delete-btn table-header-action"
                        onClick={handleAddClick}
                        title="Add university"
                        type="button"
                      >
                        <Plus size={16} />
                      </button>
                    )}
                  </th>
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
                    <td>-</td>
                    <td>
                      <button className="admin-delete-btn" onClick={handleCancelAdd} title="Cancel">
                        <X size={16} />
                      </button>
                    </td>
                  </tr>
                )}
                {paginatedUniversities.map((uni, index) => {
                  const isEditing = editingUniversity?.id === uni.id
                  const editingValue = isEditing ? editingUniversity : null
                  return (
                    <tr key={uni.id} className={isEditing ? 'editing-row' : ''}>
                      <td>{startIndex + index + 1}</td>
                      <td
                        className={!isEditing ? 'editable-cell' : ''}
                        onDoubleClick={() => !isEditing && handleStartEdit(uni)}
                      >
                        {isEditing && editingValue ? (
                          <input
                            ref={editUniversityInputRef}
                            type="text"
                            value={editingValue.university}
                            onChange={(e) =>
                              setEditingUniversity({ ...editingValue, university: e.target.value })
                            }
                            onKeyDown={handleEditKeyDown}
                            className="inline-input"
                          />
                        ) : uni.url ? (
                          <a href={uni.url} target="_blank" rel="noopener noreferrer">
                            {uni.university}
                          </a>
                        ) : (
                          <span className="university-name-link">{uni.university}</span>
                        )}
                      </td>
                      <td
                        className={!isEditing ? 'editable-cell' : ''}
                        onDoubleClick={() => !isEditing && handleStartEdit(uni)}
                      >
                        {isEditing && editingValue ? (
                          <select
                            value={editingValue.country_id || ''}
                            onChange={(e) =>
                              setEditingUniversity({
                                ...editingValue,
                                country_id: e.target.value || null,
                              })
                            }
                            onKeyDown={handleEditKeyDown}
                            className="inline-input"
                          >
                            <option value="">Select country</option>
                            {countries.map((c) => (
                              <option key={c.id} value={c.id}>
                                {c.name}
                              </option>
                            ))}
                          </select>
                        ) : (
                          uni.country?.name || '-'
                        )}
                      </td>
                      <td
                        className={!isEditing ? 'editable-cell' : ''}
                        onDoubleClick={() => !isEditing && handleStartEdit(uni)}
                      >
                        {isEditing && editingValue ? (
                          <input
                            type="number"
                            value={editingValue.us_news_2025_rank}
                            onChange={(e) =>
                              setEditingUniversity({ ...editingValue, us_news_2025_rank: e.target.value })
                            }
                            onKeyDown={handleEditKeyDown}
                            className="inline-input"
                          />
                        ) : (
                          uni.us_news_2025_rank || '-'
                        )}
                      </td>
                      <td>{uni.school_count || 0}</td>
                      <td>
                        {isEditing ? (
                          <button className="admin-delete-btn" onClick={handleCancelEdit} title="Cancel">
                            <X size={16} />
                          </button>
                        ) : (
                          <button
                            className="admin-delete-btn"
                            onClick={() => handleDelete(uni.id, uni.university)}
                            title="Delete"
                          >
                            <X size={16} />
                          </button>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            {totalPages > 1 && (
              <div className="admin-pagination">
                <button
                  className="btn-secondary btn-small"
                  onClick={() => setPage(page - 1)}
                  disabled={page === 1}
                >
                  Previous
                </button>
                <span className="page-info">
                  Page {page} of {totalPages}
                </span>
                <button
                  className="btn-secondary btn-small"
                  onClick={() => setPage(page + 1)}
                  disabled={page >= totalPages}
                >
                  Next
                </button>
              </div>
            )}
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

interface SchoolTabProps {
  isActive: boolean
  state: SchoolTabState
  setState: React.Dispatch<React.SetStateAction<SchoolTabState>>
}

const SCHOOL_TYPE_OPTIONS: { value: SchoolType; label: string }[] = [
  { value: 'degree_granting', label: 'Degree Granting' },
  { value: 'continuing_education', label: 'Continuing Education' },
  { value: 'non_degree', label: 'Non-Degree' },
  { value: 'administrative', label: 'Administrative' },
]

function SchoolTab({ isActive, state, setState }: SchoolTabProps) {
  const { data: universities = [] } = useUniversities()
  const { selectedUniversityId, searchQuery, sortColumn, sortDirection, page } = state
  const { data: schools = [], isLoading, error } = useSchoolsByUniversity(selectedUniversityId)
  const createSchool = useCreateSchool(selectedUniversityId)
  const deleteSchool = useDeleteSchool(selectedUniversityId)
  const updateSchool = useUpdateSchool(selectedUniversityId)
  const toast = useToast()

  const [universitySearch, setUniversitySearch] = useState('')
  const [isAdding, setIsAdding] = useState(false)
  const [newSchool, setNewSchool] = useState('')
  const [newType, setNewType] = useState<SchoolType>('degree_granting')
  const [pinnedSchoolIds, setPinnedSchoolIds] = useState<string[]>([])
  const schoolInputRef = useRef<HTMLInputElement>(null)
  const editSchoolInputRef = useRef<HTMLInputElement>(null)
  const [editingSchool, setEditingSchool] = useState<EditingSchool | null>(null)

  // Filter universities for search dropdown
  const filteredUniversities = useMemo(() => {
    if (!universitySearch.trim()) return universities.slice(0, 20)
    const search = universitySearch.toLowerCase()
    return universities.filter(u => u.university.toLowerCase().includes(search)).slice(0, 20)
  }, [universities, universitySearch])

  const selectedUniversity = useMemo(() => {
    return universities.find(u => u.id === selectedUniversityId) || null
  }, [universities, selectedUniversityId])

  useEffect(() => {
    if (isAdding && schoolInputRef.current) {
      schoolInputRef.current.focus()
    }
  }, [isAdding])

  useEffect(() => {
    if (editingSchool && editSchoolInputRef.current) {
      editSchoolInputRef.current.focus()
    }
  }, [editingSchool])

  const setSelectedUniversityId = (id: string | null) => {
    setState(prev => ({ ...prev, selectedUniversityId: id, searchQuery: '', page: 1 }))
    setPinnedSchoolIds([])
    setIsAdding(false)
    setEditingSchool(null)
  }

  const setSearchQuery = (query: string) => {
    setState(prev => ({ ...prev, searchQuery: query, page: 1 }))
  }

  const setPage = (newPage: number) => {
    setState(prev => ({ ...prev, page: newPage }))
  }

  const handleSort = (column: SchoolSortColumn) => {
    setState(prev => {
      if (prev.sortColumn === column) {
        return { ...prev, sortDirection: prev.sortDirection === 'asc' ? 'desc' : 'asc', page: 1 }
      } else {
        return { ...prev, sortColumn: column, sortDirection: 'asc', page: 1 }
      }
    })
  }

  const handleAddClick = () => {
    setIsAdding(true)
    setNewSchool('')
    setNewType('degree_granting')
  }

  const handleCancelAdd = () => {
    setIsAdding(false)
    setNewSchool('')
    setNewType('degree_granting')
  }

  const handleDelete = (schoolId: string, name: string) => {
    if (!window.confirm(`Delete "${name}"? This cannot be undone.`)) return
    deleteSchool.mutate(schoolId, {
      onSuccess: () => {
        toast.showSuccess('School deleted')
        setPinnedSchoolIds((prev) => prev.filter((id) => id !== schoolId))
      },
      onError: () => {
        toast.showError('Failed to delete school')
      },
    })
  }

  const handleSaveNew = () => {
    if (newSchool.trim() && selectedUniversityId) {
      createSchool.mutate(
        {
          school: newSchool.trim(),
          university_id: selectedUniversityId,
          type: newType,
        },
        {
          onSuccess: (school) => {
            setIsAdding(false)
            setNewSchool('')
            setNewType('degree_granting')
            setPinnedSchoolIds((prev) => [...prev, school.id])
            toast.showSuccess('School added')
          },
          onError: (error: { code?: string; message?: string }) => {
            const message = error?.message?.toLowerCase() || ''
            if (error?.code === '23505' || message.includes('duplicate') || message.includes('unique')) {
              toast.showError('School already exists for this university')
              return
            }
            toast.showError('Failed to add school')
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

  const sortedSchools = useMemo(() => {
    const filtered = schools.filter((s) =>
      s.school.toLowerCase().includes(searchQuery.toLowerCase())
    )

    const pinnedSet = new Set(pinnedSchoolIds)
    const pinned = pinnedSchoolIds
      .map((id) => filtered.find((school) => school.id === id))
      .filter((school): school is typeof filtered[number] => Boolean(school))

    const temps = filtered.filter((school) => school.id.startsWith('temp-') && !pinnedSet.has(school.id))

    const rest = filtered.filter((school) => !pinnedSet.has(school.id) && !school.id.startsWith('temp-'))

    const sortedRest = [...rest].sort((a, b) => {
      let aVal: string | number
      let bVal: string | number

      switch (sortColumn) {
        case 'school':
          aVal = a.school
          bVal = b.school
          break
        case 'type':
          aVal = a.type
          bVal = b.type
          break
        case 'department_count':
          aVal = a.department_count ?? 0
          bVal = b.department_count ?? 0
          break
        default:
          return 0
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1
      return 0
    })

    return [...pinned, ...temps, ...sortedRest]
  }, [schools, searchQuery, sortColumn, sortDirection, pinnedSchoolIds])

  const startIndex = (page - 1) * SCHOOLS_PER_PAGE
  const totalPages = Math.ceil(sortedSchools.length / SCHOOLS_PER_PAGE)
  const paginatedSchools = sortedSchools.slice(startIndex, startIndex + SCHOOLS_PER_PAGE)

  useEffect(() => {
    if (totalPages > 0 && page > totalPages) {
      setPage(totalPages)
    }
  }, [page, totalPages])

  const handleStartEdit = (s: typeof schools[number]) => {
    setEditingSchool({
      id: s.id,
      school: s.school,
      type: s.type,
      originalSchool: s.school,
      originalType: s.type,
    })
  }

  const handleCancelEdit = () => {
    setEditingSchool(null)
  }

  const handleSaveEdit = () => {
    if (!editingSchool) return

    const trimmedName = editingSchool.school.trim()
    if (!trimmedName) {
      toast.showError('School name cannot be empty.')
      return
    }

    const hasChanges =
      trimmedName !== editingSchool.originalSchool ||
      editingSchool.type !== editingSchool.originalType

    if (!hasChanges) {
      setEditingSchool(null)
      return
    }

    updateSchool.mutate(
      {
        id: editingSchool.id,
        school: trimmedName,
        type: editingSchool.type,
      },
      {
        onSuccess: () => {
          toast.showSuccess('School updated.')
          setEditingSchool(null)
        },
        onError: () => {
          toast.showError('Failed to update school.')
        },
      }
    )
  }

  const handleEditKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      handleSaveEdit()
    }
    if (e.key === 'Escape') {
      e.preventDefault()
      handleCancelEdit()
    }
  }

  const formatSchoolType = (type: SchoolType) => {
    return SCHOOL_TYPE_OPTIONS.find(o => o.value === type)?.label || type
  }

  return (
    <div className="university-admin">
      <div className="admin-section university-tab-content">
        {/* University selector and school search */}
        <div className="admin-toolbar">
          <p className="admin-description">
            {selectedUniversityId
              ? `${sortedSchools.length} school${sortedSchools.length !== 1 ? 's' : ''}`
              : '\u00A0'}
          </p>
          <div className="admin-search-input search-box">
            <input
              type="text"
              value={selectedUniversity ? selectedUniversity.university : universitySearch}
              onChange={(e) => {
                setUniversitySearch(e.target.value)
                if (selectedUniversityId) {
                  setSelectedUniversityId(null)
                }
              }}
              placeholder="Search university..."
            />
            {selectedUniversityId && (
              <button
                className="admin-delete-btn"
                onClick={() => {
                  setSelectedUniversityId(null)
                  setUniversitySearch('')
                }}
                title="Clear selection"
                type="button"
              >
                <X size={14} />
              </button>
            )}
          </div>
          {selectedUniversityId && (
            <SearchInput
              value={searchQuery}
              onChange={setSearchQuery}
              placeholder="Search schools..."
              className="admin-search-input"
            />
          )}
        </div>

        {/* University search results */}
        {!selectedUniversityId && universitySearch && filteredUniversities.length > 0 && (
          <div className="university-table-wrapper" style={{ maxHeight: '300px', overflow: 'auto' }}>
            <table className="university-table">
              <thead>
                <tr>
                  <th>University</th>
                  <th>Country</th>
                </tr>
              </thead>
              <tbody>
                {filteredUniversities.map((u) => (
                  <tr
                    key={u.id}
                    onClick={() => {
                      setSelectedUniversityId(u.id)
                      setUniversitySearch('')
                    }}
                    style={{ cursor: 'pointer' }}
                  >
                    <td>{u.university}</td>
                    <td>{u.country?.name || '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Schools list - only show when university is selected */}
        {selectedUniversityId && (
          <>

            {isLoading && <div className="admin-placeholder">Loading schools...</div>}

            {error && (
              <div className="admin-placeholder" style={{ color: 'var(--color-error)' }}>
                Failed to load schools.
              </div>
            )}

            {!isLoading && !error && (sortedSchools.length > 0 || isAdding) && (
              <div className="university-table-wrapper">
                <table className="university-table">
                  <thead>
                    <tr>
                      <th>#</th>
                      <th className="sortable" onClick={() => handleSort('school')}>
                        School {sortColumn === 'school' && (sortDirection === 'asc' ? '▲' : '▼')}
                      </th>
                      <th className="sortable" onClick={() => handleSort('type')}>
                        Type {sortColumn === 'type' && (sortDirection === 'asc' ? '▲' : '▼')}
                      </th>
                      <th className="sortable" onClick={() => handleSort('department_count')}>
                        Depts {sortColumn === 'department_count' && (sortDirection === 'asc' ? '▲' : '▼')}
                      </th>
                      <th className="table-header-action-cell">
                        {!isAdding && (
                          <button
                            className="admin-delete-btn table-header-action"
                            onClick={handleAddClick}
                            title="Add school"
                            type="button"
                          >
                            <Plus size={16} />
                          </button>
                        )}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {isAdding && (
                      <tr className="adding-row">
                        <td>-</td>
                        <td>
                          <input
                            ref={schoolInputRef}
                            type="text"
                            value={newSchool}
                            onChange={(e) => setNewSchool(e.target.value)}
                            onKeyDown={handleKeyDown}
                            placeholder="School name"
                            className="inline-input"
                          />
                        </td>
                        <td>
                          <select
                            value={newType}
                            onChange={(e) => setNewType(e.target.value as SchoolType)}
                            onKeyDown={handleKeyDown}
                            className="inline-input"
                          >
                            {SCHOOL_TYPE_OPTIONS.map((opt) => (
                              <option key={opt.value} value={opt.value}>
                                {opt.label}
                              </option>
                            ))}
                          </select>
                        </td>
                        <td>-</td>
                        <td>
                          <button className="admin-delete-btn" onClick={handleCancelAdd} title="Cancel">
                            <X size={16} />
                          </button>
                        </td>
                      </tr>
                    )}
                    {paginatedSchools.map((s, index) => {
                      const isEditing = editingSchool?.id === s.id
                      const editingValue = isEditing ? editingSchool : null
                      return (
                        <tr key={s.id} className={isEditing ? 'editing-row' : ''}>
                          <td>{startIndex + index + 1}</td>
                          <td
                            className={!isEditing ? 'editable-cell' : ''}
                            onDoubleClick={() => !isEditing && handleStartEdit(s)}
                          >
                            {isEditing && editingValue ? (
                              <input
                                ref={editSchoolInputRef}
                                type="text"
                                value={editingValue.school}
                                onChange={(e) =>
                                  setEditingSchool({ ...editingValue, school: e.target.value })
                                }
                                onKeyDown={handleEditKeyDown}
                                className="inline-input"
                              />
                            ) : s.url ? (
                              <a href={s.url} target="_blank" rel="noopener noreferrer">
                                {s.school}
                              </a>
                            ) : (
                              <span className="university-name-link">{s.school}</span>
                            )}
                          </td>
                          <td
                            className={!isEditing ? 'editable-cell' : ''}
                            onDoubleClick={() => !isEditing && handleStartEdit(s)}
                          >
                            {isEditing && editingValue ? (
                              <select
                                value={editingValue.type}
                                onChange={(e) =>
                                  setEditingSchool({ ...editingValue, type: e.target.value as SchoolType })
                                }
                                onKeyDown={handleEditKeyDown}
                                className="inline-input"
                              >
                                {SCHOOL_TYPE_OPTIONS.map((opt) => (
                                  <option key={opt.value} value={opt.value}>
                                    {opt.label}
                                  </option>
                                ))}
                              </select>
                            ) : (
                              formatSchoolType(s.type)
                            )}
                          </td>
                          <td>{s.department_count || 0}</td>
                          <td>
                            {isEditing ? (
                              <button className="admin-delete-btn" onClick={handleCancelEdit} title="Cancel">
                                <X size={16} />
                              </button>
                            ) : (
                              <button
                                className="admin-delete-btn"
                                onClick={() => handleDelete(s.id, s.school)}
                                title="Delete"
                              >
                                <X size={16} />
                              </button>
                            )}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
                {totalPages > 1 && (
                  <div className="admin-pagination">
                    <button
                      className="btn-secondary btn-small"
                      onClick={() => setPage(page - 1)}
                      disabled={page === 1}
                    >
                      Previous
                    </button>
                    <span className="page-info">
                      Page {page} of {totalPages}
                    </span>
                    <button
                      className="btn-secondary btn-small"
                      onClick={() => setPage(page + 1)}
                      disabled={page >= totalPages}
                    >
                      Next
                    </button>
                  </div>
                )}
              </div>
            )}

            {!isLoading && !error && sortedSchools.length === 0 && !isAdding && (
              <div className="admin-placeholder">
                {searchQuery ? 'No schools match your search.' : 'No schools found for this university.'}
              </div>
            )}
          </>
        )}

        {!selectedUniversityId && !universitySearch && (
          <div className="admin-placeholder">
            Search for a university to view its schools.
          </div>
        )}
      </div>
    </div>
  )
}

interface DepartmentTabProps {
  isActive: boolean
  state: DepartmentTabState
  setState: React.Dispatch<React.SetStateAction<DepartmentTabState>>
}

function DepartmentTab({ isActive, state, setState }: DepartmentTabProps) {
  const { data: universities = [] } = useUniversities()
  const { selectedSchoolId, searchQuery, sortColumn, sortDirection, page } = state
  const { data: departments = [], isLoading, error } = useDepartmentsBySchool(selectedSchoolId)
  const createDepartment = useCreateDepartment(selectedSchoolId)
  const deleteDepartment = useDeleteDepartment(selectedSchoolId)
  const updateDepartment = useUpdateDepartment(selectedSchoolId)
  const toast = useToast()

  const [schoolSearch, setSchoolSearch] = useState('')
  const [selectedUniversityId, setSelectedUniversityIdLocal] = useState<string | null>(null)
  const { data: schools = [] } = useSchoolsByUniversity(selectedUniversityId)
  const [isAdding, setIsAdding] = useState(false)
  const [newDepartment, setNewDepartment] = useState('')
  const [pinnedDepartmentIds, setPinnedDepartmentIds] = useState<string[]>([])
  const departmentInputRef = useRef<HTMLInputElement>(null)
  const editDepartmentInputRef = useRef<HTMLInputElement>(null)
  const [editingDepartment, setEditingDepartment] = useState<EditingDepartment | null>(null)

  // Build a flat list of schools with their university names for searching
  const allSchools = useMemo(() => {
    if (!selectedUniversityId) return []
    return schools.map(s => ({
      ...s,
      universityName: universities.find(u => u.id === s.university_id)?.university || '',
    }))
  }, [schools, universities, selectedUniversityId])

  // Filter schools for search dropdown
  const filteredSchools = useMemo(() => {
    if (!schoolSearch.trim()) return allSchools.slice(0, 20)
    const search = schoolSearch.toLowerCase()
    return allSchools.filter(s => s.school.toLowerCase().includes(search)).slice(0, 20)
  }, [allSchools, schoolSearch])

  // Filter universities for university selection dropdown
  const filteredUniversities = useMemo(() => {
    if (!schoolSearch.trim() && !selectedUniversityId) return universities.slice(0, 20)
    const search = schoolSearch.toLowerCase()
    return universities.filter(u => u.university.toLowerCase().includes(search)).slice(0, 20)
  }, [universities, schoolSearch, selectedUniversityId])

  const selectedSchool = useMemo(() => {
    return allSchools.find(s => s.id === selectedSchoolId) || null
  }, [allSchools, selectedSchoolId])

  const selectedUniversity = useMemo(() => {
    return universities.find(u => u.id === selectedUniversityId) || null
  }, [universities, selectedUniversityId])

  useEffect(() => {
    if (isAdding && departmentInputRef.current) {
      departmentInputRef.current.focus()
    }
  }, [isAdding])

  useEffect(() => {
    if (editingDepartment && editDepartmentInputRef.current) {
      editDepartmentInputRef.current.focus()
    }
  }, [editingDepartment])

  const setSelectedSchoolId = (id: string | null) => {
    setState(prev => ({ ...prev, selectedSchoolId: id, searchQuery: '', page: 1 }))
    setPinnedDepartmentIds([])
    setIsAdding(false)
    setEditingDepartment(null)
  }

  const setSearchQuery = (query: string) => {
    setState(prev => ({ ...prev, searchQuery: query, page: 1 }))
  }

  const setPage = (newPage: number) => {
    setState(prev => ({ ...prev, page: newPage }))
  }

  const handleSort = (column: DepartmentSortColumn) => {
    setState(prev => {
      if (prev.sortColumn === column) {
        return { ...prev, sortDirection: prev.sortDirection === 'asc' ? 'desc' : 'asc', page: 1 }
      } else {
        return { ...prev, sortColumn: column, sortDirection: 'asc', page: 1 }
      }
    })
  }

  const handleAddClick = () => {
    setIsAdding(true)
    setNewDepartment('')
  }

  const handleCancelAdd = () => {
    setIsAdding(false)
    setNewDepartment('')
  }

  const handleDelete = (departmentId: string, name: string) => {
    if (!window.confirm(`Delete "${name}"? This cannot be undone.`)) return
    deleteDepartment.mutate(departmentId, {
      onSuccess: () => {
        toast.showSuccess('Department deleted')
        setPinnedDepartmentIds((prev) => prev.filter((id) => id !== departmentId))
      },
      onError: () => {
        toast.showError('Failed to delete department')
      },
    })
  }

  const handleSaveNew = () => {
    if (newDepartment.trim() && selectedSchoolId) {
      createDepartment.mutate(
        {
          department: newDepartment.trim(),
          school_id: selectedSchoolId,
        },
        {
          onSuccess: (department) => {
            setIsAdding(false)
            setNewDepartment('')
            setPinnedDepartmentIds((prev) => [...prev, department.id])
            toast.showSuccess('Department added')
          },
          onError: (error: { code?: string; message?: string }) => {
            const message = error?.message?.toLowerCase() || ''
            if (error?.code === '23505' || message.includes('duplicate') || message.includes('unique')) {
              toast.showError('Department already exists for this school')
              return
            }
            toast.showError('Failed to add department')
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

  const sortedDepartments = useMemo(() => {
    const filtered = departments.filter((d) =>
      d.department.toLowerCase().includes(searchQuery.toLowerCase())
    )

    const pinnedSet = new Set(pinnedDepartmentIds)
    const pinned = pinnedDepartmentIds
      .map((id) => filtered.find((department) => department.id === id))
      .filter((department): department is typeof filtered[number] => Boolean(department))

    const temps = filtered.filter((department) => department.id.startsWith('temp-') && !pinnedSet.has(department.id))

    const rest = filtered.filter((department) => !pinnedSet.has(department.id) && !department.id.startsWith('temp-'))

    const sortedRest = [...rest].sort((a, b) => {
      let aVal: string
      let bVal: string

      switch (sortColumn) {
        case 'department':
          aVal = a.department
          bVal = b.department
          break
        default:
          return 0
      }

      if (aVal < bVal) return sortDirection === 'asc' ? -1 : 1
      if (aVal > bVal) return sortDirection === 'asc' ? 1 : -1
      return 0
    })

    return [...pinned, ...temps, ...sortedRest]
  }, [departments, searchQuery, sortColumn, sortDirection, pinnedDepartmentIds])

  const startIndex = (page - 1) * DEPARTMENTS_PER_PAGE
  const totalPages = Math.ceil(sortedDepartments.length / DEPARTMENTS_PER_PAGE)
  const paginatedDepartments = sortedDepartments.slice(startIndex, startIndex + DEPARTMENTS_PER_PAGE)

  useEffect(() => {
    if (totalPages > 0 && page > totalPages) {
      setPage(totalPages)
    }
  }, [page, totalPages])

  const handleStartEdit = (d: typeof departments[number]) => {
    setEditingDepartment({
      id: d.id,
      department: d.department,
      originalDepartment: d.department,
    })
  }

  const handleCancelEdit = () => {
    setEditingDepartment(null)
  }

  const handleSaveEdit = () => {
    if (!editingDepartment) return

    const trimmedName = editingDepartment.department.trim()
    if (!trimmedName) {
      toast.showError('Department name cannot be empty.')
      return
    }

    const hasChanges = trimmedName !== editingDepartment.originalDepartment

    if (!hasChanges) {
      setEditingDepartment(null)
      return
    }

    updateDepartment.mutate(
      {
        id: editingDepartment.id,
        department: trimmedName,
      },
      {
        onSuccess: () => {
          toast.showSuccess('Department updated.')
          setEditingDepartment(null)
        },
        onError: () => {
          toast.showError('Failed to update department.')
        },
      }
    )
  }

  const handleEditKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      handleSaveEdit()
    }
    if (e.key === 'Escape') {
      e.preventDefault()
      handleCancelEdit()
    }
  }

  return (
    <div className="university-admin">
      <div className="admin-section university-tab-content">
        {/* School selector and department search */}
        <div className="admin-toolbar">
          <p className="admin-description">
            {selectedSchoolId
              ? `${sortedDepartments.length} department${sortedDepartments.length !== 1 ? 's' : ''}`
              : '\u00A0'}
          </p>
          {/* Step 1: Select university first */}
          {!selectedUniversityId && (
            <div className="admin-search-input search-box">
              <input
                type="text"
                value={schoolSearch}
                onChange={(e) => setSchoolSearch(e.target.value)}
                placeholder="Search university..."
              />
            </div>
          )}
          {/* Step 2: Show selected university and school search */}
          {selectedUniversityId && !selectedSchoolId && (
            <>
              <div className="admin-search-input search-box">
                <input
                  type="text"
                  value={selectedUniversity?.university || ''}
                  readOnly
                  style={{ color: 'var(--color-text)' }}
                />
                <button
                  className="admin-delete-btn"
                  onClick={() => {
                    setSelectedUniversityIdLocal(null)
                    setSchoolSearch('')
                  }}
                  title="Clear selection"
                  type="button"
                >
                  <X size={14} />
                </button>
              </div>
              <div className="admin-search-input search-box">
                <input
                  type="text"
                  value={schoolSearch}
                  onChange={(e) => setSchoolSearch(e.target.value)}
                  placeholder="Search school..."
                />
              </div>
            </>
          )}
          {/* Step 3: Show selected school and department search */}
          {selectedSchoolId && (
            <>
              <div className="admin-search-input search-box">
                <input
                  type="text"
                  value={selectedSchool ? selectedSchool.school : ''}
                  readOnly
                  style={{ color: 'var(--color-text)' }}
                />
                <button
                  className="admin-delete-btn"
                  onClick={() => {
                    setSelectedSchoolId(null)
                    setSchoolSearch('')
                  }}
                  title="Clear selection"
                  type="button"
                >
                  <X size={14} />
                </button>
              </div>
              <SearchInput
                value={searchQuery}
                onChange={setSearchQuery}
                placeholder="Search departments..."
                className="admin-search-input"
              />
            </>
          )}
        </div>

        {/* University search results - Step 1 */}
        {!selectedUniversityId && schoolSearch && filteredUniversities.length > 0 && (
          <div className="university-table-wrapper">
            <table className="university-table">
              <thead>
                <tr>
                  <th>University</th>
                  <th>Country</th>
                </tr>
              </thead>
              <tbody>
                {filteredUniversities.map((u) => (
                  <tr
                    key={u.id}
                    onClick={() => {
                      setSelectedUniversityIdLocal(u.id)
                      setSchoolSearch('')
                    }}
                    style={{ cursor: 'pointer' }}
                  >
                    <td>{u.university}</td>
                    <td>{u.country?.name || '-'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* School search results - Step 2 */}
        {selectedUniversityId && !selectedSchoolId && (schoolSearch ? filteredSchools.length > 0 : allSchools.length > 0) && (
          <div className="university-table-wrapper">
            <table className="university-table">
              <thead>
                <tr>
                  <th>School</th>
                  <th>Type</th>
                </tr>
              </thead>
              <tbody>
                {(schoolSearch ? filteredSchools : allSchools).map((s) => (
                  <tr
                    key={s.id}
                    onClick={() => {
                      setSelectedSchoolId(s.id)
                      setSchoolSearch('')
                    }}
                    style={{ cursor: 'pointer' }}
                  >
                    <td>{s.school}</td>
                    <td>{s.type}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* No schools message */}
        {selectedUniversityId && !selectedSchoolId && allSchools.length === 0 && (
          <div className="admin-placeholder">
            No schools found for this university.
          </div>
        )}

        {/* Departments list - only show when school is selected */}
        {selectedSchoolId && (
          <>
            {isLoading && <div className="admin-placeholder">Loading departments...</div>}

            {error && (
              <div className="admin-placeholder" style={{ color: 'var(--color-error)' }}>
                Failed to load departments.
              </div>
            )}

            {!isLoading && !error && (sortedDepartments.length > 0 || isAdding) && (
              <div className="university-table-wrapper">
                <table className="university-table">
                  <thead>
                    <tr>
                      <th>#</th>
                      <th className="sortable" onClick={() => handleSort('department')}>
                        Department {sortColumn === 'department' && (sortDirection === 'asc' ? '▲' : '▼')}
                      </th>
                      <th className="table-header-action-cell">
                        {!isAdding && (
                          <button
                            className="admin-delete-btn table-header-action"
                            onClick={handleAddClick}
                            title="Add department"
                            type="button"
                          >
                            <Plus size={16} />
                          </button>
                        )}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {isAdding && (
                      <tr className="adding-row">
                        <td>-</td>
                        <td>
                          <input
                            ref={departmentInputRef}
                            type="text"
                            value={newDepartment}
                            onChange={(e) => setNewDepartment(e.target.value)}
                            onKeyDown={handleKeyDown}
                            placeholder="Department name"
                            className="inline-input"
                          />
                        </td>
                        <td>
                          <button className="admin-delete-btn" onClick={handleCancelAdd} title="Cancel">
                            <X size={16} />
                          </button>
                        </td>
                      </tr>
                    )}
                    {paginatedDepartments.map((d, index) => {
                      const isEditing = editingDepartment?.id === d.id
                      const editingValue = isEditing ? editingDepartment : null
                      return (
                        <tr key={d.id} className={isEditing ? 'editing-row' : ''}>
                          <td>{startIndex + index + 1}</td>
                          <td
                            className={!isEditing ? 'editable-cell' : ''}
                            onDoubleClick={() => !isEditing && handleStartEdit(d)}
                          >
                            {isEditing && editingValue ? (
                              <input
                                ref={editDepartmentInputRef}
                                type="text"
                                value={editingValue.department}
                                onChange={(e) =>
                                  setEditingDepartment({ ...editingValue, department: e.target.value })
                                }
                                onKeyDown={handleEditKeyDown}
                                className="inline-input"
                              />
                            ) : d.url ? (
                              <a href={d.url} target="_blank" rel="noopener noreferrer">
                                {d.department}
                              </a>
                            ) : (
                              <span className="university-name-link">{d.department}</span>
                            )}
                          </td>
                          <td>
                            {isEditing ? (
                              <button className="admin-delete-btn" onClick={handleCancelEdit} title="Cancel">
                                <X size={16} />
                              </button>
                            ) : (
                              <button
                                className="admin-delete-btn"
                                onClick={() => handleDelete(d.id, d.department)}
                                title="Delete"
                              >
                                <X size={16} />
                              </button>
                            )}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
                {totalPages > 1 && (
                  <div className="admin-pagination">
                    <button
                      className="btn-secondary btn-small"
                      onClick={() => setPage(page - 1)}
                      disabled={page === 1}
                    >
                      Previous
                    </button>
                    <span className="page-info">
                      Page {page} of {totalPages}
                    </span>
                    <button
                      className="btn-secondary btn-small"
                      onClick={() => setPage(page + 1)}
                      disabled={page >= totalPages}
                    >
                      Next
                    </button>
                  </div>
                )}
              </div>
            )}

            {!isLoading && !error && sortedDepartments.length === 0 && !isAdding && (
              <div className="admin-placeholder">
                {searchQuery ? 'No departments match your search.' : 'No departments found for this school.'}
              </div>
            )}
          </>
        )}

        {!selectedUniversityId && !schoolSearch && (
          <div className="admin-placeholder">
            Search for a university, then select a school to view its departments.
          </div>
        )}
      </div>
    </div>
  )
}
