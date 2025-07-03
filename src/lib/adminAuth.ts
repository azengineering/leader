
import { supabase } from './db';

export async function checkAdminAuth(): Promise<boolean> {
  try {
    const { data: { session } } = await supabase.auth.getSession();
    
    if (!session || localStorage.getItem('admin_auth') !== 'true') {
      return false;
    }

    // Verify admin role
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', session.user.id)
      .single();

    return profile && ['admin', 'super_admin'].includes(profile.role);
  } catch (error) {
    console.error('Error checking admin auth:', error);
    return false;
  }
}

export async function adminLogout(): Promise<void> {
  await supabase.auth.signOut();
  localStorage.removeItem('admin_auth');
  localStorage.removeItem('admin_user_id');
  window.location.href = '/admin/login';
}

export function getAdminUserId(): string | null {
  return localStorage.getItem('admin_user_id');
}
