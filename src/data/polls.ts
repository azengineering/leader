
'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export type PollQuestionType = 'yes_no' | 'multiple_choice';

export interface PollOption {
  id: string;
  question_id: string;
  option_text: string;
  option_order: number;
}

export interface PollQuestion {
  id: string;
  poll_id: string;
  question_text: string;
  question_type: PollQuestionType;
  question_order: number;
  options: PollOption[];
}

export interface Poll {
  id: string;
  title: string;
  description: string | null;
  is_active: boolean;
  active_until: string | null;
  created_at: string;
  questions: PollQuestion[];
}

export interface PollListItem {
    id: string;
    title: string;
    is_active: boolean;
    active_until: string | null;
    created_at: string;
    response_count: number;
    is_promoted?: boolean;
}

export interface PollForParticipation extends Poll {
    user_has_voted: boolean;
}

export interface PollAnswer {
    questionId: string;
    optionId: string;
}

export interface PollResult {
    pollTitle: string;
    totalResponses: number;
    genderDistribution: { name: string; value: number }[];
    questions: {
        id: string;
        text: string;
        answers: { name: string; value: number }[];
    }[];
}


// --- Admin Panel Functions ---

export async function getPollsForAdmin(): Promise<PollListItem[]> {
    const { data, error } = await supabaseAdmin.rpc('get_admin_polls');
    if (error) {
        console.error("Error getting polls for admin:", error);
        return [];
    }
    return data;
}

export async function getPollForEdit(pollId: string): Promise<Poll | null> {
    const { data, error } = await supabaseAdmin
        .from('polls')
        .select(`
            *,
            questions:poll_questions (
                *,
                options:poll_options (*)
            )
        `)
        .eq('id', pollId)
        .single();
    
    if (error) {
        console.error("Error getting poll for edit:", error);
        return null;
    }
    return data;
}

export async function deletePoll(pollId: string): Promise<void> {
    const { error } = await supabaseAdmin.from('polls').delete().eq('id', pollId);
    if (error) {
        console.error("Error deleting poll:", error);
        throw error;
    }
}

export async function upsertPoll(poll: Omit<Poll, 'created_at'>): Promise<Poll> {
    const { data, error } = await supabaseAdmin.rpc('upsert_poll', { poll_data: poll });
    if (error) {
        console.error("Error upserting poll:", error);
        throw error;
    }
    const newPoll = await getPollForEdit(data);
    return newPoll!;
}

export async function getPollResults(pollId: string): Promise<PollResult | null> {
    const { data, error } = await supabaseAdmin.rpc('get_poll_results', { p_poll_id: pollId });
    if (error) {
        console.error("Error getting poll results:", error);
        return null;
    }
    return data;
}


// --- User Facing Functions ---

export async function getActivePollsForUser(userId: string | null): Promise<(PollListItem & { user_has_voted: boolean; description: string | null; })[]> {
    const { data, error } = await supabase.rpc('get_active_polls_for_user', { p_user_id: userId });
    if (error) {
        console.error("Error getting active polls:", error);
        return [];
    }
    return data;
}

export async function getPollForParticipation(pollId: string, userId: string | null): Promise<PollForParticipation | null> {
    const { data: poll, error } = await supabase
        .from('polls')
        .select(`
            *,
            questions:poll_questions (
                *,
                options:poll_options (*)
            )
        `)
        .eq('id', pollId)
        .single();

    if (error || !poll) {
        console.error("Error getting poll for participation:", error);
        return null;
    }

    let hasVoted = false;
    if (userId) {
        const { data, error: voteError } = await supabase
            .from('poll_responses')
            .select('id', { count: 'exact', head: true })
            .eq('poll_id', pollId)
            .eq('user_id', userId);
            
        if (voteError) console.error("Error checking if user voted:", voteError);
        hasVoted = (data?.length ?? 0) > 0;
    }

    return { ...poll, user_has_voted: hasVoted };
}

export async function submitPollResponse(pollId: string, userId: string, answers: PollAnswer[]): Promise<void> {
    const { error } = await supabase.rpc('submit_poll_response', {
        p_poll_id: pollId,
        p_user_id: userId,
        p_answers: answers
    });

    if (error) {
        console.error("Error submitting poll response:", error);
        throw new Error(error.message);
    }
}
