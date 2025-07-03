-- =================================================================
--
--           PolitiRate Supabase Database Schema
--
-- This script will create all necessary tables, types, functions,
-- and security policies for the PolitiRate application.
--
-- Run this script in your Supabase SQL Editor.
--
-- =================================================================

-- Drop existing objects to ensure a clean setup
DROP TABLE IF EXISTS "public"."poll_answers" CASCADE;
DROP TABLE IF EXISTS "public"."poll_responses" CASCADE;
DROP TABLE IF EXISTS "public"."poll_options" CASCADE;
DROP TABLE IF EXISTS "public"."poll_questions" CASCADE;
DROP TABLE IF EXISTS "public"."polls" CASCADE;
DROP TABLE IF EXISTS "public"."support_tickets" CASCADE;
DROP TABLE IF EXISTS "public"."admin_messages" CASCADE;
DROP TABLE IF EXISTS "public"."ratings" CASCADE;
DROP TABLE IF EXISTS "public"."leaders" CASCADE;
DROP TABLE IF EXISTS "public"."site_settings" CASCADE;
DROP TABLE IF EXISTS "public"."profiles" CASCADE;

DROP TYPE IF EXISTS "public"."gender_enum";
DROP TYPE IF EXISTS "public"."election_type_enum";
DROP TYPE IF EXISTS "public"."leader_status_enum";
DROP TYPE IF EXISTS "public"."election_status_enum";
DROP TYPE IF EXISTS "public"."question_type_enum";
DROP TYPE IF EXISTS "public"."ticket_status_enum";
DROP TYPE IF EXISTS "public"."social_behaviour_enum";

-- =============================================
-- 1. Custom Types (ENUMs) for Data Integrity
-- =============================================

CREATE TYPE "public"."gender_enum" AS ENUM ('male', 'female', 'other');
CREATE TYPE "public"."election_type_enum" AS ENUM ('national', 'state', 'panchayat');
CREATE TYPE "public"."leader_status_enum" AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE "public"."election_status_enum" AS ENUM ('winner', 'loser');
CREATE TYPE "public"."question_type_enum" AS ENUM ('yes_no', 'multiple_choice');
CREATE TYPE "public"."ticket_status_enum" AS ENUM ('open', 'in-progress', 'resolved', 'closed');
CREATE TYPE "public"."social_behaviour_enum" AS ENUM (
    'social-worker', 'honest', 'corrupt', 'criminal',
    'aggressive', 'humble', 'fraud', 'average'
);


-- =============================================
-- 2. Table Creation
-- =============================================

-- Profiles table linked to Supabase Auth users
CREATE TABLE "public"."profiles" (
    "id" "uuid" NOT NULL,
    "name" "text",
    "gender" "public"."gender_enum",
    "age" "int2",
    "state" "text",
    "mp_constituency" "text",
    "mla_constituency" "text",
    "panchayat" "text",
    "created_at" "timestamptz" DEFAULT "now"() NOT NULL,
    "is_blocked" "bool" DEFAULT false NOT NULL,
    "blocked_until" "timestamptz",
    "block_reason" "text",
    CONSTRAINT "profiles_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE
);
ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;

-- Leaders table
CREATE TABLE "public"."leaders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "party_name" "text" NOT NULL,
    "gender" "public"."gender_enum" NOT NULL,
    "age" "int2" NOT NULL,
    "photo_url" "text",
    "constituency" "text" NOT NULL,
    "native_address" "text" NOT NULL,
    "election_type" "public"."election_type_enum" NOT NULL,
    "location" "jsonb",
    "rating" "float4" DEFAULT '0'::"real" NOT NULL,
    "review_count" "int4" DEFAULT 0 NOT NULL,
    "previous_elections" "jsonb",
    "manifesto_url" "text",
    "twitter_url" "text",
    "added_by_user_id" "uuid",
    "created_at" "timestamptz" DEFAULT "now"() NOT NULL,
    "status" "public"."leader_status_enum" DEFAULT 'pending'::"public"."leader_status_enum" NOT NULL,
    "admin_comment" "text",
    CONSTRAINT "leaders_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "leaders_added_by_user_id_fkey" FOREIGN KEY ("added_by_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL
);
ALTER TABLE "public"."leaders" ENABLE ROW LEVEL SECURITY;

