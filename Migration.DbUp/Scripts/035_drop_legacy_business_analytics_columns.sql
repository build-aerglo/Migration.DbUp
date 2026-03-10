-- ============================================================================
-- Migration 035: Fix business_analytics NOT NULL Constraints
-- Description: Makes legacy columns nullable to unblock the analytics service.
--              This is a SAFE first step — no data is deleted.
--              Actual column drops happen in migration 036 after verification.
--
-- ROOT CAUSE OF CRASH:
--   period_type, period_start, period_end have NOT NULL constraints but
--   AnalyticsRepository.UpsertAsync never supplies them, causing every
--   INSERT to fail: "null value in column period_start violates not-null constraint"
--
-- APPROACH:
--   Make ALL legacy columns nullable now (safe, no data loss).
--   Review each column group carefully before dropping in migration 036.
-- ============================================================================

-- ============================================================================
-- STEP 1: Fix the BLOCKING columns (these are crashing the service right now)
-- Period columns are from the old multi-row-per-business design.
-- Now superseded by single row per business + time series inside metrics JSONB.
-- Making nullable unblocks inserts immediately.
-- ============================================================================

ALTER TABLE business_analytics ALTER COLUMN period_type     DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN period_start    DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN period_end      DROP NOT NULL;

-- ============================================================================
-- STEP 2: Make all other legacy columns nullable too
-- These are already covered in the metrics JSONB (see notes per group below).
-- Making them nullable now means they won't block anything if missed.
-- ============================================================================

-- Response metrics
-- COVERED: WrrCalculationService writes into metrics->responseMetrics every run.
-- Safe to drop in 036 after verification.
ALTER TABLE business_analytics ALTER COLUMN response_rate               DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN average_response_time_hours DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN total_responses             DROP NOT NULL;

-- Sentiment counts
-- COVERED: SentimentAnalysisService writes into metrics->sentiment every run.
-- Safe to drop in 036 after verification.
ALTER TABLE business_analytics ALTER COLUMN positive_reviews DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN neutral_reviews  DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN negative_reviews DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN sentiment_score  DROP NOT NULL;

-- Helpful votes
-- COVERED: Computed live from review.helpful_count, written into
--          metrics->engagement->helpfulVotes on every analytics run.
-- Safe to drop in 036 after verification.
ALTER TABLE business_analytics ALTER COLUMN helpful_votes DROP NOT NULL;

-- Keyword / complaint / praise data
-- PARTIALLY COVERED: Migration 034 copied existing data into metrics->legacyData
-- as a ONE-TIME migration. However, KeywordExtractionService currently writes
-- keyword frequency into metrics->sentiment->keywords but does NOT maintain
-- top_complaints_json / top_praise_json / keyword_cloud_json going forward.
-- DO NOT DROP until you decide whether to:
--   (a) Remove these features entirely, or
--   (b) Update KeywordExtractionService to write structured complaint/praise data
-- For now just ensure they are nullable.
-- (These columns may already be nullable — ALTER IF they have NOT NULL constraints)
ALTER TABLE business_analytics ALTER COLUMN top_complaints_json DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN top_praise_json     DROP NOT NULL;
ALTER TABLE business_analytics ALTER COLUMN keyword_cloud_json  DROP NOT NULL;

-- profile_views and qr_code_scans
-- STILL IN USE: Read directly by AnalyticsAggregationService.GetEngagementMetricsAsync.
-- Do NOT drop these — they are actively queried.
-- Leave untouched.

-- ============================================================================
-- STEP 3: Verify the fix
-- ============================================================================

DO $$
DECLARE
blocking_count INTEGER;
BEGIN
    -- Check none of the formerly-blocking columns still have NOT NULL
SELECT COUNT(*) INTO blocking_count
FROM information_schema.columns
WHERE table_name   = 'business_analytics'
  AND table_schema = 'public'
  AND column_name  IN ('period_type', 'period_start', 'period_end')
  AND is_nullable  = 'NO';

IF blocking_count > 0 THEN
        RAISE EXCEPTION 'Migration 035 failed: % column(s) still have NOT NULL constraint', blocking_count;
ELSE
        RAISE NOTICE '============================================================================';
        RAISE NOTICE 'Migration 035 completed successfully';
        RAISE NOTICE 'All legacy columns are now nullable — service inserts will succeed.';
        RAISE NOTICE '';
        RAISE NOTICE 'NEXT STEPS before running migration 036 (actual drops):';
        RAISE NOTICE '  1. Verify analytics service runs successfully end-to-end.';
        RAISE NOTICE '  2. Confirm response_rate / sentiment columns are in metrics JSONB.';
        RAISE NOTICE '  3. Decide fate of top_complaints_json / top_praise_json:';
        RAISE NOTICE '     - Drop them if those features are replaced by KeywordExtractionService.';
        RAISE NOTICE '     - Keep and maintain them if structured complaint/praise data is needed.';
        RAISE NOTICE '  4. period_start/end/type are safe to drop once 036 is ready.';
        RAISE NOTICE '============================================================================';
END IF;
END $$;