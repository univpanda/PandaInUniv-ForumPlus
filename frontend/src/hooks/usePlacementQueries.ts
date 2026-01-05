import { useQuery } from '@tanstack/react-query'
import { supabase } from '../lib/supabase'
import type {
  PlacementFilters,
  PlacementSearchParams,
  ReverseSearchParams,
  PlacementSearchResult,
  Placement,
} from '../types'

// Query keys
export const placementKeys = {
  all: ['placements'] as const,
  filters: () => [...placementKeys.all, 'filters'] as const,
  search: (params: PlacementSearchParams) => [...placementKeys.all, 'search', params] as const,
  reverseSearch: (params: ReverseSearchParams) => [...placementKeys.all, 'reverse', params] as const,
  programsForUniversity: (university: string) => [...placementKeys.all, 'programs', university] as const,
  universitiesForProgram: (program: string) => [...placementKeys.all, 'universities', program] as const,
}

// Fetch placement filters (degrees, programs, universities, years)
export function usePlacementFilters() {
  return useQuery({
    queryKey: placementKeys.filters(),
    queryFn: async (): Promise<PlacementFilters> => {
      const { data, error } = await supabase.rpc('get_placement_filters')
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

// Search placements
export function usePlacementSearch(params: PlacementSearchParams, enabled: boolean = true) {
  return useQuery({
    queryKey: placementKeys.search(params),
    queryFn: async (): Promise<PlacementSearchResult> => {
      const { data, error } = await supabase.rpc('search_placements', {
        p_degree: params.degree || null,
        p_program: params.program || null,
        p_university: params.university || null,
        p_from_year: params.fromYear || null,
        p_to_year: params.toYear || null,
        p_limit: params.limit || 100,
        p_offset: params.offset || 0,
      })

      if (error) throw error

      const placements: Placement[] = (data || []).map((row: Record<string, unknown>) => ({
        id: row.id as string,
        name: row.name as string | null,
        institution: row.institution as string | null,
        role: row.role as string | null,
        year: row.year as number | null,
        university: row.university as string | null,
        program: row.program as string | null,
        degree: row.degree as string | null,
      }))

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
    queryFn: async (): Promise<PlacementSearchResult> => {
      const { data, error } = await supabase.rpc('reverse_search_placements', {
        p_institution: params.institution,
        p_degree: params.degree || null,
        p_program: params.program || null,
        p_from_year: params.fromYear || null,
        p_to_year: params.toYear || null,
        p_limit: params.limit || 100,
        p_offset: params.offset || 0,
      })

      if (error) throw error

      const placements: Placement[] = (data || []).map((row: Record<string, unknown>) => ({
        id: row.id as string,
        name: row.name as string | null,
        institution: row.institution as string | null,
        role: row.role as string | null,
        year: row.year as number | null,
        university: row.university as string | null,
        program: row.program as string | null,
        degree: row.degree as string | null,
      }))

      const totalCount = data?.[0]?.total_count || 0

      return { placements, totalCount }
    },
    enabled: enabled && !!params.institution,
    staleTime: 30 * 1000,
  })
}

// Get programs for a specific university
export function useProgramsForUniversity(university: string | null) {
  return useQuery({
    queryKey: placementKeys.programsForUniversity(university || ''),
    queryFn: async (): Promise<string[]> => {
      if (!university) return []
      const { data, error } = await supabase.rpc('get_programs_for_university', {
        p_university: university,
      })
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
    queryFn: async (): Promise<string[]> => {
      if (!program) return []
      const { data, error } = await supabase.rpc('get_universities_for_program', {
        p_program: program,
      })
      if (error) throw error
      return (data || []).filter(Boolean).sort()
    },
    enabled: !!program,
    staleTime: 5 * 60 * 1000,
  })
}
