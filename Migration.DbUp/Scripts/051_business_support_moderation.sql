-- ============================================================
-- 051 — Business Support Moderation
-- Adds suspension state to business table.
-- Creates business_action_log for business-specific auditing.
-- ============================================================

ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS is_suspended         BOOLEAN   NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS suspended_at         TIMESTAMP,
    ADD COLUMN IF NOT EXISTS suspended_by         UUID      REFERENCES public.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS suspension_reason    TEXT,
  ADD COLUMN IF NOT EXISTS suspension_lifted_at TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_business_is_suspended
    ON public.business(is_suspended)
    WHERE is_suspended = TRUE;

-- Full text search support for business listing
CREATE INDEX IF NOT EXISTS idx_business_name_lower
    ON public.business(LOWER(name));

-- Business action log (business-specific audit trail)
CREATE TABLE IF NOT EXISTS public.business_action_log (
                                                          id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    support_user_id  UUID        NOT NULL REFERENCES public.users(id),
    business_id      UUID        NOT NULL REFERENCES public.business(id) ON DELETE CASCADE,
    action_type      TEXT        NOT NULL,
    -- Enum values: BUSINESS_SUSPENDED, BUSINESS_UNSUSPENDED, BUSINESS_CLOSED,
    --   BUSINESS_EDITED, OWNER_CHANGED, OWNER_REMOVED, CLAIM_REVOKED,
    --   BUSINESS_MERGED, SUBSCRIPTION_SUSPENDED, SUBSCRIPTION_OVERRIDE
    previous_state   JSONB,
    new_state        JSONB,
    reason           TEXT,
    created_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

CREATE INDEX IF NOT EXISTS idx_business_action_log_business
    ON public.business_action_log(business_id);

CREATE INDEX IF NOT EXISTS idx_business_action_log_support
    ON public.business_action_log(support_user_id);

CREATE INDEX IF NOT EXISTS idx_business_action_log_created
    ON public.business_action_log(created_at DESC);