-- Ratings table
CREATE TABLE "public"."ratings" (
    "user_id" "uuid" NOT NULL,
    "leader_id" "uuid" NOT NULL,
    "rating" "int2" NOT NULL,
    "social_behaviour" "public"."social_behaviour_enum",
    "comment" "text",
    "created_at" "timestamptz" DEFAULT "now"() NOT NULL,
    "updated_at" "timestamptz" DEFAULT "now"() NOT NULL,
    CONSTRAINT "ratings_pkey" PRIMARY KEY ("user_id", "leader_id"),
    CONSTRAINT "ratings_leader_id_fkey" FOREIGN KEY ("leader_id") REFERENCES "public"."leaders"("id") ON DELETE CASCADE,
    CONSTRAINT "ratings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE,
    CONSTRAINT "ratings_rating_check" CHECK (("rating" >= 1) AND ("rating" <= 5))
);
ALTER TABLE "public"."ratings" ENABLE ROW LEVEL SECURITY;

-- Site Settings table
CREATE TABLE "public"."site_settings" (
    "key" "text" NOT NULL,
    "value" "text",
    CONSTRAINT "site_settings_pkey" PRIMARY KEY ("key")
);
-- RLS for settings: public read, admin write
ALTER TABLE "public"."site_settings" ENABLE ROW LEVEL SECURITY;

-- Admin Messages table
CREATE TABLE "public"."admin_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "message" "text" NOT NULL,
    "is_read" "bool" DEFAULT false NOT NULL,
    "created_at" "timestamptz" DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_messages_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "admin_messages_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE
);
ALTER TABLE "public"."admin_messages" ENABLE ROW LEVEL SECURITY;

-- Support Tickets table
CREATE TABLE "public"."support_tickets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "user_name" "text" NOT NULL,
    "user_email" "text" NOT NULL,
    "subject" "text" NOT NULL,
    "message" "text" NOT NULL,
    "status" "public"."ticket_status_enum" DEFAULT 'open'::"public"."ticket_status_enum" NOT NULL,
    "created_at" "timestamptz" DEFAULT "now"() NOT NULL,
    "updated_at" "timestamptz" DEFAULT "now"() NOT NULL,
    "resolved_at" "timestamptz",
    "admin_notes" "text",
    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "support_tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL
);
ALTER TABLE "public"."support_tickets" ENABLE ROW LEVEL SECURITY;

-- Polls tables
CREATE TABLE "public"."polls" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "is_active" "bool" DEFAULT false NOT NULL,
    "active_until" "timestamptz",
    "response_count" "int4" DEFAULT 0 NOT NULL,
    "created_at" "timestamptz" DEFAULT "now"() NOT NULL,
    CONSTRAINT "polls_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "public"."polls" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."poll_questions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "poll_id" "uuid" NOT NULL,
    "question_text" "text" NOT NULL,
    "question_type" "public"."question_type_enum" NOT NULL,
    "question_order" "int2" NOT NULL,
    CONSTRAINT "poll_questions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "poll_questions_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "public"."polls"("id") ON DELETE CASCADE
);
ALTER TABLE "public"."poll_questions" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."poll_options" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "question_id" "uuid" NOT NULL,
    "option_text" "text" NOT NULL,
    "option_order" "int2" NOT NULL,
    "vote_count" "int4" DEFAULT 0 NOT NULL,
    CONSTRAINT "poll_options_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "poll_options_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."poll_questions"("id") ON DELETE CASCADE
);
ALTER TABLE "public"."poll_options" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."poll_responses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "poll_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" "timestamptz" DEFAULT "now"() NOT NULL,
    CONSTRAINT "poll_responses_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "poll_responses_poll_id_user_id_key" UNIQUE ("poll_id", "user_id"),
    CONSTRAINT "poll_responses_poll_id_fkey" FOREIGN KEY ("poll_id") REFERENCES "public"."polls"("id") ON DELETE CASCADE,
    CONSTRAINT "poll_responses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE
);
ALTER TABLE "public"."poll_responses" ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."poll_answers" (
    "response_id" "uuid" NOT NULL,
    "question_id" "uuid" NOT NULL,
    "selected_option_id" "uuid" NOT NULL,
    CONSTRAINT "poll_answers_pkey" PRIMARY KEY ("response_id", "question_id"),
    CONSTRAINT "poll_answers_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "public"."poll_questions"("id") ON DELETE CASCADE,
    CONSTRAINT "poll_answers_response_id_fkey" FOREIGN KEY ("response_id") REFERENCES "public"."poll_responses"("id") ON DELETE CASCADE,
    CONSTRAINT "poll_answers_selected_option_id_fkey" FOREIGN KEY ("selected_option_id") REFERENCES "public"."poll_options"("id") ON DELETE CASCADE
);
ALTER TABLE "public"."poll_answers" ENABLE ROW LEVEL SECURITY;

