-- ============================================================================
-- Migration 035: Category Benchmark Table
--
-- Replaces the approach of embedding benchmark data inside each business's
-- business_analytics JSONB. Instead:
--
--   category_benchmark   — one row per category, stores the aggregated
--                          top-10% and category-average metrics. Written
--                          by the Azure Function whenever ANY business in
--                          that category is processed. All businesses in
--                          the category see fresh data on next read.
--
--   business_analytics   — gets new scalar columns for per-business rank
--                          data (rank, category_id, own metrics needed
--                          for the "Your Business" column).
--
-- Dashboard read in BusinessService:
--   SELECT ba.*, cb.*
--   FROM   business_analytics ba
--   LEFT JOIN category_benchmark cb ON cb.category_id = ba.category_id
--   WHERE  ba.business_id = ?
-- ============================================================================

-- ── 1. Category benchmark table ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.category_benchmark (
                                                         id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id             UUID NOT NULL UNIQUE,

    -- Top 10% averages (businesses ranked by TopScore)
    top10_avg_rating        DECIMAL(4,2)  NOT NULL DEFAULT 0,
    top10_avg_wrr           DECIMAL(6,2)  NOT NULL DEFAULT 0,
    top10_avg_recency       DECIMAL(6,4)  NOT NULL DEFAULT 0,
    top10_avg_positive_pct  DECIMAL(6,2)  NOT NULL DEFAULT 0,
    top10_avg_negative_pct  DECIMAL(6,2)  NOT NULL DEFAULT 0,
    top10_business_count    INTEGER       NOT NULL DEFAULT 0,

    -- Category-wide averages (all businesses with ≥1 approved review)
    cat_avg_rating          DECIMAL(4,2)  NOT NULL DEFAULT 0,
    cat_avg_wrr             DECIMAL(6,2)  NOT NULL DEFAULT 0,
    cat_avg_recency         DECIMAL(6,4)  NOT NULL DEFAULT 0,
    cat_avg_positive_pct    DECIMAL(6,2)  NOT NULL DEFAULT 0,
    cat_avg_negative_pct    DECIMAL(6,2)  NOT NULL DEFAULT 0,
    cat_business_count      INTEGER       NOT NULL DEFAULT 0,

    last_updated_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

CREATE INDEX IF NOT EXISTS idx_category_benchmark_category_id
    ON public.category_benchmark (category_id);

-- ── 2. New columns on business_analytics ───────────────────────────────────
-- These store per-business benchmark inputs so the dashboard query only
-- needs to read business_analytics + one JOIN; no extra computation at read time.

ALTER TABLE public.business_analytics
    ADD COLUMN IF NOT EXISTS category_id       UUID,
    ADD COLUMN IF NOT EXISTS category_rank     INTEGER,
    ADD COLUMN IF NOT EXISTS recency_score     DECIMAL(6,4),
    ADD COLUMN IF NOT EXISTS wrr_pct           DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS positive_pct      DECIMAL(6,2),
    ADD COLUMN IF NOT EXISTS negative_pct      DECIMAL(6,2);

CREATE INDEX IF NOT EXISTS idx_business_analytics_category_id
    ON public.business_analytics (category_id)
    WHERE category_id IS NOT NULL;