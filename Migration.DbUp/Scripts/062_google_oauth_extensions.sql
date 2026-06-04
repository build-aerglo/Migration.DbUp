-- ============================================================
-- 055 — Google OAuth Extensions
-- Extends external_review_source + external_review with Google
-- fields, sync lock, and raw payload. Adds OAuth CSRF state table.
-- ============================================================

-- Extend external_review_source for Google integration
ALTER TABLE public.external_review_source
    ADD COLUMN IF NOT EXISTS google_account_id      VARCHAR(255),
    ADD COLUMN IF NOT EXISTS google_location_id     VARCHAR(255),
    ADD COLUMN IF NOT EXISTS google_place_id        VARCHAR(255),
    ADD COLUMN IF NOT EXISTS requires_reauth        BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS sync_lock_acquired_at  TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS sync_lock_token        VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_external_source_due_for_sync
    ON public.external_review_source(auto_sync_enabled, last_sync_at)
    WHERE auto_sync_enabled = TRUE AND is_active = TRUE AND requires_reauth = FALSE;

-- Extend external_review for raw payload and Google fields
ALTER TABLE public.external_review
    ADD COLUMN IF NOT EXISTS source_type            VARCHAR(50),
    ADD COLUMN IF NOT EXISTS raw_payload            JSONB,
    ADD COLUMN IF NOT EXISTS google_review_name     VARCHAR(500),
    ADD COLUMN IF NOT EXISTS owner_reply_text       TEXT,
    ADD COLUMN IF NOT EXISTS owner_reply_at         TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS reviewer_profile_url   TEXT,
    ADD COLUMN IF NOT EXISTS relative_publish_time  VARCHAR(100);

-- Backfill source_type from source table
UPDATE public.external_review er
SET source_type = ers.source_type
FROM public.external_review_source ers
WHERE er.source_id = ers.id AND er.source_type IS NULL;

-- Composite index for the most common query: business profile page
CREATE INDEX IF NOT EXISTS idx_external_review_business_visible
    ON public.external_review(business_id, is_visible, external_created_at DESC)
    WHERE is_visible = TRUE;

-- GIN index for raw_payload JSONB queries
CREATE INDEX IF NOT EXISTS idx_external_review_raw_payload
    ON public.external_review USING GIN (raw_payload)
    WHERE raw_payload IS NOT NULL;

-- OAuth CSRF state table
CREATE TABLE IF NOT EXISTS public.external_oauth_state (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_token  VARCHAR(128) NOT NULL UNIQUE,
    business_id  UUID NOT NULL,
    source_type  VARCHAR(50) NOT NULL,
    user_id      UUID NOT NULL,
    expires_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
    used_at      TIMESTAMP WITH TIME ZONE,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_oauth_state_unused
    ON public.external_oauth_state(state_token)
    WHERE used_at IS NULL;

-- Cleanup job — expired states older than 1 hour
CREATE OR REPLACE FUNCTION public.cleanup_expired_oauth_states()
RETURNS INTEGER AS $$
DECLARE deleted_count INTEGER;
BEGIN
    DELETE FROM public.external_oauth_state
    WHERE expires_at < NOW() - INTERVAL '1 hour';
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE public.external_oauth_state IS
    'OAuth 2.0 CSRF state tokens. TTL 10 minutes, single-use.';
