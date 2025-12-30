interface FooterProps {
  showTerms: boolean
  onShowTerms: () => void
}

export function Footer({ showTerms, onShowTerms }: FooterProps) {
  return (
    <footer className={`footer ${showTerms ? 'hidden' : ''}`}>
      <div className="footer-content">
        <button className="footer-link" onClick={onShowTerms}>
          Terms & Conditions
        </button>
      </div>
    </footer>
  )
}
