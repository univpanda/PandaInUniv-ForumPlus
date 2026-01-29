interface FooterProps {
  onShowTerms: () => void
}

export function Footer({ onShowTerms }: FooterProps) {
  const currentYear = new Date().getFullYear()

  return (
    <footer className="footer">
      <div className="footer-content">
        <div className="footer-left">
          © {currentYear} PandaInUniv
        </div>
        <div className="footer-right">
          <div className="footer-legal">
            <button className="footer-link" onClick={onShowTerms}>
              Terms of Use
            </button>
          </div>
          <div className="footer-social">
            <a
              className="footer-social-link"
              href="https://x.com/pandainuniv"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="Twitter"
            >
              <span className="footer-social-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" role="img" aria-hidden="true">
                  <path d="M13.2 10.7L20.8 2h-1.8l-6.7 7.6L7.1 2H2l7.9 11.1L2 22h1.8l6.9-7.9L16.9 22H22l-8.8-11.3zM11.4 13l-.8-1.2-6-8.6h2.3l4.9 7.1.8 1.2 6.3 9.1h-2.2L11.4 13z" />
                </svg>
              </span>
              <span className="footer-social-text">Twitter</span>
            </a>
            <a
              className="footer-social-link"
              href="https://www.reddit.com/r/pandainuniv/"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="Reddit"
            >
              <span className="footer-social-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" role="img" aria-hidden="true">
                  <path d="M14.6 3.5c.2-.1.4-.2.6-.2.9 0 1.6.7 1.6 1.6 0 .7-.4 1.3-1 1.5 0 0-.3.1-.4.1-.4 0-.7-.1-1-.4-1.1.1-2.3.3-3.6.7l.7 3.2c1.7-.4 3.6-.4 5.3 0 1.1-.6 2.6-.6 3.7.2 1 .7 1.6 1.8 1.6 3.1 0 2-1.6 3.7-3.9 4.5-1.6.5-3.4.7-5.4.7s-3.8-.2-5.4-.7C3.6 18.8 2 17.1 2 15.1c0-1.3.6-2.4 1.6-3.1 1.1-.7 2.6-.8 3.7-.2 1.7-.4 3.6-.4 5.3 0l-.8-3.7c-1.2.4-2.3.7-3.2.9-.1.6-.7 1-1.3 1-.8 0-1.4-.6-1.4-1.4 0-.8.6-1.4 1.4-1.4.4 0 .7.2 1 .4 1.3-.3 2.6-.6 3.9-.9l.4-.1zM8.6 14.4c-.7 0-1.3.6-1.3 1.3 0 .7.6 1.3 1.3 1.3.7 0 1.3-.6 1.3-1.3 0-.7-.6-1.3-1.3-1.3zm6.8 0c-.7 0-1.3.6-1.3 1.3 0 .7.6 1.3 1.3 1.3.7 0 1.3-.6 1.3-1.3 0-.7-.6-1.3-1.3-1.3zm-6.6 4.2c1.3 1 4.1 1 5.4 0 .2-.2.5-.2.6 0 .2.2.2.5 0 .7-.8.7-1.9 1-3.3 1-1.4 0-2.5-.3-3.3-1-.2-.2-.2-.5 0-.7.2-.2.5-.2.6 0z" />
                </svg>
              </span>
              <span className="footer-social-text">Reddit</span>
            </a>
          </div>
        </div>
      </div>
    </footer>
  )
}
