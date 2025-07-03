
-- =============================================
-- PolitiRate Database Schema - Complete Version
-- =============================================

-- =============================================
-- 1. Drop existing tables and recreate (if needed)
-- =============================================

-- Drop existing functions first to avoid conflicts
DROP FUNCTION IF EXISTS public.handle_new_rating(uuid,uuid,integer,text,text) CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_rating(uuid,uuid,integer,text,public.citext) CASCADE;
DROP FUNCTION IF EXISTS public.handle_rating_deletion(uuid,uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_reviews_for_leader(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_user_activities(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_all_activities() CASCADE;
DROP FUNCTION IF EXISTS public.update_leader_rating() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.is_admin(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.get_admin_polls() CASCADE;
DROP FUNCTION IF EXISTS public.get_active_polls_for_user(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.submit_poll_response(uuid,uuid,jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.get_ticket_stats() CASCADE;
DROP FUNCTION IF EXISTS public.create_admin_user(text) CASCADE;
DROP FUNCTION IF EXISTS public.ensure_user_profile_exists() CASCADE;

-- First, let's make sure we have clean slate
DROP TABLE IF EXISTS public.contact_messages CASCADE;
DROP TABLE IF EXISTS public.support_tickets CASCADE;
DROP TABLE IF EXISTS public.poll_responses CASCADE;
DROP TABLE IF EXISTS public.poll_options CASCADE;
DROP TABLE IF EXISTS public.poll_questions CASCADE;
DROP TABLE IF EXISTS public.polls CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.site_settings CASCADE;
DROP TABLE IF EXISTS public.admin_messages CASCADE;
DROP TABLE IF EXISTS public.ratings CASCADE;
DROP TABLE IF EXISTS public.leaders CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- Drop custom types if they exist
DROP TYPE IF EXISTS public.ticket_status CASCADE;
DROP TYPE IF EXISTS public.poll_question_type CASCADE;
DROP TYPE IF EXISTS public.leader_status CASCADE;
DROP TYPE IF EXISTS public.user_role CASCADE;

-- =============================================
-- 2. Create Custom Types & Extensions
-- =============================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create enum for leader status
CREATE TYPE public.leader_status AS ENUM ('pending', 'approved', 'rejected');

-- Create enum for user roles
CREATE TYPE public.user_role AS ENUM ('user', 'admin', 'super_admin');

-- Create enum for ticket status
CREATE TYPE public.ticket_status AS ENUM ('open', 'in-progress', 'resolved', 'closed');

-- Create enum for poll question types
CREATE TYPE public.poll_question_type AS ENUM ('yes_no', 'multiple_choice');

-- =============================================
-- 3. Core Tables
-- =============================================

-- Users table (extends auth.users)
CREATE TABLE public.users (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text NOT NULL,
    name text DEFAULT '',
    gender text,
    age integer,
    state text,
    "mpConstituency" text,
    "mlaConstituency" text,
    panchayat text,
    location text,
    "isBlocked" boolean NOT NULL DEFAULT false,
    "blockedUntil" timestamptz,
    "blockReason" text,
    role user_role NOT NULL DEFAULT 'user',
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "updatedAt" timestamptz NOT NULL DEFAULT now()
);

-- Leaders table
CREATE TABLE public.leaders (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    "partyName" text NOT NULL,
    gender text NOT NULL,
    age integer NOT NULL,
    "photoUrl" text,
    constituency text NOT NULL,
    "nativeAddress" text,
    "electionType" text NOT NULL,
    location jsonb,
    rating double precision DEFAULT 0 NOT NULL,
    "reviewCount" integer DEFAULT 0 NOT NULL,
    "previousElections" jsonb DEFAULT '[]'::jsonb,
    "manifestoUrl" text,
    "twitterUrl" text,
    "addedByUserId" uuid REFERENCES public.users(id) ON DELETE SET NULL,
    status leader_status NOT NULL DEFAULT 'pending',
    "adminComment" text,
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "updatedAt" timestamptz NOT NULL DEFAULT now()
);

-- Ratings table
CREATE TABLE public.ratings (
    "leaderId" uuid NOT NULL REFERENCES public.leaders(id) ON DELETE CASCADE,
    "userId" uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment text,
    "socialBehaviour" text,
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    "updatedAt" timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY ("leaderId", "userId")
);

-- Admin messages table
CREATE TABLE public.admin_messages (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message text NOT NULL,
    is_read boolean NOT NULL DEFAULT false,
    "createdAt" timestamptz NOT NULL DEFAULT now()
);

-- Site settings table
CREATE TABLE public.site_settings (
    id text NOT NULL PRIMARY KEY DEFAULT 'main',
    maintenance_active boolean NOT NULL DEFAULT false,
    maintenance_start timestamptz,
    maintenance_end timestamptz,
    maintenance_message text DEFAULT 'We are currently performing maintenance. Please check back later.',
    contact_email text,
    contact_phone text,
    contact_twitter text,
    contact_linkedin text,
    contact_youtube text,
    contact_facebook text,
    "updatedAt" timestamptz NOT NULL DEFAULT now()
);

-- Notifications table
CREATE TABLE public.notifications (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    message text NOT NULL,
    "startTime" timestamptz NOT NULL DEFAULT now(),
    "endTime" timestamptz,
    "isActive" boolean NOT NULL DEFAULT true,
    "createdAt" timestamptz NOT NULL DEFAULT now(),
    link text
);

-- Polls table
CREATE TABLE public.polls (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT false,
    active_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Poll questions table
CREATE TABLE public.poll_questions (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    question_text text NOT NULL,
    question_type poll_question_type NOT NULL,
    question_order integer NOT NULL
);

-- Poll options table
CREATE TABLE public.poll_options (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES public.poll_questions(id) ON DELETE CASCADE,
    option_text text NOT NULL,
    option_order integer NOT NULL,
    vote_count integer NOT NULL DEFAULT 0
);

-- Poll responses table
CREATE TABLE public.poll_responses (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    answers jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(poll_id, user_id)
);

-- Support tickets table
CREATE TABLE public.support_tickets (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    user_name text NOT NULL,
    user_email text NOT NULL,
    subject text NOT NULL,
    message text NOT NULL,
    status ticket_status NOT NULL DEFAULT 'open',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    admin_notes text
);

-- Contact messages table
CREATE TABLE public.contact_messages (
    id uuid NOT NULL PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    email text NOT NULL,
    subject text NOT NULL,
    message text NOT NULL,
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================
-- 4. Indexes for Performance
-- =============================================

CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_role ON public.users(role);
CREATE INDEX idx_users_blocked ON public.users("isBlocked");
CREATE INDEX idx_users_state ON public.users(state);

CREATE INDEX idx_leaders_status ON public.leaders(status);
CREATE INDEX idx_leaders_constituency ON public.leaders(constituency);
CREATE INDEX idx_leaders_election_type ON public.leaders("electionType");
CREATE INDEX idx_leaders_added_by ON public.leaders("addedByUserId");
CREATE INDEX idx_leaders_rating ON public.leaders(rating);
CREATE INDEX idx_leaders_created_at ON public.leaders("createdAt");

CREATE INDEX idx_ratings_leader_id ON public.ratings("leaderId");
CREATE INDEX idx_ratings_user_id ON public.ratings("userId");
CREATE INDEX idx_ratings_created_at ON public.ratings("createdAt");

CREATE INDEX idx_admin_messages_user_read ON public.admin_messages(user_id, is_read);
CREATE INDEX idx_notifications_active ON public.notifications("isActive");
CREATE INDEX idx_notifications_time ON public.notifications("startTime", "endTime");

CREATE INDEX idx_polls_active ON public.polls(is_active);
CREATE INDEX idx_poll_questions_poll_id ON public.poll_questions(poll_id);
CREATE INDEX idx_poll_options_question_id ON public.poll_options(question_id);
CREATE INDEX idx_poll_responses_poll_user ON public.poll_responses(poll_id, user_id);

CREATE INDEX idx_support_tickets_status ON public.support_tickets(status);
CREATE INDEX idx_support_tickets_user_id ON public.support_tickets(user_id);
CREATE INDEX idx_contact_messages_read ON public.contact_messages(is_read);

-- =============================================
-- 5. Functions and Triggers
-- =============================================

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.users (id, email, name)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
END;
$$;

-- Function to update leader rating
CREATE OR REPLACE FUNCTION public.update_leader_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE public.leaders
        SET
            "reviewCount" = (SELECT COUNT(*) FROM public.ratings WHERE "leaderId" = OLD."leaderId"),
            rating = COALESCE((SELECT AVG(rating) FROM public.ratings WHERE "leaderId" = OLD."leaderId"), 0)
        WHERE id = OLD."leaderId";
        RETURN OLD;
    ELSE
        UPDATE public.leaders
        SET
            "reviewCount" = (SELECT COUNT(*) FROM public.ratings WHERE "leaderId" = NEW."leaderId"),
            rating = COALESCE((SELECT AVG(rating) FROM public.ratings WHERE "leaderId" = NEW."leaderId"), 0)
        WHERE id = NEW."leaderId";
        RETURN NEW;
    END IF;
END;
$$;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = user_id AND role IN ('admin', 'super_admin')
    );
END;
$$;

-- Function to ensure user profile exists
CREATE OR REPLACE FUNCTION public.ensure_user_profile_exists()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_user_email text;
    v_user_name text;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE id = v_user_id) THEN
        -- Get email and name from auth.users
        SELECT email, raw_user_meta_data->>'name'
        INTO v_user_email, v_user_name
        FROM auth.users
        WHERE id = v_user_id;

        -- Insert into public.users
        INSERT INTO public.users (id, email, name)
        VALUES (v_user_id, v_user_email, v_user_name);
    END IF;
END;
$$;

-- RPC function for handling ratings
CREATE OR REPLACE FUNCTION public.handle_new_rating(
    p_leader_id uuid, 
    p_user_id uuid, 
    p_rating integer, 
    p_comment text, 
    p_social_behaviour text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.ratings ("leaderId", "userId", rating, comment, "socialBehaviour", "updatedAt")
    VALUES (p_leader_id, p_user_id, p_rating, p_comment, p_social_behaviour, now())
    ON CONFLICT ("leaderId", "userId")
    DO UPDATE SET
        rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        "socialBehaviour" = EXCLUDED."socialBehaviour",
        "updatedAt" = now();
END;
$$;

-- RPC function for deleting ratings
CREATE OR REPLACE FUNCTION public.handle_rating_deletion(
    p_user_id uuid, 
    p_leader_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.ratings
    WHERE "userId" = p_user_id AND "leaderId" = p_leader_id;
END;
$$;

-- RPC function to get reviews for a leader
CREATE OR REPLACE FUNCTION public.get_reviews_for_leader(p_leader_id uuid)
RETURNS TABLE(
    "userName" text, 
    rating integer, 
    comment text, 
    "updatedAt" timestamptz, 
    "socialBehaviour" text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.name AS "userName",
        r.rating,
        r.comment,
        r."updatedAt",
        r."socialBehaviour"
    FROM public.ratings r
    JOIN public.users u ON r."userId" = u.id
    WHERE r."leaderId" = p_leader_id
    ORDER BY r."updatedAt" DESC;
END;
$$;

-- RPC function to get user activities
CREATE OR REPLACE FUNCTION public.get_user_activities(p_user_id uuid)
RETURNS TABLE(
    "leaderId" uuid, 
    "leaderName" text, 
    "leaderPhotoUrl" text, 
    rating integer, 
    comment text, 
    "updatedAt" timestamptz, 
    leader jsonb, 
    "socialBehaviour" text, 
    "userName" text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r."leaderId",
        l.name AS "leaderName",
        l."photoUrl" AS "leaderPhotoUrl",
        r.rating,
        r.comment,
        r."updatedAt",
        to_jsonb(l) AS leader,
        r."socialBehaviour",
        u.name AS "userName"
    FROM public.ratings r
    JOIN public.leaders l ON r."leaderId" = l.id
    JOIN public.users u ON r."userId" = u.id
    WHERE r."userId" = p_user_id
    ORDER BY r."updatedAt" DESC;
END;
$$;

-- RPC function to get all activities
CREATE OR REPLACE FUNCTION public.get_all_activities()
RETURNS TABLE(
    "leaderId" uuid, 
    "leaderName" text, 
    rating integer, 
    comment text, 
    "updatedAt" timestamptz, 
    "socialBehaviour" text, 
    "userName" text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r."leaderId",
        l.name AS "leaderName",
        r.rating,
        r.comment,
        r."updatedAt",
        r."socialBehaviour",
        u.name AS "userName"
    FROM public.ratings r
    JOIN public.leaders l ON r."leaderId" = l.id
    JOIN public.users u ON r."userId" = u.id
    ORDER BY r."updatedAt" DESC;
END;
$$;

-- RPC function to get admin polls
CREATE OR REPLACE FUNCTION public.get_admin_polls()
RETURNS TABLE(
    id uuid,
    title text,
    is_active boolean,
    active_until timestamptz,
    created_at timestamptz,
    response_count bigint,
    is_promoted boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.title,
        p.is_active,
        p.active_until,
        p.created_at,
        (SELECT count(*) FROM poll_responses pr WHERE pr.poll_id = p.id) as response_count,
        EXISTS (SELECT 1 FROM notifications n WHERE n.link = '/polls/' || p.id::text) as is_promoted
    FROM polls p
    ORDER BY p.created_at DESC;
END;
$$;

-- RPC function to get active polls for user
CREATE OR REPLACE FUNCTION public.get_active_polls_for_user(p_user_id uuid)
RETURNS TABLE(
    id uuid,
    title text,
    is_active boolean,
    active_until timestamptz,
    created_at timestamptz,
    response_count bigint,
    user_has_voted boolean,
    description text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.title,
        p.is_active,
        p.active_until,
        p.created_at,
        (SELECT count(*) FROM poll_responses pr WHERE pr.poll_id = p.id) as response_count,
        CASE
            WHEN p_user_id IS NULL THEN false
            ELSE EXISTS (SELECT 1 FROM poll_responses pr WHERE pr.poll_id = p.id AND pr.user_id = p_user_id)
        END as user_has_voted,
        p.description
    FROM polls p
    WHERE p.is_active = true AND (p.active_until IS NULL OR p.active_until > now())
    ORDER BY p.created_at DESC;
END;
$$;

-- RPC function to submit poll response
CREATE OR REPLACE FUNCTION public.submit_poll_response(
    p_poll_id uuid, 
    p_user_id uuid, 
    p_answers jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    answer_record RECORD;
BEGIN
    -- Insert the response
    INSERT INTO poll_responses (poll_id, user_id, answers) 
    VALUES (p_poll_id, p_user_id, p_answers);
    
    -- Update vote counts
    FOR answer_record IN 
        SELECT (value->>'optionId')::uuid as option_id 
        FROM jsonb_array_elements(p_answers)
    LOOP
        UPDATE poll_options 
        SET vote_count = vote_count + 1 
        WHERE id = answer_record.option_id;
    END LOOP;
END;
$$;

-- RPC function to get ticket stats
CREATE OR REPLACE FUNCTION public.get_ticket_stats()
RETURNS TABLE(
    total bigint,
    open bigint,
    in_progress bigint,
    resolved bigint,
    closed bigint,
    avg_resolution_hours double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'open') as open,
        COUNT(*) FILTER (WHERE status = 'in-progress') as in_progress,
        COUNT(*) FILTER (WHERE status = 'resolved') as resolved,
        COUNT(*) FILTER (WHERE status = 'closed') as closed,
        AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600.0) as avg_resolution_hours
    FROM support_tickets;
END;
$$;

-- Function to create admin user
CREATE OR REPLACE FUNCTION public.create_admin_user(admin_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.users 
    SET role = 'super_admin' 
    WHERE id IN (
        SELECT id FROM auth.users 
        WHERE email = admin_email
    );
    
    -- If user doesn't exist in users table, create them
    IF NOT FOUND THEN
        INSERT INTO public.users (id, email, name, role)
        SELECT id, email, COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1)), 'super_admin'
        FROM auth.users
        WHERE email = admin_email;
    END IF;
END;
$$;

-- Create triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS on_rating_change ON public.ratings;
CREATE TRIGGER on_rating_change
    AFTER INSERT OR UPDATE OR DELETE ON public.ratings
    FOR EACH ROW EXECUTE FUNCTION public.update_leader_rating();

-- =============================================
-- 6. Row Level Security Policies
-- =============================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY "Users can view all profiles" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can view all users" ON public.users FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can update any user" ON public.users FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Leaders policies
CREATE POLICY "Anyone can view approved leaders" ON public.leaders FOR SELECT USING (
    status = 'approved' OR 
    "addedByUserId" = auth.uid() OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Authenticated users can add leaders" ON public.leaders FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
);
CREATE POLICY "Users can update own pending leaders" ON public.leaders FOR UPDATE USING (
    ("addedByUserId" = auth.uid() AND status = 'pending') OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can delete leaders" ON public.leaders FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Ratings policies
CREATE POLICY "Anyone can view ratings" ON public.ratings FOR SELECT USING (true);
CREATE POLICY "Authenticated users can add ratings" ON public.ratings FOR INSERT WITH CHECK (
    auth.uid() = "userId"
);
CREATE POLICY "Users can update own ratings" ON public.ratings FOR UPDATE USING (
    auth.uid() = "userId"
);
CREATE POLICY "Users can delete own ratings" ON public.ratings FOR DELETE USING (
    auth.uid() = "userId" OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Admin messages policies
CREATE POLICY "Users can view own messages" ON public.admin_messages FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Users can update own messages" ON public.admin_messages FOR UPDATE USING (
    auth.uid() = user_id
);
CREATE POLICY "Admins can manage messages" ON public.admin_messages FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Site settings policies
CREATE POLICY "Anyone can view site settings" ON public.site_settings FOR SELECT USING (true);
CREATE POLICY "Admins can update site settings" ON public.site_settings FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Notifications policies
CREATE POLICY "Anyone can view active notifications" ON public.notifications FOR SELECT USING (
    "isActive" = true OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage notifications" ON public.notifications FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Polls policies
CREATE POLICY "Anyone can view active polls" ON public.polls FOR SELECT USING (
    is_active = true OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage polls" ON public.polls FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Poll questions policies
CREATE POLICY "Anyone can view questions of active polls" ON public.poll_questions FOR SELECT USING (
    EXISTS (SELECT 1 FROM polls p WHERE p.id = poll_id AND p.is_active = true) OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage poll questions" ON public.poll_questions FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Poll options policies
CREATE POLICY "Anyone can view options of active polls" ON public.poll_options FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM poll_questions pq 
        JOIN polls p ON pq.poll_id = p.id 
        WHERE pq.id = question_id AND p.is_active = true
    ) OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage poll options" ON public.poll_options FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Poll responses policies
CREATE POLICY "Authenticated users can submit responses" ON public.poll_responses FOR INSERT WITH CHECK (
    auth.uid() = user_id
);
CREATE POLICY "Users can view own responses" ON public.poll_responses FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Support tickets policies
CREATE POLICY "Authenticated users can create tickets" ON public.support_tickets FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
);
CREATE POLICY "Users can view own tickets" ON public.support_tickets FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
CREATE POLICY "Admins can manage tickets" ON public.support_tickets FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- Contact messages policies
CREATE POLICY "Anyone can create contact messages" ON public.contact_messages FOR INSERT WITH CHECK (true);
CREATE POLICY "Admins can manage contact messages" ON public.contact_messages FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);

-- =============================================
-- 7. Initial Data and Setup
-- =============================================

-- Insert default site settings
INSERT INTO public.site_settings (id, maintenance_active, maintenance_message)
VALUES ('main', false, 'We are currently performing maintenance. Please check back later.')
ON CONFLICT (id) DO NOTHING;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

GRANT ALL ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Grant execute permissions on specific functions
GRANT EXECUTE ON FUNCTION public.handle_new_rating(uuid, uuid, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_rating_deletion(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reviews_for_leader(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_activities(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_activities() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_polls_for_user(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_poll_response(uuid, uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_user_profile_exists() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_admin_polls() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_ticket_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_admin_user(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;

-- Comment with usage instructions
COMMENT ON FUNCTION public.create_admin_user IS 'Use this function to make a user an admin: SELECT create_admin_user(''your-email@example.com'');';
