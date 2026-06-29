-- ============================================================
-- 066 — Two-Axis Source Visibility
-- Splits the single is_active flag on external_review_source into
-- two independent axes (Architecture Decision 4):
--   sync_enabled        → drives the sync worker
--   is_publicly_visible → drives the public business page
-- ============================================================

ALTER TABLE public.external_review_source
    ADD COLUMN IF NOT EXISTS sync_enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS is_publicly_visible BOOLEAN NOT NULL DEFAULT TRUE;

-- Backfill: preserve current behaviour for existing rows.
UPDATE public.external_review_source
SET sync_enabled        = is_active,
    is_publicly_visible = is_active;

COMMENT ON COLUMN public.external_review_source.sync_enabled        IS 'When FALSE the sync worker skips this source. Lets an owner keep reviews privately without public display.';
COMMENT ON COLUMN public.external_review_source.is_publicly_visible IS 'When FALSE this source''s reviews are hidden from the public business page. Independent of sync_enabled.';

-- Index supporting the sync-due query. NOTE: external_review_source has no
-- next_sync_at column (that lives on the unrelated external_source table) —
-- the sync-due predicate filters on last_sync_at, so index that.
CREATE INDEX IF NOT EXISTS idx_external_review_source_sync_due
    ON public.external_review_source (last_sync_at)
    WHERE sync_enabled = TRUE AND requires_reauth = FALSE;
