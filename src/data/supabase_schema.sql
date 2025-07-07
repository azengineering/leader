-- =============================================
-- 1. ENUMERATED TYPES
-- =============================================
-- Custom type for leader status
CREATE TYPE public.leader_status AS ENUM ('pending', 'approved', 'rejected');
-- Custom type for support ticket status
CREATE TYPE public.ticket_status AS ENUM ('open', 'in-progress', 'resolved', 'closed');
-- Custom type for poll question types
CREATE TYPE public.poll_question_type AS ENUM ('yes_no', 'multiple_choice');

-- =============================================
-- 2. TABLES
-- =============================================
-- Users Table
-- Stores public user information, extending the built-in auth.users table.
CREATE TABLE public.users (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email character varying NOT NULL,
    name character varying,
    gender character varying,
    age integer,
    state character varying,
    "mpConstituency" character varying,
    "mlaConstituency" character varying,
    panchayat character varying,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "isBlocked" boolean DEFAULT false NOT NULL,
    "blockedUntil" timestamp with time zone,
    "blockReason" character varying
);
COMMENT ON TABLE public.users IS 'Public profile information for each user.';

-- Leaders Table
-- Stores information about political leaders.
CREATE TABLE public.leaders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name character varying NOT NULL,
    "partyName" character varying NOT NULL,
    gender character varying NOT NULL,
    age integer NOT NULL,
    "photoUrl" text,
    constituency character varying NOT NULL,
    "nativeAddress" text,
    "electionType" character varying NOT NULL,
    location jsonb,
    rating double precision DEFAULT 0 NOT NULL,
    "reviewCount" integer DEFAULT 0 NOT NULL,
    "previousElections" jsonb,
    "manifestoUrl" text,
    "twitterUrl" text,
    "addedByUserId" uuid REFERENCES public.users(id) ON DELETE SET NULL,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    status public.leader_status DEFAULT 'pending'::public.leader_status NOT NULL,
    "adminComment" text
);
COMMENT ON TABLE public.leaders IS 'Stores profiles of political leaders.';

-- Ratings Table
-- Stores individual ratings and comments from users for leaders.
CREATE TABLE public.ratings (
    "leaderId" uuid NOT NULL REFERENCES public.leaders(id) ON DELETE CASCADE,
    "userId" uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    rating integer NOT NULL,
    comment text,
    "socialBehaviour" character varying,
    "createdAt" timestamp with time zone DEFAULT now() NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY ("leaderId", "userId")
);
COMMENT ON TABLE public.ratings IS 'User ratings and comments for leaders.';

-- Admin Messages Table
-- For administrators to send messages/warnings to users.
CREATE TABLE public.admin_messages (
    id uuid PRIMARY KEY default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    message text not null,
    is_read boolean default false not null,
    "createdAt" timestamp with time zone not null default now()
);
COMMENT ON TABLE public.admin_messages IS 'Stores messages sent from admins to users.';

-- Site Settings Table
-- For global configuration of the application.
CREATE TABLE public.site_settings (
    id smallint PRIMARY KEY,
    maintenance_active boolean DEFAULT false,
    maintenance_start timestamptz,
    maintenance_end timestamptz,
    maintenance_message text,
    contact_email text,
    contact_phone text,
    contact_twitter text,
    contact_linkedin text,
    contact_youtube text,
    contact_facebook text
);
-- Insert a single row for settings
INSERT INTO public.site_settings (id) VALUES (1);
COMMENT ON TABLE public.site_settings IS 'Global configuration for the website.';

-- Support Tickets Table
-- Stores contact form submissions from users.
CREATE TABLE public.support_tickets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
    user_name text NOT NULL,
    user_email text NOT NULL,
    subject text NOT NULL,
    message text NOT NULL,
    status public.ticket_status NOT NULL DEFAULT 'open',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    admin_notes text
);
COMMENT ON TABLE public.support_tickets IS 'User-submitted support tickets from the contact form.';

