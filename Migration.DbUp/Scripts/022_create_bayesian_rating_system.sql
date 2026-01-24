-- ============================================================================
-- Migration 022: Bayesian Average Rating System
-- Description: Creates tables and functions for advanced Bayesian rating
--              calculation with category-aware prior means
-- ============================================================================

-- Business Rating Aggregation Table
CREATE TABLE IF NOT EXISTS public.business_rating (
                                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL UNIQUE,
    category_id UUID,

    -- Raw statistics
    total_reviews INTEGER NOT NULL DEFAULT 0,
    sum_ratings DECIMAL(10, 1) NOT NULL DEFAULT 0,

    -- Star distribution
    one_star_count INTEGER NOT NULL DEFAULT 0,
    two_star_count INTEGER NOT NULL DEFAULT 0,
    three_star_count INTEGER NOT NULL DEFAULT 0,
    four_star_count INTEGER NOT NULL DEFAULT 0,
    five_star_count INTEGER NOT NULL DEFAULT 0,

    -- Calculated ratings
    simple_average DECIMAL(3, 2) NOT NULL DEFAULT 0.00,
    bayesian_average DECIMAL(3, 2) NOT NULL DEFAULT 0.00,

    -- Bayesian parameters
    confidence_parameter DECIMAL(5, 2) NOT NULL DEFAULT 10.00,
    prior_mean DECIMAL(3, 2) NOT NULL DEFAULT 3.50,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_calculated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

-- Category Average Table (for prior mean calculation)
CREATE TABLE IF NOT EXISTS public.category_rating_stats (
                                                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID NOT NULL UNIQUE,
    category_name VARCHAR(255) NOT NULL,
    total_businesses INTEGER NOT NULL DEFAULT 0,
    total_reviews INTEGER NOT NULL DEFAULT 0,
    sum_all_ratings DECIMAL(10, 1) NOT NULL DEFAULT 0,
    category_average DECIMAL(3, 2) NOT NULL DEFAULT 3.50,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

-- Platform-wide Statistics
CREATE TABLE IF NOT EXISTS public.platform_rating_stats (
                                                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stat_key VARCHAR(50) NOT NULL UNIQUE,
    stat_value DECIMAL(10, 4) NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_business_rating_business_id ON public.business_rating(business_id);
CREATE INDEX IF NOT EXISTS idx_business_rating_category_id ON public.business_rating(category_id);
CREATE INDEX IF NOT EXISTS idx_business_rating_bayesian ON public.business_rating(bayesian_average DESC);
CREATE INDEX IF NOT EXISTS idx_business_rating_simple ON public.business_rating(simple_average DESC);
CREATE INDEX IF NOT EXISTS idx_business_rating_total_reviews ON public.business_rating(total_reviews DESC);
CREATE INDEX IF NOT EXISTS idx_category_rating_stats_category_id ON public.category_rating_stats(category_id);

-- Triggers for updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trg_business_rating_updated_at'
    ) THEN
CREATE TRIGGER trg_business_rating_updated_at
    BEFORE UPDATE ON public.business_rating
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trg_category_rating_stats_updated_at'
    ) THEN
CREATE TRIGGER trg_category_rating_stats_updated_at
    BEFORE UPDATE ON public.category_rating_stats
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
END IF;
END $$;

-- Function to calculate Bayesian average
-- Formula: (C * m + sum_ratings) / (C + total_reviews)
-- Where: C = confidence parameter, m = prior mean (category average)
CREATE OR REPLACE FUNCTION public.calculate_bayesian_average(
    p_total_reviews INTEGER,
    p_sum_ratings DECIMAL,
    p_confidence DECIMAL DEFAULT 10.00,
    p_prior_mean DECIMAL DEFAULT 3.50
)
RETURNS DECIMAL AS $$
BEGIN
    IF p_total_reviews = 0 THEN
        RETURN p_prior_mean;
END IF;

RETURN ROUND(
        ((p_confidence * p_prior_mean) + p_sum_ratings) / (p_confidence + p_total_reviews),
        2
       );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to update business rating when a review changes
CREATE OR REPLACE FUNCTION public.update_business_rating_from_reviews()
RETURNS TRIGGER AS $$
DECLARE
v_category_avg DECIMAL;
    v_category_id UUID;
BEGIN
    -- Get business category and category average
SELECT bc.category_id, COALESCE(crs.category_average, 3.50)
INTO v_category_id, v_category_avg
FROM public.business b
         LEFT JOIN public.business_category bc ON b.id = bc.business_id
         LEFT JOIN public.category_rating_stats crs ON bc.category_id = crs.category_id
WHERE b.id = COALESCE(NEW.business_id, OLD.business_id)
    LIMIT 1;

-- Default to 3.50 if no category found
v_category_avg := COALESCE(v_category_avg, 3.50);

    -- Recalculate and update business rating
INSERT INTO public.business_rating (
    business_id,
    category_id,
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
    v_category_id,
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
            v_category_avg
    ) as bayesian_avg,
    v_category_avg,
    NOW()
FROM public.review r
WHERE r.business_id = COALESCE(NEW.business_id, OLD.business_id)
  AND r.status = 'APPROVED'
GROUP BY r.business_id
    ON CONFLICT (business_id) DO UPDATE SET
    category_id = EXCLUDED.category_id,
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

-- Create triggers to update business rating
-- Separate triggers for INSERT/UPDATE and DELETE to avoid NEW/OLD issues
DO $$
BEGIN
    -- Drop old trigger if exists
DROP TRIGGER IF EXISTS trigger_update_business_rating ON public.review;
DROP TRIGGER IF EXISTS trigger_update_business_rating_insert_update ON public.review;
DROP TRIGGER IF EXISTS trigger_update_business_rating_delete ON public.review;

-- Create new triggers
CREATE TRIGGER trigger_update_business_rating_insert_update
    AFTER INSERT OR UPDATE OF status, star_rating ON public.review
    FOR EACH ROW
    WHEN (NEW.status = 'APPROVED')
    EXECUTE FUNCTION public.update_business_rating_from_reviews();

CREATE TRIGGER trigger_update_business_rating_delete
    AFTER DELETE ON public.review
    FOR EACH ROW
    WHEN (OLD.status = 'APPROVED')
    EXECUTE FUNCTION public.update_business_rating_from_reviews();
END $$;

-- Insert platform-wide default stats
INSERT INTO public.platform_rating_stats (stat_key, stat_value, description)
VALUES
    ('default_confidence_parameter', 10.00, 'Default C value for Bayesian calculation'),
    ('default_prior_mean', 3.50, 'Default m value when no category average available'),
    ('platform_average_rating', 3.50, 'Overall platform average rating')
    ON CONFLICT (stat_key) DO UPDATE SET
    stat_value = EXCLUDED.stat_value,
                                  description = EXCLUDED.description,
                                  updated_at = NOW();

-- Comments
COMMENT ON TABLE public.business_rating IS 'Aggregated rating calculations using Bayesian average';
COMMENT ON TABLE public.category_rating_stats IS 'Category-level average ratings for Bayesian prior mean';
COMMENT ON TABLE public.platform_rating_stats IS 'Platform-wide rating statistics and parameters';
COMMENT ON COLUMN public.business_rating.simple_average IS 'Traditional arithmetic mean rating';
COMMENT ON COLUMN public.business_rating.bayesian_average IS 'Bayesian average: (C*m + sum)/(C + n) - more stable for low review counts';
COMMENT ON COLUMN public.business_rating.confidence_parameter IS 'C in Bayesian formula - higher = more weight to prior mean';
COMMENT ON COLUMN public.business_rating.prior_mean IS 'm in Bayesian formula - typically category or platform average';

-- Migrate existing data from business.avg_rating if it exists
DO $$
DECLARE
v_avg_rating_exists BOOLEAN;
BEGIN
    -- Check if avg_rating column exists in business table
SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'business'
      AND column_name = 'avg_rating'
) INTO v_avg_rating_exists;

IF v_avg_rating_exists THEN
        -- Migrate existing ratings
        INSERT INTO public.business_rating (
            business_id,
            total_reviews,
            simple_average,
            bayesian_average,
            prior_mean
        )
SELECT
    b.id,
    COALESCE(b.review_count, 0),
    COALESCE(b.avg_rating, 0.00),
    COALESCE(b.avg_rating, 0.00), -- Initially same as simple
    3.50
FROM public.business b
WHERE b.review_count > 0 OR b.avg_rating > 0
    ON CONFLICT (business_id) DO NOTHING;

RAISE NOTICE 'Migrated existing ratings from business.avg_rating';
END IF;
END $$;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Migration 022: Bayesian rating system created successfully';
    RAISE NOTICE 'Existing ratings have been migrated if business.avg_rating existed';
    RAISE NOTICE 'Triggers will automatically update ratings when reviews are approved/changed';
END $$;