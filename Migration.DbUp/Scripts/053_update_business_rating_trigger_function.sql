CREATE OR REPLACE FUNCTION update_business_rating()
RETURNS TRIGGER AS $$
DECLARE v_category_avg DECIMAL;
BEGIN
SELECT COALESCE(crs.category_average, 3.50) INTO v_category_avg
FROM business_rating br
         LEFT JOIN category_rating_stats crs ON br.category_id = crs.category_id
WHERE br.business_id = COALESCE(NEW.business_id, OLD.business_id);

IF v_category_avg IS NULL THEN
        v_category_avg := 3.50;
END IF;

INSERT INTO business_rating (
    business_id, total_reviews, sum_ratings,
    one_star_count, two_star_count, three_star_count, four_star_count, five_star_count,
    simple_average, bayesian_average, prior_mean, last_calculated_at
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
            ((10.00 * v_category_avg) + SUM(r.star_rating)) / (10.00 + COUNT(*)), 2
    ) as bayesian_avg,
    v_category_avg,
    NOW()
FROM review r
WHERE r.business_id = COALESCE(NEW.business_id, OLD.business_id)
  AND r.status = 'APPROVED'
  AND r.is_verification_pending = FALSE  -- ✅ the fix
GROUP BY r.business_id
    ON CONFLICT (business_id) DO UPDATE SET
    total_reviews      = EXCLUDED.total_reviews,
                                     sum_ratings        = EXCLUDED.sum_ratings,
                                     one_star_count     = EXCLUDED.one_star_count,
                                     two_star_count     = EXCLUDED.two_star_count,
                                     three_star_count   = EXCLUDED.three_star_count,
                                     four_star_count    = EXCLUDED.four_star_count,
                                     five_star_count    = EXCLUDED.five_star_count,
                                     simple_average     = EXCLUDED.simple_average,
                                     bayesian_average   = EXCLUDED.bayesian_average,
                                     prior_mean         = EXCLUDED.prior_mean,
                                     last_calculated_at = NOW(),
                                     updated_at         = NOW();

RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;