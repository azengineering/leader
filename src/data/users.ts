'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export interface User {
  id: string;
  email: string;
  name?: string;
  location?: string;
  isBlocked?: boolean | number;
  blockedUntil?: string | null;
  blockReason?: string | null;
  role?: string;
  createdAt?: string;
  updatedAt?: string;
}

export interface AdminMessage {
  id: string;
  userId: string;
  message: string;
  isRead: boolean;
  createdAt: string;
}

export async function findUserById(id: string): Promise<User | null> {
  try {
    const { data, error } = await supabase
      .from('users')
      .select('*')
      .eq('id', id)
      .single();

    if (error) {
      console.error('Error finding user by ID:', error);
      return null;
    }
    return data;
  } catch (error) {
    console.error('Error finding user by ID:', error);
    return null;
  }
}

export async function updateUserProfile(userId: string, profileData: Partial<Omit<User, 'id' | 'email' | 'createdAt'>>): Promise<User | null> {
  try {
    const { data, error } = await supabaseAdmin
      .from('users')
      .update(profileData)
      .eq('id', userId)
      .select()
      .single();

    if (error) {
      console.error("Error updating user profile:", error);
      return null;
    }
    return data;
  } catch (error) {
    console.error("Error updating user profile:", error);
    return null;
  }
}

export async function getUserCount(filters?: { startDate?: string, endDate?: string, location?: string }): Promise<number> {
  try {
    let query = supabaseAdmin.from('users').select('*', { count: 'exact', head: true });

    if (filters?.startDate && filters?.endDate) {
      query = query.gte('"createdAt"', filters.startDate).lte('"createdAt"', filters.endDate);
    }
    if (filters?.location) {
      query = query.ilike('location', `%${filters.location}%`);
    }

    const { count, error } = await query;
    if (error) {
      console.error("Error getting user count:", error);
      return 0;
    }
    return count ?? 0;
  } catch (error) {
    console.error("Error getting user count:", error);
    return 0;
  }
}

export async function blockUser(userId: string, reason: string, blockedUntil: string | null): Promise<void> {
  try {
    const { error } = await supabaseAdmin
      .from('users')
      .update({ 
        "isBlocked": true, 
        "blockReason": reason, 
        "blockedUntil": blockedUntil,
        "updatedAt": new Date().toISOString()
      })
      .eq('id', userId);

    if (error) {
      console.error("Error blocking user:", error);
      throw error;
    }
  } catch (error) {
    console.error("Error blocking user:", error);
    throw error;
  }
}

export async function unblockUser(userId: string): Promise<void> {
  try {
    const { error } = await supabaseAdmin
      .from('users')
      .update({ 
        "isBlocked": false, 
        "blockReason": null, 
        "blockedUntil": null,
        "updatedAt": new Date().toISOString()
      })
      .eq('id', userId);

    if (error) {
      console.error("Error unblocking user:", error);
      throw error;
    }
  } catch (error) {
    console.error("Error unblocking user:", error);
    throw error;
  }
}

export interface UserWithCounts extends User {
  email?: string;
  leaderCount: number;
  ratingCount: number;
}

