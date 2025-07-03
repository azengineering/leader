
import { supabase } from './db';
import { supabaseAdmin } from './supabaseAdmin';

export interface AdminSession {
  user: {
    id: string;
    email: string;
    role: 'admin' | 'super_admin';
    name?: string;
  };
  isValid: boolean;
  expiresAt: number;
}

const ADMIN_SESSION_KEY = 'admin_session';
const SESSION_DURATION = 8 * 60 * 60 * 1000; // 8 hours

export async function authenticateAdmin(email: string, password: string): Promise<AdminSession | null> {
  try {
    // Sign in with Supabase
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (authError || !authData.user) {
      throw new Error('Invalid credentials');
    }

    // Get user profile with admin role verification
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role, name')
      .eq('id', authData.user.id)
      .single();

    if (profileError || !profile) {
      await supabase.auth.signOut();
      throw new Error('Unable to verify admin status');
    }

    if (!['admin', 'super_admin'].includes(profile.role)) {
      await supabase.auth.signOut();
      throw new Error('Access denied. Admin privileges required.');
    }

    // Create admin session
    const session: AdminSession = {
      user: {
        id: authData.user.id,
        email: authData.user.email!,
        role: profile.role as 'admin' | 'super_admin',
        name: profile.name || authData.user.email?.split('@')[0],
      },
      isValid: true,
      expiresAt: Date.now() + SESSION_DURATION,
    };

    // Store session
    if (typeof window !== 'undefined') {
      localStorage.setItem(ADMIN_SESSION_KEY, JSON.stringify(session));
    }

    return session;
  } catch (error: any) {
    console.error('Admin authentication error:', error);
    throw error;
  }
}

export async function checkAdminAuth(): Promise<AdminSession | null> {
  try {
    if (typeof window === 'undefined') return null;

    // Check stored session
    const storedSession = localStorage.getItem(ADMIN_SESSION_KEY);
    if (!storedSession) return null;

    const session: AdminSession = JSON.parse(storedSession);

    // Check if session is expired
    if (Date.now() > session.expiresAt) {
      await adminLogout();
      return null;
    }

    // Verify current Supabase session
    const { data: { session: supabaseSession } } = await supabase.auth.getSession();
    if (!supabaseSession || supabaseSession.user.id !== session.user.id) {
      await adminLogout();
      return null;
    }

    // Verify admin role is still valid
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', session.user.id)
      .single();

    if (!profile || !['admin', 'super_admin'].includes(profile.role)) {
      await adminLogout();
      return null;
    }

    // Extend session if user is active and session is more than half expired
    const halfDuration = SESSION_DURATION / 2;
    if (Date.now() > (session.expiresAt - halfDuration)) {
      session.expiresAt = Date.now() + SESSION_DURATION;
      localStorage.setItem(ADMIN_SESSION_KEY, JSON.stringify(session));
    }

    return session;
  } catch (error) {
    console.error('Error checking admin auth:', error);
    await adminLogout();
    return null;
  }
}

export async function adminLogout(): Promise<void> {
  try {
    await supabase.auth.signOut();
  } catch (error) {
    console.error('Error during logout:', error);
  } finally {
    if (typeof window !== 'undefined') {
      localStorage.removeItem(ADMIN_SESSION_KEY);
      localStorage.removeItem('admin_auth'); // Remove old key
      localStorage.removeItem('admin_user_id'); // Remove old key
    }
  }
}

export function getAdminSession(): AdminSession | null {
  if (typeof window === 'undefined') return null;
  
  const storedSession = localStorage.getItem(ADMIN_SESSION_KEY);
  if (!storedSession) return null;
  
  try {
    const session: AdminSession = JSON.parse(storedSession);
    return Date.now() <= session.expiresAt ? session : null;
  } catch {
    return null;
  }
}

export function hasAdminRole(requiredRole: 'admin' | 'super_admin' = 'admin'): boolean {
  const session = getAdminSession();
  if (!session) return false;
  
  if (requiredRole === 'super_admin') {
    return session.user.role === 'super_admin';
  }
  
  return ['admin', 'super_admin'].includes(session.user.role);
}
