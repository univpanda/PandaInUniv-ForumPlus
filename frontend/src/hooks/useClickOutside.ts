import { useEffect, type RefObject } from 'react'

/**
 * Hook that triggers a callback when clicking outside of the referenced element.
 *
 * @param ref - React ref to the element to detect clicks outside of
 * @param handler - Callback function to run when clicking outside
 * @param enabled - Whether the listener is active (default: true)
 *
 * @example
 * const menuRef = useRef<HTMLDivElement>(null)
 * const [isOpen, setIsOpen] = useState(false)
 *
 * useClickOutside(menuRef, () => setIsOpen(false), isOpen)
 */
export function useClickOutside<T extends HTMLElement>(
  ref: RefObject<T | null>,
  handler: () => void,
  enabled: boolean = true
): void {
  useEffect(() => {
    if (!enabled) return

    function handleClickOutside(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        handler()
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [ref, handler, enabled])
}
