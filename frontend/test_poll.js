// Test poll creation
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.VITE_SUPABASE_URL
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY

console.log('URL:', supabaseUrl)
console.log('Key:', supabaseKey?.substring(0, 20) + '...')

const supabase = createClient(supabaseUrl, supabaseKey)

async function testPoll() {
  // First sign in (you'll need a test user)
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'test@test.com',
    password: 'testpassword'
  })

  if (authError) {
    console.log('Auth error (expected if no test user):', authError.message)
    console.log('Testing RPC call without auth...')
  } else {
    console.log('Signed in as:', authData.user?.email)
  }

  // Try calling the RPC
  const { data, error } = await supabase.rpc('create_poll_thread', {
    p_title: 'Test Poll',
    p_content: 'Test content',
    p_poll_options: ['Option A', 'Option B'],
    p_allow_multiple: false,
    p_show_results_before_vote: false,
    p_allow_vote_change: false,
    p_is_flagged: false,
    p_flag_reason: null,
  })

  if (error) {
    console.log('Error:', error)
  } else {
    console.log('Success! Thread ID:', data)
  }
}

testPoll()
