import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://cvhjyibdupajanlvkxkm.supabase.co'
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN2aGp5aWJkdXBhamFubHZreGttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUzNDQwOTAsImV4cCI6MjA4MDkyMDA5MH0.TBRW3mKOS5EOukQCh83FPsNfSJBiVB7meLCMlYjqW0U'

const supabase = createClient(supabaseUrl, supabaseKey)

async function testPoll() {
  console.log('Testing poll creation...\n')

  // Sign in with a test user - you'll need to provide credentials
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: 'sumitgper@gmail.com',
    password: 'Panda@123'
  })

  if (authError) {
    console.log('Auth error:', authError.message)
    console.log('\nPlease update the password in this script to test.')
    return
  }

  console.log('Signed in as:', authData.user?.email)
  console.log('User ID:', authData.user?.id)

  // Try calling the RPC
  console.log('\nCalling create_poll_thread...')
  const { data, error } = await supabase.rpc('create_poll_thread', {
    p_title: 'Test Poll from Script',
    p_content: 'Testing poll creation',
    p_poll_options: ['Option A', 'Option B', 'Option C'],
    p_allow_multiple: false,
    p_show_results_before_vote: false,
    p_allow_vote_change: false,
    p_is_flagged: false,
    p_flag_reason: null,
  })

  if (error) {
    console.log('\nError:', JSON.stringify(error, null, 2))
  } else {
    console.log('\nSuccess! Thread ID:', data)

    // Verify the poll was created
    const { data: pollData } = await supabase.rpc('get_poll_data', { p_thread_id: data })
    console.log('\nPoll data:', JSON.stringify(pollData, null, 2))
  }

  await supabase.auth.signOut()
}

testPoll()
