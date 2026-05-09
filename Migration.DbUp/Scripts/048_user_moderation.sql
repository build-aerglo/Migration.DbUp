-- ============================================================
-- 048 — User Moderation (warn, suspend, ban)
-- Adds moderation state to public.users.
-- All columns default to safe values so no existing rows change.
-- ============================================================

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS is_suspended      BOOLEAN     NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS suspended_until   TIMESTAMP,
    ADD COLUMN IF NOT EXISTS suspension_reason TEXT,
    ADD COLUMN IF NOT EXISTS suspended_by      UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS suspended_at      TIMESTAMP,
  ADD COLUMN IF NOT EXISTS warning_count     INTEGER     NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_banned         BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS ban_reason        TEXT,
  ADD COLUMN IF NOT EXISTS banned_by         UUID        REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS banned_at         TIMESTAMP;

-- Partial indexes for hot-path login check (only indexes rows that match)
CREATE INDEX IF NOT EXISTS idx_users_is_suspended
    ON public.users(is_suspended)
    WHERE is_suspended = TRUE;

CREATE INDEX IF NOT EXISTS idx_users_is_banned
    ON public.users(is_banned)
    WHERE is_banned = TRUE;

-- Composite index for paginated support user listing
CREATE INDEX IF NOT EXISTS idx_users_type_created
    ON public.users(user_type, created_at DESC);

-- Function: auto-lift expired suspensions (called by scheduled job)
CREATE OR REPLACE FUNCTION public.lift_expired_suspensions()
RETURNS INTEGER AS $$
DECLARE lifted_count INTEGER;
BEGIN
UPDATE public.users
SET is_suspended      = FALSE,
    suspended_until   = NULL,
    suspension_reason = NULL,
    updated_at        = NOW()
WHERE is_suspended = TRUE
  AND suspended_until IS NOT NULL
  AND suspended_until <= NOW();
GET DIAGNOSTICS lifted_count = ROW_COUNT;
RETURN lifted_count;
END;
$$ LANGUAGE plpgsql;