export async function getUsersForAdminPanel(filters: {
  name?: string;
  email?: string;
  location?: string;
  isBlocked?: boolean;
  ratingCount?: number;
  leaderCount?: number;
} = {}): Promise<UserWithCounts[]> {
  try {
    let query = supabaseAdmin
      .from('users')
      .select(`
        id,
        name,
        location,
        isBlocked,
        blockReason,
        blockedUntil,
        role,
        createdAt,
        updatedAt,
        leaders!leaders_addedByUserId_fkey(id),
        ratings!ratings_userId_fkey(id)
      `);

    // Apply filters
    if (filters.name) {
      query = query.ilike('name', `%${filters.name}%`);
    }
    if (filters.location) {
      query = query.ilike('location', `%${filters.location}%`);
    }
    if (filters.isBlocked !== undefined) {
      query = query.eq('isBlocked', filters.isBlocked);
    }

    const { data, error } = await query.order('createdAt', { ascending: false });

    if (error) {
      console.error("Error fetching users for admin:", error);
      return [];
    }

    // Get emails from auth.users for each user
    const userIds = (data as any[]).map(user => user.id);
    const { data: authUsers } = await supabaseAdmin.auth.admin.listUsers();

    const emailMap = new Map();
    authUsers.users?.forEach(authUser => {
      emailMap.set(authUser.id, authUser.email);
    });

    const results = (data as any[]).map(user => ({
      ...user,
      email: emailMap.get(user.id),
      ratingCount: user.ratings?.[0]?.count || 0,
      leaderAddedCount: user.leaders?.[0]?.count || 0,
      unreadMessageCount: user.admin_messages?.[0]?.count || 0,
    }));

    return results;
  } catch (error) {
    console.error("Error fetching users for admin:", error);
    return [];
  }
}

export async function getUsers(query?: string): Promise<User[]> {
  try {
    let usersQuery = supabaseAdmin
      .from('users')
      .select(`
        *,
        ratings!inner(count),
        leaders!leaders_addedByUserId_fkey(count),
        admin_messages!admin_messages_user_id_fkey(count)
      `)
      .eq('admin_messages.isRead', false);

    if (query) {
      // Handle UUID vs string search properly
      const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(query);

      if (isUUID) {
        usersQuery = usersQuery.eq('id', query);
      } else {
        usersQuery = usersQuery.or(`name.ilike.%${query}%`);
      }
    }

    const { data, error } = await usersQuery
      .order('createdAt', { ascending: false });

    if (error) {
      console.error('Error fetching users for admin:', error);
      throw new Error(`Failed to fetch users: ${error.message}`);
    }

    return data || [];
  } catch (error) {
    console.error('Error in getUsers:', error);
    throw error;
  }
}

export async function addAdminMessage(userId: string, message: string): Promise<void> {
  try {
    const { error } = await supabaseAdmin
      .from('admin_messages')
      .insert({ 
        user_id: userId, 
        message: message,
        createdAt: new Date().toISOString()
      });

    if (error) {
      console.error("Error adding admin message:", error);
      throw error;
    }
  } catch (error) {
    console.error("Error adding admin message:", error);
    throw error;
  }
}

export async function getAdminMessages(userId: string): Promise<AdminMessage[]> {
  try {
    const { data, error } = await supabaseAdmin
      .from('admin_messages')
      .select('*')
      .eq('user_id', userId)
      .order('createdAt', { ascending: false });

    if (error) {
      console.error("Error getting admin messages:", error);
      return [];
    }
    return data || [];
  } catch (error) {
    console.error("Error getting admin messages:", error);
    return [];
  }
}

export async function getUnreadMessages(userId: string): Promise<AdminMessage[]> {
  try {
    const { data, error } = await supabase
      .from('admin_messages')
      .select('*')
      .eq('user_id', userId)
      .eq('isRead', false)
      .order('createdAt', { ascending: true });

    if (error) {
      console.error("Error getting unread messages:", error);
      return [];
    }
    return data || [];
  } catch (error) {
    console.error("Error getting unread messages:", error);
    return [];
  }
}

export async function markMessageAsRead(messageId: string): Promise<void> {
  try {
    const { error } = await supabase
      .from('admin_messages')
      .update({ isRead: true })
      .eq('id', messageId);

    if (error) {
      console.error("Error marking message as read:", error);
      throw error;
    }
  } catch (error) {
    console.error("Error marking message as read:", error);
    throw error;
  }
}

export async function deleteAdminMessage(messageId: string): Promise<void> {
  try {
    const { error } = await supabaseAdmin
      .from('admin_messages')
      .delete()
      .eq('id', messageId);

    if (error) {
      console.error("Error deleting admin message:", error);
      throw error;
    }
  } catch (error) {
    console.error("Error deleting admin message:", error);
    throw error;
  }
}