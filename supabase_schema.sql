
-- =============================================
-- POLITIRATE PLATFORM - COMPLETE SUPABASE SCHEMA
-- =============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";

-- =============================================
-- 1. ENUMERATED TYPES
-- =============================================

-- Custom type for leader status
CREATE TYPE public.leader_status AS ENUM ('pending', 'approved', 'rejected');

-- Custom type for support ticket status
CREATE TYPE public.ticket_status AS ENUM ('open', 'in-progress', 'resolved', 'closed');

-- Custom type for poll question types
CREATE TYPE public.poll_question_type AS ENUM ('yes_no', 'multiple_choice');

-- Custom type for user roles
CREATE TYPE public.user_role AS ENUM ('user', 'admin', 'moderator');

-- Custom type for notification types
CREATE TYPE public.notification_type AS ENUM ('general', 'poll', 'announcement', 'maintenance');

-- =============================================
-- 2. CORE TABLES
-- =============================================

-- Users Table (extends auth.users)
CREATE TABLE public.users (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email character varying NOT NULL UNIQUE,
    name character varying,
    gender character varying,
    age integer CHECK (age >= 18 AND age <= 120),
    state character varying,
    "mpConstituency" character varying,
    "mlaConstituency" character varying,
    panchayat character varying,
    role public.user_role DEFAULT 'user'::public.user_role NOT NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "isBlocked" boolean DEFAULT false NOT NULL,
    "blockedUntil" timestamp with time zone,
    "blockReason" character varying,
    "lastLoginAt" timestamp with time zone,
    "isEmailVerified" boolean DEFAULT false NOT NULL,
    avatar_url text,
    phone_number character varying,
    bio text,
    preferences jsonb DEFAULT '{}'::jsonb
);

-- Add indexes for performance
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_role ON public.users(role);
CREATE INDEX idx_users_state ON public.users(state);
CREATE INDEX idx_users_blocked ON public.users("isBlocked");

COMMENT ON TABLE public.users IS 'Extended user profiles with demographic and preference data';

-- Leaders Table
CREATE TABLE public.leaders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    "partyName" character varying,
    gender character varying NOT NULL,
    age integer CHECK (age >= 18 AND age <= 120),
    "photoUrl" text,
    constituency character varying NOT NULL,
    "nativeAddress" text,
    "electionType" character varying NOT NULL,
    location jsonb,
    rating double precision DEFAULT 0 NOT NULL CHECK (rating >= 0 AND rating <= 5),
    "reviewCount" integer DEFAULT 0 NOT NULL CHECK ("reviewCount" >= 0),
    "previousElections" jsonb DEFAULT '[]'::jsonb,
    "manifestoUrl" text,
    "twitterUrl" text,
    "facebookUrl" text,
    "instagramUrl" text,
    "websiteUrl" text,
    "addedByUserId" uuid REFERENCES public.users(id) ON DELETE SET NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    status public.leader_status DEFAULT 'pending'::public.leader_status NOT NULL,
    "adminComment" text,
    "verificationStatus" character varying DEFAULT 'unverified',
    "contactEmail" character varying,
    "contactPhone" character varying,
    education text,
    profession text,
    "keyPromises" jsonb DEFAULT '[]'::jsonb,
    "currentPosition" character varying,
    "termStartDate" date,
    "termEndDate" date,
    "isActive" boolean DEFAULT true NOT NULL
);

-- Add indexes for leaders
CREATE INDEX idx_leaders_status ON public.leaders(status);
CREATE INDEX idx_leaders_constituency ON public.leaders(constituency);
CREATE INDEX idx_leaders_party ON public.leaders("partyName");
CREATE INDEX idx_leaders_election_type ON public.leaders("electionType");
CREATE INDEX idx_leaders_rating ON public.leaders(rating DESC);
CREATE INDEX idx_leaders_active ON public.leaders("isActive");

COMMENT ON TABLE public.leaders IS 'Political leaders with comprehensive profile information';

-- Ratings Table
CREATE TABLE public.ratings (
    "leaderId" uuid NOT NULL REFERENCES public.leaders(id) ON DELETE CASCADE,
    "userId" uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment text,
    "socialBehaviour" character varying,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "isVerified" boolean DEFAULT false NOT NULL,
    "helpfulCount" integer DEFAULT 0 NOT NULL,
    "reportCount" integer DEFAULT 0 NOT NULL,
    "isHidden" boolean DEFAULT false NOT NULL,
    category character varying DEFAULT 'general',
    PRIMARY KEY ("leaderId", "userId")
);

