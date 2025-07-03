
'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

// Interfaces remain the same as they define the shape of the data for the app
export interface Leader {
  id: string;
  name: string;
  partyName: string;
  gender: 'male' | 'female' | 'other';
  age: number;
  photoUrl: string;
  constituency: string;
  nativeAddress: string;
  electionType: 'national' | 'state' | 'panchayat';
  location: {
    state?: string;
    district?: string;
  };
  rating: number;
  reviewCount: number;
  previousElections: Array<{
    electionType: string;
    constituency: string;
    status: 'winner' | 'loser';
    electionYear: string;
    partyName: string;
    state?: string;
  }>;
  manifestoUrl?: string;
  twitterUrl?: string;
  addedByUserId?: string | null;
  createdAt?: string;
  status: 'pending' | 'approved' | 'rejected';
  adminComment?: string | null;
  userName?: string;
}

export interface Review {
  userName: string;
  rating: number;
  comment: string | null;
  updatedAt: string;
  socialBehaviour: string | null;
}

export interface UserActivity {
  leaderId: string;
  leaderName: string;
  leaderPhotoUrl: string;
  rating: number;
  comment: string | null;
  updatedAt: string;
  leader: Leader;
  socialBehaviour: string | null;
  userName: string;
}

export interface RatingDistribution {
  rating: number;
  count: number;
}

export interface SocialBehaviourDistribution {
  name: string;
  count: number;
}


// --- Public API ---

export async function getLeaders(): Promise<Leader[]> {
  const { data, error } = await supabase
    .from('leaders')
    .select('*')
    .eq('status', 'approved');

  if (error) {
    console.error("Error fetching leaders:", error);
    return [];
  }
  return data.map(leader => ({
      ...leader,
      previousElections: leader.previousElections || []
  }));
}

export async function addLeader(leaderData: Omit<Leader, 'id' | 'rating' | 'reviewCount' | 'createdAt' | 'status' | 'adminComment' | 'userName'>, userId: string | null): Promise<void> {
    const { error } = await supabase.from('leaders').insert({
        ...leaderData,
        addedByUserId: userId,
        status: 'pending'
    });

    if (error) {
        console.error("Error adding leader:", error);
        throw error;
    }
}

export async function getLeaderById(id: string): Promise<Leader | null> {
    const { data, error } = await supabase
        .from('leaders')
        .select('*')
        .eq('id', id)
        .single();
        
    if (error) {
        console.error("Error fetching leader by ID:", error);
        return null;
    }
    return {
        ...data,
        previousElections: data.previousElections || []
    };
}

export async function updateLeader(leaderId: string, leaderData: Partial<Omit<Leader, 'id' | 'rating' | 'reviewCount' | 'createdAt' | 'status' | 'adminComment'>>, userId: string | null, isAdmin: boolean): Promise<Leader | null> {
    const db = isAdmin ? supabaseAdmin : supabase;

    const leaderToUpdate = await getLeaderById(leaderId);
    if (!leaderToUpdate) throw new Error("Leader not found.");

    if (!isAdmin && leaderToUpdate.addedByUserId !== userId) {
        throw new Error("You are not authorized to edit this leader.");
    }

    const payload: Partial<Leader> = { ...leaderData };
    if (!isAdmin) {
        payload.status = 'pending';
        payload.adminComment = 'User updated details. Pending re-approval.';
    }
    
    const { data, error } = await db
        .from('leaders')
        .update(payload)
        .eq('id', leaderId)
        .select()
        .single();

    if (error) {
        console.error("Error updating leader:", error);
        throw error;
    }
    return data;
}

export async function submitRatingAndComment(leaderId: string, userId: string, newRating: number, comment: string | null, socialBehaviour: string | null): Promise<Leader | null> {
    const { error } = await supabase.rpc('handle_new_rating', {
        p_leader_id: leaderId,
        p_user_id: userId,
        p_rating: newRating,
        p_comment: comment,
        p_social_behaviour: socialBehaviour
    });

    if (error) {
        console.error('Error submitting rating via RPC:', error);
        throw error;
    }
    
    return getLeaderById(leaderId);
}

export async function getReviewsForLeader(leaderId: string): Promise<Review[]> {
    const { data, error } = await supabase
        .rpc('get_reviews_for_leader', { p_leader_id: leaderId });

    if (error) {
        console.error('Error getting reviews for leader:', error);
        return [];
    }
    return data;
}

export async function getRatingDistribution(leaderId: string): Promise<RatingDistribution[]> {
    const { data, error } = await supabaseAdmin
        .from('ratings')
        .select('rating, count:id')
        .eq('leaderId', leaderId)
        .groupBy('rating');
        
    if (error) {
        console.error("Error getting rating distribution:", error);
        return [];
    }
    return (data as any[]).map(d => ({ rating: d.rating, count: d.count }));
}

