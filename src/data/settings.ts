'use server';

import { supabase } from '@/lib/db';
import { supabaseAdmin } from '@/lib/supabaseAdmin';

export interface SiteSettings {
  id: number;
  site_title: string;
  site_description: string;
  maintenance_active: boolean;
  maintenance_start: string;
  maintenance_end: string;
  maintenance_message: string;
  contact_email: string;
  contact_phone: string;
  contact_twitter: string;
  contact_linkedin: string;
  contact_youtube: string;
  contact_facebook: string;
  enable_user_registration: boolean;
  enable_public_polls: boolean;
  max_ratings_per_user: number;
  updatedAt: string;
}

export type PartialSiteSettings = {
  [K in keyof Omit<SiteSettings, 'id' | 'updatedAt'>]?: SiteSettings[K];
}

export async function getSiteSettings(): Promise<SiteSettings> {
  try {
    const { data, error } = await supabaseAdmin
      .from('site_settings')
      .select('*')
      .eq('id', 1)
      .single();

    if (error) {
      console.error('Error fetching site settings:', error);
      // Return default settings if none exist
      return {
        id: 1,
        site_title: 'PolitiRate',
        site_description: 'Rate and review political leaders',
        maintenance_active: false,
        maintenance_start: '',
        maintenance_end: '',
        maintenance_message: 'The site is currently down for maintenance. Please check back later.',
        contact_email: '',
        contact_phone: '',
        contact_twitter: '',
        contact_linkedin: '',
        contact_youtube: '',
        contact_facebook: '',
        enable_user_registration: true,
        enable_public_polls: true,
        max_ratings_per_user: 100,
        updated_at: new Date().toISOString(),
      };
    }

    return data;
  } catch (error) {
    console.error('Error in getSiteSettings:', error);
    throw new Error('Failed to fetch site settings');
  }
}

export async function updateSiteSettings(updates: PartialSiteSettings): Promise<void> {
  try {
    // Validate critical fields
    if (updates.contact_email && updates.contact_email !== '') {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(updates.contact_email)) {
        throw new Error('Invalid email format');
      }
    }

    if (updates.maintenance_active !== undefined && typeof updates.maintenance_active !== 'boolean') {
      throw new Error('Invalid maintenance_active value');
    }

    const { error } = await supabaseAdmin
      .from('site_settings')
      .upsert({
        id: 1,
        ...updates,
        updatedAt: new Date().toISOString(),
      }, {
        onConflict: 'id',
      });

    if (error) {
      console.error('Error updating site settings:', error);
      throw new Error(`Failed to update site settings: ${error.message}`);
    }
  } catch (error) {
    console.error('Error in updateSiteSettings:', error);
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Failed to update site settings');
  }
}

export async function initializeSiteSettings(): Promise<void> {
  try {
    const { data: existing } = await supabaseAdmin
      .from('site_settings')
      .select('id')
      .eq('id', 1)
      .single();

    if (!existing) {
      await updateSiteSettings({
        site_title: 'PolitiRate',
        site_description: 'Rate and review political leaders in your constituency',
        maintenance_active: false,
        maintenance_message: 'The site is currently down for maintenance. Please check back later.',
        contact_email: '',
        enable_user_registration: true,
        enable_public_polls: true,
        max_ratings_per_user: 100,
        updated_at: new Date().toISOString(),
      });
    }
  } catch (error) {
    console.error('Error initializing site settings:', error);
    throw new Error('Failed to initialize site settings');
  }
}
```