-- ======================================================
-- 001 - Enable PostgreSQL Extensions & Utility Functions
-- ======================================================

-- Enable the citext extension (for case-insensitive text)
CREATE EXTENSION IF NOT EXISTS citext;

-- Utility trigger function to auto-update "updated_at"
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
