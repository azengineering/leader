
'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export interface SiteNotification {
  id: string;
  title: string;
  message: string;
  isActive: boolean;
  startTime: string | null;
  endTime: string | null;
  notification_type: 'announcement' | 'alert' | 'info' | 'warning';
  show_banner: boolean;
  link: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateNotificationData {
  message: string;
  isActive: boolean;
  startTime: string | null;
  endTime: string | null;
  title?: string;
  notification_type?: 'announcement' | 'alert' | 'info' | 'warning';
  show_banner?: boolean;
  link?: string | null;
}

export interface UpdateNotificationData extends Partial<CreateNotificationData> {}

export async function getNotifications(): Promise<SiteNotification[]> {
  try {
    const { data, error } = await supabaseAdmin
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching notifications:', error);
      throw new Error(`Failed to fetch notifications: ${error.message}`);
    }

    return data || [];
  } catch (error) {
    console.error('Error in getNotifications:', error);
    throw new Error('Failed to fetch notifications');
  }
}

export async function getActiveNotifications(): Promise<SiteNotification[]> {
  try {
    const now = new Date().toISOString();
    
    const { data, error } = await supabaseAdmin
      .from('notifications')
      .select('*')
      .eq('isActive', true)
      .or(`startTime.is.null,startTime.lte.${now}`)
      .or(`endTime.is.null,endTime.gte.${now}`)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching active notifications:', error);
      throw new Error(`Failed to fetch active notifications: ${error.message}`);
    }

    return data || [];
  } catch (error) {
    console.error('Error in getActiveNotifications:', error);
    return [];
  }
}

export async function addNotification(notificationData: CreateNotificationData): Promise<SiteNotification> {
  try {
    // Validate required fields
    if (!notificationData.message?.trim()) {
      throw new Error('Message is required');
    }

    if (notificationData.startTime && notificationData.endTime) {
      const start = new Date(notificationData.startTime);
      const end = new Date(notificationData.endTime);
      if (start >= end) {
        throw new Error('End time must be after start time');
      }
    }

    const { data, error } = await supabaseAdmin
      .from('notifications')
      .insert({
        title: notificationData.title || 'Site Notification',
        message: notificationData.message.trim(),
        isActive: notificationData.isActive,
        startTime: notificationData.startTime,
        endTime: notificationData.endTime,
        notification_type: notificationData.notification_type || 'announcement',
        show_banner: notificationData.show_banner ?? true,
        link: notificationData.link,
      })
      .select()
      .single();

    if (error) {
      console.error('Error adding notification:', error);
      throw new Error(`Failed to add notification: ${error.message}`);
    }

    return data;
  } catch (error) {
    console.error('Error in addNotification:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to add notification');
  }
}

export async function updateNotification(id: string, updates: UpdateNotificationData): Promise<void> {
  try {
    if (!id) {
      throw new Error('Notification ID is required');
    }

    // Validate updates
    if (updates.message !== undefined && !updates.message?.trim()) {
      throw new Error('Message cannot be empty');
    }

    if (updates.startTime && updates.endTime) {
      const start = new Date(updates.startTime);
      const end = new Date(updates.endTime);
      if (start >= end) {
        throw new Error('End time must be after start time');
      }
    }

    const updateData: any = {
      ...updates,
      updated_at: new Date().toISOString(),
    };

    if (updates.message) {
      updateData.message = updates.message.trim();
    }

    const { error } = await supabaseAdmin
      .from('notifications')
      .update(updateData)
      .eq('id', id);

    if (error) {
      console.error('Error updating notification:', error);
      throw new Error(`Failed to update notification: ${error.message}`);
    }
  } catch (error) {
    console.error('Error in updateNotification:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to update notification');
  }
}

export async function deleteNotification(id: string): Promise<void> {
  try {
    if (!id) {
      throw new Error('Notification ID is required');
    }

    const { error } = await supabaseAdmin
      .from('notifications')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting notification:', error);
      throw new Error(`Failed to delete notification: ${error.message}`);
    }
  } catch (error) {
    console.error('Error in deleteNotification:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to delete notification');
  }
}