-- Add indexes for ratings
CREATE INDEX idx_ratings_leader_id ON public.ratings("leaderId");
CREATE INDEX idx_ratings_user_id ON public.ratings("userId");
CREATE INDEX idx_ratings_created_at ON public.ratings("createdAt" DESC);
CREATE INDEX idx_ratings_rating ON public.ratings(rating);

COMMENT ON TABLE public.ratings IS 'User ratings and reviews for political leaders';

-- Admin Messages Table
CREATE TABLE public.admin_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    sender_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    message text NOT NULL,
    subject character varying,
    "isRead" boolean DEFAULT false NOT NULL,
    "createdAt" timestamp with time zone NOT NULL DEFAULT now(),
    "readAt" timestamp with time zone,
    priority character varying DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    message_type character varying DEFAULT 'info' CHECK (message_type IN ('info', 'warning', 'error', 'success'))
);

CREATE INDEX idx_admin_messages_user_id ON public.admin_messages(user_id);
CREATE INDEX idx_admin_messages_unread ON public.admin_messages("isRead", "createdAt");

COMMENT ON TABLE public.admin_messages IS 'Messages sent from administrators to users';

-- Site Settings Table
CREATE TABLE public.site_settings (
    id smallint PRIMARY KEY DEFAULT 1,
    maintenance_active boolean DEFAULT false,
    maintenance_start timestamptz,
    maintenance_end timestamptz,
    maintenance_message text,
    contact_email text,
    contact_phone text,
    contact_twitter text,
    contact_linkedin text,
    contact_youtube text,
    contact_facebook text,
    contact_instagram text,
    site_title text DEFAULT 'Politirate',
    site_description text DEFAULT 'Rate and review political leaders',
    privacy_policy_url text,
    terms_of_service_url text,
    max_ratings_per_user integer DEFAULT 100,
    enable_user_registration boolean DEFAULT true,
    enable_public_polls boolean DEFAULT true,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedBy" uuid REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT single_settings_row CHECK (id = 1)
);

-- Insert default settings
INSERT INTO public.site_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE public.site_settings IS 'Global configuration settings for the platform';

-- Support Tickets Table
CREATE TABLE public.support_tickets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    user_name text NOT NULL,
    user_email text NOT NULL,
    subject text NOT NULL,
    message text NOT NULL,
    status public.ticket_status NOT NULL DEFAULT 'open',
    priority character varying DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    category character varying DEFAULT 'general',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    resolved_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    admin_notes text,
    attachments jsonb DEFAULT '[]'::jsonb,
    tags text[] DEFAULT '{}'::text[]
);

CREATE INDEX idx_support_tickets_status ON public.support_tickets(status);
CREATE INDEX idx_support_tickets_user_id ON public.support_tickets(user_id);
CREATE INDEX idx_support_tickets_created_at ON public.support_tickets(created_at DESC);

COMMENT ON TABLE public.support_tickets IS 'User support tickets and inquiries';

-- Notifications Table
CREATE TABLE public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    message text NOT NULL,
    "startTime" timestamptz DEFAULT now(),
    "endTime" timestamptz,
    "isActive" boolean NOT NULL DEFAULT true,
    notification_type public.notification_type DEFAULT 'general',
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    link text,
    target_audience character varying DEFAULT 'all' CHECK (target_audience IN ('all', 'users', 'admins', 'specific')),
    target_users uuid[] DEFAULT '{}'::uuid[],
    priority character varying DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high')),
    show_banner boolean DEFAULT false,
    show_popup boolean DEFAULT false,
    icon character varying,
    color character varying DEFAULT '#3b82f6'
);

CREATE INDEX idx_notifications_active ON public.notifications("isActive", "startTime", "endTime");
CREATE INDEX idx_notifications_type ON public.notifications(notification_type);

COMMENT ON TABLE public.notifications IS 'Site-wide notifications and announcements';

-- Polls Table
CREATE TABLE public.polls (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT false,
    active_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    updated_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    min_age integer,
    max_age integer,
    target_states text[] DEFAULT '{}'::text[],
    target_constituencies text[] DEFAULT '{}'::text[],
    allow_anonymous boolean DEFAULT false,
    show_results_before_vote boolean DEFAULT false,
    show_results_after_vote boolean DEFAULT true,
    max_responses integer,
    "requiresLogin" boolean DEFAULT true
);

CREATE INDEX idx_polls_active ON public.polls(is_active, active_until);
CREATE INDEX idx_polls_created_at ON public.polls(created_at DESC);

COMMENT ON TABLE public.polls IS 'Polls and surveys for public engagement';

-- Poll Questions Table
CREATE TABLE public.poll_questions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    question_text text NOT NULL,
    question_type public.poll_question_type NOT NULL,
    question_order integer NOT NULL,
    is_required boolean DEFAULT true,
    description text,
    image_url text
);

