-- ============================================================================
-- Migration 028: Performance Indexes and Optimizations
-- ============================================================================


CREATE EXTENSION IF NOT EXISTS pg_trgm;
       
-- Review table composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_review_business_status_created
    ON public.review(business_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_review_business_rating
    ON public.review(business_id, star_rating, created_at DESC)
    WHERE status = 'APPROVED';

CREATE INDEX IF NOT EXISTS idx_review_reviewer_status
    ON public.review(reviewer_id, status, created_at DESC)
    WHERE reviewer_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_review_email_status
    ON public.review(email, status, created_at DESC)
    WHERE is_guest_review = TRUE;

CREATE INDEX IF NOT EXISTS idx_review_validation_pending
    ON public.review(status, created_at)
    WHERE status = 'PENDING';

-- Business table indexes
CREATE INDEX IF NOT EXISTS idx_business_name_trgm
    ON public.business USING gin (name gin_trgm_ops);

-- Business category composite index
CREATE INDEX IF NOT EXISTS idx_business_category_business
    ON public.business_category(category_id, business_id);

-- User table indexes
CREATE INDEX IF NOT EXISTS idx_users_email_lower
    ON public.users(LOWER(email::text));

CREATE INDEX IF NOT EXISTS idx_users_username_lower
    ON public.users(LOWER(username::text));

CREATE INDEX IF NOT EXISTS idx_users_user_type_created
    ON public.users(user_type, created_at DESC);

-- Points and badges indexes
CREATE INDEX IF NOT EXISTS idx_user_points_total_points_user
    ON public.user_points(total_points DESC, user_id);

CREATE INDEX IF NOT EXISTS idx_user_badges_active
    ON public.user_badges(user_id, badge_type, is_active)
    WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_point_transactions_user_date
    ON public.point_transactions(user_id, created_at DESC);

-- Referral indexes
CREATE INDEX IF NOT EXISTS idx_referrals_code_status
    ON public.referrals(referral_code, status);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer_status
    ON public.referrals(referrer_id, status, created_at DESC);

-- Business rating indexes
CREATE INDEX IF NOT EXISTS idx_business_rating_bayesian_reviews
    ON public.business_rating(bayesian_average DESC, total_reviews DESC);

CREATE INDEX IF NOT EXISTS idx_business_rating_category_bayesian
    ON public.business_rating(category_id, bayesian_average DESC)
    WHERE category_id IS NOT NULL;

-- Dispute indexes
CREATE INDEX IF NOT EXISTS idx_dispute_business_status_created
    ON public.dispute(business_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_dispute_category_status
    ON public.dispute(category_id, status);

-- Reply indexes
CREATE INDEX IF NOT EXISTS idx_business_reply_business_status
    ON public.business_reply(business_id, status, created_at DESC);

-- Sentiment indexes
CREATE INDEX IF NOT EXISTS idx_sentiment_analysis_sentiment_confidence
    ON public.sentiment_analysis(sentiment, confidence_score DESC);

CREATE INDEX IF NOT EXISTS idx_business_sentiment_business_period
    ON public.business_sentiment_stats(business_id, period_type, period_start DESC);

-- External review indexes
CREATE INDEX IF NOT EXISTS idx_external_review_business_visible
    ON public.external_review(business_id, is_visible, external_created_at DESC)
    WHERE is_visible = TRUE;

CREATE INDEX IF NOT EXISTS idx_external_review_source_created
    ON public.external_review(source_id, external_created_at DESC);

-- Location/geolocation indexes
CREATE INDEX IF NOT EXISTS idx_user_geolocations_state_enabled
    ON public.user_geolocations(state, is_enabled)
    WHERE is_enabled = TRUE;

CREATE INDEX IF NOT EXISTS idx_geolocation_history_user_recorded
    ON public.geolocation_history(user_id, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_geolocation_history_vpn
    ON public.geolocation_history(vpn_detected, recorded_at DESC)
    WHERE vpn_detected = TRUE;

-- Business subscription indexes
CREATE INDEX IF NOT EXISTS idx_business_subscription_status_end
    ON public.business_subscription(status, end_date)
    WHERE status = 0; -- Active subscriptions

CREATE INDEX IF NOT EXISTS idx_business_subscription_expiring
    ON public.business_subscription(end_date)
    WHERE status = 0;

-- Verification tokens indexes
CREATE INDEX IF NOT EXISTS idx_verification_tokens_target_type
    ON public.verification_tokens(target, verification_type, expires_at)
    WHERE NOT is_used;

CREATE INDEX IF NOT EXISTS idx_verification_tokens_expires
    ON public.verification_tokens(expires_at)
    WHERE NOT is_used;

-- Analytics indexes (if business_analytics table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'business_analytics') THEN
CREATE INDEX IF NOT EXISTS idx_business_analytics_business_period
    ON public.business_analytics(business_id, period_type, period_start DESC);
CREATE INDEX IF NOT EXISTS idx_business_analytics_period_type
    ON public.business_analytics(period_type, period_start DESC);
END IF;
END $$;

-- Add missing constraints that improve query optimization
DO $$
BEGIN
    -- Ensure proper foreign key indexes exist
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_business_reps_business_id') THEN
CREATE INDEX idx_business_reps_business_id ON public.business_reps(business_id);
END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_business_branches_business_id') THEN
CREATE INDEX idx_business_branches_business_id ON public.business_branches(business_id);
END IF;
END $$;

COMMENT ON INDEX public.idx_review_business_status_created IS 'Optimizes business review list queries';
COMMENT ON INDEX public.idx_review_business_rating IS 'Optimizes rating calculation queries';
COMMENT ON INDEX public.idx_business_rating_bayesian_reviews IS 'Optimizes leaderboard/top business queries';

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Migration 028: Performance indexes created successfully';
    RAISE NOTICE 'Query performance should be significantly improved';
END $$;
