import { memo, useEffect, useLayoutEffect, useCallback, useState, useRef } from 'react'
import { useClickOutside } from '../../hooks/useClickOutside'
import { useEditor, EditorContent } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'
import { LatexNode } from './LatexExtension'
import { Send, Bold, Italic, Link as LinkIcon, List, Smile, Sigma } from 'lucide-react'
import TurndownService from 'turndown'
import { ButtonSpinner } from '../ui'
import 'katex/dist/katex.min.css'

// Common emojis for quick access
const EMOJI_LIST = [
  '😀', '😂', '😊', '🥰', '😎', '🤔', '😢', '😡',
  '👍', '👎', '👏', '🙏', '💪', '🎉', '❤️', '🔥',
  '✅', '❌', '⚠️', '💡', '📈', '📉', '💰', '🚀',
]

// Convert HTML to Markdown
const turndownService = new TurndownService({
  headingStyle: 'atx',
  codeBlockStyle: 'fenced',
})

// Add rule to convert LaTeX nodes - use <latex> tags
turndownService.addRule('latexNode', {
  filter: (node) => {
    return node.nodeName === 'SPAN' && node.hasAttribute('data-latex')
  },
  replacement: (_content, node) => {
    // Get raw text content, strip zero-width spaces used as placeholders
    const latex = (node as HTMLElement).textContent?.replace(/\u200B/g, '').trim() || ''
    return latex ? `<latex>${latex}</latex>` : ''
  },
})

interface ReplyInputProps {
  value: string
  onChange: (value: string) => void
  onSubmit: () => void
  placeholder?: string
  submitting?: boolean
  size?: 'normal' | 'small'
  autoFocus?: boolean
}