CREATE INDEX idx_poll_questions_poll_id ON public.poll_questions(poll_id, question_order);

COMMENT ON TABLE public.poll_questions IS 'Questions within polls';

-- Poll Options Table
CREATE TABLE public.poll_options (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES public.poll_questions(id) ON DELETE CASCADE,
    option_text text NOT NULL,
    option_order integer NOT NULL,
    vote_count integer NOT NULL DEFAULT 0 CHECK (vote_count >= 0),
    image_url text,
    description text
);

CREATE INDEX idx_poll_options_question_id ON public.poll_options(question_id, option_order);

COMMENT ON TABLE public.poll_options IS 'Answer options for poll questions';

-- Poll Responses Table
CREATE TABLE public.poll_responses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    answers jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    user_agent text,
    ip_address inet,
    demographics jsonb DEFAULT '{}'::jsonb,
    UNIQUE(poll_id, user_id)
);

CREATE INDEX idx_poll_responses_poll_id ON public.poll_responses(poll_id);
CREATE INDEX idx_poll_responses_user_id ON public.poll_responses(user_id);

COMMENT ON TABLE public.poll_responses IS 'User responses to polls';

-- User Sessions Table (for tracking active sessions)
CREATE TABLE public.user_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    session_token text NOT NULL,
    expires_at timestamptz NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    user_agent text,
    ip_address inet,
    is_active boolean DEFAULT true
);

CREATE INDEX idx_user_sessions_user_id ON public.user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON public.user_sessions(session_token);
CREATE INDEX idx_user_sessions_expires ON public.user_sessions(expires_at);

COMMENT ON TABLE public.user_sessions IS 'User session tracking for security';

-- Audit Log Table
CREATE TABLE public.audit_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    action text NOT NULL,
    table_name text NOT NULL,
    record_id uuid,
    old_values jsonb,
    new_values jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    ip_address inet,
    user_agent text
);

CREATE INDEX idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX idx_audit_logs_table_name ON public.audit_logs(table_name);

COMMENT ON TABLE public.audit_logs IS 'Audit trail for important system actions';

-- =============================================
-- 3. FUNCTIONS & TRIGGERS
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW."updatedAt" = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_leaders_updated_at BEFORE UPDATE ON public.leaders 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_ratings_updated_at BEFORE UPDATE ON public.ratings 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, name, "isEmailVerified", "lastLoginAt")
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        NEW.email_confirmed_at IS NOT NULL,
        NOW()
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user creation
CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to ensure user profile exists (for auth state changes)
CREATE OR REPLACE FUNCTION public.ensure_user_profile_exists()
RETURNS void AS $$
DECLARE
    user_id UUID := auth.uid();
    user_email TEXT;
    user_name TEXT;
BEGIN
    IF user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check if profile already exists
    IF EXISTS (SELECT 1 FROM public.users WHERE id = user_id) THEN
        RETURN;
    END IF;

    -- Get user info from auth.users
    SELECT email, COALESCE(raw_user_meta_data->>'name', raw_user_meta_data->>'full_name', split_part(email, '@', 1))
    INTO user_email, user_name
    FROM auth.users
    WHERE id = user_id;

    -- Create profile
    INSERT INTO public.users (id, email, name, "isEmailVerified", "lastLoginAt")
    VALUES (user_id, user_email, user_name, true, NOW());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update leader rating
CREATE OR REPLACE FUNCTION public.update_leader_rating()
RETURNS TRIGGER AS $$
DECLARE
    leader_id_var uuid;
BEGIN
    -- Get the leader ID from the operation
    IF TG_OP = 'DELETE' THEN
        leader_id_var := OLD."leaderId";
    ELSE
        leader_id_var := NEW."leaderId";
    END IF;

    -- Update the leader's rating and review count
    UPDATE public.leaders
    SET
        "reviewCount" = (
            SELECT COUNT(*)
            FROM public.ratings
            WHERE "leaderId" = leader_id_var AND "isHidden" = false
        ),
        rating = (
            SELECT COALESCE(AVG(rating), 0)
            FROM public.ratings
            WHERE "leaderId" = leader_id_var AND "isHidden" = false
        ),
        "updatedAt" = NOW()
    WHERE id = leader_id_var;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for rating changes
CREATE OR REPLACE TRIGGER on_rating_change
    AFTER INSERT OR UPDATE OR DELETE ON public.ratings
    FOR EACH ROW EXECUTE FUNCTION public.update_leader_rating();

