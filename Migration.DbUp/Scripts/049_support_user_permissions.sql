-- ============================================================
-- 049 — Support User Permission Levels
-- Extends support_user table with role granularity.
-- ============================================================

ALTER TABLE public.support_user
    ADD COLUMN IF NOT EXISTS permission_level TEXT    NOT NULL DEFAULT 'standard'
    CONSTRAINT chk_permission_level CHECK (permission_level IN ('standard', 'senior', 'admin')),
    ADD COLUMN IF NOT EXISTS department       TEXT,
    ADD COLUMN IF NOT EXISTS is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS last_action_at   TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_support_user_permission
    ON public.support_user(permission_level);

CREATE INDEX IF NOT EXISTS idx_support_user_active
    ON public.support_user(is_active)
    WHERE is_active = TRUE;