import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase, supabasePublic } from '../lib/supabase'
import { withTimeout } from '../utils/timeout'
import type {
  PlacementFilters,
  PlacementSearchParams,
  ReverseSearchParams,
  PlacementSearchResult,
  Placement,
} from '../types'

// Country type from pt_country table
export interface Country {
  id: string
  name: string
  code: string
}

// University type from pt_university table
export interface University {
  id: string
  university: string
  url: string | null
  country_id: string | null
  country: Country | null
  us_news_2025_rank: number | null
  updated_at: string
}

// School type enum
export type SchoolType = 'degree_granting' | 'continuing_education' | 'non_degree' | 'administrative'

// School type from pt_school table
export interface School {
  id: string
  school: string
  university_id: string | null
  university: University | null
  url: string | null
  type: SchoolType
  updated_at: string
}

// Query keys
export const placementKeys = {
  all: ['placements'] as const,
  filters: () => [...placementKeys.all, 'filters'] as const,
  universities: () => [...placementKeys.all, 'universities'] as const,
  countries: () => [...placementKeys.all, 'countries'] as const,
  schools: () => [...placementKeys.all, 'schools'] as const,
  search: (params: PlacementSearchParams) => [...placementKeys.all, 'search', params] as const,
  reverseSearch: (params: ReverseSearchParams) => [...placementKeys.all, 'reverse', params] as const,
  programsForUniversity: (university: string) => [...placementKeys.all, 'programs', university] as const,
  universitiesForProgram: (program: string) => [...placementKeys.all, 'universities', program] as const,
}

// Fetch placement filters (degrees, programs, universities, years)
export function usePlacementFilters() {
  return useQuery({
    queryKey: placementKeys.filters(),
    networkMode: 'always',
    queryFn: async (): Promise<PlacementFilters> => {
      const { data, error } = await withTimeout(
        supabasePublic.rpc('get_placement_filters'),
        15000,
        'Request timeout: placement filters took too long'
      )
      if (error) throw error

      return {
        degrees: (data?.degrees || []).filter(Boolean).sort(),
        programs: (data?.programs || []).filter(Boolean).sort(),
        universities: (data?.universities || []).filter(Boolean).sort(),
        years: (data?.years || []).filter(Boolean).sort((a: number, b: number) => b - a),
      }
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}

// Fetch all universities from pt_university table
export function useUniversities() {
  return useQuery({
    queryKey: placementKeys.universities(),
    queryFn: async (): Promise<University[]> => {
      const { data, error } = await supabase
        .from('pt_university')
        .select(`
          *,
          country:pt_country(id, name, code)
        `)
        .order('university', { ascending: true })

      if (error) throw error
      return data || []
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}

// Fetch all countries from pt_country table
export function useCountries() {
  return useQuery({
    queryKey: placementKeys.countries(),
    queryFn: async (): Promise<Country[]> => {
      const { data, error } = await supabase
        .from('pt_country')
        .select('*')
        .order('name', { ascending: true })

      if (error) throw error
      return data || []
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}

// Create a new country
export function useCreateCountry() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (newCountry: { name: string; code: string }): Promise<Country> => {
      const { data, error } = await supabase
        .from('pt_country')
        .insert(newCountry)
        .select()
        .single()

      if (error) throw error
      return data
    },
    onMutate: async (newCountry) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: placementKeys.countries() })

      // Snapshot previous value
      const previousCountries = queryClient.getQueryData<Country[]>(placementKeys.countries())
      const optimisticId = 'temp-' + Date.now()

      // Optimistically add new country
      if (previousCountries) {
        const optimisticCountry: Country = {
          id: optimisticId,
          name: newCountry.name.toLowerCase(),
          code: newCountry.code.toUpperCase(),
        }
        queryClient.setQueryData<Country[]>(
          placementKeys.countries(),
          [optimisticCountry, ...previousCountries]
        )
      }

      return { previousCountries, optimisticId }
    },
    onSuccess: (createdCountry, newCountry, context) => {
      if (!context?.optimisticId) return
      queryClient.setQueryData<Country[]>(placementKeys.countries(), (current) => {
        if (!current) return current
        return current.map((country) =>
          country.id === context.optimisticId ? createdCountry : country
        )
      })
    },
    onError: (err, newCountry, context) => {
      // Rollback on error
      if (context?.previousCountries) {
        queryClient.setQueryData(placementKeys.countries(), context.previousCountries)
      }
    },
  })
}

// Delete a country
export function useDeleteCountry() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (countryId: string): Promise<void> => {
      const { error } = await supabase
        .from('pt_country')
        .delete()
        .eq('id', countryId)

      if (error) throw error
    },
    onSuccess: (_, countryId) => {
      queryClient.setQueryData<Country[]>(placementKeys.countries(), (current) => {
        if (!current) return current
        return current.filter((country) => country.id !== countryId)
      })
    },
  })
}