-- Notifications Table
-- For displaying site-wide announcements.
CREATE TABLE public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    message text NOT NULL,
    "startTime" timestamptz,
    "endTime" timestamptz,
    "isActive" boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    link text
);
COMMENT ON TABLE public.notifications IS 'Site-wide announcements and notifications.';

-- Polls Table
CREATE TABLE public.polls (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    is_active boolean NOT NULL DEFAULT false,
    active_until timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    target_filters jsonb,
    "requiresLogin" boolean DEFAULT false
);
COMMENT ON TABLE public.polls IS 'Main poll information.';

-- Poll Questions Table
CREATE TABLE public.poll_questions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    question_text text NOT NULL,
    question_type public.poll_question_type NOT NULL,
    question_order integer NOT NULL
);
COMMENT ON TABLE public.poll_questions IS 'Questions associated with a poll.';

-- Poll Options Table
CREATE TABLE public.poll_options (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    question_id uuid NOT NULL REFERENCES public.poll_questions(id) ON DELETE CASCADE,
    option_text text NOT NULL,
    option_order integer NOT NULL,
    vote_count integer NOT NULL DEFAULT 0
);
COMMENT ON TABLE public.poll_options IS 'Answer options for a poll question.';

-- Poll Responses Table
CREATE TABLE public.poll_responses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id uuid NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    answers jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(poll_id, user_id)
);
COMMENT ON TABLE public.poll_responses IS 'Records user responses to polls.';


-- =============================================
-- 3. FUNCTIONS & TRIGGERS
-- =============================================

-- Function to create a public user profile on new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Trigger for the above function
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Function to update a leader's rating and review count
CREATE OR REPLACE FUNCTION public.update_leader_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.leaders
  SET
    "reviewCount" = (SELECT COUNT(*) FROM public.ratings WHERE "leaderId" = NEW."leaderId"),
    rating = (SELECT AVG(rating) FROM public.ratings WHERE "leaderId" = NEW."leaderId")
  WHERE id = NEW."leaderId";
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Trigger for the above function
CREATE TRIGGER on_rating_change
  AFTER INSERT OR UPDATE OR DELETE ON public.ratings
  FOR EACH ROW EXECUTE PROCEDURE public.update_leader_rating();

-- RPC for submitting a new rating
CREATE OR REPLACE FUNCTION public.handle_new_rating(p_leader_id uuid, p_user_id uuid, p_rating int, p_comment text, p_social_behaviour text)
RETURNS void AS $$
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
$$ LANGUAGE plpgsql;

-- RPC for deleting a rating
CREATE OR REPLACE FUNCTION public.handle_rating_deletion(p_user_id uuid, p_leader_id uuid)
RETURNS void AS $$
BEGIN
  DELETE FROM public.ratings
  WHERE "userId" = p_user_id AND "leaderId" = p_leader_id;
END;
$$ LANGUAGE plpgsql;

-- RPC to get reviews for a leader
CREATE OR REPLACE FUNCTION public.get_reviews_for_leader(p_leader_id uuid)
RETURNS TABLE("userName" text, rating int, comment text, "updatedAt" timestamptz, "socialBehaviour" text) AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.name AS "userName",
    r.rating,
    r.comment,
    r. "updatedAt",
    r."socialBehaviour"
  FROM public.ratings r
  JOIN public.users u ON r."userId" = u.id
  WHERE r."leaderId" = p_leader_id
  ORDER BY r."updatedAt" DESC;
END;
$$ LANGUAGE plpgsql;

