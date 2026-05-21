-- ============================================================
-- 054 — Subscription Plan Sync Limits
-- Adds sync cadence + volume caps to subscription plans so each
-- tier (Basic/Premium/Enterprise) controls external review sync.
-- ============================================================

ALTER TABLE public.subscription_plan
    ADD COLUMN IF NOT EXISTS sync_interval_hours       INTEGER NOT NULL DEFAULT 24,
    ADD COLUMN IF NOT EXISTS max_reviews_per_sync      INTEGER NOT NULL DEFAULT 50,
    ADD COLUMN IF NOT EXISTS manual_sync_daily_limit   INTEGER NOT NULL DEFAULT 1;

-- Update existing plans with tier-appropriate values
UPDATE public.subscription_plan SET sync_interval_hours = 24,
                                    max_reviews_per_sync = 50,
                                    manual_sync_daily_limit = 1
WHERE tier = 0;  -- Basic

UPDATE public.subscription_plan SET sync_interval_hours = 6,
                                    max_reviews_per_sync = 200,
                                    manual_sync_daily_limit = 4
WHERE tier = 1;  -- Premium

UPDATE public.subscription_plan SET sync_interval_hours = 1,
                                    max_reviews_per_sync = 1000,
                                    manual_sync_daily_limit = 24
WHERE tier = 2;  -- Enterprise

COMMENT ON COLUMN public.subscription_plan.sync_interval_hours IS
    'Hours between automated syncs. Lower = more frequent (Enterprise).';
