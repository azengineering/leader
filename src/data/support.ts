
'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export type TicketStatus = 'open' | 'in-progress' | 'resolved' | 'closed';

export interface SupportTicket {
    id: string;
    user_id: string | null;
    user_name: string;
    user_email: string;
    subject: string;
    message: string;
    status: TicketStatus;
    created_at: string;
    updated_at: string;
    resolved_at: string | null;
    admin_notes: string | null;
}

export interface SupportTicketStats {
    total: number;
    open: number;
    inProgress: number;
    resolved: number;
    closed: number;
    avgResolutionHours: number | null;
}


export async function createSupportTicket(data: Omit<SupportTicket, 'id' | 'status' | 'created_at' | 'resolved_at' | 'admin_notes' | 'updated_at'>): Promise<void> {
    const { error } = await supabase.from('support_tickets').insert({
        ...data,
        status: 'open',
    });
    
    if (error) {
        console.error("Error creating support ticket:", error);
        throw error;
    }
}

export async function getSupportTickets(filters: { status?: TicketStatus, dateFrom?: string, dateTo?: string, searchQuery?: string } = {}): Promise<SupportTicket[]> {
    let query = supabaseAdmin.from('support_tickets').select('*');

    if (filters.status) {
        query = query.eq('status', filters.status);
    }
    if (filters.dateFrom) {
        query = query.gte('created_at', filters.dateFrom);
    }
    if (filters.dateTo) {
        query = query.lte('created_at', filters.dateTo);
    }
    if (filters.searchQuery) {
        const searchTerm = `%${filters.searchQuery}%`;
        query = query.or(`user_name.ilike.${searchTerm},user_email.ilike.${searchTerm},subject.ilike.${searchTerm}`);
    }

    const { data, error } = await query.order('updated_at', { ascending: false });

    if (error) {
        console.error("Error fetching support tickets:", error);
        return [];
    }
    return data;
}

export async function updateTicketStatus(ticketId: string, status: TicketStatus, adminNotes: string | null): Promise<void> {
    const { error } = await supabaseAdmin
        .from('support_tickets')
        .update({
            status: status,
            admin_notes: adminNotes,
            resolved_at: (status === 'resolved' || status === 'closed') ? new Date().toISOString() : null,
            updated_at: new Date().toISOString(),
        })
        .eq('id', ticketId);

    if (error) {
        console.error("Error updating ticket status:", error);
        throw error;
    }
}

export async function getSupportTicketStats(): Promise<SupportTicketStats> {
    const { data, error } = await supabaseAdmin.rpc('get_ticket_stats');

    if (error) {
        console.error("Error fetching ticket stats:", error);
        throw error;
    }

    return {
        total: data[0].total,
        open: data[0].open,
        inProgress: data[0].in_progress,
        resolved: data[0].resolved,
        closed: data[0].closed,
        avgResolutionHours: data[0].avg_resolution_hours,
    }
}
