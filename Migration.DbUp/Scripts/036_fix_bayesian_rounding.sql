-- ============================================================================
-- Migration 036: Fix Bayesian Average Rounding to 1 Decimal Place
-- 
-- Problem: calculate_bayesian_average() was rounding to 2 decimal places.
--          The trigger (trigger_update_business_rating_insert_update) and the
--          RecalculateBusinessRatingAsync() stored query both call this function,
--          so updating the repository SQL alone has no effect — the trigger fires
--          and overwrites the value on every INSERT/UPDATE to the review table.
--
-- Fix: Redefine the function to return ROUND(..., 1) and update the trigger
--      function so the bayesian_average column always stores one decimal place.
-- ============================================================================

-- Step 1: Redefine calculate_bayesian_average to round to 1 decimal place
CREATE OR REPLACE FUNCTION public.calculate_bayesian_average(
    p_total_reviews INTEGER,
    p_sum_ratings   DECIMAL,
    p_confidence    DECIMAL DEFAULT 10.00,
    p_prior_mean    DECIMAL DEFAULT 3.50
)
RETURNS DECIMAL AS $$
BEGIN
    IF p_total_reviews = 0 THEN
        RETURN p_prior_mean;
END IF;

RETURN ROUND(
        ((p_confidence * p_prior_mean) + p_sum_ratings)
            / (p_confidence + p_total_reviews),
        1   -- ← was 2, now 1
       );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Step 2: Redefine the trigger function so its inline INSERT/UPDATE also
--         stores 1 decimal place (the function call already rounds, but
--         being explicit guards against future copy-paste drift).
CREATE OR REPLACE FUNCTION public.update_business_rating_from_reviews()
RETURNS TRIGGER AS $$
DECLARE
v_category_avg DECIMAL;
    v_category_id  UUID;
BEGIN
SELECT bc.category_id, COALESCE(crs.category_average, 3.50)
INTO   v_category_id, v_category_avg
FROM   public.business b
           LEFT JOIN public.business_category bc  ON b.id = bc.business_id
           LEFT JOIN public.category_rating_stats crs ON bc.category_id = crs.category_id
WHERE  b.id = COALESCE(NEW.business_id, OLD.business_id)
    LIMIT  1;

v_category_avg := COALESCE(v_category_avg, 3.50);

INSERT INTO public.business_rating (
    business_id, category_id,
    total_reviews, sum_ratings,
    one_star_count, two_star_count, three_star_count, four_star_count, five_star_count,
    simple_average, bayesian_average,
    prior_mean, last_calculated_at
)
SELECT
    r.business_id,
    v_category_id,
    COUNT(*)                                                       AS total_reviews,
    SUM(r.star_rating)                                             AS sum_ratings,
    COUNT(*) FILTER (WHERE r.star_rating >= 0.5 AND r.star_rating < 1.5) AS one_star,
    COUNT(*) FILTER (WHERE r.star_rating >= 1.5 AND r.star_rating < 2.5) AS two_star,
    COUNT(*) FILTER (WHERE r.star_rating >= 2.5 AND r.star_rating < 3.5) AS three_star,
    COUNT(*) FILTER (WHERE r.star_rating >= 3.5 AND r.star_rating < 4.5) AS four_star,
    COUNT(*) FILTER (WHERE r.star_rating >= 4.5)                          AS five_star,
    ROUND(AVG(r.star_rating), 2)                                   AS simple_avg,
    -- calculate_bayesian_average now returns ROUND(...,1) internally
    public.calculate_bayesian_average(
            COUNT(*)::INTEGER,
            SUM(r.star_rating),
            10.00,
            v_category_avg
    )                                                              AS bayesian_avg,
    v_category_avg,
    NOW()
FROM public.review r
WHERE r.business_id = COALESCE(NEW.business_id, OLD.business_id)
  AND r.status = 'APPROVED'
GROUP BY r.business_id
    ON CONFLICT (business_id) DO UPDATE SET
    category_id       = EXCLUDED.category_id,
                                     total_reviews     = EXCLUDED.total_reviews,
                                     sum_ratings       = EXCLUDED.sum_ratings,
                                     one_star_count    = EXCLUDED.one_star_count,
                                     two_star_count    = EXCLUDED.two_star_count,
                                     three_star_count  = EXCLUDED.three_star_count,
                                     four_star_count   = EXCLUDED.four_star_count,
                                     five_star_count   = EXCLUDED.five_star_count,
                                     simple_average    = EXCLUDED.simple_average,
                                     bayesian_average  = EXCLUDED.bayesian_average,
                                     prior_mean        = EXCLUDED.prior_mean,
                                     last_calculated_at = NOW(),
                                     updated_at        = NOW();

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Step 3: Back-fill existing rows so they reflect the new rounding
UPDATE public.business_rating
SET    bayesian_average = ROUND(bayesian_average, 1),
       updated_at       = NOW()
WHERE  bayesian_average != ROUND(bayesian_average, 1);

-- Step 4: Verify a sample of updated rows
SELECT business_id,
       bayesian_average,
       ROUND(bayesian_average, 1) AS expected,
       bayesian_average = ROUND(bayesian_average, 1) AS is_1dp
FROM   public.business_rating
           LIMIT  10;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Migration 036: bayesian_average now rounds to 1 decimal place everywhere';
    RAISE NOTICE '  - calculate_bayesian_average() updated';
    RAISE NOTICE '  - update_business_rating_from_reviews() trigger updated';
    RAISE NOTICE '  - Existing rows back-filled';
END $$;