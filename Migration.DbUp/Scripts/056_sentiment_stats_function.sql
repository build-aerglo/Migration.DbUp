-- ============================================================
-- 056 — Sentiment Stats Aggregation Function
-- Combined native + external sentiment counts per business,
-- called by SentimentStatsRefreshBackgroundService.
-- ============================================================

CREATE OR REPLACE FUNCTION public.update_business_sentiment_stats_with_external(
    p_business_id UUID
) RETURNS VOID AS $$
BEGIN
    -- Combined sentiment counts: native + external (visible only)
    DELETE FROM public.business_sentiment_stats WHERE business_id = p_business_id;

    INSERT INTO public.business_sentiment_stats (business_id, sentiment, review_count, updated_at)
    SELECT p_business_id, sentiment, SUM(cnt), NOW()
    FROM (
        SELECT sentiment, COUNT(*) AS cnt
        FROM public.review
        WHERE business_id = p_business_id AND status = 'APPROVED' AND sentiment IS NOT NULL
        GROUP BY sentiment
        UNION ALL
        SELECT sentiment, COUNT(*) AS cnt
        FROM public.external_review
        WHERE business_id = p_business_id AND is_visible = TRUE AND sentiment IS NOT NULL
        GROUP BY sentiment
    ) combined
    GROUP BY sentiment;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.update_business_sentiment_stats_with_external IS
    'Called by SentimentStatsRefreshBackgroundService every 6h for businesses with external reviews.';
