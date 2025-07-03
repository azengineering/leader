
-- =================================================================
--
--           PolitiRate Supabase Database Schema (Complete)
--
-- This script creates all necessary tables, types, functions,
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
DROP TABLE IF EXISTS "public"."notifications" CASCADE;
DROP TABLE IF EXISTS "public"."admin_messages" CASCADE;
DROP TABLE IF EXISTS "public"."ratings" CASCADE;
DROP TABLE IF EXISTS "public"."leaders" CASCADE;
DROP TABLE IF EXISTS "public"."site_settings" CASCADE;
DROP TABLE IF EXISTS "public"."profiles" CASCADE;
DROP TABLE IF EXISTS "public"."users" CASCADE;

DROP TYPE IF EXISTS "public"."gender_enum";
DROP TYPE IF EXISTS "public"."election_type_enum";
DROP TYPE IF EXISTS "public"."leader_status_enum";
DROP TYPE IF EXISTS "public"."election_status_enum";
DROP TYPE IF EXISTS "public"."question_type_enum";
DROP TYPE IF EXISTS "public"."ticket_status_enum";
DROP TYPE IF EXISTS "public"."social_behaviour_enum";
DROP TYPE IF EXISTS "public"."notification_type_enum";

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
CREATE TYPE "public"."notification_type_enum" AS ENUM ('info', 'warning', 'success', 'error');

-- =============================================
-- 2. Table Creation
-- =============================================

-- Users table (extending auth.users with profile data)
CREATE TABLE "public"."users" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "name" "text",
    "gender" "public"."gender_enum",
    "age" "int2",
    "state" "text",
    "mpConstituency" "text",
    "mlaConstituency" "text",
    "panchayat" "text",
    "createdAt" "timestamptz" DEFAULT "now"() NOT NULL,
    "isBlocked" "bool" DEFAULT false NOT NULL,
    "blockedUntil" "timestamptz",
    "blockReason" "text",
    CONSTRAINT "users_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE
);
ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;

-- Profiles table (for additional user profile data)
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
    "partyName" "text" NOT NULL,
    "gender" "public"."gender_enum" NOT NULL,
    "age" "int2" NOT NULL,
    "photoUrl" "text",
    "constituency" "text" NOT NULL,
    "nativeAddress" "text" NOT NULL,
    "electionType" "public"."election_type_enum" NOT NULL,
    "location" "jsonb",
    "rating" "float4" DEFAULT '0'::real NOT NULL,
    "reviewCount" "int4" DEFAULT 0 NOT NULL,
    "previousElections" "jsonb",
    "manifestoUrl" "text",
    "twitterUrl" "text",
    "addedByUserId" "uuid",
    "createdAt" "timestamptz" DEFAULT "now"() NOT NULL,
    "status" "public"."leader_status_enum" DEFAULT 'pending'::"public"."leader_status_enum" NOT NULL,
    "adminComment" "text",
    CONSTRAINT "leaders_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "leaders_addedByUserId_fkey" FOREIGN KEY ("addedByUserId") REFERENCES "auth"."users"("id") ON DELETE SET NULL
);
ALTER TABLE "public"."leaders" ENABLE ROW LEVEL SECURITY;

-- Ratings table
CREATE TABLE "public"."ratings" (
    "userId" "uuid" NOT NULL,
    "leaderId" "uuid" NOT NULL,
    "rating" "int2" NOT NULL,
    "socialBehaviour" "public"."social_behaviour_enum",
    "comment" "text",
    "createdAt" "timestamptz" DEFAULT "now"() NOT NULL,
    "updatedAt" "timestamptz" DEFAULT "now"() NOT NULL,
    CONSTRAINT "ratings_pkey" PRIMARY KEY ("userId", "leaderId"),
    CONSTRAINT "ratings_leaderId_fkey" FOREIGN KEY ("leaderId") REFERENCES "public"."leaders"("id") ON DELETE CASCADE,
    CONSTRAINT "ratings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "auth"."users"("id") ON DELETE CASCADE,
    CONSTRAINT "ratings_rating_check" CHECK (("rating" >= 1) AND ("rating" <= 5))
);
ALTER TABLE "public"."ratings" ENABLE ROW LEVEL SECURITY;

-- Site Settings table
CREATE TABLE "public"."site_settings" (
    "key" "text" NOT NULL,
    "value" "text",
    CONSTRAINT "site_settings_pkey" PRIMARY KEY ("key")
);
ALTER TABLE "public"."site_settings" ENABLE ROW LEVEL SECURITY;

