
'use server';

import { supabase } from '@/lib/db';

export interface SiteNotification {
    id: string;
    message: string;
    startTime: string | null;
    endTime: string | null;
    isActive: boolean;
    createdAt: string;
    link: string | null;
}

export async function getNotifications(): Promise<SiteNotification[]> {
    const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .order('created_at', { ascending: false });
        
    if (error) {
        console.error("Error getting notifications:", error);
        return [];
    }
    return data;
}

export async function getActiveNotifications(): Promise<SiteNotification[]> {
    const now = new Date().toISOString();
    const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('isActive', true)
        .or(`startTime.is.null,startTime.lte.${now}`)
        .or(`endTime.is.null,endTime.gte.${now}`)
        .order('created_at', { ascending: false });

    if (error) {
        console.error("Error getting active notifications:", error);
        return [];
    }
    return data;
}

type NotificationPayload = Omit<SiteNotification, 'id' | 'createdAt'>;

export async function addNotification(data: NotificationPayload): Promise<SiteNotification> {
    const { data: newNotification, error } = await supabase
        .from('notifications')
        .insert(data)
        .select()
        .single();

    if (error) {
        console.error("Error adding notification:", error);
        throw error;
    }
    return newNotification;
}

export async function updateNotification(id: string, data: NotificationPayload): Promise<SiteNotification> {
    const { data: updatedNotification, error } = await supabase
        .from('notifications')
        .update(data)
        .eq('id', id)
        .select()
        .single();

    if (error) {
        console.error("Error updating notification:", error);
        throw error;
    }
    return updatedNotification;
}

export async function deleteNotification(id: string): Promise<void> {
    const { error } = await supabase
        .from('notifications')
        .delete()
        .eq('id', id);

    if (error) {
        console.error("Error deleting notification:", error);
        throw error;
    }
}