export const ReplyInput = memo(function ReplyInput({
  value,
  onChange,
  onSubmit,
  placeholder = 'Write a reply...',
  submitting = false,
  size = 'normal',
  autoFocus = false,
}: ReplyInputProps) {
  const iconSize = size === 'small' ? 16 : 18
  // Force re-render when editor state changes
  const [, setForceUpdate] = useState(0)
  const [showEmojiPicker, setShowEmojiPicker] = useState(false)
  const [isExpanded, setIsExpanded] = useState(autoFocus)
  const emojiPickerRef = useRef<HTMLDivElement>(null)
  const containerRef = useRef<HTMLDivElement>(null)
  // Use refs to access current values in handleKeyDown without re-creating editor
  const valueRef = useRef(value)
  const submittingRef = useRef(submitting)
  const onSubmitRef = useRef(onSubmit)
  // Sync refs with props in useLayoutEffect to satisfy React Compiler
  useLayoutEffect(() => {
    valueRef.current = value
    submittingRef.current = submitting
    onSubmitRef.current = onSubmit
  })

  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        heading: false,
        blockquote: false,
        horizontalRule: false,
        link: false,
      }),
      Link.configure({
        openOnClick: false,
        HTMLAttributes: {
          class: 'editor-link',
        },
      }),
      Placeholder.configure({
        placeholder,
      }),
      LatexNode,
    ],
    content: '',
    autofocus: autoFocus,
    editorProps: {
      attributes: {
        class: `reply-editor ${size === 'small' ? 'small' : ''}`,
      },
      handleKeyDown: (_view, event) => {
        // Shift+Enter or Cmd+Enter (Mac) / Ctrl+Enter (Windows) to submit
        if (event.key === 'Enter' && (event.shiftKey || event.metaKey || event.ctrlKey)) {
          event.preventDefault()
          if (!submittingRef.current && valueRef.current.trim()) {
            onSubmitRef.current()
          }
          return true
        }
        return false
      },
    },
    onUpdate: ({ editor }) => {
      const html = editor.getHTML()
      if (html === '<p></p>') {
        onChange('')
      } else {
        const markdown = turndownService.turndown(html)
        onChange(markdown)
      }
      // Force re-render to update button states on content changes
      setForceUpdate(n => n + 1)
    },
    onSelectionUpdate: () => {
      // Force re-render to update button states (bold/italic/link active state)
      setForceUpdate(n => n + 1)
    },
    onTransaction: ({ transaction }) => {
      if (transaction.docChanged || transaction.selectionSet || transaction.storedMarks) {
        setForceUpdate(n => n + 1)
      }
    },
  })

  // Sync external value changes (e.g., clearing after submit)
  useEffect(() => {
    if (editor && value === '' && editor.getHTML() !== '<p></p>') {
      editor.commands.clearContent()
    }
  }, [editor, value])

  const setLink = useCallback(() => {
    if (!editor) return
    const previousUrl = editor.getAttributes('link').href
    const url = window.prompt('URL', previousUrl)

    if (url === null) return
    if (url === '') {
      editor.chain().focus().extendMarkRange('link').unsetLink().run()
      return
    }

    editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
  }, [editor])

  const insertEmoji = useCallback((emoji: string) => {
    if (!editor) return
    editor.chain().focus().insertContent(emoji).run()
    setShowEmojiPicker(false)
  }, [editor])

  const insertLatex = useCallback(() => {
    if (!editor) return
    // Insert a LaTeX node - user types in the inline input
    editor.chain().focus().insertLatex().run()
  }, [editor])

  // Close emoji picker when clicking outside
  useClickOutside(emojiPickerRef, () => setShowEmojiPicker(false), showEmojiPicker)

  // Collapse when clicking outside (only if empty)
  // Uses valueRef to avoid re-adding listeners on every keystroke
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (
        containerRef.current &&
        !containerRef.current.contains(e.target as Node) &&
        !valueRef.current.trim()
      ) {
        setIsExpanded(false)
      }
    }
    if (isExpanded) {
      document.addEventListener('mousedown', handleClickOutside)
    }
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [isExpanded])

  useEffect(() => {
    if (!isExpanded) {
      setShowEmojiPicker(false)
    }
  }, [isExpanded])

  // Expand when editor is focused
  const handleContainerClick = useCallback(() => {
    setIsExpanded(true)
    editor?.commands.focus()
  }, [editor])

  if (!editor) return null

  return (
    <div
      ref={containerRef}
      className={`reply-input-container ${size === 'small' ? 'inline-reply-form' : ''} ${isExpanded ? 'expanded' : 'collapsed'}`}
      onClick={!isExpanded ? handleContainerClick : undefined}
    >
      <div className="reply-input-wrapper">
        <EditorContent editor={editor} />
        <div className={`reply-formatting-bar ${isExpanded ? 'is-visible' : 'is-hidden'}`}>
          <button
            type="button"
            onMouseDown={(e) => {
              e.preventDefault() // Prevent losing focus/selection
            }}
            onClick={() => {
              editor.chain().focus().toggleBold().run()
            }}
            className={`format-btn ${editor.isActive('bold') ? 'active' : ''}`}
            title="Bold (Ctrl+B)"
          >
            <Bold size={14} />
          </button>
          <button
            type="button"
            onMouseDown={(e) => {
              e.preventDefault()
            }}
            onClick={() => {
              editor.chain().focus().toggleItalic().run()
            }}
            className={`format-btn ${editor.isActive('italic') ? 'active' : ''}`}
            title="Italic (Ctrl+I)"
          >
            <Italic size={14} />
          </button>
          <div className="emoji-picker-wrapper" ref={emojiPickerRef}>
            <button
              type="button"
              onMouseDown={(e) => {
                e.preventDefault()
              }}
              onClick={() => {
                setShowEmojiPicker(!showEmojiPicker)
              }}
              className={`format-btn ${showEmojiPicker ? 'active' : ''}`}
              title="Emoji"
            >
              <Smile size={14} />
            </button>
            {showEmojiPicker && (
              <div className="emoji-picker">
                {EMOJI_LIST.map((emoji) => (
                  <button
                    key={emoji}
                    type="button"
                    className="emoji-btn"
                    onClick={() => insertEmoji(emoji)}
                  >
                    {emoji}
                  </button>
                ))}
              </div>
            )}
          </div>
          <button
            type="button"
            onMouseDown={(e) => {
              e.preventDefault()
            }}
            onClick={() => {
              setLink()
            }}
            className={`format-btn ${editor.isActive('link') ? 'active' : ''}`}
            title="Link"
          >
            <LinkIcon size={14} />
          </button>
          <button
            type="button"
            onMouseDown={(e) => {
              e.preventDefault()
            }}
            onClick={() => {
              editor.chain().focus().toggleBulletList().run()
            }}
            className={`format-btn ${editor.isActive('bulletList') ? 'active' : ''}`}
            title="List"
          >
            <List size={14} />
          </button>
          <button
            type="button"
            onMouseDown={(e) => {
              e.preventDefault()
            }}
            onClick={() => {
              insertLatex()
            }}
            className="format-btn"
            title="LaTeX formula"
          >
            <Sigma size={14} />
          </button>
        </div>
      </div>
      {isExpanded && (
        <button
          onClick={onSubmit}
          disabled={submitting || !value.trim()}
          className={`send-reply-btn ${size === 'small' ? 'small' : ''}`}
        >
          {submitting ? <ButtonSpinner size={iconSize} /> : <Send size={iconSize} />}
        </button>
      )}
    </div>
  )
})
