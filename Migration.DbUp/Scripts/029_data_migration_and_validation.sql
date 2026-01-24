-- ============================================================================
-- Migration 029: Data Migration and Integrity Checks
-- ============================================================================

-- Step 1: Migrate business rating data if needed
DO $$
DECLARE
v_migrated_count INTEGER := 0;
BEGIN
    -- Check if business.avg_rating exists and has data
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'business' AND column_name = 'avg_rating'
    ) THEN
        -- Migrate only businesses not yet in business_rating
        INSERT INTO public.business_rating (
            business_id,
            total_reviews,
            simple_average,
            bayesian_average,
            prior_mean,
            created_at,
            updated_at,
            last_calculated_at
        )
SELECT
    b.id,
    COALESCE(b.review_count, 0),
    COALESCE(b.avg_rating, 0.00),
    COALESCE(b.avg_rating, 0.00),
    3.50,
    NOW(),
    NOW(),
    NOW()
FROM public.business b
WHERE (b.review_count > 0 OR b.avg_rating > 0)
  AND NOT EXISTS (
    SELECT 1 FROM public.business_rating br
    WHERE br.business_id = b.id
);

GET DIAGNOSTICS v_migrated_count = ROW_COUNT;

IF v_migrated_count > 0 THEN
            RAISE NOTICE 'Migrated % businesses from business.avg_rating to business_rating table', v_migrated_count;
END IF;
END IF;
END $$;

-- Step 2: Recalculate business ratings from actual reviews
DO $$
DECLARE
v_recalculated_count INTEGER := 0;
BEGIN
    -- Update business_rating from actual review data
UPDATE public.business_rating br
SET
    total_reviews = subquery.total_reviews,
    sum_ratings = subquery.sum_ratings,
    one_star_count = subquery.one_star,
    two_star_count = subquery.two_star,
    three_star_count = subquery.three_star,
    four_star_count = subquery.four_star,
    five_star_count = subquery.five_star,
    simple_average = subquery.simple_avg,
    bayesian_average = subquery.bayesian_avg,
    last_calculated_at = NOW(),
    updated_at = NOW()
    FROM (
        SELECT
            r.business_id,
            COUNT(*) as total_reviews,
            SUM(r.star_rating) as sum_ratings,
            COUNT(*) FILTER (WHERE r.star_rating >= 0.5 AND r.star_rating < 1.5) as one_star,
            COUNT(*) FILTER (WHERE r.star_rating >= 1.5 AND r.star_rating < 2.5) as two_star,
            COUNT(*) FILTER (WHERE r.star_rating >= 2.5 AND r.star_rating < 3.5) as three_star,
            COUNT(*) FILTER (WHERE r.star_rating >= 3.5 AND r.star_rating < 4.5) as four_star,
            COUNT(*) FILTER (WHERE r.star_rating >= 4.5) as five_star,
            ROUND(AVG(r.star_rating), 2) as simple_avg,
            public.calculate_bayesian_average(
                COUNT(*)::INTEGER,
                SUM(r.star_rating),
                10.00,
                3.50
            ) as bayesian_avg
        FROM public.review r
        WHERE r.status = 'APPROVED'
        GROUP BY r.business_id
    ) AS subquery
WHERE br.business_id = subquery.business_id;

GET DIAGNOSTICS v_recalculated_count = ROW_COUNT;

IF v_recalculated_count > 0 THEN
        RAISE NOTICE 'Recalculated ratings for % businesses from actual review data', v_recalculated_count;
END IF;
END $$;

-- Step 3: Initialize helpful_count for existing reviews
DO $$
DECLARE
v_updated_count INTEGER := 0;
BEGIN
UPDATE public.review r
SET helpful_count = COALESCE(vote_counts.count, 0)
    FROM (
        SELECT review_id, COUNT(*) as count
        FROM public.helpful_vote
        GROUP BY review_id
    ) AS vote_counts
WHERE r.id = vote_counts.review_id
  AND r.helpful_count != vote_counts.count;

GET DIAGNOSTICS v_updated_count = ROW_COUNT;

IF v_updated_count > 0 THEN
        RAISE NOTICE 'Updated helpful_count for % reviews', v_updated_count;
END IF;
END $$;

-- Step 4: Create category rating stats if categories exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'category') THEN
        INSERT INTO public.category_rating_stats (
            category_id,
            category_name,
            total_businesses,
            total_reviews,
            sum_all_ratings,
            category_average
        )
SELECT
    c.id,
    c.name,
    COUNT(DISTINCT bc.business_id) as total_businesses,
    SUM(br.total_reviews) as total_reviews,
    SUM(br.sum_ratings) as sum_all_ratings,
    ROUND(AVG(br.simple_average), 2) as category_average
