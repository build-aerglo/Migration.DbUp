-- ============================================================================
-- Migration 019: Enhance Review Table
-- Description: Safely adds missing columns to existing review table for
--              sentiment analysis, edit tracking, and helpful votes
-- Safe for: Both fresh installs and existing databases with data
-- ============================================================================

-- Add sentiment analysis columns
DO $$
BEGIN
    -- Add sentiment column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'sentiment'
    ) THEN
ALTER TABLE public.review ADD COLUMN sentiment VARCHAR(20);
ALTER TABLE public.review ADD CONSTRAINT chk_review_sentiment
    CHECK (sentiment IN ('POSITIVE', 'NEGATIVE', 'NEUTRAL'));
END IF;

    -- Add sentiment_score column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'sentiment_score'
    ) THEN
ALTER TABLE public.review ADD COLUMN sentiment_score DECIMAL(5, 4);
END IF;

    -- Add sentiment_analyzed_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'sentiment_analyzed_at'
    ) THEN
ALTER TABLE public.review ADD COLUMN sentiment_analyzed_at TIMESTAMP WITH TIME ZONE;
END IF;
END $$;

-- Add edit tracking columns
DO $$
BEGIN
    -- Add is_edited column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'is_edited'
    ) THEN
ALTER TABLE public.review ADD COLUMN is_edited BOOLEAN NOT NULL DEFAULT FALSE;
END IF;

    -- Add edit_count column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'edit_count'
    ) THEN
ALTER TABLE public.review ADD COLUMN edit_count INTEGER NOT NULL DEFAULT 0;
END IF;

    -- Add last_edited_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'last_edited_at'
    ) THEN
ALTER TABLE public.review ADD COLUMN last_edited_at TIMESTAMP WITH TIME ZONE;
END IF;

    -- Add original_review_body column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'original_review_body'
    ) THEN
ALTER TABLE public.review ADD COLUMN original_review_body TEXT;
END IF;
END $$;

-- Add helpful votes cache column
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'review' AND column_name = 'helpful_count'
    ) THEN
ALTER TABLE public.review ADD COLUMN helpful_count INTEGER NOT NULL DEFAULT 0;
END IF;
END $$;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_review_sentiment ON public.review(sentiment)
    WHERE sentiment IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_review_is_edited ON public.review(is_edited)
    WHERE is_edited = TRUE;
CREATE INDEX IF NOT EXISTS idx_review_helpful_count ON public.review(helpful_count DESC)
    WHERE helpful_count > 0;

-- Add comments
COMMENT ON COLUMN public.review.sentiment IS 'AI-analyzed sentiment: POSITIVE, NEGATIVE, or NEUTRAL';
COMMENT ON COLUMN public.review.sentiment_score IS 'Confidence score for sentiment (0.0000 to 1.0000)';
COMMENT ON COLUMN public.review.sentiment_analyzed_at IS 'Timestamp when sentiment analysis was performed';
COMMENT ON COLUMN public.review.is_edited IS 'Whether review has been edited after creation';
COMMENT ON COLUMN public.review.edit_count IS 'Number of times review has been edited';
COMMENT ON COLUMN public.review.last_edited_at IS 'Timestamp of last edit';
COMMENT ON COLUMN public.review.original_review_body IS 'Original review text before first edit';
COMMENT ON COLUMN public.review.helpful_count IS 'Cached count of helpful votes (updated by trigger)';

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Migration 019: Review table enhanced successfully';
END $$;