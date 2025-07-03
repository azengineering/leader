-- =============================================
-- Politirate Database Schema - Complete Version
-- =============================================

-- =============================================
-- 1. Create Custom Types
-- =============================================

-- Create enum for leader status
DO $$ BEGIN
    CREATE TYPE leader_status AS ENUM ('pending', 'approved', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create enum for user roles
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('user', 'admin', 'super_admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- =============================================
-- 2. Core Tables
-- =============================================

-- Profiles table (extends auth.users)
CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" uuid NOT NULL PRIMARY KEY REFERENCES "auth"."users"("id") ON DELETE CASCADE,
    "name" text NOT NULL DEFAULT '',
    "location" text,
    "isBlocked" boolean NOT NULL DEFAULT false,
    "blockReason" text,
    "blockedUntil" timestamptz,
    "role" user_role NOT NULL DEFAULT 'user',
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "updatedAt" timestamptz NOT NULL DEFAULT now()
);

-- Leaders table
CREATE TABLE IF NOT EXISTS "public"."leaders" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "name" text NOT NULL,
    "party" text NOT NULL,
    "constituency" text NOT NULL,
    "state" text NOT NULL,
    "manifesto" text,
    "previousElections" jsonb DEFAULT '[]'::jsonb,
    "currentOffice" text,
    "status" leader_status NOT NULL DEFAULT 'pending',
    "adminComment" text,
    "addedByUserId" uuid REFERENCES "public"."profiles"("id") ON DELETE SET NULL,
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "updatedAt" timestamptz NOT NULL DEFAULT now()
);

-- Ratings table
CREATE TABLE IF NOT EXISTS "public"."ratings" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "userId" uuid NOT NULL REFERENCES "public"."profiles"("id") ON DELETE CASCADE,
    "leaderId" uuid NOT NULL REFERENCES "public"."leaders"("id") ON DELETE CASCADE,
    "rating" integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
    "review" text,
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "updatedAt" timestamptz NOT NULL DEFAULT now(),
    UNIQUE("userId", "leaderId")
);

-- Admin messages table
CREATE TABLE IF NOT EXISTS "public"."admin_messages" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "userId" uuid NOT NULL REFERENCES "public"."profiles"("id") ON DELETE CASCADE,
    "message" text NOT NULL,
    "isRead" boolean NOT NULL DEFAULT false,
    "createdAt" timestamptz NOT NULL DEFAULT now()
);

-- Site settings table
CREATE TABLE IF NOT EXISTS "public"."site_settings" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "maintenanceMode" boolean NOT NULL DEFAULT false,
    "maintenanceMessage" text DEFAULT 'We are currently performing maintenance. Please check back later.',
    "updatedAt" timestamptz NOT NULL DEFAULT now()
);

-- Notifications table
CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "title" text NOT NULL,
    "message" text NOT NULL,
    "isActive" boolean NOT NULL DEFAULT true,
    "startTime" timestamptz NOT NULL DEFAULT now(),
    "endTime" timestamptz,
    "createdAt" timestamptz NOT NULL DEFAULT now()
);

-- Polls table
CREATE TABLE IF NOT EXISTS "public"."polls" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "title" text NOT NULL,
    "description" text,
    "options" jsonb NOT NULL,
    "votes" jsonb NOT NULL DEFAULT '{}'::jsonb,
    "isActive" boolean NOT NULL DEFAULT true,
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "endDate" timestamptz
);

-- Contact messages table
CREATE TABLE IF NOT EXISTS "public"."contact_messages" (
    "id" uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    "name" text NOT NULL,
    "email" text NOT NULL,
    "subject" text NOT NULL,
    "message" text NOT NULL,
    "isRead" boolean NOT NULL DEFAULT false,
    "createdAt" timestamptz NOT NULL DEFAULT now()
);

-- =============================================
-- 3. Indexes for Performance
-- =============================================

CREATE INDEX IF NOT EXISTS "idx_leaders_status" ON "public"."leaders"("status");
CREATE INDEX IF NOT EXISTS "idx_leaders_state" ON "public"."leaders"("state");
CREATE INDEX IF NOT EXISTS "idx_leaders_constituency" ON "public"."leaders"("constituency");
CREATE INDEX IF NOT EXISTS "idx_leaders_created_at" ON "public"."leaders"("createdAt");
CREATE INDEX IF NOT EXISTS "idx_ratings_leader_id" ON "public"."ratings"("leaderId");
CREATE INDEX IF NOT EXISTS "idx_ratings_user_id" ON "public"."ratings"("userId");
CREATE INDEX IF NOT EXISTS "idx_ratings_created_at" ON "public"."ratings"("createdAt");
CREATE INDEX IF NOT EXISTS "idx_profiles_role" ON "public"."profiles"("role");
CREATE INDEX IF NOT EXISTS "idx_profiles_blocked" ON "public"."profiles"("isBlocked");
CREATE INDEX IF NOT EXISTS "idx_admin_messages_user_read" ON "public"."admin_messages"("userId", "isRead");
CREATE INDEX IF NOT EXISTS "idx_notifications_active" ON "public"."notifications"("isActive");
CREATE INDEX IF NOT EXISTS "idx_contact_messages_read" ON "public"."contact_messages"("isRead");

-- =============================================
-- 4. Row Level Security Policies
-- =============================================

