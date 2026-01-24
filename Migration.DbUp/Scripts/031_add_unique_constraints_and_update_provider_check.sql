-- ============================================================================
-- Add UNIQUE constraints and update provider check constraint
-- Version: 2.0.3
-- ============================================================================

-- Add UNIQUE constraint to end_user table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_end_user_user_id'
    ) THEN
ALTER TABLE end_user ADD CONSTRAINT uq_end_user_user_id UNIQUE (user_id);
END IF;
END $$;

-- Add UNIQUE constraint to user_settings table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_user_settings_user_id'
    ) THEN
ALTER TABLE user_settings ADD CONSTRAINT uq_user_settings_user_id UNIQUE (user_id);
END IF;
END $$;

-- Drop the old provider constraint
ALTER TABLE social_identities
DROP CONSTRAINT IF EXISTS chk_provider;

-- Add new constraint with exact Auth0 provider names
ALTER TABLE social_identities
    ADD CONSTRAINT chk_provider
        CHECK (provider IN ('google-oauth2', 'Facebook', 'Apple', 'GitHub', 'Twitter', 'linkedin'));


-- Add businessAddress to business Table
ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS business_address TEXT;