// Update a country
export function useUpdateCountry() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async ({ id, name, code }: { id: string; name: string; code: string }): Promise<Country> => {
      const { data, error } = await supabase
        .from('pt_country')
        .update({ name, code })
        .eq('id', id)
        .select()
        .single()

      if (error) throw error
      return data
    },
    onMutate: async ({ id, name, code }) => {
      await queryClient.cancelQueries({ queryKey: placementKeys.countries() })
      const previousCountries = queryClient.getQueryData<Country[]>(placementKeys.countries())

      // Optimistically update
      if (previousCountries) {
        queryClient.setQueryData<Country[]>(placementKeys.countries(), (current) => {
          if (!current) return current
          return current.map((country) =>
            country.id === id ? { ...country, name: name.toLowerCase(), code: code.toUpperCase() } : country
          )
        })
      }

      return { previousCountries }
    },
    onError: (err, variables, context) => {
      if (context?.previousCountries) {
        queryClient.setQueryData(placementKeys.countries(), context.previousCountries)
      }
    },
  })
}

// Create a new university
export function useCreateUniversity() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (newUniversity: {
      university: string
      country_id?: string | null
      us_news_2025_rank?: number | null
      url?: string | null
    }): Promise<University> => {
      const { data, error } = await supabase
        .from('pt_university')
        .insert(newUniversity)
        .select(`
          *,
          country:pt_country(id, name, code)
        `)
        .single()

      if (error) throw error
      return data
    },
    onMutate: async (newUniversity) => {
      await queryClient.cancelQueries({ queryKey: placementKeys.universities() })

      const previousUniversities = queryClient.getQueryData<University[]>(placementKeys.universities())
      const optimisticId = 'temp-' + Date.now()

      if (previousUniversities) {
        const optimisticUniversity: University = {
          id: optimisticId,
          university: newUniversity.university.toLowerCase(),
          url: newUniversity.url || null,
          country_id: newUniversity.country_id || null,
          country: null,
          us_news_2025_rank: newUniversity.us_news_2025_rank || null,
          updated_at: new Date().toISOString(),
        }
        queryClient.setQueryData<University[]>(
          placementKeys.universities(),
          [optimisticUniversity, ...previousUniversities]
        )
      }

      return { previousUniversities, optimisticId }
    },
    onSuccess: (createdUniversity, newUniversity, context) => {
      if (!context?.optimisticId) return
      queryClient.setQueryData<University[]>(placementKeys.universities(), (current) => {
        if (!current) return current
        return current.map((university) =>
          university.id === context.optimisticId ? createdUniversity : university
        )
      })
    },
    onError: (err, newUniversity, context) => {
      if (context?.previousUniversities) {
        queryClient.setQueryData(placementKeys.universities(), context.previousUniversities)
      }
    },
  })
}

// Delete a university
export function useDeleteUniversity() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (universityId: string): Promise<void> => {
      const { error } = await supabase
        .from('pt_university')
        .delete()
        .eq('id', universityId)

      if (error) throw error
    },
    onSuccess: (_, universityId) => {
      queryClient.setQueryData<University[]>(placementKeys.universities(), (current) => {
        if (!current) return current
        return current.filter((university) => university.id !== universityId)
      })
    },
  })
}

// Update a university
export function useUpdateUniversity() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (updates: {
      id: string
      university: string
      country_id: string | null
      us_news_2025_rank: number | null
    }): Promise<University> => {
      const { data, error } = await supabase
        .from('pt_university')
        .update({
          university: updates.university,
          country_id: updates.country_id,
          us_news_2025_rank: updates.us_news_2025_rank,
        })
        .eq('id', updates.id)
        .select(`
          *,
          country:pt_country(id, name, code)
        `)
        .single()

      if (error) throw error
      return data
    },
    onMutate: async (updates) => {
      await queryClient.cancelQueries({ queryKey: placementKeys.universities() })
      const previousUniversities = queryClient.getQueryData<University[]>(placementKeys.universities())

      if (previousUniversities) {
        queryClient.setQueryData<University[]>(placementKeys.universities(), (current) => {
          if (!current) return current
          return current.map((uni) => {
            if (uni.id !== updates.id) return uni
            const keepCountry = updates.country_id === uni.country_id
            return {
              ...uni,
              university: updates.university.toLowerCase(),
              country_id: updates.country_id,
              us_news_2025_rank: updates.us_news_2025_rank,
              country: keepCountry ? uni.country : null,
            }
          })
        })
      }

      return { previousUniversities }
    },
    onSuccess: (updatedUniversity) => {
      queryClient.setQueryData<University[]>(placementKeys.universities(), (current) => {
        if (!current) return current
        return current.map((uni) => (uni.id === updatedUniversity.id ? updatedUniversity : uni))
      })
    },
    onError: (err, variables, context) => {
      if (context?.previousUniversities) {
        queryClient.setQueryData(placementKeys.universities(), context.previousUniversities)
      }
    },
  })
}