-- Notifications table
CREATE TABLE "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "type" "public"."notification_type_enum" DEFAULT 'info'::"public"."notification_type_enum" NOT NULL,
    "isActive" "bool" DEFAULT true NOT NULL,
    "createdAt" "timestamptz" DEFAULT "now"() NOT NULL,
    "expiresAt" "timestamptz",
    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;

-- Admin Messages table
CREATE TABLE "public"."admin_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "message" "text" NOT NULL,
    "isRead" "bool" DEFAULT false NOT NULL,
    "createdAt" "timestamptz" DEFAULT "now"() NOT NULL,
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
-- 3. Functions and Triggers
-- =============================================

-- Function to check if a user is an admin
CREATE OR REPLACE FUNCTION "public"."is_admin"()
RETURNS boolean
LANGUAGE "plpgsql"
SECURITY DEFINER
AS $$
BEGIN
  RETURN auth.jwt()->>'email' = 'admin@politirate.com' OR 
         auth.jwt()->>'role' = 'admin' OR
         auth.jwt()->>'user_role' = 'admin';
END;
$$;

-- Function to ensure a user profile exists
CREATE OR REPLACE FUNCTION "public"."ensure_user_profile_exists"()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert into users table if not exists
  INSERT INTO public.users (id, email, name)
  SELECT 
    auth.uid(), 
    auth.jwt() ->> 'email',
    COALESCE(
      auth.jwt() ->> 'user_metadata' ->> 'name', 
      auth.jwt() ->> 'user_metadata' ->> 'full_name',
      split_part(auth.jwt() ->> 'email', '@', 1)
    )
  WHERE auth.uid() IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid());
  
  -- Also insert into profiles table for backward compatibility
  INSERT INTO public.profiles (id, name)
  SELECT 
    auth.uid(), 
    COALESCE(
      auth.jwt() ->> 'user_metadata' ->> 'name', 
      auth.jwt() ->> 'user_metadata' ->> 'full_name',
      split_part(auth.jwt() ->> 'email', '@', 1)
    )
  WHERE auth.uid() IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid());
END;
$$;

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION "public"."handle_new_user"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert into users table
  INSERT INTO public.users (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data ->> 'name', 
      NEW.raw_user_meta_data ->> 'full_name',
      split_part(NEW.email, '@', 1)
    )
  );
  
  -- Insert into profiles table for backward compatibility
  INSERT INTO public.profiles (id, name)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data ->> 'name', 
      NEW.raw_user_meta_data ->> 'full_name',
      split_part(NEW.email, '@', 1)
    )
  );
  
  RETURN NEW;
END;
$$;

-- Trigger to automatically create profile on user signup
CREATE OR REPLACE TRIGGER "on_auth_user_created"
  AFTER INSERT ON "auth"."users"
  FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_user"();

-- Function to update leader ratings
CREATE OR REPLACE FUNCTION "public"."update_leader_rating"()
RETURNS trigger
LANGUAGE plpgsql
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
    "leaderId" = COALESCE(NEW."leaderId", OLD."leaderId");

  UPDATE public.leaders
  SET
    rating = COALESCE(new_rating, 0),
    "reviewCount" = COALESCE(new_review_count, 0)
  WHERE
    id = COALESCE(NEW."leaderId", OLD."leaderId");

  RETURN NULL;
END;
$$;

-- Trigger to update leader ratings
CREATE OR REPLACE TRIGGER "rating_changed_trigger"
  AFTER INSERT OR UPDATE OR DELETE ON "public"."ratings"
  FOR EACH ROW EXECUTE FUNCTION "public"."update_leader_rating"();

