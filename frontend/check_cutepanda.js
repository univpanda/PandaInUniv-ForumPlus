const { createClient } = require("@supabase/supabase-js");
const supabase = createClient(
  "https://jsprwslapmfqxkpfotmj.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpzcHJ3c2xhcG1mcXhrcGZvdG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkzNzQ4ODIsImV4cCI6MjA2NDk1MDg4Mn0.n5hXLLy5c-U0IiYosswgIVQfSJO_Lxf2p7bw9RaVizU"
);

async function check() {
  const { data: profile } = await supabase
    .from("profiles")
    .select("id, username")
    .ilike("username", "%cutepanda%")
    .single();
  
  console.log("Profile:", profile);
  
  if (profile) {
    const { data: ops } = await supabase
      .from("posts")
      .select("id, is_deleted, thread_id")
      .eq("author_id", profile.id)
      .is("parent_id", null);
    
    console.log("\nOP Posts by cutepanda:");
    console.log("Total OPs:", ops?.length || 0);
    
    const deleted = ops?.filter(p => p.is_deleted === true) || [];
    const notDeleted = ops?.filter(p => p.is_deleted === false || p.is_deleted === null) || [];
    
    console.log("Deleted OPs:", deleted.length);
    console.log("Non-deleted OPs:", notDeleted.length);
    
    console.log("\nDetails:");
    ops?.forEach(p => console.log("  Thread " + p.thread_id + ": is_deleted=" + p.is_deleted));
  }
}

check().catch(console.error);