// Fetch all schools from pt_school table
export function useSchools() {
  return useQuery({
    queryKey: placementKeys.schools(),
    queryFn: async (): Promise<School[]> => {
      const { data, error } = await supabase
        .from('pt_school')
        .select(`
          *,
          university:pt_university(id, university, url, country_id, us_news_2025_rank, updated_at)
        `)
        .order('school', { ascending: true })

      if (error) throw error
      return data || []
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}

// Create a new school
export function useCreateSchool() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (newSchool: {
      school: string
      university_id?: string | null
      url?: string | null
      type?: SchoolType
    }): Promise<School> => {
      const { data, error } = await supabase
        .from('pt_school')
        .insert(newSchool)
        .select(`
          *,
          university:pt_university(id, university, url, country_id, us_news_2025_rank, updated_at)
        `)
        .single()

      if (error) throw error
      return data
    },
    onMutate: async (newSchool) => {
      await queryClient.cancelQueries({ queryKey: placementKeys.schools() })

      const previousSchools = queryClient.getQueryData<School[]>(placementKeys.schools())
      const optimisticId = 'temp-' + Date.now()

      if (previousSchools) {
        const optimisticSchool: School = {
          id: optimisticId,
          school: newSchool.school.toLowerCase(),
          university_id: newSchool.university_id || null,
          university: null,
          url: newSchool.url || null,
          type: newSchool.type || 'degree_granting',
          updated_at: new Date().toISOString(),
        }
        queryClient.setQueryData<School[]>(
          placementKeys.schools(),
          [optimisticSchool, ...previousSchools]
        )
      }

      return { previousSchools, optimisticId }
    },
    onSuccess: (createdSchool, newSchool, context) => {
      if (!context?.optimisticId) return
      queryClient.setQueryData<School[]>(placementKeys.schools(), (current) => {
        if (!current) return current
        return current.map((school) =>
          school.id === context.optimisticId ? createdSchool : school
        )
      })
    },
    onError: (err, newSchool, context) => {
      if (context?.previousSchools) {
        queryClient.setQueryData(placementKeys.schools(), context.previousSchools)
      }
    },
  })
}

// Delete a school
export function useDeleteSchool() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (schoolId: string): Promise<void> => {
      const { error } = await supabase
        .from('pt_school')
        .delete()
        .eq('id', schoolId)

      if (error) throw error
    },
    onSuccess: (_, schoolId) => {
      queryClient.setQueryData<School[]>(placementKeys.schools(), (current) => {
        if (!current) return current
        return current.filter((school) => school.id !== schoolId)
      })
    },
  })
}

// Update a school
export function useUpdateSchool() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (updates: {
      id: string
      school: string
      university_id: string | null
      type: SchoolType
    }): Promise<School> => {
      const { data, error } = await supabase
        .from('pt_school')
        .update({
          school: updates.school,
          university_id: updates.university_id,
          type: updates.type,
        })
        .eq('id', updates.id)
        .select(`
          *,
          university:pt_university(id, university, url, country_id, us_news_2025_rank, updated_at)
        `)
        .single()

      if (error) throw error
      return data
    },
    onMutate: async (updates) => {
      await queryClient.cancelQueries({ queryKey: placementKeys.schools() })
      const previousSchools = queryClient.getQueryData<School[]>(placementKeys.schools())

      if (previousSchools) {
        queryClient.setQueryData<School[]>(placementKeys.schools(), (current) => {
          if (!current) return current
          return current.map((s) => {
            if (s.id !== updates.id) return s
            const keepUniversity = updates.university_id === s.university_id
            return {
              ...s,
              school: updates.school.toLowerCase(),
              university_id: updates.university_id,
              type: updates.type,
              university: keepUniversity ? s.university : null,
            }
          })
        })
      }

      return { previousSchools }
    },
    onSuccess: (updatedSchool) => {
      queryClient.setQueryData<School[]>(placementKeys.schools(), (current) => {
        if (!current) return current
        return current.map((s) => (s.id === updatedSchool.id ? updatedSchool : s))
      })
    },
    onError: (err, variables, context) => {
      if (context?.previousSchools) {
        queryClient.setQueryData(placementKeys.schools(), context.previousSchools)
      }
    },
  })
}

