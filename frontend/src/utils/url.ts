// Clean OAuth hash fragments from URL after authentication
// Used after sign-in (access_token) and sign-out (any leftover hash)
export const cleanOAuthHash = (): void => {
  if (window.location.hash) {
    window.history.replaceState(null, '', window.location.pathname)
  }
}
