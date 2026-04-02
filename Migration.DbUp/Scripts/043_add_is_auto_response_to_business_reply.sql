-- ============================================================================
-- Migration 043: Add is_auto_response to business_reply
--
-- WHY THIS EXISTS:
--   The Weighted Response Rate (WRR) formula explicitly excludes auto-responses.
--   Previously, is_auto_approved was misread as indicating an auto-response, but
--   that flag tracks moderation pathway (auto-moderated vs human-reviewed), not
--   reply origin. A clean human reply that passes all moderation rules also has
--   is_auto_approved = true.
--
--   is_auto_response = TRUE means the reply was generated and submitted by the
--   auto-response template system — not typed by a human. These must be excluded
--   from WRR so the metric only reflects deliberate, manual business engagement.
--
-- COLUMN SEMANTICS:
--   is_auto_approved  = HOW the reply cleared moderation (auto vs human review)
--   is_auto_response  = WHERE the reply originated (template system vs human input)
--
-- DEFAULT FALSE: all existing rows are legitimate human replies — correct default.
-- ============================================================================

ALTER TABLE public.business_reply
    ADD COLUMN IF NOT EXISTS is_auto_response BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.business_reply.is_auto_response IS
'TRUE = this reply was generated and submitted by the auto-response template system
 (AutoResponseService). FALSE = typed and submitted by a human (business owner /
 staff). Auto-responses are excluded from the Weighted Response Rate (WRR) metric
 per the formula spec. Do not confuse with is_auto_approved, which tracks moderation
 pathway, not reply origin.';

CREATE INDEX IF NOT EXISTS idx_business_reply_is_auto_response
    ON public.business_reply (business_id, is_auto_response)
    WHERE is_auto_response = FALSE;

DO $$
BEGIN
    RAISE NOTICE 'Migration 043: is_auto_response column added to business_reply.';
    RAISE NOTICE 'All % existing rows defaulted to is_auto_response = FALSE.',
        (SELECT COUNT(*) FROM public.business_reply);
END $$;