-- ============================================================
-- 070 — External Audit Log (Item 11)
-- Append-only audit trail for external-integration actions:
-- connect / disconnect / sync-toggle / public-visibility-toggle.
-- actor_type ∈ business_user | support_user | system.
-- before_json / after_json capture the relevant state snapshot.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.external_audit_log (
    id          UUID         NOT NULL DEFAULT gen_random_uuid(),
    actor_id    UUID         NOT NULL,
    actor_type  VARCHAR(20)  NOT NULL,   -- business_user | support_user | system
    action      VARCHAR(60)  NOT NULL,
    target_id   UUID,
    target_type VARCHAR(30),
    before_json JSONB,
    after_json  JSONB,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_external_audit_log PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_external_audit_log_actor
    ON public.external_audit_log (actor_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_external_audit_log_target
    ON public.external_audit_log (target_id, created_at DESC);
