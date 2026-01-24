-- ============================================================================
-- Migration 025: Sentiment Analysis
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.sentiment_analysis (
                                                         id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.review(id) ON DELETE CASCADE,
    sentiment VARCHAR(20) NOT NULL,
    confidence_score DECIMAL(5, 4) NOT NULL,
    positive_score DECIMAL(5, 4),
    negative_score DECIMAL(5, 4),
    neutral_score DECIMAL(5, 4),
    model_version VARCHAR(50),
    analyzed_text TEXT,
    analysis_provider VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_sentiment_analysis_sentiment CHECK (
                                                          sentiment IN ('POSITIVE', 'NEGATIVE', 'NEUTRAL')
    ),
    CONSTRAINT chk_sentiment_analysis_confidence CHECK (
                                                           confidence_score >= 0 AND confidence_score <= 1
                                                       ),
    CONSTRAINT uq_sentiment_analysis_review UNIQUE (review_id)
    );

CREATE TABLE IF NOT EXISTS public.business_sentiment_stats (
                                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    period_type VARCHAR(20) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_reviews INTEGER NOT NULL DEFAULT 0,
    positive_count INTEGER NOT NULL DEFAULT 0,
    negative_count INTEGER NOT NULL DEFAULT 0,
    neutral_count INTEGER NOT NULL DEFAULT 0,
    positive_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    negative_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    neutral_percentage DECIMAL(5, 2) NOT NULL DEFAULT 0.00,
    avg_confidence_score DECIMAL(5, 4),
    trend VARCHAR(20),
    trend_percentage_change DECIMAL(6, 2),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_business_sentiment_period_type CHECK (
                                                            period_type IN ('DAILY', 'WEEKLY', 'MONTHLY', 'ALL_TIME')
    ),
    CONSTRAINT chk_business_sentiment_trend CHECK (
                                                      trend IN ('IMPROVING', 'DECLINING', 'STABLE', 'INSUFFICIENT_DATA')
    ),
    CONSTRAINT uq_business_sentiment_period UNIQUE (business_id, period_type, period_start)
    );

CREATE TABLE IF NOT EXISTS public.sentiment_keywords (
                                                         id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    keyword VARCHAR(100) NOT NULL,
    sentiment VARCHAR(20) NOT NULL,
    occurrence_count INTEGER NOT NULL DEFAULT 1,
    last_seen_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_sentiment_keywords_sentiment CHECK (
                                                          sentiment IN ('POSITIVE', 'NEGATIVE', 'NEUTRAL')
    ),
    CONSTRAINT uq_business_keyword_sentiment UNIQUE (business_id, keyword, sentiment)
    );

CREATE TABLE IF NOT EXISTS public.sentiment_alert (
                                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    threshold_value DECIMAL(5, 2),
    actual_value DECIMAL(5, 2),
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    is_dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

CREATE INDEX IF NOT EXISTS idx_sentiment_analysis_review_id ON public.sentiment_analysis(review_id);
CREATE INDEX IF NOT EXISTS idx_sentiment_analysis_sentiment ON public.sentiment_analysis(sentiment);
CREATE INDEX IF NOT EXISTS idx_business_sentiment_stats_business_id ON public.business_sentiment_stats(business_id);
CREATE INDEX IF NOT EXISTS idx_business_sentiment_stats_period ON public.business_sentiment_stats(period_type, period_start);
CREATE INDEX IF NOT EXISTS idx_sentiment_keywords_business_id ON public.sentiment_keywords(business_id);
CREATE INDEX IF NOT EXISTS idx_sentiment_alert_business_id ON public.sentiment_alert(business_id);
CREATE INDEX IF NOT EXISTS idx_sentiment_alert_unread ON public.sentiment_alert(business_id, is_read)
    WHERE NOT is_read;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_business_sentiment_stats_updated_at') THEN
CREATE TRIGGER trg_business_sentiment_stats_updated_at
    BEFORE UPDATE ON public.business_sentiment_stats
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
END IF;
END $$;

-- Function to update sentiment stats after analysis
CREATE OR REPLACE FUNCTION public.update_business_sentiment_after_analysis()
RETURNS TRIGGER AS $$
DECLARE
v_business_id UUID;
BEGIN
SELECT business_id INTO v_business_id FROM public.review WHERE id = NEW.review_id;

INSERT INTO public.business_sentiment_stats (
    business_id, period_type, period_start, period_end,
    total_reviews, positive_count, negative_count, neutral_count,
    positive_percentage, negative_percentage, neutral_percentage
)
SELECT
    v_business_id, 'ALL_TIME', '1900-01-01'::DATE, '2099-12-31'::DATE,
    COUNT(*),
    COUNT(*) FILTER (WHERE s.sentiment = 'POSITIVE'),
    COUNT(*) FILTER (WHERE s.sentiment = 'NEGATIVE'),
    COUNT(*) FILTER (WHERE s.sentiment = 'NEUTRAL'),
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.sentiment = 'POSITIVE') / NULLIF(COUNT(*), 0), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.sentiment = 'NEGATIVE') / NULLIF(COUNT(*), 0), 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.sentiment = 'NEUTRAL') / NULLIF(COUNT(*), 0), 2)
FROM public.sentiment_analysis s
         JOIN public.review r ON s.review_id = r.id
WHERE r.business_id = v_business_id AND r.status = 'APPROVED'
    ON CONFLICT (business_id, period_type, period_start) DO UPDATE SET
    total_reviews = EXCLUDED.total_reviews,
                                                                positive_count = EXCLUDED.positive_count,
                                                                negative_count = EXCLUDED.negative_count,
                                                                neutral_count = EXCLUDED.neutral_count,
                                                                positive_percentage = EXCLUDED.positive_percentage,
                                                                negative_percentage = EXCLUDED.negative_percentage,
                                                                neutral_percentage = EXCLUDED.neutral_percentage,
                                                                updated_at = NOW();

RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
DROP TRIGGER IF EXISTS trigger_update_business_sentiment_after_analysis ON public.sentiment_analysis;
CREATE TRIGGER trigger_update_business_sentiment_after_analysis
    AFTER INSERT OR UPDATE ON public.sentiment_analysis
                        FOR EACH ROW
                        EXECUTE FUNCTION public.update_business_sentiment_after_analysis();
END $$;

COMMENT ON TABLE public.sentiment_analysis IS 'AI sentiment analysis results for reviews';
COMMENT ON TABLE public.business_sentiment_stats IS 'Aggregated sentiment statistics by business and time period';
