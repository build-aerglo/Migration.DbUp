-- ============================================================================
-- Complete Database Trigger Solution with NOTIFY
-- ============================================================================

-- STEP 1: Create sync function (updates business table when business_rating changes)
CREATE OR REPLACE FUNCTION sync_business_rating_to_business()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the business table whenever business_rating changes
UPDATE business
SET
    avg_rating = NEW.bayesian_average,
    review_count = NEW.total_reviews,
    updated_at = NOW()
WHERE id = NEW.business_id;

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop old trigger if exists
DROP TRIGGER IF EXISTS trigger_sync_business_rating ON business_rating;

-- Create trigger on business_rating table
CREATE TRIGGER trigger_sync_business_rating
    AFTER INSERT OR UPDATE ON business_rating
                        FOR EACH ROW
                        EXECUTE FUNCTION sync_business_rating_to_business();

-- ============================================================================
-- STEP 2: Create notification function (notifies app when business updates)
-- ============================================================================
CREATE OR REPLACE FUNCTION notify_business_updated()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify application via PostgreSQL LISTEN/NOTIFY
    -- Only notify when ratings actually change
    PERFORM pg_notify('business_updated', NEW.id::text);
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop old trigger if exists
DROP TRIGGER IF EXISTS trigger_notify_business_rating_update ON business;

-- Create trigger on business table (fires AFTER the sync trigger updates it)
CREATE TRIGGER trigger_notify_business_rating_update
    AFTER UPDATE OF avg_rating, review_count ON business
    FOR EACH ROW
    WHEN (OLD.avg_rating IS DISTINCT FROM NEW.avg_rating 
          OR OLD.review_count IS DISTINCT FROM NEW.review_count)
    EXECUTE FUNCTION notify_business_updated();

-- ============================================================================
-- STEP 3: Sync existing data
-- ============================================================================
UPDATE business b
SET
    avg_rating = br.bayesian_average,
    review_count = br.total_reviews,
    updated_at = NOW()
    FROM business_rating br
WHERE b.id = br.business_id
  AND br.total_reviews > 0;

-- ============================================================================
-- STEP 4: Verify the setup
-- ============================================================================
SELECT
    b.id,
    b.name,
    b.avg_rating as business_avg,
    b.review_count as business_count,
    br.bayesian_average as rating_bayesian,
    br.total_reviews as rating_count,
    b.avg_rating = br.bayesian_average as in_sync
FROM business b
         LEFT JOIN business_rating br ON b.id = br.business_id
WHERE br.total_reviews > 0
    LIMIT 10;