-- Function to handle rating upsert
CREATE OR REPLACE FUNCTION public.handle_rating_upsert(
    p_leader_id uuid,
    p_user_id uuid,
    p_rating integer,
    p_comment text DEFAULT NULL,
    p_social_behaviour text DEFAULT NULL,
    p_category text DEFAULT 'general'
)
RETURNS void AS $$
BEGIN
    INSERT INTO public.ratings (
        "leaderId", "userId", rating, comment, "socialBehaviour", 
        category, "updatedAt"
    )
    VALUES (
        p_leader_id, p_user_id, p_rating, p_comment, p_social_behaviour,
        p_category, NOW()
    )
    ON CONFLICT ("leaderId", "userId")
    DO UPDATE SET
        rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        "socialBehaviour" = EXCLUDED."socialBehaviour",
        category = EXCLUDED.category,
        "updatedAt" = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete rating
CREATE OR REPLACE FUNCTION public.delete_rating(p_user_id uuid, p_leader_id uuid)
RETURNS void AS $$
BEGIN
    DELETE FROM public.ratings
    WHERE "userId" = p_user_id AND "leaderId" = p_leader_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get leader reviews
CREATE OR REPLACE FUNCTION public.get_leader_reviews(
    p_leader_id uuid,
    p_limit integer DEFAULT 10,
    p_offset integer DEFAULT 0
)
RETURNS TABLE(
    "userName" text,
    rating integer,
    comment text,
    "updatedAt" timestamptz,
    "socialBehaviour" text,
    category text,
    "helpfulCount" integer,
    "isVerified" boolean
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(u.name, 'Anonymous') AS "userName",
        r.rating,
        r.comment,
        r."updatedAt",
        r."socialBehaviour",
        r.category,
        r."helpfulCount",
        r."isVerified"
    FROM public.ratings r
    LEFT JOIN public.users u ON r."userId" = u.id
    WHERE r."leaderId" = p_leader_id 
        AND r."isHidden" = false
    ORDER BY r."updatedAt" DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user activities
CREATE OR REPLACE FUNCTION public.get_user_activities(
    p_user_id uuid,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS TABLE(
    "leaderId" uuid,
    "leaderName" text,
    "leaderPhotoUrl" text,
    rating integer,
    comment text,
    "updatedAt" timestamptz,
    "socialBehaviour" text,
    category text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r."leaderId",
        l.name AS "leaderName",
        l."photoUrl" AS "leaderPhotoUrl",
        r.rating,
        r.comment,
        r."updatedAt",
        r."socialBehaviour",
        r.category
    FROM public.ratings r
    JOIN public.leaders l ON r."leaderId" = l.id
    WHERE r."userId" = p_user_id
    ORDER BY r."updatedAt" DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all activities (for admin)
CREATE OR REPLACE FUNCTION public.get_all_activities(
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE(
    "leaderId" uuid,
    "leaderName" text,
    "userName" text,
    rating integer,
    comment text,
    "updatedAt" timestamptz,
    "socialBehaviour" text,
    category text
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        r."leaderId",
        l.name AS "leaderName",
        u.name AS "userName",
        r.rating,
        r.comment,
        r."updatedAt",
        r."socialBehaviour",
        r.category
    FROM public.ratings r
    JOIN public.leaders l ON r."leaderId" = l.id
    JOIN public.users u ON r."userId" = u.id
    ORDER BY r."updatedAt" DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get admin polls
CREATE OR REPLACE FUNCTION public.get_admin_polls()
RETURNS TABLE (
    id uuid,
    title text,
    is_active boolean,
    active_until timestamptz,
    created_at timestamptz,
    response_count bigint,
    is_promoted boolean,
    created_by_name text
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.title,
        p.is_active,
        p.active_until,
        p.created_at,
        (SELECT COUNT(*) FROM public.poll_responses pr WHERE pr.poll_id = p.id) as response_count,
        EXISTS (SELECT 1 FROM public.notifications n WHERE n.link = '/polls/' || p.id::text) as is_promoted,
        u.name as created_by_name
    FROM public.polls p
    LEFT JOIN public.users u ON p.created_by = u.id
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get active polls for users
CREATE OR REPLACE FUNCTION public.get_active_polls_for_user(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    is_active boolean,
    active_until timestamptz,
    created_at timestamptz,
    response_count bigint,
    user_has_voted boolean,
    "requiresLogin" boolean
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.title,
        p.description,
        p.is_active,
        p.active_until,
        p.created_at,
        (SELECT COUNT(*) FROM public.poll_responses pr WHERE pr.poll_id = p.id) as response_count,
        CASE
            WHEN p_user_id IS NULL THEN false
            ELSE EXISTS (SELECT 1 FROM public.poll_responses pr WHERE pr.poll_id = p.id AND pr.user_id = p_user_id)
        END as user_has_voted,
        p."requiresLogin"
    FROM public.polls p
    WHERE p.is_active = true 
        AND (p.active_until IS NULL OR p.active_until > NOW())
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to submit poll response
CREATE OR REPLACE FUNCTION public.submit_poll_response(
    p_poll_id uuid,
    p_user_id uuid,
    p_answers jsonb,
    p_user_agent text DEFAULT NULL,
    p_ip_address inet DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
    response_id uuid;
    rec RECORD;
BEGIN
    -- Insert the response
    INSERT INTO public.poll_responses (poll_id, user_id, answers, user_agent, ip_address)
    VALUES (p_poll_id, p_user_id, p_answers, p_user_agent, p_ip_address)
    RETURNING id INTO response_id;
    
    -- Update vote counts for each option
    FOR rec IN SELECT (value->>'optionId')::uuid as option_id FROM jsonb_array_elements(p_answers)
    LOOP
        UPDATE public.poll_options 
        SET vote_count = vote_count + 1 
        WHERE id = rec.option_id;
    END LOOP;
    
    RETURN response_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get poll results
CREATE OR REPLACE FUNCTION public.get_poll_results(p_poll_id uuid)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'pollId', p.id,
        'pollTitle', p.title,
        'pollDescription', p.description,
        'totalResponses', (SELECT COUNT(*) FROM public.poll_responses pr WHERE pr.poll_id = p.id),
        'isActive', p.is_active,
        'activeUntil', p.active_until,
        'createdAt', p.created_at,
        'demographics', jsonb_build_object(
            'genderDistribution', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object('name', COALESCE(u.gender, 'Unknown'), 'value', COUNT(*))), '[]'::jsonb)
                FROM public.poll_responses pr
                LEFT JOIN public.users u ON pr.user_id = u.id
                WHERE pr.poll_id = p.id
                GROUP BY u.gender
            ),
            'ageDistribution', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object('name', age_group, 'value', COUNT(*))), '[]'::jsonb)
                FROM (
                    SELECT 
                        CASE 
                            WHEN u.age BETWEEN 18 AND 25 THEN '18-25'
                            WHEN u.age BETWEEN 26 AND 35 THEN '26-35'
                            WHEN u.age BETWEEN 36 AND 45 THEN '36-45'
                            WHEN u.age BETWEEN 46 AND 55 THEN '46-55'
                            WHEN u.age > 55 THEN '55+'
                            ELSE 'Unknown'
                        END as age_group
                    FROM public.poll_responses pr
                    LEFT JOIN public.users u ON pr.user_id = u.id
                    WHERE pr.poll_id = p.id
                ) age_groups
                GROUP BY age_group
            )
        ),
        'questions', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'id', pq.id,
                    'text', pq.question_text,
                    'type', pq.question_type,
                    'order', pq.question_order,
                    'answers', (
                        SELECT COALESCE(jsonb_agg(
                            jsonb_build_object(
                                'id', po.id,
                                'name', po.option_text,
                                'value', po.vote_count,
                                'percentage', CASE 
                                    WHEN (SELECT COUNT(*) FROM public.poll_responses pr2 WHERE pr2.poll_id = p.id) > 0 
                                    THEN ROUND((po.vote_count * 100.0) / (SELECT COUNT(*) FROM public.poll_responses pr2 WHERE pr2.poll_id = p.id), 2)
                                    ELSE 0
                                END
                            ) ORDER BY po.option_order
                        ), '[]'::jsonb)
                        FROM public.poll_options po
                        WHERE po.question_id = pq.id
                    )
                ) ORDER BY pq.question_order
            ), '[]'::jsonb)
            FROM public.poll_questions pq
            WHERE pq.poll_id = p.id
        )
    )
    INTO result
    FROM public.polls p
    WHERE p.id = p_poll_id;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get support ticket stats
