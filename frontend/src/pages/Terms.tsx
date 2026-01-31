import { useState } from 'react'
import { useAuth } from '../hooks/useAuth'
import { useDeleteOwnAccount } from '../hooks'
import { ButtonSpinner } from '../components/ui/LoadingSpinner'



export function Terms() {
  const { user } = useAuth()
  const deleteAccount = useDeleteOwnAccount()
  const [confirmDelete, setConfirmDelete] = useState(false)

  return (
    <div className="terms-page">
      <div className="terms-content">
        <div className="terms-header">
          <h1>Terms and Conditions</h1>
        </div>
        <p className="terms-updated">Last updated: January 2026</p>

        <section>
          <h2>1. Acceptance of Terms</h2>
          <p>
            By accessing and using PandaInUniv ("the Platform"), you agree to these Terms and
            Conditions. If you do not agree, do not use the Platform.
          </p>
        </section>

        <section>
          <h2>2. Description of Service</h2>
          <p>PandaInUniv is a platform that provides:</p>
          <ul>
            <li>
              A community discussion forum with threaded discussions, voting, polls, and bookmarking
            </li>
            <li>Private messaging between users (with ability to block unwanted contacts)</li>
            <li>PhD placement data search and exploration</li>
            <li>Notifications for forum activity (replies, votes)</li>
          </ul>
        </section>

        <section>
          <h2>3. User Accounts</h2>
          <p>
            To access certain features, you must sign in using Google. By creating an account, you
            agree to:
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
          <p>
            You may delete your account at any time while signed in. Upon deletion, your posts will
            remain on the Platform. Once deleted, an account cannot be recovered. You may create a
            new account using the same email, but it will be treated as a completely new account
            with a new identity.
            {user && (
              <span className="delete-account-inline">
                {!confirmDelete ? (
                  <button
                    type="button"
                    className="delete-account-link"
                    onClick={() => setConfirmDelete(true)}
                  >
                    Delete account
                  </button>
                ) : (
                  <>
                    <span className="delete-confirm-text">Confirm delete?</span>
                    <button
                      type="button"
                      className="delete-confirm-btn cancel"
                      onClick={() => setConfirmDelete(false)}
                      disabled={deleteAccount.isPending}
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      className="delete-confirm-btn confirm"
                      onClick={() => deleteAccount.mutate()}
                      disabled={deleteAccount.isPending}
                    >
                      {deleteAccount.isPending ? <ButtonSpinner size={14} /> : 'Delete'}
                    </button>
                  </>
                )}
              </span>
            )}
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
            <li>Reveal private information about others without consent (doxxing)</li>
          </ul>
        </section>

        <section>
          <h2>5. User Content</h2>
          <p>
            By posting content on the Platform (including forum posts, replies, and private
            messages), you:
          </p>
          <ul>
            <li>
              Grant us a perpetual, worldwide, royalty-free license to use, copy, modify,
              distribute, and display your content in any manner
            </li>
            <li>Represent that you have the right to post such content</li>
            <li>Acknowledge that your content may be moderated or removed at our discretion</li>
          </ul>
          <p>
            You may edit your posts within 15 minutes of posting. After this period, original thread
            posts may add additional comments (clearly marked with timestamp), but the original
            content cannot be changed. Replies cannot be edited after 15 minutes. You may delete
            your own posts within 15 minutes of posting, provided they have no replies.
          </p>
          <p>
            You may set your profile to "private" to hide your activity statistics and post history
            from other users. However, your individual posts will still be visible in forum threads
            where they were posted.
          </p>
        </section>

        <section>
          <h2>6. Content Moderation</h2>
          <p>
            We reserve the right to review, edit, or remove any content that violates these terms.
            Accounts that repeatedly violate terms may be suspended or terminated.
          </p>
        </section>

        <section>
          <h2>7. Intellectual Property</h2>
          <p>
            The Platform's design, code, logos, and original content are owned by us and protected
            by intellectual property laws. You may not copy, modify, distribute, or create
            derivative works from our proprietary content without permission.
          </p>
        </section>

        <section>
          <h2>8. Voting and Reputation</h2>
          <p>The Platform includes a voting system for forum content:</p>
          <ul>
            <li>Users may upvote or downvote posts and replies</li>
            <li>Vote counts are publicly visible on all content</li>
            <li>Your voting activity contributes to community content ranking</li>
            <li>
              Abuse of the voting system (e.g., targeted downvoting) may result in account action
            </li>
          </ul>
        </section>

        <section>
          <h2>9. Placement Data</h2>
          <p>
            The Platform provides access to PhD placement data for informational purposes. This data
            is compiled from publicly available sources and is provided "as is" without guarantees
            of accuracy or completeness. Users should verify placement information independently and
            not rely on it as the sole basis for academic or career decisions.
          </p>
        </section>

        <section>
          <h2>10. Privacy</h2>
          <p>
            We only store your email address for authentication purposes. We do not access or store
            your name, gender, or other personal information from your Google account. We do not
            sell your data to third parties.
          </p>
        </section>

        <section>
          <h2>11. Limitation of Liability</h2>
          <p>
            The Platform is provided "as is" without warranties of any kind. We do not warrant that
            the Platform will be uninterrupted, error-free, or secure. To the maximum extent
            permitted by law, we shall not be liable for any indirect, incidental, special,
            consequential, or punitive damages, including but not limited to loss of profits, data,
            or goodwill.
          </p>
        </section>

        <section>
          <h2>12. Changes to Terms</h2>
          <p>
            We may update these Terms and Conditions at any time. Continued use of the Platform
            after changes constitutes acceptance. Please review periodically.
          </p>
        </section>

        <section>
          <h2>13. Governing Law</h2>
          <p>
            These terms shall be governed by the laws of the jurisdiction in which the Platform
            operates. Any disputes arising from these terms or your use of the Platform shall be
            subject to the exclusive jurisdiction of the courts in that jurisdiction.
          </p>
        </section>

        <section>
          <h2>14. Contact</h2>
          <p>
            If you have questions, please contact an administrator through the Platform's private
            messaging feature.
          </p>
        </section>

        <div className="terms-footer">
          <p>
            By using PandaInUniv, you acknowledge that you have read, understood, and agree to these
            Terms and Conditions.
          </p>
        </div>
      </div>
    </div>
  )
}
