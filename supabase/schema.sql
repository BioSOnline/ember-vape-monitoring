-- EMBER - Supabase Database Schema
-- Early Monitoring of Behavioral & Environmental Risk
-- MITE CSE Final Year Project - March 2026

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT now(),
  daily_puff_goal INTEGER,
  baseline_puffs_per_day INTEGER,
  years_smoked INTEGER,
  product_type TEXT,
  preferred_strategy TEXT,
  primary_trigger TEXT,
  quit_strategy TEXT DEFAULT 'gradual_reduction',
  plan_start_date TIMESTAMPTZ DEFAULT now(),
  target_quit_date TIMESTAMPTZ,
  weekly_reduction_rate FLOAT DEFAULT 10.0
);

-- Schema migration additions for existing databases
ALTER TABLE users ADD COLUMN IF NOT EXISTS quit_strategy TEXT DEFAULT 'gradual_reduction';
ALTER TABLE users ADD COLUMN IF NOT EXISTS plan_start_date TIMESTAMPTZ DEFAULT now();
ALTER TABLE users ADD COLUMN IF NOT EXISTS target_quit_date TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS weekly_reduction_rate FLOAT DEFAULT 10.0;

-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  puff_count INTEGER DEFAULT 0,
  avg_interval_sec FLOAT
);

-- Puff events table
CREATE TABLE IF NOT EXISTS puff_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  detected_at TIMESTAMPTZ NOT NULL,
  input_mode TEXT CHECK (input_mode IN ('manual', 'video_upload', 'live_camera')),
  confidence_score FLOAT CHECK (confidence_score >= 0 AND confidence_score <= 1)
);

-- Addiction scores table
CREATE TABLE IF NOT EXISTS addiction_scores (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  scored_at TIMESTAMPTZ DEFAULT now(),
  level TEXT CHECK (level IN ('low', 'moderate', 'high')),
  score_value FLOAT CHECK (score_value >= 0 AND score_value <= 100),
  top_feature TEXT NOT NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_puff_events_user_id ON puff_events(user_id);
CREATE INDEX IF NOT EXISTS idx_puff_events_detected_at ON puff_events(detected_at);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON sessions(started_at);
CREATE INDEX IF NOT EXISTS idx_addiction_scores_user_id ON addiction_scores(user_id);
CREATE INDEX IF NOT EXISTS idx_addiction_scores_scored_at ON addiction_scores(scored_at);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE puff_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE addiction_scores ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users table
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON users;
CREATE POLICY "Users can insert own profile" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- RLS Policies for puff_events table
DROP POLICY IF EXISTS "Users can view own puff events" ON puff_events;
CREATE POLICY "Users can view own puff events" ON puff_events
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own puff events" ON puff_events;
CREATE POLICY "Users can insert own puff events" ON puff_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own puff events" ON puff_events;
CREATE POLICY "Users can delete own puff events" ON puff_events
  FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for sessions table
DROP POLICY IF EXISTS "Users can view own sessions" ON sessions;
CREATE POLICY "Users can view own sessions" ON sessions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own sessions" ON sessions;
CREATE POLICY "Users can insert own sessions" ON sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own sessions" ON sessions;
CREATE POLICY "Users can update own sessions" ON sessions
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for addiction_scores table
DROP POLICY IF EXISTS "Users can view own addiction scores" ON addiction_scores;
CREATE POLICY "Users can view own addiction scores" ON addiction_scores
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own addiction scores" ON addiction_scores;
CREATE POLICY "Users can insert own addiction scores" ON addiction_scores
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own addiction scores" ON addiction_scores;
CREATE POLICY "Users can delete own addiction scores" ON addiction_scores
  FOR DELETE USING (auth.uid() = user_id);

-- Function to automatically create user profile after signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, created_at)
  VALUES (new.id, new.created_at);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Trigger to create user profile on auth signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Sample queries for analytics

-- Get daily puff counts for last 30 days
-- SELECT DATE(detected_at) as date, COUNT(*) as puff_count
-- FROM puff_events
-- WHERE user_id = 'USER_ID'
--   AND detected_at >= NOW() - INTERVAL '30 days'
-- GROUP BY DATE(detected_at)
-- ORDER BY date DESC;

-- Get average session duration
-- SELECT AVG(EXTRACT(EPOCH FROM (ended_at - started_at))/60) as avg_duration_minutes
-- FROM sessions
-- WHERE user_id = 'USER_ID'
--   AND ended_at IS NOT NULL;

-- Get addiction score history
-- SELECT scored_at, level, score_value, top_feature
-- FROM addiction_scores
-- WHERE user_id = 'USER_ID'
-- ORDER BY scored_at DESC;