CREATE OR REPLACE FUNCTION public.get_support_ticket_stats()
RETURNS TABLE (
    total bigint,
    open bigint,
    in_progress bigint,
    resolved bigint,
    closed bigint,
    avg_resolution_hours double precision,
    avg_response_time_hours double precision
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE status = 'open') as open,
        COUNT(*) FILTER (WHERE status = 'in-progress') as in_progress,
        COUNT(*) FILTER (WHERE status = 'resolved') as resolved,
        COUNT(*) FILTER (WHERE status = 'closed') as closed,
        AVG(EXTRACT(EPOCH FROM (resolved_at - created_at)) / 3600.0) as avg_resolution_hours,
        AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600.0) as avg_response_time_hours
    FROM public.support_tickets;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid DEFAULT auth.uid())
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users 
        WHERE id = user_id AND role IN ('admin', 'moderator')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create admin user (use Supabase Admin API instead)
CREATE OR REPLACE FUNCTION public.promote_user_to_admin(
    p_user_id uuid,
    p_admin_level text DEFAULT 'admin'
)
RETURNS boolean AS $$
BEGIN
    -- Promote existing user to admin
    UPDATE public.users 
    SET role = p_admin_level::public.user_role,
        "updatedAt" = NOW()
    WHERE id = p_user_id;
    
    -- Log the promotion
    INSERT INTO public.audit_logs (user_id, action, table_name, record_id, new_values)
    VALUES (
        p_user_id,
        'PROMOTE_TO_ADMIN',
        'users',
        p_user_id,
        jsonb_build_object('new_role', p_admin_level)
    );
    
    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user profile details
