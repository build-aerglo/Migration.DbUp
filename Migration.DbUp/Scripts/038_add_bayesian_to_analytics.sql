

ALTER TABLE business_analytics
    ADD COLUMN IF NOT EXISTS bayesian_average_rating DECIMAL(3, 1) NOT NULL DEFAULT 0.0;

COMMENT ON COLUMN business_analytics.bayesian_average_rating IS
    'Bayesian average rating pulled from business_rating.bayesian_average on each '
    'analytics run. Accounts for review count — low-volume businesses are pulled '
    'toward the category/platform mean. Rounded to 1dp (same as business_rating).';

COMMENT ON COLUMN business_analytics.average_rating IS
    'Plain arithmetic average of approved review star ratings, rounded to 1dp. '
    'Use bayesian_average_rating for any ranking or public display.';


UPDATE business_analytics ba
SET    bayesian_average_rating = ROUND(br.bayesian_average, 1)
    FROM   business_rating br
WHERE  br.business_id = ba.business_id
  AND  ba.bayesian_average_rating = 0.0;


UPDATE business_analytics
SET    average_rating = ROUND(average_rating, 1)
WHERE  average_rating != ROUND(average_rating, 1);



DO $$
DECLARE
total_rows      INTEGER;
    backfilled_rows INTEGER;
    zero_bayesian   INTEGER;
BEGIN
SELECT COUNT(*)  INTO total_rows      FROM business_analytics;
SELECT COUNT(*)  INTO backfilled_rows FROM business_analytics WHERE bayesian_average_rating != 0.0;
SELECT COUNT(*)  INTO zero_bayesian   FROM business_analytics WHERE bayesian_average_rating = 0.0;

RAISE NOTICE '============================================================================';
    RAISE NOTICE 'Migration 038 completed';
    RAISE NOTICE 'Total analytics rows : %', total_rows;
    RAISE NOTICE 'Back-filled (bayesian): %', backfilled_rows;
    RAISE NOTICE 'Still zero (no match) : % (businesses with no reviews yet)', zero_bayesian;
    RAISE NOTICE '============================================================================';
END $$;