import { memo } from 'react'
import { AuthButton } from './AuthButton'
import pandaLogo from '../assets/png/pandalogo.jpg'

export type Tab = 'discussion' | 'chat' | 'users' | 'profile' | 'notifications' | 'placements' | 'admin'

interface HeaderProps {
  tabs?: React.ReactNode
}

export const Header = memo(function Header({ tabs }: HeaderProps) {
  return (
    <header className="header">
      <div className="header-content">
        <div className="logo header-logo">
          <div className="logo-text">
            <h1>
              <img src={pandaLogo} alt="PandaInUniv" className="logo-image" />
            </h1>
          </div>
        </div>
        {tabs && (
          <div className="header-tabs">
            <div className="header-tabs-pill">{tabs}</div>
          </div>
        )}
        <div className="header-right">
          <AuthButton />
        </div>
      </div>
    </header>
  )
})
