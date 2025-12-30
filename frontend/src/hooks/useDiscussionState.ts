import { useReducer, useCallback, useEffect } from 'react'
import type { Post } from '../types'

// Modal state reducer - handles edit, delete, and info modals
interface ModalState {
  editingPost: Post | null
  editContent: string
  additionalComment: string
  deletingPost: Post | null
  showUserDeletedInfo: boolean
}

type ModalAction =
  | { type: 'START_EDIT'; payload: { post: Post; canEdit: boolean } }
  | { type: 'SET_EDIT_CONTENT'; payload: string }
  | { type: 'SET_ADDITIONAL_COMMENT'; payload: string }
  | { type: 'CLOSE_EDIT_MODAL' }
  | { type: 'SUBMIT_EDIT' }
  | { type: 'START_DELETE'; payload: Post }
  | { type: 'CLOSE_DELETE_MODAL' }
  | { type: 'CONFIRM_DELETE' }
  | { type: 'SHOW_USER_DELETED_INFO' }
  | { type: 'HIDE_USER_DELETED_INFO' }
  | { type: 'CLOSE_ALL' }

const initialModalState: ModalState = {
  editingPost: null,
  editContent: '',
  additionalComment: '',
  deletingPost: null,
  showUserDeletedInfo: false,
}

function modalReducer(state: ModalState, action: ModalAction): ModalState {
  switch (action.type) {
    case 'START_EDIT':
      return {
        ...state,
        editingPost: action.payload.post,
        editContent: action.payload.canEdit ? action.payload.post.content : '',
        additionalComment: '',
      }

    case 'SET_EDIT_CONTENT':
      return { ...state, editContent: action.payload }

    case 'SET_ADDITIONAL_COMMENT':
      return { ...state, additionalComment: action.payload }

    case 'CLOSE_EDIT_MODAL':
    case 'SUBMIT_EDIT':
      return { ...state, editingPost: null, editContent: '', additionalComment: '' }

    case 'START_DELETE':
      return { ...state, deletingPost: action.payload }

    case 'CLOSE_DELETE_MODAL':
    case 'CONFIRM_DELETE':
      return { ...state, deletingPost: null }

    case 'SHOW_USER_DELETED_INFO':
      return { ...state, showUserDeletedInfo: true }

    case 'HIDE_USER_DELETED_INFO':
      return { ...state, showUserDeletedInfo: false }

    case 'CLOSE_ALL':
      return initialModalState

    default:
      return state
  }
}

export function useModalState() {
  const [state, dispatch] = useReducer(modalReducer, initialModalState)

  // Handle Escape key to close modals
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (state.editingPost) dispatch({ type: 'CLOSE_EDIT_MODAL' })
        else if (state.deletingPost) dispatch({ type: 'CLOSE_DELETE_MODAL' })
        else if (state.showUserDeletedInfo) dispatch({ type: 'HIDE_USER_DELETED_INFO' })
      }
    }
    if (state.editingPost || state.deletingPost || state.showUserDeletedInfo) {
      document.addEventListener('keydown', handleEscape)
      return () => document.removeEventListener('keydown', handleEscape)
    }
  }, [state.editingPost, state.deletingPost, state.showUserDeletedInfo])

  const actions = {
    startEdit: useCallback(
      (post: Post, canEdit: boolean) =>
        dispatch({ type: 'START_EDIT', payload: { post, canEdit } }),
      []
    ),
    setEditContent: useCallback(
      (content: string) => dispatch({ type: 'SET_EDIT_CONTENT', payload: content }),
      []
    ),
    setAdditionalComment: useCallback(
      (comment: string) => dispatch({ type: 'SET_ADDITIONAL_COMMENT', payload: comment }),
      []
    ),
    closeEditModal: useCallback(() => dispatch({ type: 'CLOSE_EDIT_MODAL' }), []),
    submitEdit: useCallback(() => dispatch({ type: 'SUBMIT_EDIT' }), []),

    startDelete: useCallback((post: Post) => dispatch({ type: 'START_DELETE', payload: post }), []),
    closeDeleteModal: useCallback(() => dispatch({ type: 'CLOSE_DELETE_MODAL' }), []),
    confirmDelete: useCallback(() => dispatch({ type: 'CONFIRM_DELETE' }), []),

    showUserDeletedInfo: useCallback(() => dispatch({ type: 'SHOW_USER_DELETED_INFO' }), []),
    hideUserDeletedInfo: useCallback(() => dispatch({ type: 'HIDE_USER_DELETED_INFO' }), []),
  }

  return { state, actions }
}

export type { ModalState, ModalAction }
export type ModalActions = ReturnType<typeof useModalState>['actions']