-- Enable RLS on all tables
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."leaders" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."ratings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."admin_messages" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."site_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."polls" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "public"."contact_messages" ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles" ON "public"."profiles" FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can update any profile" ON "public"."profiles" FOR UPDATE USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Leaders policies
CREATE POLICY "Anyone can view approved leaders" ON "public"."leaders" FOR SELECT USING (status = 'approved');
CREATE POLICY "Authenticated users can add leaders" ON "public"."leaders" FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users can update own pending leaders" ON "public"."leaders" FOR UPDATE USING (
    addedByUserId = auth.uid() AND status = 'pending'
);
CREATE POLICY "Admins can view all leaders" ON "public"."leaders" FOR SELECT USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can update all leaders" ON "public"."leaders" FOR UPDATE USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can delete leaders" ON "public"."leaders" FOR DELETE USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Ratings policies
CREATE POLICY "Anyone can view ratings" ON "public"."ratings" FOR SELECT USING (true);
CREATE POLICY "Authenticated users can add ratings" ON "public"."ratings" FOR INSERT WITH CHECK (auth.uid() = userId);
CREATE POLICY "Users can update own ratings" ON "public"."ratings" FOR UPDATE USING (auth.uid() = userId);
CREATE POLICY "Users can delete own ratings" ON "public"."ratings" FOR DELETE USING (auth.uid() = userId);
CREATE POLICY "Admins can delete any ratings" ON "public"."ratings" FOR DELETE USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Admin messages policies
CREATE POLICY "Users can view own messages" ON "public"."admin_messages" FOR SELECT USING (auth.uid() = userId);
CREATE POLICY "Users can update own messages" ON "public"."admin_messages" FOR UPDATE USING (auth.uid() = userId);
CREATE POLICY "Admins can view all messages" ON "public"."admin_messages" FOR SELECT USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can insert messages" ON "public"."admin_messages" FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Site settings policies
CREATE POLICY "Anyone can view site settings" ON "public"."site_settings" FOR SELECT USING (true);
CREATE POLICY "Admins can update site settings" ON "public"."site_settings" FOR ALL USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Notifications policies
CREATE POLICY "Anyone can view active notifications" ON "public"."notifications" FOR SELECT USING (isActive = true);
CREATE POLICY "Admins can view all notifications" ON "public"."notifications" FOR SELECT USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage notifications" ON "public"."notifications" FOR ALL USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Polls policies
CREATE POLICY "Anyone can view active polls" ON "public"."polls" FOR SELECT USING (isActive = true);
CREATE POLICY "Admins can view all polls" ON "public"."polls" FOR SELECT USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage polls" ON "public"."polls" FOR ALL USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Contact messages policies
CREATE POLICY "Admins can view contact messages" ON "public"."contact_messages" FOR SELECT USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can update contact messages" ON "public"."contact_messages" FOR UPDATE USING (
    EXISTS (SELECT 1 FROM "public"."profiles" WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Anyone can insert contact messages" ON "public"."contact_messages" FOR INSERT WITH CHECK (true);

-- =============================================
-- 5. Functions and Triggers
-- =============================================

-- Function to ensure a user profile exists
CREATE OR REPLACE FUNCTION ensure_user_profile_exists()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  SELECT auth.uid(), COALESCE(auth.jwt() ->> 'user_metadata' ->> 'name', split_part(auth.jwt() ->> 'email', '@', 1))
  WHERE auth.uid() IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid());
END;
$$;

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'name', split_part(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$;

-- Function to handle rating deletion and update leader stats
CREATE OR REPLACE FUNCTION handle_rating_deletion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Rating deletion is handled by the trigger automatically
  -- This function can be extended for additional cleanup if needed
  RETURN OLD;
END;
$$;

-- RPC function for handling rating deletion (admin use)
CREATE OR REPLACE FUNCTION handle_rating_deletion(p_user_id uuid, p_leader_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.ratings 
  WHERE "userId" = p_user_id AND "leaderId" = p_leader_id;
END;
$$;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin(user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = user_id AND role IN ('admin', 'super_admin')
  );
END;
$$;

-- Trigger to automatically create profile on user signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Trigger for rating deletion cleanup
DROP TRIGGER IF EXISTS on_rating_deleted ON public.ratings;
CREATE TRIGGER on_rating_deleted
  AFTER DELETE ON public.ratings
  FOR EACH ROW EXECUTE FUNCTION handle_rating_deletion();

-- =============================================
-- 6. Initial Data
-- =============================================

-- Insert default site settings
INSERT INTO "public"."site_settings" (maintenanceMode, maintenanceMessage)
VALUES (false, 'We are currently performing maintenance. Please check back later.')
ON CONFLICT DO NOTHING;

-- Create a default admin user (update this with your actual admin email)
-- Note: This will only work if the user already exists in auth.users
DO $$
BEGIN
    -- Update any existing user with admin email to admin role
    -- Replace 'admin@example.com' with your actual admin email
    UPDATE public.profiles 
    SET role = 'super_admin' 
    WHERE id IN (
        SELECT id FROM auth.users 
        WHERE email = 'admin@example.com'
    );
END $$;

-- =============================================
-- 7. Additional Grants (if needed)
-- =============================================

-- Grant necessary permissions to authenticated users
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- Grant permissions to service_role for admin operations
GRANT ALL ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;