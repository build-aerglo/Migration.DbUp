-- ============================================================
-- 069 — Sync-Policy Config Unification (Roadmap Item 8)
-- Moves the two hardcoded per-plan sync throttles (max reviews per
-- sync, manual-sync rate limit) out of code and into a support-editable
-- table, and lets manual vs auto syncs be counted separately.
--   sync_policy_config  → per (source_type, plan_tier) throttle row
--   external_review_sync_log.triggered_by → 'AUTO' | 'MANUAL'
-- ============================================================

CREATE TABLE IF NOT EXISTS public.sync_policy_config (
    id                       UUID        NOT NULL DEFAULT gen_random_uuid(),
    source_type              VARCHAR(50) NOT NULL,
    plan_tier                VARCHAR(50) NOT NULL,
    auto_sync_interval_hours INT         NOT NULL DEFAULT 24,
    max_reviews_per_sync     INT         NOT NULL DEFAULT 50,
    manual_sync_count        INT         NOT NULL DEFAULT 1,
    manual_sync_window_hours INT         NOT NULL DEFAULT 24,
    is_active                BOOLEAN     NOT NULL DEFAULT TRUE,
    updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by               UUID,
    CONSTRAINT pk_sync_policy_config PRIMARY KEY (id),
    CONSTRAINT uq_sync_policy_config UNIQUE (source_type, plan_tier)
);

COMMENT ON TABLE  public.sync_policy_config                          IS 'Support-editable per-(source_type, plan_tier) sync throttles. Replaces the hardcoded plan switches in GoogleSyncService and the manual-sync rate limit. Read with a 5-min cache.';
COMMENT ON COLUMN public.sync_policy_config.auto_sync_interval_hours IS 'Stored for a later item; not yet consumed by the sync cadence (that still uses external_review_source.sync_frequency_hours).';
COMMENT ON COLUMN public.sync_policy_config.max_reviews_per_sync     IS 'Cap on reviews fetched per sync run for this plan tier.';
COMMENT ON COLUMN public.sync_policy_config.manual_sync_count        IS 'Allowed manual syncs within manual_sync_window_hours. 0 disables manual sync for the tier.';

-- Seed the Google My Business throttles per plan tier. Idempotent.
INSERT INTO public.sync_policy_config
    (source_type, plan_tier, auto_sync_interval_hours, max_reviews_per_sync, manual_sync_count, manual_sync_window_hours)
VALUES
    ('GOOGLE_MY_BUSINESS', 'ENTERPRISE',  8, 100, 3, 24),
    ('GOOGLE_MY_BUSINESS', 'PREMIUM',    12,  50, 1, 24),
    ('GOOGLE_MY_BUSINESS', 'BUSINESS',   24,  25, 1, 48),
    ('GOOGLE_MY_BUSINESS', 'BASIC',      48,  10, 0, 24)
ON CONFLICT (source_type, plan_tier) DO NOTHING;

-- Track whether each sync run was triggered automatically or by an owner,
-- so the manual rate limit can count only MANUAL rows (Item 8 defect fix:
-- it previously gated on the shared last_sync_at).
ALTER TABLE public.external_review_sync_log
    ADD COLUMN IF NOT EXISTS triggered_by VARCHAR(10) NOT NULL DEFAULT 'AUTO'
    CHECK (triggered_by IN ('AUTO', 'MANUAL'));

COMMENT ON COLUMN public.external_review_sync_log.triggered_by IS 'AUTO = background poller; MANUAL = owner-initiated sync. The manual rate limit counts MANUAL rows within the plan window.';
