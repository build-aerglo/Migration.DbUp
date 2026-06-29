-- ============================================================
-- 058 — Redemption Hardening
-- Adds idempotency_key, provider tracking, audit columns,
-- extends the status CHECK constraint, and adds query indexes.
-- ============================================================

-- Step 1: Idempotency key — prevents double-spend at DB level
ALTER TABLE public.point_redemptions
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(100);

CREATE UNIQUE INDEX IF NOT EXISTS uidx_point_redemptions_idempotency_key
    ON public.point_redemptions(idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- Step 2: Provider tracking
ALTER TABLE public.point_redemptions
    ADD COLUMN IF NOT EXISTS provider_name         VARCHAR(50)  DEFAULT 'AfricaTalking',
    ADD COLUMN IF NOT EXISTS provider_transaction_id VARCHAR(255),
    ADD COLUMN IF NOT EXISTS operator_name         VARCHAR(50);

-- Step 3: Audit columns
ALTER TABLE public.point_redemptions
    ADD COLUMN IF NOT EXISTS points_balance_before DECIMAL(10, 2),
    ADD COLUMN IF NOT EXISTS points_balance_after  DECIMAL(10, 2),
    ADD COLUMN IF NOT EXISTS refunded_at           TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS failure_reason        TEXT;

-- Step 4: Extend status CHECK constraint to include 'processing' and 'refunded'
-- Dynamically finds the existing constraint name so this is safe regardless of
-- whether the DB used PostgreSQL's auto-generated name or the explicit 'chk_status'.
DO $$
DECLARE constraint_name_var TEXT;
BEGIN
    SELECT constraint_name INTO constraint_name_var
    FROM information_schema.table_constraints
    WHERE table_name    = 'point_redemptions'
      AND constraint_type = 'CHECK'
      AND constraint_name LIKE '%status%';

    IF constraint_name_var IS NOT NULL THEN
        EXECUTE format(
            'ALTER TABLE public.point_redemptions DROP CONSTRAINT IF EXISTS %I',
            constraint_name_var);
    END IF;
END $$;

ALTER TABLE public.point_redemptions
    ADD CONSTRAINT point_redemptions_status_check
    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'refunded'));

-- Step 5: Indexes for new query patterns
CREATE INDEX IF NOT EXISTS idx_point_redemptions_user_daily
    ON public.point_redemptions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_point_redemptions_stuck_processing
    ON public.point_redemptions(status, created_at)
    WHERE status = 'processing';

-- Comments
COMMENT ON COLUMN public.point_redemptions.idempotency_key IS
    'Client-generated UUID. DB-level unique constraint prevents double-spend on concurrent submits.';
COMMENT ON COLUMN public.point_redemptions.provider_name IS
    'Airtime provider used: Reloadly | AfricaTalking';
COMMENT ON COLUMN public.point_redemptions.points_balance_before IS
    'User point balance immediately before deduction. Audit column for support investigations.';
COMMENT ON COLUMN public.point_redemptions.points_balance_after IS
    'User point balance immediately after deduction. Audit column.';
COMMENT ON COLUMN public.point_redemptions.refunded_at IS
    'When points were credited back to the user after a failed airtime call.';
COMMENT ON COLUMN public.point_redemptions.failure_reason IS
    'Human-readable reason for failure or refund. Populated on failed/refunded status transitions.';
