import { memo } from 'react'
import { AuthButton } from './AuthButton'

export type Tab = 'discussion' | 'chat' | 'users' | 'profile' | 'notifications' | 'placements'

export const Header = memo(function Header() {
  return (
    <header className="header">
      <div className="header-content">
        <div className="logo header-logo">
          <div className="logo-text">
            <h1>
              <span className="logo-full">PandaInUniv</span>
              <span className="logo-short" aria-hidden="true">P</span>
            </h1>
          </div>
        </div>
        <div className="header-utilities" id="header-utilities" />
        <div className="header-right">
          <AuthButton />
        </div>
      </div>
    </header>
  )
})
