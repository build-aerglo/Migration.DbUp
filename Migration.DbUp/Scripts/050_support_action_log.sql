-- ============================================================
-- 050 — Support Action Log (user & review moderation audit)
-- Append-only audit log. No UPDATE or DELETE should ever run
-- against this table.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.support_action_log (
                                                         id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    support_user_id  UUID        NOT NULL REFERENCES public.users(id),
    action_type      TEXT        NOT NULL,
    -- Enum values: USER_WARNED, USER_WARNED_AUTO_SUSPEND, USER_SUSPENDED,
    --   USER_SUSPENSION_LIFTED, USER_BANNED,
    --   REVIEW_APPROVED, REVIEW_DELETED
    target_type      TEXT        NOT NULL,  -- 'user' | 'review'
    target_id        UUID        NOT NULL,
    reason           TEXT,
    metadata         JSONB,
    created_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

CREATE INDEX IF NOT EXISTS idx_support_action_log_support_user
    ON public.support_action_log(support_user_id);

CREATE INDEX IF NOT EXISTS idx_support_action_log_target
    ON public.support_action_log(target_id, target_type);

CREATE INDEX IF NOT EXISTS idx_support_action_log_created
    ON public.support_action_log(created_at DESC);