export async function getSocialBehaviourDistribution(leaderId: string): Promise<SocialBehaviourDistribution[]> {
    const { data, error } = await supabaseAdmin
        .from('ratings')
        .select('socialBehaviour, count:id')
        .eq('leaderId', leaderId)
        .not('socialBehaviour', 'is', null)
        .groupBy('socialBehaviour');

    if (error) {
        console.error("Error getting social behaviour distribution:", error);
        return [];
    }
    return (data as any[]).map(d => ({ name: d.socialBehaviour.charAt(0).toUpperCase() + d.socialBehaviour.slice(1).replace('-', ' '), count: d.count }));
}

export async function getActivitiesForUser(userId: string): Promise<UserActivity[]> {
     const { data, error } = await supabase
        .rpc('get_user_activities', { p_user_id: userId });

    if (error) {
        console.error('Error getting user activities:', error);
        return [];
    }
    return data;
}

export async function getAllActivities(): Promise<UserActivity[]> {
    const { data, error } = await supabaseAdmin.rpc('get_all_activities');

    if (error) {
        console.error('Error getting all activities:', error);
        return [];
    }
    return data;
}

export async function getLeadersAddedByUser(userId: string): Promise<Leader[]> {
  const { data, error } = await supabase
    .from('leaders')
    .select('*')
    .eq('addedByUserId', userId)
    .order('name', { ascending: true });
    
  if (error) {
      console.error("Error getting leaders added by user:", error);
      return [];
  }
  return data.map(leader => ({
      ...leader,
      previousElections: leader.previousElections || []
  }));
}


export async function getLeaderCount(filters?: { startDate?: string, endDate?: string, state?: string, constituency?: string }): Promise<number> {
    let query = supabaseAdmin.from('leaders').select('*', { count: 'exact', head: true });

    if (filters?.startDate) query = query.gte('createdAt', filters.startDate);
    if (filters?.endDate) query = query.lte('createdAt', filters.endDate);
    if (filters?.state) query = query.eq('location->>state', filters.state);
    if (filters?.constituency) query = query.ilike('constituency', `%${filters.constituency}%`);

    const { error, count } = await query;
    if (error) console.error("Error getting leader count:", error);
    return count ?? 0;
}

export async function getRatingCount(filters?: { startDate?: string, endDate?: string, state?: string, constituency?: string }): Promise<number> {
    let query = supabaseAdmin.from('ratings').select('leaderId, leaders!inner(*)', { count: 'exact', head: true });
    
    if (filters?.startDate) query = query.gte('createdAt', filters.startDate);
    if (filters?.endDate) query = query.lte('createdAt', filters.endDate);
    if (filters?.state) query = query.eq('leaders.location->>state', filters.state);
    if (filters?.constituency) query = query.ilike('leaders.constituency', `%${filters.constituency}%`);

    const { error, count } = await query;
    if (error) console.error("Error getting rating count:", error);
    return count ?? 0;
}

// --- Admin Functions ---
export async function getLeadersForAdminPanel(filters: { dateFrom?: string; dateTo?: string; state?: string; constituency?: string; candidateName?: string; }): Promise<Leader[]> {
  let query = supabaseAdmin
    .from('leaders')
    .select('*, userName:users(name)')
    .order('createdAt', { ascending: false });

  if (filters.dateFrom) query = query.gte('createdAt', filters.dateFrom);
  if (filters.dateTo) query = query.lte('createdAt', filters.dateTo);
  if (filters.state) query = query.eq('location->>state', filters.state);
  if (filters.constituency) query = query.ilike('constituency', `%${filters.constituency}%`);
  if (filters.candidateName) query = query.ilike('name', `%${filters.candidateName}%`);

  const { data, error } = await query;

  if (error) {
    console.error("Error fetching leaders for admin:", error);
    return [];
  }
  
  return data.map(leader => ({
      ...leader,
      userName: (leader.userName as any)?.name ?? 'Admin/System',
      previousElections: leader.previousElections || []
  }));
}

export async function approveLeader(leaderId: string): Promise<void> {
    await updateLeaderStatus(leaderId, 'approved', 'Approved by admin.');
}

export async function updateLeaderStatus(leaderId: string, status: 'pending' | 'approved' | 'rejected', adminComment: string | null): Promise<void> {
  const { error } = await supabaseAdmin
    .from('leaders')
    .update({ status, adminComment })
    .eq('id', leaderId);
    
  if (error) {
      console.error("Error updating leader status:", error);
      throw error;
  }
}

export async function deleteLeader(leaderId: string): Promise<void> {
    const { error } = await supabaseAdmin
        .from('leaders')
        .delete()
        .eq('id', leaderId);
        
    if (error) {
        console.error("Error deleting leader:", error);
        throw error;
    }
}

export async function deleteRating(userId: string, leaderId: string): Promise<void> {
    const { error } = await supabaseAdmin.rpc('handle_rating_deletion', {
        p_user_id: userId,
        p_leader_id: leaderId
    });

    if (error) {
        console.error("Error deleting rating via RPC:", error);
        throw error;
    }
}
