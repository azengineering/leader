'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export type TicketStatus = 'open' | 'in-progress' | 'resolved' | 'closed';
export type TicketPriority = 'low' | 'medium' | 'high' | 'urgent';

export interface SupportTicket {
  id: string;
  user_name: string;
  user_email: string;
  subject: string;
  message: string;
  status: TicketStatus;
  priority: TicketPriority;
  admin_notes: string | null;
  resolved_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateTicketData {
  user_name: string;
  user_email: string;
  subject: string;
  message: string;
  priority?: TicketPriority;
}

export interface SupportTicketStats {
  total: number;
  open: number;
  inProgress: number;
  resolved: number;
  closed: number;
  avgResolutionHours: number | null;
  avgResponseTimeHours: number | null;
}

export interface GetTicketsOptions {
  status?: TicketStatus;
  searchQuery?: string;
  limit?: number;
  offset?: number;
}

export async function getSupportTickets(options: GetTicketsOptions = {}): Promise<SupportTicket[]> {
  try {
    let query = supabaseAdmin
      .from('support_tickets')
      .select('*');

    if (options.status) {
      query = query.eq('status', options.status);
    }

    if (options.searchQuery?.trim()) {
      const searchTerm = `%${options.searchQuery.trim()}%`;
      query = query.or(`user_name.ilike.${searchTerm},user_email.ilike.${searchTerm},subject.ilike.${searchTerm}`);
    }

    query = query.order('created_at', { ascending: false });

    if (options.limit) {
      query = query.limit(options.limit);
    }

    if (options.offset) {
      query = query.range(options.offset, options.offset + (options.limit || 50) - 1);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching support tickets:', error);
      throw new Error(`Failed to fetch support tickets: ${error.message}`);
    }

    return data || [];
  } catch (error) {
    console.error('Error in getSupportTickets:', error);
    throw new Error('Failed to fetch support tickets');
  }
}

export async function getSupportTicketStats(): Promise<SupportTicketStats> {
  try {
    // Use direct query instead of RPC function to avoid type mismatch
    const { data, error } = await supabaseAdmin
      .from('support_tickets')
      .select('status, created_at, resolved_at');

    if (error) {
      console.error('Error fetching ticket stats:', error);
      throw new Error(`Failed to fetch ticket statistics: ${error.message}`);
    }

    const tickets = data || [];
    const total = tickets.length;
    const open = tickets.filter(t => t.status === 'open').length;
    const in_progress = tickets.filter(t => t.status === 'in-progress').length;
    const resolved = tickets.filter(t => t.status === 'resolved').length;
    const closed = tickets.filter(t => t.status === 'closed').length;

    // Calculate average resolution time
    const resolvedTickets = tickets.filter(t => t.resolved_at);
    const avg_resolution_hours = resolvedTickets.length > 0 
      ? resolvedTickets.reduce((sum, ticket) => {
          const created = new Date(ticket.created_at);
          const resolved = new Date(ticket.resolved_at);
          return sum + (resolved.getTime() - created.getTime()) / (1000 * 60 * 60);
        }, 0) / resolvedTickets.length
      : 0;

    return {
      total,
      open,
      inProgress: in_progress,
      resolved,
      closed,
      avgResolutionHours: avg_resolution_hours,
      avgResponseTimeHours: null,
    };
  } catch (error) {
    console.error('Error in getSupportTicketStats:', error);
    throw new Error('Failed to fetch ticket statistics');
  }
}

export async function createSupportTicket(ticketData: CreateTicketData): Promise<SupportTicket> {
  try {
    // Validate required fields
    if (!ticketData.user_name?.trim()) {
      throw new Error('Name is required');
    }
    if (!ticketData.user_email?.trim()) {
      throw new Error('Email is required');
    }
    if (!ticketData.subject?.trim()) {
      throw new Error('Subject is required');
    }
    if (!ticketData.message?.trim()) {
      throw new Error('Message is required');
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(ticketData.user_email)) {
      throw new Error('Invalid email format');
    }

    const { data, error } = await supabaseAdmin
      .from('support_tickets')
      .insert({
        user_name: ticketData.user_name.trim(),
        user_email: ticketData.user_email.trim().toLowerCase(),
        subject: ticketData.subject.trim(),
        message: ticketData.message.trim(),
        priority: ticketData.priority || 'medium',
        status: 'open',
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating support ticket:', error);
      throw new Error(`Failed to create support ticket: ${error.message}`);
    }

    return data;
  } catch (error) {
    console.error('Error in createSupportTicket:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to create support ticket');
  }
}

export async function updateTicketStatus(
  ticketId: string, 
  status: TicketStatus, 
  adminNotes?: string
): Promise<void> {
  try {
    if (!ticketId) {
      throw new Error('Ticket ID is required');
    }

    const updateData: any = {
      status,
      updated_at: new Date().toISOString(),
    };

    if (adminNotes !== undefined) {
      updateData.admin_notes = adminNotes.trim() || null;
    }

    if (status === 'resolved' || status === 'closed') {
      updateData.resolved_at = new Date().toISOString();
    }

    const { error } = await supabaseAdmin
      .from('support_tickets')
      .update(updateData)
      .eq('id', ticketId);

    if (error) {
      console.error('Error updating ticket status:', error);
      throw new Error(`Failed to update ticket status: ${error.message}`);
    }
  } catch (error) {
    console.error('Error in updateTicketStatus:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to update ticket status');
  }
}

export async function deleteTicket(ticketId: string): Promise<void> {
  try {
    if (!ticketId) {
      throw new Error('Ticket ID is required');
    }

    const { error } = await supabaseAdmin
      .from('support_tickets')
      .delete()
      .eq('id', ticketId);

    if (error) {
      console.error('Error deleting ticket:', error);
      throw new Error(`Failed to delete ticket: ${error.message}`);
    }
  } catch (error) {
    console.error('Error in deleteTicket:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to delete ticket');
  }
}