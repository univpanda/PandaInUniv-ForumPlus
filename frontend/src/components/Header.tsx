import { memo } from 'react'
import { AuthButton } from './AuthButton'
import pandaLogo from '../assets/png/pandalogo.jpg'

export type Tab = 'discussion' | 'chat' | 'users' | 'profile' | 'notifications' | 'placements' | 'admin'

interface HeaderProps {
  onLogoClick?: () => void
  tabs?: React.ReactNode
}

export const Header = memo(function Header({ onLogoClick, tabs }: HeaderProps) {
  const logoContent = (
    <img src={pandaLogo} alt="PandaInUniv" className="logo-image" />
  )

  return (
    <header className="header">
      <div className="header-content">
        <div className="logo header-logo">
          <div className="logo-text">
            {onLogoClick ? (
              <button className="logo-button" onClick={onLogoClick}>
                {logoContent}
              </button>
            ) : (
              <h1>{logoContent}</h1>
            )}
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