CREATE OR REPLACE FUNCTION public.get_user_profile(p_user_id uuid)
RETURNS TABLE(
    id uuid,
    email text,
    name text,
    gender text,
    age integer,
    state text,
    "mpConstituency" text,
    "mlaConstituency" text,
    panchayat text,
    role text,
    "createdAt" timestamptz,
    "updatedAt" timestamptz,
    "lastLoginAt" timestamptz,
    "isEmailVerified" boolean,
    avatar_url text,
    phone_number text,
    bio text,
    preferences jsonb,
    total_ratings bigint,
    total_leaders_added bigint,
    avg_rating_given numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.email,
        u.name,
        u.gender,
        u.age,
        u.state,
        u."mpConstituency",
        u."mlaConstituency",
        u.panchayat,
        u.role::text,
        u."createdAt",
        u."updatedAt",
        u."lastLoginAt",
        u."isEmailVerified",
        u.avatar_url,
        u.phone_number,
        u.bio,
        u.preferences,
        (SELECT COUNT(*) FROM public.ratings r WHERE r."userId" = u.id) as total_ratings,
        (SELECT COUNT(*) FROM public.leaders l WHERE l."addedByUserId" = u.id) as total_leaders_added,
        (SELECT ROUND(AVG(r.rating), 2) FROM public.ratings r WHERE r."userId" = u.id) as avg_rating_given
    FROM public.users u
    WHERE u.id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user profile
CREATE OR REPLACE FUNCTION public.update_user_profile(
    p_user_id uuid,
    p_name text DEFAULT NULL,
    p_gender text DEFAULT NULL,
    p_age integer DEFAULT NULL,
    p_state text DEFAULT NULL,
    p_mp_constituency text DEFAULT NULL,
    p_mla_constituency text DEFAULT NULL,
    p_panchayat text DEFAULT NULL,
    p_avatar_url text DEFAULT NULL,
    p_phone_number text DEFAULT NULL,
    p_bio text DEFAULT NULL,
    p_preferences jsonb DEFAULT NULL
)
RETURNS boolean AS $$
BEGIN
    UPDATE public.users 
    SET 
        name = COALESCE(p_name, name),
        gender = COALESCE(p_gender, gender),
        age = COALESCE(p_age, age),
        state = COALESCE(p_state, state),
        "mpConstituency" = COALESCE(p_mp_constituency, "mpConstituency"),
        "mlaConstituency" = COALESCE(p_mla_constituency, "mlaConstituency"),
        panchayat = COALESCE(p_panchayat, panchayat),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        phone_number = COALESCE(p_phone_number, phone_number),
        bio = COALESCE(p_bio, bio),
        preferences = COALESCE(p_preferences, preferences),
        "updatedAt" = NOW()
    WHERE id = p_user_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can view all public profiles" ON public.users 
    FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile" ON public.users 
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can update any user" ON public.users 
    FOR UPDATE USING (public.is_admin());

CREATE POLICY "Admins can view all user data" ON public.users 
    FOR SELECT USING (public.is_admin());

-- Leaders table policies
CREATE POLICY "Anyone can view approved leaders" ON public.leaders 
    FOR SELECT USING (status = 'approved' AND "isActive" = true);

CREATE POLICY "Authenticated users can add leaders" ON public.leaders 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can view their own submitted leaders" ON public.leaders 
    FOR SELECT USING (auth.uid() = "addedByUserId");

CREATE POLICY "Users can update their own submitted leaders" ON public.leaders 
    FOR UPDATE USING (auth.uid() = "addedByUserId" AND status = 'pending');

CREATE POLICY "Admins can view all leaders" ON public.leaders 
    FOR SELECT USING (public.is_admin());

CREATE POLICY "Admins can update any leader" ON public.leaders 
    FOR UPDATE USING (public.is_admin());

CREATE POLICY "Admins can delete leaders" ON public.leaders 
    FOR DELETE USING (public.is_admin());

-- Ratings table policies
CREATE POLICY "Anyone can view non-hidden ratings" ON public.ratings 
    FOR SELECT USING ("isHidden" = false);

CREATE POLICY "Users can manage their own ratings" ON public.ratings 
    FOR ALL USING (auth.uid() = "userId");

CREATE POLICY "Admins can view all ratings" ON public.ratings 
    FOR SELECT USING (public.is_admin());

CREATE POLICY "Admins can update any rating" ON public.ratings 
    FOR UPDATE USING (public.is_admin());

-- Admin messages policies
CREATE POLICY "Users can view their own messages" ON public.admin_messages 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own messages" ON public.admin_messages 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all messages" ON public.admin_messages 
    FOR ALL USING (public.is_admin());

-- Site settings policies
CREATE POLICY "Anyone can view site settings" ON public.site_settings 
    FOR SELECT USING (true);

CREATE POLICY "Only admins can update site settings" ON public.site_settings 
    FOR UPDATE USING (public.is_admin());

-- Support tickets policies
CREATE POLICY "Authenticated users can create tickets" ON public.support_tickets 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can view their own tickets" ON public.support_tickets 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own tickets" ON public.support_tickets 
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all tickets" ON public.support_tickets 
    FOR ALL USING (public.is_admin());

-- Notifications policies
CREATE POLICY "Anyone can view active notifications" ON public.notifications 
    FOR SELECT USING (
        "isActive" = true 
        AND ("startTime" IS NULL OR "startTime" <= NOW())
        AND ("endTime" IS NULL OR "endTime" >= NOW())
    );

CREATE POLICY "Admins can manage notifications" ON public.notifications 
    FOR ALL USING (public.is_admin());

-- Polls policies
CREATE POLICY "Anyone can view active polls" ON public.polls 
    FOR SELECT USING (
        is_active = true 
        AND (active_until IS NULL OR active_until > NOW())
    );

CREATE POLICY "Admins can manage polls" ON public.polls 
    FOR ALL USING (public.is_admin());

-- Poll questions policies
CREATE POLICY "Anyone can view questions of active polls" ON public.poll_questions 
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.polls p 
            WHERE p.id = poll_id 
                AND p.is_active = true 
                AND (p.active_until IS NULL OR p.active_until > NOW())
        )
    );