-- =============================================
-- 3. Database Functions & Triggers
-- =============================================

-- Function to check if a user is an admin
-- In a real app, you would have a more secure way to manage roles.
-- For this prototype, we'll check against a specific email.
CREATE OR REPLACE FUNCTION "public"."is_admin"()
RETURNS boolean
LANGUAGE "plpgsql"
AS $$
BEGIN
  RETURN auth.jwt()->>'email' = 'Admin';
END;
$$;


-- Function to create a user profile automatically on new user signup
CREATE OR REPLACE FUNCTION "public"."handle_new_user"()
RETURNS "trigger"
LANGUAGE "plpgsql"
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'displayName');
  RETURN NEW;
END;
$$;

-- Trigger to call handle_new_user on new user creation
CREATE TRIGGER "on_auth_user_created"
AFTER INSERT ON "auth"."users"
FOR EACH ROW EXECUTE PROCEDURE "public"."handle_new_user"();


-- Function to update the average rating and review count on the leaders table
CREATE OR REPLACE FUNCTION "public"."update_leader_rating"()
RETURNS "trigger"
LANGUAGE "plpgsql"
AS $$
DECLARE
  new_rating float4;
  new_review_count int4;
BEGIN
  SELECT
    AVG(rating),
    COUNT(rating)
  INTO
    new_rating,
    new_review_count
  FROM
    public.ratings
  WHERE
    leader_id = COALESCE(NEW.leader_id, OLD.leader_id);

  UPDATE public.leaders
  SET
    rating = COALESCE(new_rating, 0),
    review_count = COALESCE(new_review_count, 0)
  WHERE
    id = COALESCE(NEW.leader_id, OLD.leader_id);

  RETURN NULL;
END;
$$;

-- Trigger to call update_leader_rating after changes to the ratings table
CREATE TRIGGER "rating_changed_trigger"
AFTER INSERT OR UPDATE OR DELETE ON "public"."ratings"
FOR EACH ROW EXECUTE PROCEDURE "public"."update_leader_rating"();


-- Function to update poll response counts
CREATE OR REPLACE FUNCTION "public"."update_poll_counts"()
RETURNS "trigger"
LANGUAGE "plpgsql"
AS $$
BEGIN
  -- Increment option count
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.poll_options
    SET vote_count = vote_count + 1
    WHERE id = NEW.selected_option_id;

    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

-- Function to update the main poll response count after a new response is added
CREATE OR REPLACE FUNCTION "public"."update_poll_response_count"()
RETURNS "trigger"
LANGUAGE "plpgsql"
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.polls
    SET response_count = response_count + 1
    WHERE id = NEW.poll_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.polls
    SET response_count = response_count - 1
    WHERE id = OLD.poll_id;
  END IF;
  
  RETURN NULL;
END;
$$;

