-- ============================================================================
-- Migration 040: Add performance indexes for competitive benchmarking query
--
-- The CompetitiveBenchmarkService runs a CTE that joins:
--   business_category (to find same-category businesses)
--   review            (to count recent reviews, pos/neg breakdowns)
--   business_rating   (for bayesian_average)
--   business_analytics (for WRR from JSONB)
--
-- These indexes ensure the benchmark query runs efficiently even with
-- thousands of businesses and reviews.
-- ============================================================================

-- Index: find all businesses in a given category quickly
CREATE INDEX IF NOT EXISTS idx_business_category_category_id
    ON public.business_category (category_id);

-- Index: find all categories for a given business quickly  
CREATE INDEX IF NOT EXISTS idx_business_category_business_id
    ON public.business_category (business_id);

-- Index: filter approved reviews by business + created_at (for recency score)
CREATE INDEX IF NOT EXISTS idx_review_business_status_created
    ON public.review (business_id, status, created_at)
    WHERE status = 'APPROVED';

-- Index: filter approved reviews by business + star_rating (for pos/neg counts)
CREATE INDEX IF NOT EXISTS idx_review_business_status_rating
    ON public.review (business_id, status, star_rating)
    WHERE status = 'APPROVED';

-- Index: look up business_rating by business_id
CREATE INDEX IF NOT EXISTS idx_business_rating_business_id
    ON public.business_rating (business_id);

-- Index: look up business_analytics by business_id (already exists as business logic
--        uses it, but CREATE IF NOT EXISTS is safe to run idempotently)
CREATE UNIQUE INDEX IF NOT EXISTS idx_business_analytics_business_id
    ON public.business_analytics (business_id);

-- Index: filter parent businesses (is_branch = false) efficiently
CREATE INDEX IF NOT EXISTS idx_business_is_branch
    ON public.business (is_branch)
    WHERE is_branch = false;