FROM public.category c
         JOIN public.business_category bc ON c.id = bc.category_id
         JOIN public.business_rating br ON bc.business_id = br.business_id
WHERE br.total_reviews > 0
GROUP BY c.id, c.name
    ON CONFLICT (category_id) DO UPDATE SET
    total_businesses = EXCLUDED.total_businesses,
                                     total_reviews = EXCLUDED.total_reviews,
                                     sum_all_ratings = EXCLUDED.sum_all_ratings,
                                     category_average = EXCLUDED.category_average,
                                     updated_at = NOW();

RAISE NOTICE 'Category rating statistics calculated';
END IF;
END $$;

-- Step 5: Data integrity checks
DO $$
DECLARE
v_orphaned_reviews INTEGER;
    v_missing_user_points INTEGER;
    v_duplicate_votes INTEGER;
BEGIN
    -- Check for orphaned reviews (business_id doesn't exist)
SELECT COUNT(*) INTO v_orphaned_reviews
FROM public.review r
WHERE NOT EXISTS (SELECT 1 FROM public.business b WHERE b.id = r.business_id);

IF v_orphaned_reviews > 0 THEN
        RAISE WARNING 'Found % orphaned reviews (business_id does not exist)', v_orphaned_reviews;
END IF;
    
    -- Check for users without user_points records
SELECT COUNT(*) INTO v_missing_user_points
FROM public.users u
WHERE u.user_type = 'end_user'
  AND NOT EXISTS (SELECT 1 FROM public.user_points up WHERE up.user_id = u.id);

IF v_missing_user_points > 0 THEN
        -- Auto-create missing user_points
        INSERT INTO public.user_points (user_id, total_points, current_streak, longest_streak)
SELECT u.id, 0, 0, 0
FROM public.users u
WHERE u.user_type = 'end_user'
  AND NOT EXISTS (SELECT 1 FROM public.user_points up WHERE up.user_id = u.id);

RAISE NOTICE 'Created user_points records for % users', v_missing_user_points;
END IF;
    
    -- Check for duplicate helpful votes (should be prevented by unique constraint)
SELECT COUNT(*) INTO v_duplicate_votes
FROM (
         SELECT review_id, user_id, COUNT(*)
         FROM public.helpful_vote
         GROUP BY review_id, user_id
         HAVING COUNT(*) > 1
     ) duplicates;

IF v_duplicate_votes > 0 THEN
        RAISE WARNING 'Found % duplicate helpful votes - constraint may need manual cleanup', v_duplicate_votes;
END IF;
END $$;

-- Step 6: Update platform statistics
DO $$
DECLARE
v_platform_avg DECIMAL;
BEGIN
SELECT ROUND(AVG(simple_average), 2) INTO v_platform_avg
FROM public.business_rating
WHERE total_reviews >= 5;

IF v_platform_avg IS NOT NULL THEN
UPDATE public.platform_rating_stats
SET stat_value = v_platform_avg, updated_at = NOW()
WHERE stat_key = 'platform_average_rating';

RAISE NOTICE 'Updated platform average rating to %', v_platform_avg;
END IF;
END $$;

-- Step 7: Vacuum analyze for performance
VACUUM ANALYZE public.review;
VACUUM ANALYZE public.business_rating;
VACUUM ANALYZE public.business;
VACUUM ANALYZE public.helpful_vote;
VACUUM ANALYZE public.user_points;

-- Final validation report
DO $$
DECLARE
v_total_reviews INTEGER;
    v_total_businesses INTEGER;
    v_businesses_with_ratings INTEGER;
    v_total_users INTEGER;
    v_total_helpful_votes INTEGER;
BEGIN
SELECT COUNT(*) INTO v_total_reviews FROM public.review;
SELECT COUNT(*) INTO v_total_businesses FROM public.business;
SELECT COUNT(*) INTO v_businesses_with_ratings FROM public.business_rating;
SELECT COUNT(*) INTO v_total_users FROM public.users;
SELECT COUNT(*) INTO v_total_helpful_votes FROM public.helpful_vote;

RAISE NOTICE '===========================================';
    RAISE NOTICE 'Migration 029: Data Migration Complete';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Total Reviews: %', v_total_reviews;
    RAISE NOTICE 'Total Businesses: %', v_total_businesses;
    RAISE NOTICE 'Businesses with Ratings: %', v_businesses_with_ratings;
    RAISE NOTICE 'Total Users: %', v_total_users;
    RAISE NOTICE 'Total Helpful Votes: %', v_total_helpful_votes;
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'All data migrations completed successfully!';
    RAISE NOTICE 'Database is ready for production use';
    RAISE NOTICE '===========================================';
END $$;