-- RPC to get all activities for a user
CREATE OR REPLACE FUNCTION public.get_user_activities(p_user_id uuid)
RETURNS TABLE("leaderId" uuid, "leaderName" text, "leaderPhotoUrl" text, rating int, comment text, "updatedAt" timestamptz, leader jsonb, "socialBehaviour" text, "userName" text) AS $$
BEGIN
  RETURN QUERY
  SELECT
    r."leaderId",
    l.name AS "leaderName",
    l."photoUrl" AS "leaderPhotoUrl",
    r.rating,
    r.comment,
    r."updatedAt",
    row_to_json(l) AS leader,
    r."socialBehaviour",
    u.name AS "userName"
  FROM public.ratings r
  JOIN public.leaders l ON r."leaderId" = l.id
  JOIN public.users u ON r."userId" = u.id
  WHERE r."userId" = p_user_id
  ORDER BY r."updatedAt" DESC;
END;
$$ LANGUAGE plpgsql;

-- RPC to get all activities
CREATE OR REPLACE FUNCTION public.get_all_activities()
RETURNS TABLE("leaderId" uuid, "leaderName" text, rating int, comment text, "updatedAt" timestamptz, "socialBehaviour" text, "userName" text) AS $$
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
$$ LANGUAGE plpgsql;

