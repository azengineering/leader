// THIS FILE IS SERVER-SIDE ONLY
// DO NOT IMPORT IT INTO ANY CLIENT-SIDE CODE

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_KEY;

const urlIsMissing = !supabaseUrl || supabaseUrl.includes('YOUR_PROJECT_URL');
const keyIsMissing = !serviceKey || serviceKey.includes('YOUR_SERVICE_ROLE_KEY');

if (urlIsMissing || keyIsMissing) {
    let errorMessage = 'Missing Supabase ADMIN environment variables required for the admin panel. Please check your .env.local file.\n';
    if (urlIsMissing) {
      errorMessage += '- NEXT_PUBLIC_SUPABASE_URL is missing or using a placeholder value.\n';
    }
    if (keyIsMissing) {
      errorMessage += '- SUPABASE_SERVICE_KEY is missing or using a placeholder value.\n';
    }
    throw new Error(errorMessage);
}


// The admin client uses the service_role key to bypass RLS.
export const supabaseAdmin = createClient(supabaseUrl, serviceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});