-- Trigger to call update_poll_counts when a new poll answer is inserted
CREATE TRIGGER "poll_answer_added"
AFTER INSERT ON "public"."poll_answers"
FOR EACH ROW EXECUTE PROCEDURE "public"."update_poll_counts"();

-- Trigger for the main poll response counter
CREATE TRIGGER "poll_response_added_or_deleted"
AFTER INSERT OR DELETE ON "public"."poll_responses"
FOR EACH ROW EXECUTE PROCEDURE "public"."update_poll_response_count"();


-- =============================================
-- 4. Row Level Security (RLS) Policies
-- =============================================

-- Profiles Policies
CREATE POLICY "Users can view their own profile." ON "public"."profiles"
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile." ON "public"."profiles"
FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Leaders Policies
CREATE POLICY "Public can view approved leaders." ON "public"."leaders"
FOR SELECT USING (status = 'approved'::leader_status_enum);

CREATE POLICY "Authenticated users can create leaders." ON "public"."leaders"
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Submitter or admin can update leaders." ON "public"."leaders"
FOR UPDATE USING (auth.uid() = added_by_user_id OR is_admin()) WITH CHECK (auth.uid() = added_by_user_id OR is_admin());

CREATE POLICY "Admins can delete leaders." ON "public"."leaders"
FOR DELETE USING (is_admin());

-- Ratings Policies
CREATE POLICY "Public can view all ratings." ON "public"."ratings"
FOR SELECT USING (true);

CREATE POLICY "Users can manage their own ratings." ON "public"."ratings"
FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Site Settings Policies
CREATE POLICY "Public can read site settings." ON "public"."site_settings"
FOR SELECT USING (true);

CREATE POLICY "Admins can update site settings." ON "public"."site_settings"
FOR UPDATE USING (is_admin());

-- Admin Messages Policies
CREATE POLICY "Users can view their own admin messages." ON "public"."admin_messages"
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all admin messages." ON "public"."admin_messages"
FOR ALL USING (is_admin());

-- Support Tickets Policies
CREATE POLICY "Users can create support tickets." ON "public"."support_tickets"
FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'anon');

CREATE POLICY "Admins can manage all support tickets." ON "public"."support_tickets"
FOR ALL USING (is_admin());

-- Polls Policies
CREATE POLICY "Public can view active polls." ON "public"."polls"
FOR SELECT USING (is_active = true AND (active_until IS NULL OR active_until > now()));

CREATE POLICY "Admins can manage polls." ON "public"."polls"
FOR ALL USING (is_admin());

CREATE POLICY "Public can view poll questions and options." ON "public"."poll_questions"
FOR SELECT USING (true);
CREATE POLICY "Admins can manage poll questions." ON "public"."poll_questions"
FOR ALL USING (is_admin());
CREATE POLICY "Admins can manage poll options." ON "public"."poll_options"
FOR ALL USING (is_admin());

CREATE POLICY "Authenticated users can create poll responses." ON "public"."poll_responses"
FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can see poll responses." ON "public"."poll_responses"
FOR SELECT USING (is_admin());

CREATE POLICY "Users can create their own answers." ON "public"."poll_answers"
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM poll_responses
        WHERE id = response_id AND user_id = auth.uid()
    )
);
CREATE POLICY "Admins can see poll answers." ON "public"."poll_answers"
FOR SELECT USING (is_admin());

-- =============================================
-- 5. Seeding Initial Data (Optional)
-- =============================================

-- Seed site settings with default values
INSERT INTO "public"."site_settings" (key, value) VALUES
('maintenance_active', 'false'),
('maintenance_message', 'The site is currently down for maintenance. We will be back shortly.'),
('contact_email', 'support@politirate.com'),
('contact_phone', NULL),
('contact_twitter', NULL),
('contact_linkedin', NULL),
('contact_youtube', NULL),
('contact_facebook', NULL)
ON CONFLICT (key) DO NOTHING;

-- You can add initial leaders or users here if needed.
-- Example:
-- INSERT INTO "public"."leaders" (name, party_name, gender, age, ...) VALUES (...);

-- End of script
