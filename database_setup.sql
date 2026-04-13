-- Unified Database Setup Script for PlantPulse
-- Run this in the Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)

-- 1. Create Profiles Table (for user metadata)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT DEFAULT '',
    phone TEXT DEFAULT '',
    location TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Create Scan History Table
CREATE TABLE IF NOT EXISTS public.scan_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    crop_name TEXT NOT NULL,
    disease_result TEXT NOT NULL,
    confidence_score FLOAT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Create Spray Reminders Table
CREATE TABLE IF NOT EXISTS public.spray_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    plant_name TEXT NOT NULL,
    disease_name TEXT NOT NULL,
    treatment_type TEXT NOT NULL,
    scheduled_time TIMESTAMPTZ NOT NULL,
    is_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scan_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.spray_reminders ENABLE ROW LEVEL SECURITY;

-- 5. Policies for Profiles
CREATE POLICY "Users can view their own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Service Role can manage all profiles" ON public.profiles
    USING (true) WITH CHECK (true);

-- 6. Policies for Scan History
CREATE POLICY "Users can view their own scans" ON public.scan_history
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own scans" ON public.scan_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 7. Policies for Spray Reminders
CREATE POLICY "Users can view their own reminders" ON public.spray_reminders
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own reminders" ON public.spray_reminders
    FOR ALL USING (auth.uid() = user_id);

-- 8. Trigger: Create a profile entry automatically on User Signup
-- Optional but recommended: ensures a row exists even before the first sync
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name)
  VALUES (new.id, new.raw_user_meta_data->>'full_name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Uncomment the line below to enable the auto-profile trigger
-- CREATE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
