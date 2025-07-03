
'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export interface User {
  id: string;
  email: string;
  name?: string;
  gender?: 'male' | 'female' | 'other' | '';
  age?: number;
  state?: string;
  mpConstituency?: string;
  mlaConstituency?: string;
  panchayat?: string;
  createdAt?: string;
  isBlocked?: boolean | number;
  blockedUntil?: string | null;
  blockReason?: string | null;
}

export interface AdminMessage {
  id: string;
  userId: string;
  message: string;
  isRead: boolean;
  createdAt: string;
}

export async function findUserById(id: string): Promise<User | null> {
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
}

export async function updateUserProfile(userId: string, profileData: Partial<Omit<User, 'id' | 'email' | 'createdAt'>>): Promise<User | null> {
    const { data, error } = await supabase
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
}

export async function getUserCount(filters?: { startDate?: string, endDate?: string, state?: string, constituency?: string }): Promise<number> {
    let query = supabaseAdmin.from('users').select('*', { count: 'exact', head: true });

    if (filters?.startDate && filters?.endDate) {
        query = query.gte('createdAt', filters.startDate).lte('createdAt', filters.endDate);
    }
    if (filters?.state) {
        query = query.eq('state', filters.state);
    }
    if (filters?.constituency) {
        const searchTerm = `%${filters.constituency}%`;
        query = query.or(`mpConstituency.ilike.${searchTerm},mlaConstituency.ilike.${searchTerm},panchayat.ilike.${searchTerm}`);
    }
    
    const { count, error } = await query;
    if (error) {
        console.error("Error getting user count:", error);
        return 0;
    }
    return count ?? 0;
}

// --- Admin Moderation Functions ---

export async function blockUser(userId: string, reason: string, blockedUntil: string | null): Promise<void> {
    const { error } = await supabaseAdmin
        .from('users')
        .update({ isBlocked: true, blockReason: reason, blockedUntil: blockedUntil })
        .eq('id', userId);
        
    if (error) {
      console.error("Error blocking user:", error);
      throw error;
    }
}

export async function unblockUser(userId: string): Promise<void> {
    const { error } = await supabaseAdmin
        .from('users')
        .update({ isBlocked: false, blockReason: null, blockedUntil: null })
        .eq('id', userId);

    if (error) {
      console.error("Error unblocking user:", error);
      throw error;
    }
}

export async function getUsers(query?: string): Promise<Partial<User>[]> {
  let selectQuery = supabaseAdmin
    .from('users')
    .select(`
        *,
        leader_added_count:leaders(count),
        rating_count:ratings(count),
        unread_message_count:admin_messages!inner(count)
    `)
    .eq('admin_messages.isRead', false)
    .order('createdAt', { ascending: false });

  if (query) {
    const searchTerm = `%${query}%`;
    selectQuery = selectQuery.or(`name.ilike.${searchTerm},email.ilike.${searchTerm},id.ilike.${searchTerm}`);
  }

  const { data, error } = await selectQuery;

  if (error) {
    console.error("Error fetching users for admin:", error);
    return [];
  }
  
  return data.map((u: any) => ({
    ...u,
    leaderAddedCount: u.leader_added_count[0]?.count ?? 0,
    ratingCount: u.rating_count[0]?.count ?? 0,
    unreadMessageCount: u.unread_message_count[0]?.count ?? 0,
  }));
}

export async function addAdminMessage(userId: string, message: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from('admin_messages')
    .insert({ user_id: userId, message: message });
    
  if (error) {
    console.error("Error adding admin message:", error);
    throw error;
  }
}

export async function getAdminMessages(userId: string): Promise<AdminMessage[]> {
  const { data, error } = await supabaseAdmin
    .from('admin_messages')
    .select('*')
    .eq('user_id', userId)
    .order('createdAt', { ascending: false });

  if (error) {
    console.error("Error getting admin messages:", error);
    return [];
  }
  return data;
}

export async function getUnreadMessages(userId: string): Promise<AdminMessage[]> {
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
  return data;
}

export async function markMessageAsRead(messageId: string): Promise<void> {
  const { error } = await supabase
    .from('admin_messages')
    .update({ isRead: true })
    .eq('id', messageId);

  if (error) {
    console.error("Error marking message as read:", error);
    throw error;
  }
}

export async function deleteAdminMessage(messageId: string): Promise<void> {
    const { error } = await supabaseAdmin
      .from('admin_messages')
      .delete()
      .eq('id', messageId);
      
    if (error) {
      console.error("Error deleting admin message:", error);
      throw error;
    }
}
