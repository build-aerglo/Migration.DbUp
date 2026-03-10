-- ============================================================================
-- Migration 034: Modernize Business Analytics Table
-- Description: Add JSONB column for flexible analytics schema
-- Safe for: Both fresh installs and existing databases with data
-- ============================================================================

-- ============================================================================
-- STEP 1: Add new columns
-- ============================================================================

ALTER TABLE business_analytics
    ADD COLUMN IF NOT EXISTS metrics JSONB DEFAULT '{}'::jsonb;

ALTER TABLE business_analytics
    ADD COLUMN IF NOT EXISTS last_calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add unique constraint if not exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'uk_business_analytics_business_id'
    ) THEN
ALTER TABLE business_analytics
    ADD CONSTRAINT uk_business_analytics_business_id UNIQUE (business_id);
END IF;
END $$;

-- ============================================================================
-- STEP 2: Create indexes for performance
-- ============================================================================

-- GIN index for JSONB queries
CREATE INDEX IF NOT EXISTS idx_business_analytics_metrics
    ON business_analytics USING GIN(metrics);

-- Index for filtering by last calculation time
CREATE INDEX IF NOT EXISTS idx_business_analytics_last_calc
    ON business_analytics(last_calculated_at DESC);

-- ============================================================================
-- STEP 3: Migrate existing data to JSONB format
-- ============================================================================

UPDATE business_analytics
SET metrics = jsonb_build_object(
        'response_metrics', jsonb_build_object(
                'response_rate', COALESCE(response_rate, 0),
                'avg_response_time_hours', COALESCE(average_response_time_hours, 0),
                'total_responses', COALESCE(total_responses, 0)
                            ),
        'sentiment', jsonb_build_object(
                'positive_reviews', COALESCE(positive_reviews, 0),
                'neutral_reviews', COALESCE(neutral_reviews, 0),
                'negative_reviews', COALESCE(negative_reviews, 0),
                'positive_pct', CASE
                                    WHEN (positive_reviews + neutral_reviews + negative_reviews) > 0
                                        THEN ROUND((positive_reviews::decimal / (positive_reviews + neutral_reviews + negative_reviews)) * 100, 2)
                                    ELSE 0
                    END,
                'neutral_pct', CASE
                                   WHEN (positive_reviews + neutral_reviews + negative_reviews) > 0
                                       THEN ROUND((neutral_reviews::decimal / (positive_reviews + neutral_reviews + negative_reviews)) * 100, 2)
                                   ELSE 0
                    END,
                'negative_pct', CASE
                                    WHEN (positive_reviews + neutral_reviews + negative_reviews) > 0
                                        THEN ROUND((negative_reviews::decimal / (positive_reviews + neutral_reviews + negative_reviews)) * 100, 2)
                                    ELSE 0
                    END,
                'sentiment_score', COALESCE(sentiment_score, 0.5)
                     ),
        'engagement', jsonb_build_object(
                'helpful_votes', COALESCE(helpful_votes, 0),
                'profile_views', COALESCE(profile_views, 0),
                'qr_code_scans', COALESCE(qr_code_scans, 0)
                      ),
        'legacy_data', jsonb_build_object(
                'top_complaints', CASE
                                      WHEN top_complaints_json IS NOT NULL THEN top_complaints_json::jsonb
                                      ELSE '[]'::jsonb
                    END,
                'top_praise', CASE
                                  WHEN top_praise_json IS NOT NULL THEN top_praise_json::jsonb
                                  ELSE '[]'::jsonb
                    END,
                'keyword_cloud', CASE
                                     WHEN keyword_cloud_json IS NOT NULL THEN keyword_cloud_json::jsonb
                                     ELSE '{}'::jsonb
                    END
                       )
              )
WHERE metrics = '{}'::jsonb OR metrics IS NULL;

-- ============================================================================
-- STEP 4: Add helpful comments
-- ============================================================================

COMMENT ON COLUMN business_analytics.metrics IS 
'JSONB containing all analytics data: response_metrics, sentiment, time_series, sources, engagement, trends';

COMMENT ON COLUMN business_analytics.last_calculated_at IS 
'Timestamp of last analytics calculation by Azure Function';

-- ============================================================================
-- STEP 5: Verify migration
-- ============================================================================

DO $$
DECLARE
total_count INTEGER;
    migrated_count INTEGER;
BEGIN
SELECT COUNT(*) INTO total_count FROM business_analytics;
SELECT COUNT(*) INTO migrated_count FROM business_analytics WHERE metrics != '{}'::jsonb;

RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Migration 034 completed successfully';
    RAISE NOTICE 'Total records: %', total_count;
    RAISE NOTICE 'Migrated to JSONB: %', migrated_count;
    RAISE NOTICE '============================================================================';
END $$;

-- ============================================================================
-- Optional: Drop old columns after verification (COMMENTED OUT FOR SAFETY)
-- Run this manually after verifying everything works
-- ============================================================================

-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS response_rate;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS average_response_time_hours;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS total_responses;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS positive_reviews;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS neutral_reviews;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS negative_reviews;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS sentiment_score;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS helpful_votes;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS profile_views;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS qr_code_scans;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS top_complaints_json;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS top_praise_json;
-- ALTER TABLE business_analytics DROP COLUMN IF EXISTS keyword_cloud_json;