CREATE POLICY "Admins can manage poll questions" ON public.poll_questions 
    FOR ALL USING (public.is_admin());

-- Poll options policies
CREATE POLICY "Anyone can view options of active polls" ON public.poll_options 
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.poll_questions pq 
            JOIN public.polls p ON pq.poll_id = p.id 
            WHERE pq.id = question_id 
                AND p.is_active = true 
                AND (p.active_until IS NULL OR p.active_until > NOW())
        )
    );

CREATE POLICY "Admins can manage poll options" ON public.poll_options 
    FOR ALL USING (public.is_admin());

-- Poll responses policies
CREATE POLICY "Authenticated users can submit responses" ON public.poll_responses 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can view their own responses" ON public.poll_responses 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all responses" ON public.poll_responses 
    FOR SELECT USING (public.is_admin());

-- User sessions policies
CREATE POLICY "Users can view their own sessions" ON public.user_sessions 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own sessions" ON public.user_sessions 
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all sessions" ON public.user_sessions 
    FOR SELECT USING (public.is_admin());

-- Audit logs policies
CREATE POLICY "Admins can view audit logs" ON public.audit_logs 
    FOR SELECT USING (public.is_admin());

CREATE POLICY "Users can view their own audit logs" ON public.audit_logs 
    FOR SELECT USING (auth.uid() = user_id);

-- =============================================
-- 5. INITIAL DATA AND SETUP
-- =============================================

-- Admin User Creation Instructions:
-- 1. Create admin user through Supabase Auth Dashboard or API
-- 2. Then promote them using: SELECT public.promote_user_to_admin('user_id_here', 'admin');

-- Function to initialize default admin (call after creating user through Supabase Auth)
CREATE OR REPLACE FUNCTION public.initialize_default_admin(
    p_admin_email text DEFAULT 'admin@politirate.com'
)
RETURNS text AS $$
DECLARE
    admin_user_id uuid;
    result_message text;
BEGIN
    -- Check if admin user already exists
    SELECT id INTO admin_user_id 
    FROM public.users 
    WHERE email = p_admin_email AND role = 'admin';
    
    IF admin_user_id IS NOT NULL THEN
        result_message := 'Admin user already exists with ID: ' || admin_user_id;
    ELSE
        -- Look for user with this email
        SELECT id INTO admin_user_id 
        FROM public.users 
        WHERE email = p_admin_email;
        
        IF admin_user_id IS NOT NULL THEN
            -- Promote existing user to admin
            PERFORM public.promote_user_to_admin(admin_user_id, 'admin');
            result_message := 'User promoted to admin with ID: ' || admin_user_id;
        ELSE
            result_message := 'User not found. Please create user through Supabase Auth first, then call this function.';
        END IF;
    END IF;
    
    RETURN result_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- User Profile Management Functions