// Search placements
export function usePlacementSearch(params: PlacementSearchParams, enabled: boolean = true) {
  return useQuery({
    queryKey: placementKeys.search(params),
    networkMode: 'always',
    queryFn: async (): Promise<PlacementSearchResult> => {
      const { data, error } = await withTimeout(
        supabasePublic.rpc('search_placements', {
          p_degree: params.degree || null,
          p_program: params.program || null,
          p_university: params.university || null,
          p_from_year: params.fromYear || null,
          p_to_year: params.toYear || null,
          p_limit: params.limit || 100,
          p_offset: params.offset || 0,
        }),
        15000,
        'Request timeout: placement search took too long'
      )

      if (error) throw error

      const placements: Placement[] = (data || []).map((row: Record<string, unknown>) => {
        const rawYear = row.year ?? row.date
        const parsedYear = typeof rawYear === 'number'
          ? rawYear
          : rawYear
            ? parseInt(String(rawYear), 10)
            : null
        const placementUniv = (row.placement_univ ?? row.institution ?? row.placement) as string | null

        return {
          id: row.id as string,
          name: row.name as string | null,
          placementUniv,
          role: row.role as string | null,
          year: Number.isNaN(parsedYear) ? null : parsedYear,
          university: row.university as string | null,
          program: row.program as string | null,
          degree: row.degree as string | null,
          discipline: row.discipline as string | null,
          school: null,
          department: null,
        }
      })

      const totalCount = data?.[0]?.total_count || 0

      return { placements, totalCount }
    },
    enabled,
    staleTime: 30 * 1000, // 30 seconds
  })
}

// Reverse search placements (by hiring institution)
export function useReverseSearch(params: ReverseSearchParams, enabled: boolean = true) {
  return useQuery({
    queryKey: placementKeys.reverseSearch(params),
    networkMode: 'always',
    queryFn: async (): Promise<PlacementSearchResult> => {
      const { data, error } = await withTimeout(
        supabasePublic.rpc('reverse_search_placements', {
          p_placement_univ: params.placementUniv,
          p_degree: params.degree || null,
          p_program: params.program || null,
          p_from_year: params.fromYear || null,
          p_to_year: params.toYear || null,
          p_limit: params.limit || 100,
          p_offset: params.offset || 0,
        }),
        15000,
        'Request timeout: reverse placement search took too long'
      )

      if (error) throw error

      const placements: Placement[] = (data || []).map((row: Record<string, unknown>) => {
        const rawYear = row.year ?? row.date
        const parsedYear = typeof rawYear === 'number'
          ? rawYear
          : rawYear
            ? parseInt(String(rawYear), 10)
            : null
        const placementUniv = (row.placement_univ ?? row.institution ?? row.placement) as string | null

        return {
          id: row.id as string,
          name: row.name as string | null,
          placementUniv,
          role: row.role as string | null,
          year: Number.isNaN(parsedYear) ? null : parsedYear,
          university: row.university as string | null,
          program: row.program as string | null,
          degree: row.degree as string | null,
          discipline: row.discipline as string | null,
          school: null,
          department: null,
        }
      })

      const totalCount = data?.[0]?.total_count || 0

      return { placements, totalCount }
    },
    enabled: enabled && !!params.placementUniv,
    staleTime: 30 * 1000,
  })
}

// Get programs for a specific university
export function useProgramsForUniversity(university: string | null) {
  return useQuery({
    queryKey: placementKeys.programsForUniversity(university || ''),
    networkMode: 'always',
    queryFn: async (): Promise<string[]> => {
      if (!university) return []
      const { data, error } = await withTimeout(
        supabasePublic.rpc('get_programs_for_university', {
          p_university: university,
        }),
        15000,
        'Request timeout: programs lookup took too long'
      )
      if (error) throw error
      return (data || []).filter(Boolean).sort()
    },
    enabled: !!university,
    staleTime: 5 * 60 * 1000,
  })
}

// Get universities for a specific program
export function useUniversitiesForProgram(program: string | null) {
  return useQuery({
    queryKey: placementKeys.universitiesForProgram(program || ''),
    networkMode: 'always',
    queryFn: async (): Promise<string[]> => {
      if (!program) return []
      const { data, error } = await withTimeout(
        supabasePublic.rpc('get_universities_for_program', {
          p_program: program,
        }),
        15000,
        'Request timeout: universities lookup took too long'
      )
      if (error) throw error
      return (data || []).filter(Boolean).sort()
    },
    enabled: !!program,
    staleTime: 5 * 60 * 1000,
  })
}
