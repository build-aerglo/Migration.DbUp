-- ======================================================
-- 017 - Update Review Schema for Branch Implementation
-- ======================================================

-- Drop old foreign key constraint
ALTER TABLE public.review DROP CONSTRAINT IF EXISTS fk_review_location;

-- Drop existing triggers
DROP TRIGGER IF EXISTS trg_review_updated_at ON public.review;
DROP TRIGGER IF EXISTS trigger_update_business_rating ON public.review;
DROP TRIGGER IF EXISTS trigger_update_business_rating_insert_update ON public.review;
DROP TRIGGER IF EXISTS trigger_update_business_rating_delete ON public.review;

-- Drop ALL existing star rating check constraints (to ensure clean slate)
ALTER TABLE public.review DROP CONSTRAINT IF EXISTS review_star_rating_check;
ALTER TABLE public.review DROP CONSTRAINT IF EXISTS chk_review_star_rating;

-- Change star_rating to DECIMAL to support half stars
ALTER TABLE public.review ALTER COLUMN star_rating TYPE DECIMAL(2,1);

-- Add new star rating constraint (supports half stars)
ALTER TABLE public.review ADD CONSTRAINT chk_review_star_rating
    CHECK (star_rating >= 0.5 AND star_rating <= 5.0 AND (star_rating * 2) = FLOOR(star_rating * 2));

-- Recreate updated_at trigger
CREATE TRIGGER trg_review_updated_at
    BEFORE UPDATE ON public.review
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ======================================================
-- Create update_business_rating function if it doesn't exist
-- This function should have been created in an earlier migration,
-- but we're ensuring it exists here for safety
-- ======================================================

CREATE OR REPLACE FUNCTION update_business_rating()
RETURNS TRIGGER AS $$
DECLARE
v_category_avg DECIMAL;
BEGIN
    -- Get category average for prior mean (or use default 3.50)
SELECT COALESCE(crs.category_average, 3.50)
INTO v_category_avg
FROM business_rating br
         LEFT JOIN category_rating_stats crs ON br.category_id = crs.category_id
WHERE br.business_id = COALESCE(NEW.business_id, OLD.business_id);

IF v_category_avg IS NULL THEN
        v_category_avg := 3.50;
END IF;

    -- Recalculate and update business rating
INSERT INTO business_rating (
    business_id,
    total_reviews,
    sum_ratings,
    one_star_count,
    two_star_count,
    three_star_count,
    four_star_count,
    five_star_count,
    simple_average,
    bayesian_average,
    prior_mean,
    last_calculated_at
)
SELECT
    r.business_id,
    COUNT(*) as total_reviews,
    SUM(r.star_rating) as sum_ratings,
    COUNT(*) FILTER (WHERE r.star_rating = 1) as one_star,
    COUNT(*) FILTER (WHERE r.star_rating = 2) as two_star,
    COUNT(*) FILTER (WHERE r.star_rating = 3) as three_star,
    COUNT(*) FILTER (WHERE r.star_rating = 4) as four_star,
    COUNT(*) FILTER (WHERE r.star_rating = 5) as five_star,
    ROUND(AVG(r.star_rating), 2) as simple_avg,
    ROUND(
            ((10.00 * v_category_avg) + SUM(r.star_rating)) / (10.00 + COUNT(*)),
            2
    ) as bayesian_avg,
    v_category_avg,
    NOW()
FROM review r
WHERE r.business_id = COALESCE(NEW.business_id, OLD.business_id)
  AND r.status = 'APPROVED'
GROUP BY r.business_id
    ON CONFLICT (business_id) DO UPDATE SET
    total_reviews = EXCLUDED.total_reviews,
                                     sum_ratings = EXCLUDED.sum_ratings,
                                     one_star_count = EXCLUDED.one_star_count,
                                     two_star_count = EXCLUDED.two_star_count,
                                     three_star_count = EXCLUDED.three_star_count,
                                     four_star_count = EXCLUDED.four_star_count,
                                     five_star_count = EXCLUDED.five_star_count,
                                     simple_average = EXCLUDED.simple_average,
                                     bayesian_average = EXCLUDED.bayesian_average,
                                     prior_mean = EXCLUDED.prior_mean,
                                     last_calculated_at = NOW(),
                                     updated_at = NOW();

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ======================================================
-- Create the split triggers
-- ======================================================

-- Trigger for INSERT and UPDATE operations
CREATE TRIGGER trigger_update_business_rating_insert_update
    AFTER INSERT OR UPDATE OF status, star_rating ON public.review
    FOR EACH ROW
    WHEN (NEW.status = 'APPROVED')
    EXECUTE FUNCTION update_business_rating();

-- Trigger for DELETE operations (only references OLD, which is valid)
CREATE TRIGGER trigger_update_business_rating_delete
    AFTER DELETE ON public.review
    FOR EACH ROW
    WHEN (OLD.status = 'APPROVED')
    EXECUTE FUNCTION update_business_rating();

-- Add comments
COMMENT ON COLUMN public.review.location_id IS 'Branch ID from Business Service (no FK - different database). NULL = review for business without specific branch';
COMMENT ON COLUMN public.review.star_rating IS 'Decimal rating from 0.5 to 5.0 (supports half stars: 0.5, 1.0, 1.5, ... 5.0)';

-- Create index for location_id
CREATE INDEX IF NOT EXISTS idx_review_location_id ON public.review(location_id);