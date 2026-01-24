-- ============================================================================
-- Migration 026: External Review Integration
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.external_review_source (
                                                             id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    source_type VARCHAR(50) NOT NULL,
    source_name VARCHAR(100) NOT NULL,
    connection_config JSONB,
    external_account_id VARCHAR(255),
    external_account_name VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    auto_sync_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    sync_frequency_hours INTEGER DEFAULT 24,
    last_sync_at TIMESTAMP WITH TIME ZONE,
                               last_sync_status VARCHAR(20),
    last_sync_error TEXT,
    total_imported_reviews INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_external_source_sync_status CHECK (
                                                         last_sync_status IN ('SUCCESS', 'PARTIAL', 'FAILED', 'IN_PROGRESS')
    ),
    CONSTRAINT uq_business_source UNIQUE (business_id, source_type, external_account_id)
    );

CREATE TABLE IF NOT EXISTS public.external_review (
                                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES public.external_review_source(id) ON DELETE CASCADE,
    business_id UUID NOT NULL,
    external_review_id VARCHAR(255) NOT NULL,
    external_url TEXT,
    reviewer_name VARCHAR(255),
    reviewer_handle VARCHAR(255),
    reviewer_avatar_url TEXT,
    star_rating INTEGER,
    review_text TEXT,
    media_urls TEXT[],
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    external_created_at TIMESTAMP WITH TIME ZONE,
    external_updated_at TIMESTAMP WITH TIME ZONE,
                                                                             sentiment VARCHAR(20),
    sentiment_score DECIMAL(5, 4),
    imported_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    is_visible BOOLEAN NOT NULL DEFAULT TRUE,
    is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
    flag_reason TEXT,

    CONSTRAINT chk_external_review_star_rating CHECK (star_rating >= 1 AND star_rating <= 5),
    CONSTRAINT chk_external_review_sentiment CHECK (sentiment IN ('POSITIVE', 'NEGATIVE', 'NEUTRAL')),
    CONSTRAINT uq_external_review UNIQUE (source_id, external_review_id)
    );

CREATE TABLE IF NOT EXISTS public.external_review_sync_log (
                                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES public.external_review_source(id) ON DELETE CASCADE,
    sync_started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    sync_completed_at TIMESTAMP WITH TIME ZONE,
                                                                             status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    reviews_found INTEGER DEFAULT 0,
    reviews_imported INTEGER DEFAULT 0,
    reviews_updated INTEGER DEFAULT 0,
    reviews_skipped INTEGER DEFAULT 0,
    error_message TEXT,
    error_details JSONB,

    CONSTRAINT chk_sync_log_status CHECK (
                                             status IN ('IN_PROGRESS', 'SUCCESS', 'PARTIAL', 'FAILED')
    )
    );

CREATE TABLE IF NOT EXISTS public.csv_import_template (
                                                          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    column_mapping JSONB NOT NULL,
    date_format VARCHAR(50) DEFAULT 'YYYY-MM-DD',
    delimiter CHAR(1) DEFAULT ',',
    has_header_row BOOLEAN DEFAULT TRUE,
    is_system_template BOOLEAN NOT NULL DEFAULT FALSE,
    created_by_user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

CREATE INDEX IF NOT EXISTS idx_external_source_business_id ON public.external_review_source(business_id);
CREATE INDEX IF NOT EXISTS idx_external_source_type ON public.external_review_source(source_type);
CREATE INDEX IF NOT EXISTS idx_external_source_active ON public.external_review_source(is_active);
CREATE INDEX IF NOT EXISTS idx_external_review_source_id ON public.external_review(source_id);
CREATE INDEX IF NOT EXISTS idx_external_review_business_id ON public.external_review(business_id);
CREATE INDEX IF NOT EXISTS idx_external_review_sentiment ON public.external_review(sentiment);
CREATE INDEX IF NOT EXISTS idx_sync_log_source_id ON public.external_review_sync_log(source_id);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_external_review_source_updated_at') THEN
CREATE TRIGGER trg_external_review_source_updated_at
    BEFORE UPDATE ON public.external_review_source
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_external_review_last_updated_at') THEN
CREATE TRIGGER trg_external_review_last_updated_at
    BEFORE UPDATE ON public.external_review
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
END IF;
END $$;

INSERT INTO public.csv_import_template (name, description, column_mapping, is_system_template) VALUES
                                                                                                   ('Google Reviews Export', 'Template for Google Takeout reviews',
                                                                                                    '{"reviewer_name": "Reviewer", "review_text": "Review", "star_rating": "Rating", "external_created_at": "Date"}', TRUE),
                                                                                                   ('Facebook Reviews Export', 'Template for Facebook page reviews',
                                                                                                    '{"reviewer_name": "Reviewer Name", "review_text": "Recommendation", "external_created_at": "Created"}', TRUE),
                                                                                                   ('Generic Template', 'Basic template',
                                                                                                    '{"reviewer_name": "name", "review_text": "review", "star_rating": "rating", "external_created_at": "date"}', TRUE)
    ON CONFLICT DO NOTHING;

COMMENT ON TABLE public.external_review_source IS 'External review source configuration (social media, CSV, etc.)';
COMMENT ON TABLE public.external_review IS 'Reviews imported from external sources';