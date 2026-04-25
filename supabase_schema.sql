-- ============================================================
-- Care & Child AAC — Supabase PostgreSQL Schema v4.1
-- ============================================================
-- Run this entire file in the Supabase SQL editor.
-- It creates all tables, indexes, RLS policies, and RPC functions.
-- ============================================================

-- ─── 1. families ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_code TEXT UNIQUE NOT NULL,
  created_by UUID REFERENCES auth.users(id),
  pin_hash TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 1.5. family_members ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS family_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT CHECK (role IN ('caregiver', 'child')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(family_id, user_id)
);

-- ─── 2. requests ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  type TEXT NOT NULL,
  room TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'done')),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 3. rooms ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(family_id, name)
);

-- ─── 4. symbols ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS symbols (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  label TEXT NOT NULL,
  emoji TEXT,
  color TEXT,
  room_name TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Unique: one global symbol per type per family
CREATE UNIQUE INDEX IF NOT EXISTS idx_symbols_family_type
  ON symbols(family_id, type) WHERE room_name IS NULL;

-- Unique: one room-specific symbol per type per family per room
CREATE UNIQUE INDEX IF NOT EXISTS idx_symbols_family_type_room
  ON symbols(family_id, type, room_name) WHERE room_name IS NOT NULL;

-- ─── 5. entries (caregiver diary) ────────────────────────────
CREATE TABLE IF NOT EXISTS entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 6. behavior_logs ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS behavior_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  symbol_type TEXT NOT NULL,
  room TEXT,
  hour_of_day INT CHECK (hour_of_day BETWEEN 0 AND 23),
  day_of_week INT CHECK (day_of_week BETWEEN 0 AND 6),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 7. behavior_predictions ─────────────────────────────────
CREATE TABLE IF NOT EXISTS behavior_predictions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  room TEXT,
  hour_bucket INT CHECK (hour_bucket BETWEEN 0 AND 23),
  predicted_types JSONB,
  confidence FLOAT,
  model_version TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ─── 8. behavior_training_status ─────────────────────────────
CREATE TABLE IF NOT EXISTS behavior_training_status (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE UNIQUE,
  started_at TIMESTAMPTZ DEFAULT now(),
  total_taps INT DEFAULT 0 CHECK (total_taps >= 0),
  is_ready BOOLEAN DEFAULT false,
  last_trained_at TIMESTAMPTZ,
  CHECK (NOT is_ready OR total_taps >= 20)
);

-- ─── 9. system_config ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS system_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- ⚠️  IMPORTANT: Update 'https://your-backend.com' below to your actual
-- deployed backend URL (e.g. Render, Railway, or your server).
-- The Flutter app uses this to discover the ML prediction API.
INSERT INTO system_config(key, value)
VALUES ('behavior_api_url', 'https://your-backend.com')
ON CONFLICT (key) DO NOTHING;


-- ═════════════════════════════════════════════════════════════
-- INDEXES
-- ═════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_requests_family_created
  ON requests(family_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_behavior_logs_family_created
  ON behavior_logs(family_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_behavior_predictions_lookup
  ON behavior_predictions(family_id, room, hour_bucket);

-- Required for upsert (on_conflict) in supabase_client.py
CREATE UNIQUE INDEX IF NOT EXISTS idx_behavior_predictions_unique
  ON behavior_predictions(family_id, room, hour_bucket);

CREATE INDEX IF NOT EXISTS idx_behavior_training_family
  ON behavior_training_status(family_id);

CREATE INDEX IF NOT EXISTS idx_entries_family_created
  ON entries(family_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_symbols_family
  ON symbols(family_id);


-- ═════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═════════════════════════════════════════════════════════════

-- Helper: get family IDs the current user belongs to
CREATE OR REPLACE FUNCTION get_user_family_ids()
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT family_id FROM family_members WHERE user_id = auth.uid();
$$;

-- ─── families ────────────────────────────────────────────────
ALTER TABLE families ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read families (for join by code)"
  ON families FOR SELECT TO public
  USING (true);

CREATE POLICY "Authenticated users can create families"
  ON families FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Creators can update their families"
  ON families FOR UPDATE TO authenticated
  USING (created_by = auth.uid());

-- ─── requests ────────────────────────────────────────────────
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read requests"
  ON requests FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Any authenticated user can create requests"
  ON requests FOR INSERT TO authenticated
  WITH CHECK (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Family members can update requests"
  ON requests FOR UPDATE TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Family members can delete requests"
  ON requests FOR DELETE TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

-- ─── rooms ───────────────────────────────────────────────────
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read rooms"
  ON rooms FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Authenticated users can create rooms"
  ON rooms FOR INSERT TO authenticated
  WITH CHECK (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Family members can delete rooms"
  ON rooms FOR DELETE TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

-- ─── symbols ─────────────────────────────────────────────────
ALTER TABLE symbols ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read symbols"
  ON symbols FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Authenticated users can create symbols"
  ON symbols FOR INSERT TO authenticated
  WITH CHECK (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Family members can update symbols"
  ON symbols FOR UPDATE TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Family members can delete symbols"
  ON symbols FOR DELETE TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

-- ─── entries ─────────────────────────────────────────────────
ALTER TABLE entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read entries"
  ON entries FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Authenticated users can create entries"
  ON entries FOR INSERT TO authenticated
  WITH CHECK (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Creators can update entries"
  ON entries FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Creators can delete entries"
  ON entries FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ─── behavior_logs ───────────────────────────────────────────
ALTER TABLE behavior_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read behavior_logs"
  ON behavior_logs FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Any authenticated user can insert behavior_logs"
  ON behavior_logs FOR INSERT TO authenticated
  WITH CHECK (family_id IN (SELECT get_user_family_ids()));

-- ─── behavior_predictions ────────────────────────────────────
ALTER TABLE behavior_predictions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read predictions"
  ON behavior_predictions FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

-- Server-side only writes (service_role key), no client INSERT policy needed

-- ─── behavior_training_status ────────────────────────────────
ALTER TABLE behavior_training_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read training status"
  ON behavior_training_status FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

-- Server-side only writes (service_role key)

-- ─── system_config ───────────────────────────────────────────
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read system_config"
  ON system_config FOR SELECT TO public
  USING (true);


-- ─── family_members ──────────────────────────────────────────
ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read family_members"
  ON family_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR family_id IN (SELECT get_user_family_ids()));

-- ═════════════════════════════════════════════════════════════
-- TRIGGERS & CORE RPC
-- ═════════════════════════════════════════════════════════════

-- Trigger to add creator as caregiver
CREATE OR REPLACE FUNCTION on_family_created()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO family_members (family_id, user_id, role)
  VALUES (NEW.id, NEW.created_by, 'caregiver');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS family_created_trigger ON families;
CREATE TRIGGER family_created_trigger
  AFTER INSERT ON families
  FOR EACH ROW EXECUTE FUNCTION on_family_created();

-- RPC for child joining
CREATE OR REPLACE FUNCTION join_family_by_code(p_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_family_id UUID;
  v_normalized_code TEXT;
BEGIN
  -- Normalize to uppercase to match how codes are stored
  v_normalized_code := UPPER(TRIM(p_code));

  SELECT id INTO v_family_id FROM families WHERE family_code = v_normalized_code LIMIT 1;
  IF v_family_id IS NULL THEN
    RAISE EXCEPTION 'Family code not found';
  END IF;

  INSERT INTO family_members (family_id, user_id, role)
  VALUES (v_family_id, auth.uid(), 'child')
  ON CONFLICT (family_id, user_id) DO NOTHING;

  RETURN v_family_id;
END;
$$;

-- ═════════════════════════════════════════════════════════════
-- RPC ANALYTICS FUNCTIONS
-- ═════════════════════════════════════════════════════════════

-- 1. Dashboard stats
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_family_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_requests', (SELECT COUNT(*) FROM requests WHERE family_id = p_family_id),
    'done_count', (SELECT COUNT(*) FROM requests WHERE family_id = p_family_id AND status = 'done'),
    'pending_count', (SELECT COUNT(*) FROM requests WHERE family_id = p_family_id AND status = 'pending'),
    'today_count', (SELECT COUNT(*) FROM requests WHERE family_id = p_family_id AND created_at >= CURRENT_DATE),
    'total_entries', (SELECT COUNT(*) FROM entries WHERE family_id = p_family_id)
  ) INTO result;
  RETURN result;
END;
$$;

-- 2. Requests by day (last 7 days)
CREATE OR REPLACE FUNCTION get_requests_by_day(p_family_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_agg(row_to_json(t))
  FROM (
    SELECT
      to_char(d.day, 'Dy') AS day_label,
      COALESCE(r.cnt, 0) AS count
    FROM generate_series(
      CURRENT_DATE - INTERVAL '6 days',
      CURRENT_DATE,
      '1 day'
    ) AS d(day)
    LEFT JOIN (
      SELECT DATE(created_at) AS req_date, COUNT(*) AS cnt
      FROM requests
      WHERE family_id = p_family_id
        AND created_at >= CURRENT_DATE - INTERVAL '6 days'
      GROUP BY DATE(created_at)
    ) r ON d.day = r.req_date
    ORDER BY d.day
  ) t INTO result;
  RETURN COALESCE(result, '[]'::json);
END;
$$;

-- 3. Requests by type
CREATE OR REPLACE FUNCTION get_requests_by_type(p_family_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_agg(row_to_json(t))
  FROM (
    SELECT type, COUNT(*) AS count
    FROM requests
    WHERE family_id = p_family_id
    GROUP BY type
    ORDER BY count DESC
  ) t INTO result;
  RETURN COALESCE(result, '[]'::json);
END;
$$;

-- 4. Requests by room
CREATE OR REPLACE FUNCTION get_requests_by_room(p_family_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_agg(row_to_json(t))
  FROM (
    SELECT COALESCE(room, 'Unknown') AS room, COUNT(*) AS count
    FROM requests
    WHERE family_id = p_family_id
    GROUP BY room
    ORDER BY count DESC
  ) t INTO result;
  RETURN COALESCE(result, '[]'::json);
END;
$$;

-- 5. Peak hours
CREATE OR REPLACE FUNCTION get_peak_hours(p_family_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_agg(row_to_json(t))
  FROM (
    SELECT hour_of_day AS hour, COUNT(*) AS count
    FROM behavior_logs
    WHERE family_id = p_family_id
    GROUP BY hour_of_day
    ORDER BY hour_of_day
  ) t INTO result;
  RETURN COALESCE(result, '[]'::json);
END;
$$;

-- ═════════════════════════════════════════════════════════════
-- NEW INDEXES & TABLES FOR OPTIMIZATION & CHILD SETTINGS
-- ═════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_behavior_logs_user_id ON behavior_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_requests_user_id ON requests(user_id);

-- ─── 10. child_symbol_preferences ─────────────────────────────
CREATE TABLE IF NOT EXISTS child_symbol_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID REFERENCES families(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  symbol_id UUID REFERENCES symbols(id) ON DELETE CASCADE,
  is_hidden BOOLEAN DEFAULT false,
  sort_order INT DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, symbol_id)
);

ALTER TABLE child_symbol_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Family members can read preferences"
  ON child_symbol_preferences FOR SELECT TO authenticated
  USING (family_id IN (SELECT get_user_family_ids()));

CREATE POLICY "Users can create their own preferences"
  ON child_symbol_preferences FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own preferences"
  ON child_symbol_preferences FOR UPDATE TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Users can delete their own preferences"
  ON child_symbol_preferences FOR DELETE TO authenticated
  USING (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_child_pref_user ON child_symbol_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_child_pref_family ON child_symbol_preferences(family_id);

-- ═════════════════════════════════════════════════════════════
-- STORAGE BUCKETS & POLICIES
-- ═════════════════════════════════════════════════════════════

-- ─── Create the 'symbols' storage bucket ────────────
-- This bucket holds the actual image files uploaded by caregivers.
-- Public = true means anyone with the URL can view the image.
INSERT INTO storage.buckets (id, name, public)
VALUES ('symbols', 'symbols', true)
ON CONFLICT (id) DO NOTHING;

-- ─── Storage RLS Policies ───────────────────────────

-- 1. Allow public read access (children can view symbol photos)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Public Symbol Read'
  ) THEN
    CREATE POLICY "Public Symbol Read"
    ON storage.objects FOR SELECT
    TO public  USING ( bucket_id = 'symbols' );
  END IF;
END $$;

-- 2. Allow authenticated users to upload to the symbols bucket
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Auth Symbol Insert'
  ) THEN
    CREATE POLICY "Auth Symbol Insert"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK ( bucket_id = 'symbols' );
  END IF;
END $$;

-- 3. Allow authenticated users to update their uploads
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Auth Symbol Update'
  ) THEN
    CREATE POLICY "Auth Symbol Update"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING ( bucket_id = 'symbols' );
  END IF;
END $$;

-- 4. Allow authenticated users to delete their uploads
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Auth Symbol Delete'
  ) THEN
    CREATE POLICY "Auth Symbol Delete"
    ON storage.objects FOR DELETE
    TO authenticated
    USING ( bucket_id = 'symbols' );
  END IF;
END $$;
