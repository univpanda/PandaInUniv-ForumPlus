import { Node, mergeAttributes } from '@tiptap/core'
import { NodeViewWrapper, NodeViewContent, ReactNodeViewRenderer, type NodeViewProps } from '@tiptap/react'
import { TextSelection } from '@tiptap/pm/state'
import { useEffect, useRef } from 'react'
import katex from 'katex'

// Inline editable LaTeX node - content is editable, preview shown alongside
function LatexNodeView({ node, selected }: NodeViewProps) {
  // Strip zero-width spaces used as placeholders
  const content = (node.textContent || '').replace(/\u200B/g, '')
  const renderRef = useRef<HTMLSpanElement>(null)

  // Render KaTeX preview - compile whatever is typed as LaTeX
  useEffect(() => {
    if (renderRef.current) {
      if (content.trim()) {
        try {
          // Check for $$ delimiters or block-level environments
          const hasDoubleDollar = /^\$\$[\s\S]*\$\$$/.test(content.trim())
          const hasBlockEnv = /\\begin\{(equation\*?|align\*?|gather\*?|multline\*?|split|matrix|pmatrix|bmatrix|vmatrix|Vmatrix|smallmatrix|array|cases|subequations)\}/.test(content)
          const isDisplayMode = hasDoubleDollar || hasBlockEnv

          // Strip $$ if present
          let latexContent = content
          if (hasDoubleDollar) {
            latexContent = content.trim().slice(2, -2)
          }

          katex.render(latexContent, renderRef.current, {
            throwOnError: false,
            displayMode: isDisplayMode,
          })
        } catch {
          renderRef.current.textContent = '?'
        }
      } else {
        renderRef.current.textContent = ''
      }
    }
  }, [content])

  return (
    <NodeViewWrapper as="span" className={`latex-inline-wrapper ${selected ? 'selected' : ''}`}>
      {/* @ts-expect-error - NodeViewContent supports span but types are restrictive */}
      <NodeViewContent as="span" className="latex-editable" />
      <span ref={renderRef} className="latex-preview" />
    </NodeViewWrapper>
  )
}

// The Tiptap extension - inline node with editable content
export const LatexNode = Node.create({
  name: 'latexNode',
  group: 'inline',
  inline: true,
  content: 'text*',

  parseHTML() {
    return [
      {
        tag: 'span[data-latex]',
      },
    ]
  },

  renderHTML({ HTMLAttributes }) {
    return ['span', mergeAttributes({ 'data-latex': '' }, HTMLAttributes), 0]
  },

  addNodeView() {
    return ReactNodeViewRenderer(LatexNodeView)
  },

  addCommands() {
    return {
      insertLatex:
        () =>
        ({ chain }) => {
          return chain()
            .insertContent([
              { type: 'text', text: ' ' }, // Space before latex box for easy exit
              {
                type: this.name,
                content: [{ type: 'text', text: '\u200B' }], // Zero-width space as placeholder
              },
            ])
            .command(({ tr, state }) => {
              // Move cursor inside the latex node
              const pos = state.selection.from - 1
              tr.setSelection(TextSelection.create(tr.doc, pos))
              return true
            })
            .run()
        },
    }
  },

  addKeyboardShortcuts() {
    const nodeName = this.name
    return {
      ArrowLeft: ({ editor }) => {
        const { state } = editor
        const { selection } = state
        const { $from } = selection

        // Find if we're inside a latexNode at any depth
        let latexDepth = -1
        for (let d = $from.depth; d >= 0; d--) {
          if ($from.node(d)?.type.name === nodeName) {
            latexDepth = d
            break
          }
        }

        if (latexDepth === -1) {
          return false
        }

        // Get cursor position relative to start of latex node
        const startOfLatex = $from.start(latexDepth)
        const cursorPosInNode = $from.pos - startOfLatex

        // If at or near start, exit left
        if (cursorPosInNode <= 1) {
          // Move cursor before the latex node
          const beforePos = $from.before(latexDepth)
          editor.commands.setTextSelection(beforePos)
          return true
        }

        return false
      },
      ArrowRight: ({ editor }) => {
        const { state } = editor
        const { selection } = state
        const { $from } = selection

        // Find if we're inside a latexNode at any depth
        let latexDepth = -1
        for (let d = $from.depth; d >= 0; d--) {
          if ($from.node(d)?.type.name === nodeName) {
            latexDepth = d
            break
          }
        }

        if (latexDepth === -1) {
          return false
        }

        // Get cursor position relative to end of latex node
        const endOfLatex = $from.end(latexDepth)
        const cursorPosFromEnd = endOfLatex - $from.pos

        // If at or near end, exit right
        if (cursorPosFromEnd <= 0) {
          // Move cursor after the latex node
          const afterPos = $from.after(latexDepth)
          editor.commands.setTextSelection(afterPos)
          return true
        }

        return false
      },
    }
  },
})

// Declare the command type for TypeScript
declare module '@tiptap/core' {
  interface Commands<ReturnType> {
    latexNode: {
      insertLatex: () => ReturnType
    }
  }
}
