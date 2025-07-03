-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop existing tables if they exist (in correct order to handle dependencies)
DROP TABLE IF EXISTS public.admin_messages CASCADE;
DROP TABLE IF EXISTS public.ratings CASCADE;
DROP TABLE IF EXISTS public.poll_votes CASCADE;
DROP TABLE IF EXISTS public.polls CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.leaders CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;
DROP TABLE IF EXISTS public.site_settings CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_rating(uuid,uuid,integer,text,text) CASCADE;
DROP FUNCTION IF EXISTS public.ensure_user_profile_exists() CASCADE;
DROP FUNCTION IF EXISTS public.create_admin_user(text) CASCADE;

-- Create profiles table (renamed from users to match admin auth code)
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    name TEXT,
    role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin', 'super_admin')),
    location TEXT,
    age INTEGER,
    political_affiliation TEXT,
    is_blocked BOOLEAN DEFAULT FALSE,
    block_reason TEXT,
    blocked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create leaders table
CREATE TABLE public.leaders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    position TEXT NOT NULL,
    party TEXT,
    location TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    added_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create ratings table
CREATE TABLE public.ratings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    leader_id UUID NOT NULL REFERENCES public.leaders(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review TEXT,
    category TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, leader_id)
);

-- Create polls table
CREATE TABLE public.polls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    description TEXT,
    options JSONB NOT NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create poll_votes table
CREATE TABLE public.poll_votes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    option_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(poll_id, user_id)
);

-- Create notifications table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT DEFAULT 'info' CHECK (type IN ('info', 'warning', 'success', 'error')),
    is_active BOOLEAN DEFAULT TRUE,
    target_audience TEXT DEFAULT 'all' CHECK (target_audience IN ('all', 'users', 'admins')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- Create admin_messages table
CREATE TABLE public.admin_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create site_settings table
CREATE TABLE public.site_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key TEXT UNIQUE NOT NULL,
    value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default site settings
INSERT INTO public.site_settings (key, value) VALUES
('maintenance_active', 'false'),
('maintenance_message', 'Site is under maintenance. Please check back later.'),
('contact_email', 'admin@politirate.com'),
('contact_phone', ''),
('contact_twitter', ''),
('contact_linkedin', ''),
('contact_youtube', ''),
('contact_facebook', '');

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Public profiles are viewable by all" ON public.profiles
    FOR SELECT USING (true);

-- Leaders policies
CREATE POLICY "Anyone can view leaders" ON public.leaders
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert leaders" ON public.leaders
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update leaders they added" ON public.leaders
    FOR UPDATE USING (added_by_user_id = auth.uid());

-- Ratings policies  
CREATE POLICY "Anyone can view ratings" ON public.ratings
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert ratings" ON public.ratings
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own ratings" ON public.ratings
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own ratings" ON public.ratings
    FOR DELETE USING (auth.uid() = user_id);

-- Polls policies
CREATE POLICY "Anyone can view active polls" ON public.polls
    FOR SELECT USING (is_active = true OR created_by = auth.uid());

CREATE POLICY "Authenticated users can create polls" ON public.polls
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Poll creators can update their polls" ON public.polls
    FOR UPDATE USING (created_by = auth.uid());

-- Poll votes policies
CREATE POLICY "Users can view poll votes" ON public.poll_votes
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can vote" ON public.poll_votes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own votes" ON public.poll_votes
    FOR UPDATE USING (auth.uid() = user_id);

-- Notifications policies
CREATE POLICY "Anyone can view active notifications" ON public.notifications
    FOR SELECT USING (is_active = true);

-- Admin messages policies
CREATE POLICY "Users can view their own messages" ON public.admin_messages
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own messages" ON public.admin_messages
    FOR UPDATE USING (auth.uid() = user_id);

-- Site settings policies
CREATE POLICY "Anyone can view site settings" ON public.site_settings
    FOR SELECT USING (true);

-- Functions
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
        'user'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

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
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id = user_id) THEN
        RETURN;
    END IF;

    -- Get user info from auth.users
    SELECT email, COALESCE(raw_user_meta_data->>'name', split_part(email, '@', 1))
    INTO user_email, user_name
    FROM auth.users
    WHERE id = user_id;

    -- Create profile
    INSERT INTO public.profiles (id, email, name, role)
    VALUES (user_id, user_email, user_name, 'user');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.create_admin_user(admin_email TEXT)
RETURNS TEXT AS $$
DECLARE
    user_id UUID;
BEGIN
    -- Get user ID from email
    SELECT id INTO user_id
    FROM auth.users
    WHERE email = admin_email;

    IF user_id IS NULL THEN
        RETURN 'User not found with email: ' || admin_email;
    END IF;

    -- Update or insert profile with admin role
    INSERT INTO public.profiles (id, email, name, role)
    VALUES (user_id, admin_email, split_part(admin_email, '@', 1), 'super_admin')
    ON CONFLICT (id) 
    DO UPDATE SET role = 'super_admin';

    RETURN 'User ' || admin_email || ' has been granted super_admin privileges';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.handle_new_rating(
    p_leader_id UUID,
    p_user_id UUID,
    p_rating INTEGER,
    p_review TEXT,
    p_category TEXT
)
RETURNS UUID AS $$
DECLARE
    rating_id UUID;
BEGIN
    INSERT INTO public.ratings (leader_id, user_id, rating, review, category)
    VALUES (p_leader_id, p_user_id, p_rating, p_review, p_category)
    ON CONFLICT (user_id, leader_id)
    DO UPDATE SET
        rating = EXCLUDED.rating,
        review = EXCLUDED.review,
        category = EXCLUDED.category,
        updated_at = NOW()
    RETURNING id INTO rating_id;

    RETURN rating_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Triggers
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create indexes for better performance
CREATE INDEX idx_profiles_email ON public.profiles(email);
CREATE INDEX idx_profiles_role ON public.profiles(role);
CREATE INDEX idx_leaders_location ON public.leaders(location);
CREATE INDEX idx_leaders_party ON public.leaders(party);
CREATE INDEX idx_ratings_leader_id ON public.ratings(leader_id);
CREATE INDEX idx_ratings_user_id ON public.ratings(user_id);
CREATE INDEX idx_ratings_rating ON public.ratings(rating);
CREATE INDEX idx_polls_is_active ON public.polls(is_active);
CREATE INDEX idx_poll_votes_poll_id ON public.poll_votes(poll_id);
CREATE INDEX idx_notifications_is_active ON public.notifications(is_active);
CREATE INDEX idx_admin_messages_user_id ON public.admin_messages(user_id);
CREATE INDEX idx_admin_messages_is_read ON public.admin_messages(is_read);
CREATE INDEX idx_site_settings_key ON public.site_settings(key);