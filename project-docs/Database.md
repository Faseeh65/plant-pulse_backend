# Database Schema & Implementation — PlantPulse

## 1. Relational Overview
This schema connects Crops to Pests, and Pests to Diseases to enable the "Causal Chain" logic. It uses PostgreSQL Row-Level Security (RLS) to ensure users only access their own scan history while sharing the global disease database.

## 2. PostgreSQL Implementation Script (SQL)
Copy and paste this into the Supabase SQL Editor to build your tables.

```sql
-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLES
CREATE TABLE profiles (
  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  full_name text,
  preferred_language text DEFAULT 'en',
  created_at timestamptz DEFAULT now()
);

CREATE TABLE crops (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name_en text NOT NULL,
  name_ur text NOT NULL
);

CREATE TABLE pests (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  crop_id uuid REFERENCES crops(id) ON DELETE CASCADE,
  name_en text NOT NULL,
  name_ur text NOT NULL,
  scientific_name text,
  description_ur text
);

CREATE TABLE diseases (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  pest_id uuid REFERENCES pests(id) ON DELETE SET NULL,
  name_en text NOT NULL, -- This must match the ML Model Class Name
  name_ur text NOT NULL,
  is_fungal boolean DEFAULT false,
  treatment_organic_ur text,
  treatment_chemical_ur text,
  local_pesticide_names text[], -- Array of brands like ['Engro', 'Bayer']
  estimated_pkr_price text
);

CREATE TABLE scan_history (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  crop_id uuid REFERENCES crops(id),
  disease_id uuid REFERENCES diseases(id),
  confidence_score float,
  image_url text,
  created_at timestamptz DEFAULT now()
);

-- 3. ROW LEVEL SECURITY (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE scan_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE crops ENABLE ROW LEVEL SECURITY;
ALTER TABLE pests ENABLE ROW LEVEL SECURITY;
ALTER TABLE diseases ENABLE ROW LEVEL SECURITY;

-- POLICIES
CREATE POLICY "Public Read Access" ON crops FOR SELECT USING (true);
CREATE POLICY "Public Read Access" ON pests FOR SELECT USING (true);
CREATE POLICY "Public Read Access" ON diseases FOR SELECT USING (true);
CREATE POLICY "Profiles are viewable by owner" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can manage own scans" ON scan_history FOR ALL USING (auth.uid() = user_id);

-- 4. INITIAL SEED DATA
INSERT INTO crops (name_en, name_ur) VALUES ('Tomato', 'ٹماٹر');

DO $$
DECLARE tomato_id uuid;
DECLARE whitefly_id uuid;
BEGIN
  SELECT id INTO tomato_id FROM crops WHERE name_en = 'Tomato' LIMIT 1;
  
  INSERT INTO pests (crop_id, name_en, name_ur, scientific_name) 
  VALUES (tomato_id, 'Whitefly', 'سفید مکھی', 'Bemisia tabaci')
  RETURNING id INTO whitefly_id;

  INSERT INTO diseases (pest_id, name_en, name_ur, is_fungal, local_pesticide_names, estimated_pkr_price)
  VALUES (whitefly_id, 'Tomato_Yellow_Leaf_Curl_Virus', 'ٹماٹر کا پیلا پتا مروڑ وائرس', false, ARRAY['Imidacloprid', 'Movento'], 'PKR 1200-1500');
END $$;