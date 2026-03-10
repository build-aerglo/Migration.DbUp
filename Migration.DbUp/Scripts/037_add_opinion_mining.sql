-- Migration 037: Add opinion mining support
-- Adds opinions JSONB column to sentiment_analysis
-- Stores per-review aspect-level opinions extracted by Azure AI Language

ALTER TABLE sentiment_analysis
    ADD COLUMN IF NOT EXISTS opinions JSONB;

COMMENT ON COLUMN sentiment_analysis.opinions IS
    'Array of aspect opinions from Azure AI opinion mining. '
    'Each element: { aspect, opinion, sentiment, confidenceScore }';

-- Index for querying opinions by aspect across a business
-- Used by OpinionMiningService to aggregate across all reviews
CREATE INDEX IF NOT EXISTS idx_sentiment_analysis_opinions
    ON sentiment_analysis USING GIN (opinions)
    WHERE opinions IS NOT NULL;