-- Function to handle new rating with upsert logic
CREATE OR REPLACE FUNCTION "public"."handle_new_rating"(
  p_leader_id uuid,
  p_user_id uuid,
  p_rating int,
  p_comment text DEFAULT NULL,
  p_social_behaviour text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.ratings ("leaderId", "userId", rating, comment, "socialBehaviour", "updatedAt")
  VALUES (p_leader_id, p_user_id, p_rating, p_comment, p_social_behaviour::social_behaviour_enum, now())
  ON CONFLICT ("userId", "leaderId") 
  DO UPDATE SET
    rating = EXCLUDED.rating,
    comment = EXCLUDED.comment,
    "socialBehaviour" = EXCLUDED."socialBehaviour",
    "updatedAt" = now();
END;
$$;

-- Function to handle rating deletion
CREATE OR REPLACE FUNCTION "public"."handle_rating_deletion"(
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

-- Function to get reviews for a leader
CREATE OR REPLACE FUNCTION "public"."get_reviews_for_leader"(p_leader_id uuid)
RETURNS TABLE(
    "userName" text,
    rating int,
    comment text,
    "updatedAt" timestamptz,
    "socialBehaviour" text
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    COALESCE(u.name, 'Anonymous') as "userName",
    r.rating,
    r.comment,
    r."updatedAt",
    r."socialBehaviour"::text
  FROM public.ratings r
  LEFT JOIN public.users u ON r."userId" = u.id
  WHERE r."leaderId" = p_leader_id
  ORDER BY r."updatedAt" DESC;
$$;

-- Function to get user activities
CREATE OR REPLACE FUNCTION "public"."get_user_activities"(p_user_id uuid)
RETURNS TABLE (
    "leaderId" uuid,
    "leaderName" text,
    "leaderPhotoUrl" text,
    rating int,
    comment text,
    "updatedAt" timestamptz,
    leader jsonb,
    "socialBehaviour" text,
    "userName" text
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    r."leaderId",
    l.name as "leaderName",
    l."photoUrl" as "leaderPhotoUrl",
    r.rating,
    r.comment,
    r."updatedAt",
    row_to_json(l) as leader,
    r."socialBehaviour"::text,
    COALESCE(u.name, 'Anonymous') as "userName"
  FROM public.ratings r
  JOIN public.leaders l ON r."leaderId" = l.id
  LEFT JOIN public.users u ON r."userId" = u.id
  WHERE r."userId" = p_user_id
  ORDER BY r."updatedAt" DESC;
$$;

-- Function to get all activities (for admin)
CREATE OR REPLACE FUNCTION "public"."get_all_activities"()
RETURNS TABLE (
    "leaderId" uuid,
    "leaderName" text,
    "leaderPhotoUrl" text,
    rating int,
    comment text,
    "updatedAt" timestamptz,
    leader jsonb,
    "socialBehaviour" text,
    "userName" text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    r."leaderId",
    l.name as "leaderName",
    l."photoUrl" as "leaderPhotoUrl",
    r.rating,
    r.comment,
    r."updatedAt",
    row_to_json(l) as leader,
    r."socialBehaviour"::text,
    COALESCE(u.name, 'Anonymous') as "userName"
  FROM public.ratings r
  JOIN public.leaders l ON r."leaderId" = l.id
  LEFT JOIN public.users u ON r."userId" = u.id
  ORDER BY r."updatedAt" DESC;
$$;

-- Function to update poll counts
CREATE OR REPLACE FUNCTION "public"."update_poll_counts"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.poll_options
    SET vote_count = vote_count + 1
    WHERE id = NEW.selected_option_id;
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$;

-- Function to update poll response count
CREATE OR REPLACE FUNCTION "public"."update_poll_response_count"()
RETURNS trigger
LANGUAGE plpgsql
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

-- Triggers for poll management
CREATE OR REPLACE TRIGGER "poll_answer_added"
  AFTER INSERT ON "public"."poll_answers"
  FOR EACH ROW EXECUTE FUNCTION "public"."update_poll_counts"();

CREATE OR REPLACE TRIGGER "poll_response_added_or_deleted"
  AFTER INSERT OR DELETE ON "public"."poll_responses"
  FOR EACH ROW EXECUTE FUNCTION "public"."update_poll_response_count"();

-- =============================================
-- 4. Row Level Security (RLS) Policies
-- =============================================

-- Users table policies
CREATE POLICY "Users can view any user profile" ON "public"."users"
FOR SELECT USING (true);

CREATE POLICY "Users can update their own profile" ON "public"."users"
FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can manage all users" ON "public"."users"
FOR ALL USING (is_admin());

-- Profiles table policies
CREATE POLICY "Users can view their own profile" ON "public"."profiles"
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON "public"."profiles"
FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "Admins can manage all profiles" ON "public"."profiles"
FOR ALL USING (is_admin());

-- Leaders table policies
CREATE POLICY "Public can view approved leaders" ON "public"."leaders"
FOR SELECT USING (status = 'approved'::leader_status_enum OR is_admin());

CREATE POLICY "Authenticated users can create leaders" ON "public"."leaders"
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can view their own submitted leaders" ON "public"."leaders"
FOR SELECT USING (auth.uid() = "addedByUserId");

CREATE POLICY "Users can update their own submitted leaders" ON "public"."leaders"
FOR UPDATE USING (auth.uid() = "addedByUserId") WITH CHECK (auth.uid() = "addedByUserId");

CREATE POLICY "Admins can manage all leaders" ON "public"."leaders"
FOR ALL USING (is_admin());

-- Ratings table policies
CREATE POLICY "Public can view all ratings" ON "public"."ratings"
FOR SELECT USING (true);

CREATE POLICY "Users can manage their own ratings" ON "public"."ratings"
FOR ALL USING (auth.uid() = "userId") WITH CHECK (auth.uid() = "userId");

CREATE POLICY "Admins can manage all ratings" ON "public"."ratings"
FOR ALL USING (is_admin());

-- Site Settings policies
CREATE POLICY "Public can read site settings" ON "public"."site_settings"
FOR SELECT USING (true);

CREATE POLICY "Admins can manage site settings" ON "public"."site_settings"
FOR ALL USING (is_admin());

-- Notifications policies
CREATE POLICY "Public can view active notifications" ON "public"."notifications"
FOR SELECT USING ("isActive" = true OR is_admin());

CREATE POLICY "Admins can manage notifications" ON "public"."notifications"
FOR ALL USING (is_admin());

-- Admin Messages policies
CREATE POLICY "Users can view their own messages" ON "public"."admin_messages"
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can mark their own messages as read" ON "public"."admin_messages"
FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all messages" ON "public"."admin_messages"
FOR ALL USING (is_admin());

-- Support Tickets policies
CREATE POLICY "Users can create support tickets" ON "public"."support_tickets"
FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'anon');

CREATE POLICY "Users can view their own tickets" ON "public"."support_tickets"
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all tickets" ON "public"."support_tickets"
FOR ALL USING (is_admin());

-- Poll policies
CREATE POLICY "Public can view active polls" ON "public"."polls"
FOR SELECT USING (is_active = true AND (active_until IS NULL OR active_until > now()) OR is_admin());

CREATE POLICY "Admins can manage polls" ON "public"."polls"
FOR ALL USING (is_admin());

CREATE POLICY "Public can view poll questions" ON "public"."poll_questions"
FOR SELECT USING (true);

CREATE POLICY "Admins can manage poll questions" ON "public"."poll_questions"
FOR ALL USING (is_admin());

CREATE POLICY "Public can view poll options" ON "public"."poll_options"
FOR SELECT USING (true);

CREATE POLICY "Admins can manage poll options" ON "public"."poll_options"
FOR ALL USING (is_admin());

CREATE POLICY "Authenticated users can create poll responses" ON "public"."poll_responses"
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own responses" ON "public"."poll_responses"
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all responses" ON "public"."poll_responses"
FOR SELECT USING (is_admin());

CREATE POLICY "Users can create their own poll answers" ON "public"."poll_answers"
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM poll_responses
        WHERE id = response_id AND user_id = auth.uid()
    )
);

CREATE POLICY "Admins can view all poll answers" ON "public"."poll_answers"
FOR SELECT USING (is_admin());

-- =============================================
-- 5. Initial Data Seeding
-- =============================================

-- Seed site settings
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

-- Create a sample notification
INSERT INTO "public"."notifications" (title, message, type, "isActive") VALUES
('Welcome to PolitiRate', 'Rate and review your political leaders to make informed decisions!', 'info', true)
ON CONFLICT DO NOTHING;

-- =============================================
-- 6. Additional Indexes for Performance
-- =============================================

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS "idx_leaders_status" ON "public"."leaders" ("status");
CREATE INDEX IF NOT EXISTS "idx_leaders_election_type" ON "public"."leaders" ("electionType");
CREATE INDEX IF NOT EXISTS "idx_leaders_location" ON "public"."leaders" USING GIN ("location");
CREATE INDEX IF NOT EXISTS "idx_ratings_leader_id" ON "public"."ratings" ("leaderId");
CREATE INDEX IF NOT EXISTS "idx_ratings_user_id" ON "public"."ratings" ("userId");
CREATE INDEX IF NOT EXISTS "idx_ratings_updated_at" ON "public"."ratings" ("updatedAt");
CREATE INDEX IF NOT EXISTS "idx_notifications_active" ON "public"."notifications" ("isActive");
CREATE INDEX IF NOT EXISTS "idx_admin_messages_user_read" ON "public"."admin_messages" (user_id, "isRead");

-- End of schema
