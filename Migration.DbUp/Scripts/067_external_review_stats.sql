-- ============================================================
-- 067 — External Review Stats Aggregate
-- Gives external (Google) reviews their own analytics store so they
-- are NEVER blended into native business_sentiment_stats (Decision 1).
-- One row per (business_id, source_type), refreshed by the
-- ExternalReviewStats 6h TimerTrigger in AnalyticsFunction.
-- Also retires the dead migration-063 blended function.
-- ============================================================

-- Step 1: Separate external aggregate.
CREATE TABLE IF NOT EXISTS public.external_review_stats (
    id               UUID        NOT NULL DEFAULT gen_random_uuid(),
    business_id      UUID        NOT NULL,
    source_type      VARCHAR(50) NOT NULL,
    avg_rating       NUMERIC(3,2),
    total_reviews    INT         NOT NULL DEFAULT 0,
    rating_1         INT         NOT NULL DEFAULT 0,
    rating_2         INT         NOT NULL DEFAULT 0,
    rating_3         INT         NOT NULL DEFAULT 0,
    rating_4         INT         NOT NULL DEFAULT 0,
    rating_5         INT         NOT NULL DEFAULT 0,
    sentiment_pos    INT         NOT NULL DEFAULT 0,
    sentiment_neg    INT         NOT NULL DEFAULT 0,
    sentiment_neu    INT         NOT NULL DEFAULT 0,
    owner_reply_rate NUMERIC(5,2),
    last_synced_at   TIMESTAMPTZ,
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_external_review_stats PRIMARY KEY (id),
    CONSTRAINT uq_external_review_stats_biz_source UNIQUE (business_id, source_type)
);

CREATE INDEX IF NOT EXISTS idx_external_review_stats_business
    ON public.external_review_stats (business_id);

-- Step 2: Retire the blend.
-- Migration 063 defined update_business_sentiment_stats_with_external(UUID),
-- which UNION-ed native + external rows into business_sentiment_stats.
-- It is never called from any service, and it INSERTs columns
-- (sentiment, review_count) that do not exist on the real period-based
-- business_sentiment_stats table — so it would error if ever invoked.
-- Native sentiment stats are computed natively in C#
-- (ReviewService.SentimentAnalysisRepository). Drop the dead blend so it
-- can never reintroduce the leak.
DROP FUNCTION IF EXISTS public.update_business_sentiment_stats_with_external(UUID);

COMMENT ON TABLE public.external_review_stats IS
    'Per-business, per-source external review aggregate (Decision 1). Never blended into native business_sentiment_stats.';
