
'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export interface SiteSettings {
    maintenance_active: 'true' | 'false';
    maintenance_start: string | null;
    maintenance_end: string | null;
    maintenance_message: string | null;
    contact_email: string | null;
    contact_phone: string | null;
    contact_twitter: string | null;
    contact_linkedin: string | null;
    contact_youtube: string | null;
    contact_facebook: string | null;
}

const defaultSettings: SiteSettings = {
    maintenance_active: 'false',
    maintenance_start: null,
    maintenance_end: null,
    maintenance_message: 'The site is currently down for maintenance. We will be back shortly.',
    contact_email: 'support@politirate.com',
    contact_phone: null,
    contact_twitter: null,
    contact_linkedin: null,
    contact_youtube: null,
    contact_facebook: null,
};

export async function getSiteSettings(): Promise<SiteSettings> {
    const { data, error } = await supabase
        .from('site_settings')
        .select('*')
        .eq('id', 1)
        .single();
    
    if (error) {
        console.error("Failed to get site settings, returning defaults.", error);
        return defaultSettings;
    }
    
    return { ...defaultSettings, ...data };
}

export async function updateSiteSettings(settings: Partial<SiteSettings>): Promise<void> {
    const { error } = await supabaseAdmin
        .from('site_settings')
        .update(settings)
        .eq('id', 1);

    if (error) {
        console.error("Failed to update site settings:", error);
        throw new Error("Database transaction for updating settings failed.");
    }
}