CREATE OR REPLACE FUNCTION public.get_user_dashboard_stats(p_user_id uuid)
RETURNS TABLE(
    total_ratings bigint,
    total_leaders_added bigint,
    avg_rating_given numeric,
    recent_activities jsonb,
    account_age_days integer,
    profile_completion_percentage integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM public.ratings r WHERE r."userId" = p_user_id) as total_ratings,
        (SELECT COUNT(*) FROM public.leaders l WHERE l."addedByUserId" = p_user_id) as total_leaders_added,
        (SELECT ROUND(AVG(r.rating), 2) FROM public.ratings r WHERE r."userId" = p_user_id) as avg_rating_given,
        (SELECT jsonb_agg(
            jsonb_build_object(
                'type', 'rating',
                'leaderName', l.name,
                'rating', r.rating,
                'date', r."updatedAt"
            )
        ) FROM public.ratings r 
        JOIN public.leaders l ON r."leaderId" = l.id 
        WHERE r."userId" = p_user_id 
        ORDER BY r."updatedAt" DESC 
        LIMIT 5) as recent_activities,
        (SELECT EXTRACT(DAYS FROM NOW() - u."createdAt")::integer FROM public.users u WHERE u.id = p_user_id) as account_age_days,
        (SELECT 
            CASE 
                WHEN u.name IS NOT NULL THEN 20 ELSE 0 END +
            CASE 
                WHEN u.gender IS NOT NULL THEN 15 ELSE 0 END +
            CASE 
                WHEN u.age IS NOT NULL THEN 15 ELSE 0 END +
            CASE 
                WHEN u.state IS NOT NULL THEN 15 ELSE 0 END +
            CASE 
                WHEN u."mpConstituency" IS NOT NULL THEN 10 ELSE 0 END +
            CASE 
                WHEN u."mlaConstituency" IS NOT NULL THEN 10 ELSE 0 END +
            CASE 
                WHEN u.bio IS NOT NULL THEN 10 ELSE 0 END +
            CASE 
                WHEN u.avatar_url IS NOT NULL THEN 5 ELSE 0 END
        FROM public.users u WHERE u.id = p_user_id) as profile_completion_percentage;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert sample site settings
UPDATE public.site_settings SET
    site_title = 'Politirate',
    site_description = 'Rate and review political leaders in your constituency',
    contact_email = 'support@politirate.com',
    enable_user_registration = true,
    enable_public_polls = true,
    max_ratings_per_user = 100
WHERE id = 1;

-- Insert sample notification
INSERT INTO public.notifications (title, message, "isActive", notification_type, show_banner)
VALUES (
    'Welcome to Politirate!',
    'Start rating and reviewing political leaders in your area. Your voice matters!',
    true,
    'announcement',
    true
);

-- =============================================
-- 6. PERFORMANCE OPTIMIZATIONS
-- =============================================

-- Additional indexes for common queries
CREATE INDEX IF NOT EXISTS idx_leaders_search ON public.leaders USING gin(to_tsvector('english', name || ' ' || COALESCE("partyName", '') || ' ' || constituency));
CREATE INDEX IF NOT EXISTS idx_ratings_leader_rating ON public.ratings("leaderId", rating);
CREATE INDEX IF NOT EXISTS idx_users_demographics ON public.users(state, gender, age) WHERE "isBlocked" = false;
CREATE INDEX IF NOT EXISTS idx_support_tickets_composite ON public.support_tickets(status, priority, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_active_time ON public.notifications("isActive", "startTime", "endTime") WHERE "isActive" = true;

-- =============================================
-- SCHEMA COMPLETE
-- =============================================

-- This schema provides:
-- 1. Complete user management with roles and permissions
-- 2. Political leader profiles with ratings and reviews
-- 3. Admin panel functionality with audit trails
-- 4. Polling system for public engagement
-- 5. Support ticket system
-- 6. Notification and messaging system
-- 7. Row Level Security for data protection
-- 8. Performance optimizations with indexes
-- 9. Comprehensive audit logging
-- 10. Session management for security

-- To use this schema:
-- 1. Run this SQL in your Supabase SQL editor
-- 2. Configure your environment variables
-- 3. Set up authentication in your Supabase dashboard
-- 4. Create your first admin user through the application or SQL
-- 5. Configure email templates in Supabase Auth settings
