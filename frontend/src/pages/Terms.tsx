import { useState } from 'react'
import { ArrowLeft, Loader2 } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { useDeleteOwnAccount } from '../hooks/useAccountActions'

export function Terms() {
  const { user, signOut } = useAuth()
  const navigate = useNavigate()
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const deleteAccountMutation = useDeleteOwnAccount()

  const handleDeleteAccount = async () => {
    deleteAccountMutation.mutate(undefined, {
      onSuccess: async () => {
        await signOut()
        setShowDeleteConfirm(false)
        navigate('/')
      },
      onError: (error) => {
        alert(`Failed to delete account: ${error.message}`)
        setShowDeleteConfirm(false)
      },
    })
  }

  const deleting = deleteAccountMutation.isPending

  return (
    <div className="terms-page">
      <button className="back-button" onClick={() => navigate(-1)}>
        <ArrowLeft size={18} />
        Back
      </button>

      <div className="terms-content">
        <h1>Terms and Conditions</h1>
        <p className="terms-updated">Last updated: December 22, 2025</p>

        <section>
          <h2>1. Acceptance of Terms</h2>
          <p>
            By accessing and using MasterShifu ("the Platform"), you agree to be bound by these
            Terms and Conditions. If you do not agree to these terms, please do not use the
            Platform.
          </p>
        </section>

        <section>
          <h2>2. Description of Service</h2>
          <p>MasterShifu is a platform that provides:</p>
          <ul>
            <li>A community discussion forum for users to share information and opinions</li>
            <li>Private messaging between users</li>
            <li>User feedback and support features</li>
          </ul>
        </section>

        <section>
          <h2>3. User Accounts</h2>
          <p>
            To access certain features, you must sign in using Google OAuth authentication. By
            creating an account, you agree to:
          </p>
          <ul>
            <li>Provide accurate information</li>
            <li>Maintain the security of your account credentials</li>
            <li>Accept responsibility for all activities under your account</li>
            <li>Not share your account with others</li>
          </ul>
          <p>
            You may customize your username (3-30 characters, letters, numbers, and underscores
            only). Usernames must be unique and must not impersonate others or be offensive.
          </p>
        </section>

        <section>
          <h2>4. User Conduct</h2>
          <p>When using the Platform, you agree NOT to:</p>
          <ul>
            <li>
              Post content that is illegal, harmful, threatening, abusive, harassing, defamatory, or
              otherwise objectionable
            </li>
            <li>Impersonate any person or entity</li>
            <li>Post spam, advertisements, or promotional content without permission</li>
            <li>Attempt to gain unauthorized access to any part of the Platform</li>
            <li>
              Use automated systems (bots, scrapers) to access the Platform without permission
            </li>
            <li>Interfere with or disrupt the Platform's functionality</li>
            <li>Post false or misleading financial information</li>
            <li>Engage in market manipulation or securities fraud</li>
          </ul>
        </section>

        <section>
          <h2>5. User Content</h2>
          <p>
            By posting content on the Platform (including forum posts, replies, and feedback
            messages), you:
          </p>
          <ul>
            <li>Retain ownership of your original content</li>
            <li>
              Grant us a non-exclusive, royalty-free license to display, distribute, and use your
              content on the Platform
            </li>
            <li>Represent that you have the right to post such content</li>
            <li>
              Acknowledge that your content may be moderated, edited, or removed at our discretion
            </li>
          </ul>
          <p>
            You may edit your posts within 30 minutes of posting. After this period, original posts
            may add additional comments but the original content cannot be changed. You may delete
            your own posts at any time.
          </p>
        </section>

        <section>
          <h2>6. Content Moderation</h2>
          <p>We reserve the right to moderate user content. This includes:</p>
          <ul>
            <li>Automated filtering of inappropriate language</li>
            <li>Manual review of flagged content by administrators</li>
            <li>Removal of content that violates these terms</li>
            <li>Suspension or termination of accounts that repeatedly violate terms</li>
          </ul>
          <p>
            Flagged content may remain visible while under review. Administrators may mark content
            as reviewed or delete it as appropriate.
          </p>
        </section>

        <section>
          <h2>7. Intellectual Property</h2>
          <p>
            The Platform's design, code, logos, and original content are owned by us and protected
            by intellectual property laws.
          </p>
          <p>
            You may not copy, modify, distribute, or create derivative works from our proprietary
            content without permission.
          </p>
        </section>

        <section>
          <h2>8. File Uploads</h2>
          <p>When uploading files (such as feedback attachments), you agree to:</p>
          <ul>
            <li>Only upload files you have the right to share</li>
            <li>Not upload malicious files (executables, scripts, etc.)</li>
            <li>Respect file size limits (default 2MB, may vary)</li>
            <li>Only upload permitted file types (images by default)</li>
          </ul>
        </section>

        <section>
          <h2>9. Privacy</h2>
          <p>
            Your use of the Platform is also governed by our Privacy Policy. By using the Platform,
            you consent to the collection and use of information as described in our Privacy Policy.
          </p>
          <p>
            We use Supabase for authentication and data storage. Your data is stored securely and is
            not sold to third parties.
          </p>
        </section>

        <section>
          <h2>10. Account Termination</h2>
          <p>
            You may delete your account at any time
            {user ? (
              showDeleteConfirm ? (
                <span className="delete-account-inline">
                  <span className="delete-confirm-text">Are you sure?</span>
                  <button
                    className="delete-confirm-btn cancel"
                    onClick={() => setShowDeleteConfirm(false)}
                    disabled={deleting}
                  >
                    Cancel
                  </button>
                  <button
                    className="delete-confirm-btn confirm"
                    onClick={handleDeleteAccount}
                    disabled={deleting}
                  >
                    {deleting ? <Loader2 size={14} className="spin" /> : 'Delete'}
                  </button>
                </span>
              ) : (
                <>
                  {' - '}
                  <button
                    className="delete-account-link"
                    onClick={() => setShowDeleteConfirm(true)}
                  >
                    delete your account
                  </button>
                </>
              )
            ) : (
              ' while being signed in'
            )}
            . We reserve the right to suspend or terminate accounts that violate these terms.
          </p>
          <p>Upon account deletion:</p>
          <ul>
            <li>Your profile information will be removed</li>
            <li>Your posts will remain visible under your username</li>
            <li>
              This action cannot be undone - if you register again using the same email, it will be
              a new account and you will not be able to choose the same username
            </li>
          </ul>
        </section>

        <section>
          <h2>11. Limitation of Liability</h2>
          <p>
            The platform is provided "as is" without warranties of any kind, express or implied. We
            do not warrant that the platform will be uninterrupted, error-free, or secure.
          </p>
          <p>
            To the maximum extent permitted by law, we shall not be liable for any indirect,
            incidental, special, consequential, or punitive damages, including but not limited to
            loss of profits, data, or goodwill.
          </p>
        </section>

        <section>
          <h2>12. Indemnification</h2>
          <p>
            You agree to indemnify and hold harmless the Platform, its operators, and affiliates
            from any claims, damages, or expenses arising from your use of the Platform or violation
            of these terms.
          </p>
        </section>

        <section>
          <h2>13. Changes to Terms</h2>
          <p>
            We may update these Terms and Conditions at any time. Continued use of the Platform
            after changes constitutes acceptance of the new terms. We encourage you to review these
            terms periodically.
          </p>
        </section>

        <section>
          <h2>14. Governing Law</h2>
          <p>
            These terms shall be governed by and construed in accordance with the laws of the
            jurisdiction in which the Platform operates, without regard to conflict of law
            principles.
          </p>
        </section>

        <section>
          <h2>15. Contact</h2>
          <p>
            If you have questions about these Terms and Conditions, please use the Feedback feature
            on the Platform to contact us.
          </p>
        </section>

        <div className="terms-footer">
          <p>
            By using MasterShifu, you acknowledge that you have read, understood, and agree to these
            Terms and Conditions.
          </p>
        </div>
      </div>
    </div>
  )
}
