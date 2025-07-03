
import { supabaseAdmin } from './supabaseAdmin';

export interface AdminCreationResult {
  success: boolean;
  message: string;
  userId?: string;
  error?: string;
}

/**
 * Creates a new admin user through Supabase Auth and promotes them to admin role
 * This should only be called from server-side code or during initial setup
 */
export async function createAdminUser(
  email: string,
  password: string,
  name: string = 'Admin User',
  adminLevel: 'admin' | 'moderator' = 'admin'
): Promise<AdminCreationResult> {
  try {
    // Check if user already exists
    const { data: existingUser } = await supabaseAdmin
      .from('users')
      .select('id, email, role')
      .eq('email', email)
      .single();

    if (existingUser) {
      if (existingUser.role === 'admin' || existingUser.role === 'moderator') {
        return {
          success: false,
          message: 'Admin user with this email already exists',
          userId: existingUser.id
        };
      } else {
        // Promote existing user to admin
        const { error: promoteError } = await supabaseAdmin.rpc('promote_user_to_admin', {
          p_user_id: existingUser.id,
          p_admin_level: adminLevel
        });

        if (promoteError) {
          return {
            success: false,
            message: 'Failed to promote user to admin',
            error: promoteError.message
          };
        }

        return {
          success: true,
          message: 'Existing user promoted to admin successfully',
          userId: existingUser.id
        };
      }
    }

    // Create new user through Supabase Auth
    const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: {
        name,
        role: adminLevel
      }
    });

    if (authError || !authData.user) {
      return {
        success: false,
        message: 'Failed to create user account',
        error: authError?.message
      };
    }

    // The user profile should be created automatically by the trigger
    // Wait a moment for the trigger to execute
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Promote user to admin
    const { error: promoteError } = await supabaseAdmin.rpc('promote_user_to_admin', {
      p_user_id: authData.user.id,
      p_admin_level: adminLevel
    });

    if (promoteError) {
      return {
        success: false,
        message: 'User created but failed to promote to admin',
        error: promoteError.message,
        userId: authData.user.id
      };
    }

    return {
      success: true,
      message: 'Admin user created successfully',
      userId: authData.user.id
    };

  } catch (error) {
    console.error('Error creating admin user:', error);
    return {
      success: false,
      message: 'Unexpected error occurred',
      error: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

/**
 * Initialize the default admin user for the platform
 */
export async function initializeDefaultAdmin(): Promise<AdminCreationResult> {
  const defaultEmail = process.env.DEFAULT_ADMIN_EMAIL || 'admin@politirate.com';
  const defaultPassword = process.env.DEFAULT_ADMIN_PASSWORD || 'SecureAdmin123!';
  const defaultName = process.env.DEFAULT_ADMIN_NAME || 'System Administrator';

  return await createAdminUser(defaultEmail, defaultPassword, defaultName, 'admin');
}

/**
 * Get comprehensive user profile data
 */
export async function getUserProfileData(userId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc('get_user_profile', {
      p_user_id: userId
    });

    if (error) {
      throw error;
    }

    return data[0] || null;
  } catch (error) {
    console.error('Error fetching user profile:', error);
    return null;
  }
}

/**
 * Get user dashboard statistics
 */
export async function getUserDashboardStats(userId: string) {
  try {
    const { data, error } = await supabaseAdmin.rpc('get_user_dashboard_stats', {
      p_user_id: userId
    });

    if (error) {
      throw error;
    }

    return data[0] || null;
  } catch (error) {
    console.error('Error fetching user dashboard stats:', error);
    return null;
  }
}