-- RPC to get poll list for admin
CREATE OR REPLACE FUNCTION public.get_admin_polls()
RETURNS TABLE (
    id uuid,
    title text,
    is_active boolean,
    active_until timestamptz,
    created_at timestamptz,
    response_count bigint,
    is_promoted boolean
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
        EXISTS (SELECT 1 FROM public.notifications n WHERE n.link = '/polls/' || p.id::text) as is_promoted
    FROM public.polls p
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get active polls for a user with vote status
CREATE OR REPLACE FUNCTION public.get_active_polls_for_user(p_user_id uuid DEFAULT NULL)
RETURNS TABLE (
    id uuid,
    title text,
    is_active boolean,
    active_until timestamptz,
    created_at timestamptz,
    response_count bigint,
    user_has_voted boolean,
    description text,
    "requiresLogin" boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_state text;
    user_constituency text;
    user_gender text;
    user_age integer;
BEGIN
    -- Get user demographics if user is logged in
    IF p_user_id IS NOT NULL THEN
        SELECT u.state, u."mpConstituency", u.gender, 
               EXTRACT(YEAR FROM AGE(CURRENT_DATE, u."dateOfBirth"))
        INTO user_state, user_constituency, user_gender, user_age
        FROM public.users u
        WHERE u.id = p_user_id;
    END IF;

    RETURN QUERY
    SELECT 
        p.id,
        p.title,
        p.is_active,
        p.active_until,
        p.created_at,
        (SELECT COUNT(*) FROM public.poll_responses pr WHERE pr.poll_id = p.id) as response_count,
        EXISTS (SELECT 1 FROM public.poll_responses pr WHERE pr.poll_id = p.id AND pr.user_id = p_user_id) as user_has_voted,
        p.description,
        p."requiresLogin"
    FROM public.polls p
    WHERE p.is_active = true 
        AND (p.active_until IS NULL OR p.active_until > NOW())
        AND (
            -- No target filters means show to everyone
            p.target_filters IS NULL
            OR
            -- User not logged in and poll requires login - don't show
            (p_user_id IS NULL AND p."requiresLogin" = true)
            OR
            -- User not logged in and poll has target filters - don't show
            (p_user_id IS NULL AND p.target_filters IS NOT NULL)
            OR
            -- User logged in - check filters
            (p_user_id IS NOT NULL AND (
                -- No filters set means show to all logged in users
                p.target_filters IS NULL
                OR
                (
                    -- Check state filter
                    (p.target_filters->>'states' IS NULL 
                     OR jsonb_array_length(p.target_filters->'states') = 0
                     OR p.target_filters->'states' @> to_jsonb(ARRAY[user_state]))
                    AND
                    -- Check constituency filter  
                    (p.target_filters->>'constituencies' IS NULL 
                     OR jsonb_array_length(p.target_filters->'constituencies') = 0
                     OR p.target_filters->'constituencies' @> to_jsonb(ARRAY[user_constituency]))
                    AND
                    -- Check gender filter
                    (p.target_filters->>'gender' IS NULL 
                     OR jsonb_array_length(p.target_filters->'gender') = 0
                     OR p.target_filters->'gender' @> to_jsonb(ARRAY[user_gender]))
                    AND
                    -- Check age filter
                    (p.target_filters->>'age_min' IS NULL 
                     OR (p.target_filters->>'age_min')::integer <= user_age)
                    AND
                    (p.target_filters->>'age_max' IS NULL 
                     OR (p.target_filters->>'age_max')::integer >= user_age)
                )
            ))
        )
    ORDER BY p.created_at DESC;
END;
$$;

-- RPC for creating/updating a poll
CREATE OR REPLACE FUNCTION upsert_poll(poll_data jsonb)
RETURNS uuid AS $$
DECLARE
    poll_id uuid;
    q jsonb;
    o jsonb;
    question_id uuid;
BEGIN
    -- Upsert poll
    IF poll_data->>'id' = '' THEN
        INSERT INTO polls (title, description, is_active, active_until)
        VALUES (poll_data->>'title', poll_data->>'description', (poll_data->>'is_active')::boolean, (poll_data->>'active_until')::timestamptz)
        RETURNING id INTO poll_id;
    ELSE
        poll_id := (poll_data->>'id')::uuid;
        UPDATE polls
        SET title = poll_data->>'title',
            description = poll_data->>'description',
            is_active = (poll_data->>'is_active')::boolean,
            active_until = (poll_data->>'active_until')::timestamptz
        WHERE id = poll_id;
    END IF;

    -- Delete old questions/options to handle removed items
    DELETE FROM poll_questions WHERE poll_id = poll_id AND id NOT IN (SELECT (value->>'id')::uuid FROM jsonb_array_elements(poll_data->'questions') WHERE value->>'id' != '');

    -- Upsert questions and options
    FOR q IN SELECT * FROM jsonb_array_elements(poll_data->'questions')
    LOOP
        IF q->>'id' = '' THEN
            INSERT INTO poll_questions (poll_id, question_text, question_type, question_order)
            VALUES (poll_id, q->>'question_text', (q->>'question_type')::poll_question_type, (q->>'question_order')::int)
            RETURNING id INTO question_id;
        ELSE
            question_id := (q->>'id')::uuid;
            UPDATE poll_questions
            SET question_text = q->>'question_text',
                question_type = (q->>'question_type')::poll_question_type,
                question_order = (q->>'question_order')::int
            WHERE id = question_id;
        END IF;

        -- Delete old options
        DELETE FROM poll_options WHERE question_id = question_id AND id NOT IN (SELECT (value->>'id')::uuid FROM jsonb_array_elements(q->'options') WHERE value->>'id' != '');

        FOR o IN SELECT * FROM jsonb_array_elements(q->'options')
        LOOP
            IF o->>'id' = '' THEN
                INSERT INTO poll_options (question_id, option_text, option_order)
                VALUES (question_id, o->>'option_text', (o->>'option_order')::int);
            ELSE
                UPDATE poll_options
                SET option_text = o->>'option_text',
                    option_order = (o->>'option_order')::int
                WHERE id = (o->>'id')::uuid;
            END IF;
        END LOOP;
    END LOOP;

    RETURN poll_id;
END;
$$ LANGUAGE plpgsql;

-- RPC for submitting a poll response
CREATE OR REPLACE FUNCTION submit_poll_response(p_poll_id uuid, p_user_id uuid, p_answers jsonb)
RETURNS void AS $$
DECLARE
    rec RECORD;
BEGIN
    -- Record the response to prevent re-voting
    INSERT INTO poll_responses (poll_id, user_id, answers) VALUES (p_poll_id, p_user_id, p_answers);

    -- Increment vote counts for each option
    FOR rec IN SELECT (value->>'optionId')::uuid as option_id FROM jsonb_array_elements(p_answers)
    LOOP
        UPDATE poll_options SET vote_count = vote_count + 1 WHERE id = rec.option_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- RPC for getting poll results
CREATE OR REPLACE FUNCTION get_poll_results(p_poll_id uuid)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'pollTitle', p.title,
        'totalResponses', (SELECT COUNT(*) FROM poll_responses pr WHERE pr.poll_id = p.id),
        'genderDistribution', (
            SELECT jsonb_agg(jsonb_build_object('name', COALESCE(u.gender, 'Unknown'), 'value', COUNT(*)))
            FROM poll_responses pr
            JOIN users u ON pr.user_id = u.id
            WHERE pr.poll_id = p.id
            GROUP BY u.gender
        ),
        'questions', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', pq.id,
                    'text', pq.question_text,
                    'answers', (
                        SELECT jsonb_agg(jsonb_build_object('name', po.option_text, 'value', po.vote_count))
                        FROM poll_options po
                        WHERE po.question_id = pq.id
                    )
                )
            )
            FROM poll_questions pq
            WHERE pq.poll_id = p.id
        )
    )
    INTO result
    FROM polls p
    WHERE p.id = p_poll_id;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- RPC to get ticket stats
CREATE OR REPLACE FUNCTION get_ticket_stats()
RETURNS TABLE (
    total bigint,
    open bigint,
    in_progress bigint,
    resolved bigint,
    closed bigint,
    avg_resolution_hours double precision
) AS $$
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
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. ROW LEVEL SECURITY (RLS)
-- =============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view all public profiles." ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update their own profile." ON public.users FOR UPDATE USING (auth.uid() = id);

ALTER TABLE public.leaders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view approved leaders." ON public.leaders FOR SELECT USING (status = 'approved'::public.leader_status);
CREATE POLICY "Authenticated users can add leaders." ON public.leaders FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can view their own pending/rejected leaders." ON public.leaders FOR SELECT USING (auth.uid() = "addedByUserId");
CREATE POLICY "Users can update leaders they added." ON public.leaders FOR UPDATE USING (auth.uid() = "addedByUserId");

ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view ratings." ON public.ratings FOR SELECT USING (true);
CREATE POLICY "Authenticated users can add/update their own ratings." ON public.ratings FOR ALL USING (auth.uid() = "userId");

ALTER TABLE public.admin_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view messages sent to them." ON public.admin_messages FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can mark their own messages as read." ON public.admin_messages FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view site settings." ON public.site_settings FOR SELECT USING (true);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can create support tickets." ON public.support_tickets FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can view their own tickets." ON public.support_tickets FOR SELECT USING (auth.uid() = user_id);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view notifications." ON public.notifications FOR SELECT USING (true);

ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view active polls." ON public.polls FOR SELECT USING (is_active = true);

ALTER TABLE public.poll_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view questions of active polls." ON public.poll_questions FOR SELECT USING (EXISTS (SELECT 1 FROM polls p WHERE p.id = poll_id AND p.is_active = true));

ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can view options of active polls." ON public.poll_options FOR SELECT USING (EXISTS (SELECT 1 FROM poll_questions pq JOIN polls p ON pq.poll_id = p.id WHERE pq.id = question_id AND p.is_active = true));

ALTER TABLE public.poll_responses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Authenticated users can submit a response." ON public.poll_responses FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Users can view their own responses." ON public.poll_responses FOR SELECT USING (auth.uid() = user_id);


-- Disable RLS for admin role to bypass all policies.
-- Create the admin role in Supabase UI under Database > Roles
-- Ensure this matches your JWT settings if using a custom JWT.
-- By default, Supabase bypasses RLS for roles with 'supabase_admin' or for the 'postgres' role.
-- If you create a custom 'admin' role, you would grant it bypass RLS privileges.
-- No SQL needed here if using the default service_role or postgres role for admin actions from the server.