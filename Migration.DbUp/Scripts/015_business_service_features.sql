-- V4: Add Business Service Features (BS-001 to BS-008)
-- Migration for business verification, subscription, multi-user access, auto-response,
-- analytics, claims, and external source integration

-- ============================================
-- BS-001: Business Verification Badge System
-- ============================================
CREATE TABLE IF NOT EXISTS business_verification (
                                       id UUID PRIMARY KEY,
                                       business_id UUID NOT NULL,

    -- Standard Level Requirements
                                       cac_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                       cac_number VARCHAR(50),
                                       cac_verified_at TIMESTAMPTZ,

                                       phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                       phone_number VARCHAR(20),
                                       phone_verified_at TIMESTAMPTZ,

                                       email_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                       email VARCHAR(255),
                                       email_verified_at TIMESTAMPTZ,

                                       address_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                       address_proof_url TEXT,
                                       address_verified_at TIMESTAMPTZ,

    -- Verified Level Requirements
                                       online_presence_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                       website_url TEXT,
                                       social_media_url TEXT,
                                       online_presence_verified_at TIMESTAMPTZ,

                                       other_ids_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                       tin_number VARCHAR(50),
                                       license_number VARCHAR(100),
                                       other_id_document_url TEXT,
                                       other_ids_verified_at TIMESTAMPTZ,

    -- Trusted Level Requirements
                                       business_domain_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                       business_domain_email VARCHAR(255),
                                       business_domain_email_verified_at TIMESTAMPTZ,

    -- Re-verification tracking
                                       requires_reverification BOOLEAN NOT NULL DEFAULT FALSE,
                                       reverification_reason TEXT,
                                       reverification_requested_at TIMESTAMPTZ,

    -- Audit fields
                                       created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                       verified_by_user_id UUID,

                                       CONSTRAINT fk_business_verification_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE,
                                       CONSTRAINT uk_business_verification_business UNIQUE (business_id)
);

CREATE INDEX IF NOT EXISTS idx_business_verification_business_id ON business_verification(business_id);
CREATE INDEX IF NOT EXISTS idx_business_verification_requires_reverification ON business_verification(requires_reverification) WHERE requires_reverification = TRUE;

-- ============================================
-- BS-002: Subscription Plan Management
-- ============================================
CREATE TABLE IF NOT EXISTS subscription_plan (
                                   id UUID PRIMARY KEY,
                                   name VARCHAR(100) NOT NULL,
                                   tier INTEGER NOT NULL DEFAULT 0, -- 0=Basic, 1=Premium, 2=Enterprise
                                   description TEXT,

    -- Pricing
                                   monthly_price DECIMAL(12, 2) NOT NULL DEFAULT 0,
                                   annual_price DECIMAL(12, 2) NOT NULL DEFAULT 0,
                                   currency VARCHAR(3) NOT NULL DEFAULT 'NGN',

    -- Limits
                                   monthly_reply_limit INTEGER NOT NULL DEFAULT 10,
                                   monthly_dispute_limit INTEGER NOT NULL DEFAULT 5,
                                   external_source_limit INTEGER NOT NULL DEFAULT 1,
                                   user_login_limit INTEGER NOT NULL DEFAULT 1,

    -- Feature flags
                                   private_reviews_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                                   data_api_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                                   dnd_mode_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                                   auto_response_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                                   branch_comparison_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                                   competitor_comparison_enabled BOOLEAN NOT NULL DEFAULT FALSE,

    -- Status
                                   is_active BOOLEAN NOT NULL DEFAULT TRUE,
                                   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                   updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                                   CONSTRAINT uk_subscription_plan_name UNIQUE (name)
);

CREATE INDEX IF NOT EXISTS idx_subscription_plan_tier ON subscription_plan(tier);
CREATE INDEX IF NOT EXISTS idx_subscription_plan_is_active ON subscription_plan(is_active) WHERE is_active = TRUE;

-- Insert default subscription plans
INSERT INTO subscription_plan (id, name, tier, description, monthly_price, annual_price, monthly_reply_limit, monthly_dispute_limit, external_source_limit, user_login_limit, private_reviews_enabled, data_api_enabled, dnd_mode_enabled, auto_response_enabled, branch_comparison_enabled, competitor_comparison_enabled)
VALUES
    (gen_random_uuid(), 'Basic', 0, 'Free plan with essential features', 0, 0, 10, 5, 1, 1, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),
    (gen_random_uuid(), 'Premium', 1, 'Enhanced features for growing businesses', 15000, 150000, 120, 25, 3, 3, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
    (gen_random_uuid(), 'Enterprise', 2, 'Full-featured plan for large businesses', 50000, 500000, 2147483647, 2147483647, 2147483647, 10, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE) ON CONFLICT (name) DO NOTHING;

-- Business Subscription table
CREATE TABLE IF NOT EXISTS business_subscription (
                                       id UUID PRIMARY KEY,
                                       business_id UUID NOT NULL,
                                       subscription_plan_id UUID NOT NULL,

    -- Subscription period
                                       start_date TIMESTAMPTZ NOT NULL,
                                       end_date TIMESTAMPTZ NOT NULL,
                                       billing_date TIMESTAMPTZ,
                                       is_annual BOOLEAN NOT NULL DEFAULT FALSE,

    -- Status
                                       status INTEGER NOT NULL DEFAULT 0, -- 0=Active, 1=Suspended, 2=Cancelled, 3=Expired, 4=PendingPayment
                                       cancelled_at TIMESTAMPTZ,
                                       cancellation_reason TEXT,

    -- Monthly usage tracking
                                       replies_used_this_month INTEGER NOT NULL DEFAULT 0,
                                       disputes_used_this_month INTEGER NOT NULL DEFAULT 0,
                                       usage_reset_date TIMESTAMPTZ NOT NULL,

    -- Audit fields
                                       created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                                       CONSTRAINT fk_business_subscription_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE,
                                       CONSTRAINT fk_business_subscription_plan FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plan(id),
                                       CONSTRAINT uk_business_subscription_business UNIQUE (business_id)
);

CREATE INDEX IF NOT EXISTS idx_business_subscription_business_id ON business_subscription(business_id);
CREATE INDEX IF NOT EXISTS idx_business_subscription_status ON business_subscription(status);
CREATE INDEX IF NOT EXISTS idx_business_subscription_end_date ON business_subscription(end_date);

-- ============================================
-- BS-003: Multi-User Access (Parent/Child)
-- ============================================
CREATE TABLE IF NOT EXISTS business_user (
                               id UUID PRIMARY KEY,
                               business_id UUID NOT NULL,
                               user_id UUID,

    -- User details
                               email VARCHAR(255) NOT NULL,
                               name VARCHAR(255),
                               phone_number VARCHAR(20),

    -- Role and permissions
                               role INTEGER NOT NULL DEFAULT 1, -- 0=Parent, 1=Child
                               is_owner BOOLEAN NOT NULL DEFAULT FALSE,

    -- Account status
                               status INTEGER NOT NULL DEFAULT 0, -- 0=Pending, 1=Active, 2=Disabled, 3=Revoked
                               invited_at TIMESTAMPTZ,
                               accepted_at TIMESTAMPTZ,
                               invitation_token VARCHAR(64),
                               invitation_expires_at TIMESTAMPTZ,

    -- Parent-managed settings
                               is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
                               enabled_by_user_id UUID,
                               disabled_at TIMESTAMPTZ,

    -- Audit fields
                               created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                               updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                               created_by_user_id UUID,

                               CONSTRAINT fk_business_user_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE,
                               CONSTRAINT uk_business_user_email_business UNIQUE (business_id, email)
);

CREATE INDEX IF NOT EXISTS idx_business_user_business_id ON business_user(business_id);
CREATE INDEX IF NOT EXISTS idx_business_user_user_id ON business_user(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_business_user_email ON business_user(email);
CREATE INDEX IF NOT EXISTS idx_business_user_invitation_token ON business_user(invitation_token) WHERE invitation_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_business_user_status ON business_user(status);

-- ============================================
-- BS-004: Auto-Response Templates
-- ============================================
CREATE TABLE IF NOT EXISTS auto_response_template (
                                        id UUID PRIMARY KEY,
                                        business_id UUID NOT NULL,

    -- Template details
                                        name VARCHAR(255) NOT NULL,
                                        sentiment INTEGER NOT NULL DEFAULT 0, -- 0=Positive, 1=Neutral, 2=Negative
                                        template_content TEXT NOT NULL,

    -- Template settings
                                        is_active BOOLEAN NOT NULL DEFAULT TRUE,
                                        is_default BOOLEAN NOT NULL DEFAULT FALSE,
                                        priority INTEGER NOT NULL DEFAULT 1,

    -- Star rating filter
                                        min_star_rating INTEGER,
                                        max_star_rating INTEGER,

    -- Usage statistics
                                        times_used INTEGER NOT NULL DEFAULT 0,
                                        last_used_at TIMESTAMPTZ,

    -- Audit fields
                                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                        created_by_user_id UUID,

                                        CONSTRAINT fk_auto_response_template_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE,
                                        CONSTRAINT chk_star_rating_range CHECK (
                                            (min_star_rating IS NULL OR (min_star_rating >= 1 AND min_star_rating <= 5)) AND
                                            (max_star_rating IS NULL OR (max_star_rating >= 1 AND max_star_rating <= 5)) AND
                                            (min_star_rating IS NULL OR max_star_rating IS NULL OR min_star_rating <= max_star_rating)
                                            )
);

CREATE INDEX IF NOT EXISTS idx_auto_response_template_business_id ON auto_response_template(business_id);
CREATE INDEX IF NOT EXISTS idx_auto_response_template_sentiment ON auto_response_template(sentiment);
CREATE INDEX IF NOT EXISTS idx_auto_response_template_is_active ON auto_response_template(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_auto_response_template_is_default ON auto_response_template(is_default) WHERE is_default = TRUE;

-- ============================================
-- BS-007: Business Comparison Analytics
-- ============================================
CREATE TABLE IF NOT EXISTS business_analytics (
                                    id UUID PRIMARY KEY,
                                    business_id UUID NOT NULL,

    -- Time period
                                    period_start TIMESTAMPTZ NOT NULL,
                                    period_end TIMESTAMPTZ NOT NULL,
                                    period_type INTEGER NOT NULL DEFAULT 2, -- 0=Daily, 1=Weekly, 2=Monthly, 3=Quarterly, 4=Yearly

    -- Rating metrics
                                    average_rating DECIMAL(3, 2) NOT NULL DEFAULT 0,
                                    rating_change DECIMAL(3, 2) NOT NULL DEFAULT 0,
                                    total_reviews INTEGER NOT NULL DEFAULT 0,
                                    new_reviews INTEGER NOT NULL DEFAULT 0,

    -- Sentiment breakdown
                                    positive_reviews INTEGER NOT NULL DEFAULT 0,
                                    neutral_reviews INTEGER NOT NULL DEFAULT 0,
                                    negative_reviews INTEGER NOT NULL DEFAULT 0,
                                    sentiment_score DECIMAL(5, 2) NOT NULL DEFAULT 0,

    -- Response metrics
                                    total_responses INTEGER NOT NULL DEFAULT 0,
                                    response_rate DECIMAL(5, 2) NOT NULL DEFAULT 0,
                                    average_response_time_hours DECIMAL(8, 2) NOT NULL DEFAULT 0,

    -- Engagement metrics
                                    helpful_votes INTEGER NOT NULL DEFAULT 0,
                                    profile_views INTEGER NOT NULL DEFAULT 0,
                                    qr_code_scans INTEGER NOT NULL DEFAULT 0,

    -- JSON fields for detailed data
                                    top_complaints_json JSONB,
                                    top_praise_json JSONB,
                                    keyword_cloud_json JSONB,

    -- Audit fields
                                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                                    CONSTRAINT fk_business_analytics_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE,
                                    CONSTRAINT uk_business_analytics_period UNIQUE (business_id, period_start, period_end, period_type)
);

CREATE INDEX IF NOT EXISTS idx_business_analytics_business_id ON business_analytics(business_id);
CREATE INDEX IF NOT EXISTS idx_business_analytics_period ON business_analytics(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_business_analytics_period_type ON business_analytics(period_type);

-- Branch Comparison Snapshot
CREATE TABLE IF NOT EXISTS branch_comparison_snapshot (
                                            id UUID PRIMARY KEY,
                                            parent_business_id UUID NOT NULL,
                                            snapshot_date TIMESTAMPTZ NOT NULL,

    -- JSON containing comparison data for all branches
                                            branch_metrics_json JSONB,

    -- Summary statistics
                                            top_performing_branch_id UUID,
                                            lowest_performing_branch_id UUID,
                                            average_rating_across_branches DECIMAL(3, 2) NOT NULL DEFAULT 0,
                                            total_reviews_across_branches INTEGER NOT NULL DEFAULT 0,

    -- Audit fields
                                            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                                            CONSTRAINT fk_branch_comparison_parent FOREIGN KEY (parent_business_id) REFERENCES business(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_branch_comparison_parent_id ON branch_comparison_snapshot(parent_business_id);
CREATE INDEX IF NOT EXISTS idx_branch_comparison_snapshot_date ON branch_comparison_snapshot(snapshot_date);

-- Competitor Comparison
CREATE TABLE IF NOT EXISTS competitor_comparison (
                                       id UUID PRIMARY KEY,
                                       business_id UUID NOT NULL,
                                       competitor_business_id UUID NOT NULL,

    -- Competitor details (cached)
                                       competitor_name VARCHAR(255) NOT NULL,
                                       competitor_category_id UUID,

    -- Comparison settings
                                       is_active BOOLEAN NOT NULL DEFAULT TRUE,
                                       display_order INTEGER NOT NULL DEFAULT 0,

    -- Audit fields
                                       created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                       updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                       added_by_user_id UUID,

                                       CONSTRAINT fk_competitor_comparison_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE,
                                       CONSTRAINT fk_competitor_comparison_competitor FOREIGN KEY (competitor_business_id) REFERENCES business(id) ON DELETE CASCADE,
                                       CONSTRAINT uk_competitor_comparison UNIQUE (business_id, competitor_business_id),
                                       CONSTRAINT chk_different_businesses CHECK (business_id != competitor_business_id)
    );

CREATE INDEX IF NOT EXISTS idx_competitor_comparison_business_id ON competitor_comparison(business_id);
CREATE INDEX IF NOT EXISTS idx_competitor_comparison_is_active ON competitor_comparison(is_active) WHERE is_active = TRUE;

-- Competitor Comparison Snapshot
CREATE TABLE IF NOT EXISTS competitor_comparison_snapshot (
                                                id UUID PRIMARY KEY,
                                                business_id UUID NOT NULL,
                                                snapshot_date TIMESTAMPTZ NOT NULL,
                                                period_type INTEGER NOT NULL DEFAULT 2, -- 0=Daily, 1=Weekly, 2=Monthly, 3=Quarterly, 4=Yearly

    -- JSON containing aggregated comparison data
                                                comparison_data_json JSONB,

    -- Summary
                                                competitors_compared INTEGER NOT NULL DEFAULT 0,
                                                ranking_position INTEGER NOT NULL DEFAULT 0,
                                                average_rating_difference DECIMAL(3, 2) NOT NULL DEFAULT 0,

    -- Audit fields
                                                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                                                CONSTRAINT fk_competitor_snapshot_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_competitor_snapshot_business_id ON competitor_comparison_snapshot(business_id);
CREATE INDEX IF NOT EXISTS idx_competitor_snapshot_date ON competitor_comparison_snapshot(snapshot_date);

-- ============================================
-- BS-008: Unclaimed Business Management
-- ============================================
CREATE TABLE IF NOT EXISTS business_claim_request (
                                        id UUID PRIMARY KEY,
                                        business_id UUID NOT NULL,
                                        claimant_user_id UUID,

    -- Claimant details
                                        full_name VARCHAR(255) NOT NULL,
                                        email VARCHAR(255) NOT NULL,
                                        phone_number VARCHAR(20) NOT NULL,
                                        role INTEGER NOT NULL DEFAULT 0, -- 0=Owner, 1=Manager, 2=AuthorizedRepresentative

    -- Verification documents
                                        cac_number VARCHAR(50),
                                        cac_document_url TEXT,
                                        id_document_url TEXT,
                                        proof_of_ownership_url TEXT,
                                        additional_documents_json JSONB,

    -- Claim status
                                        status INTEGER NOT NULL DEFAULT 0, -- 0=Pending, 1=UnderReview, 2=MoreInfoRequired, 3=Approved, 4=Rejected, 5=Cancelled
                                        submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                        reviewed_at TIMESTAMPTZ,
                                        reviewed_by_user_id UUID,
                                        review_notes TEXT,
                                        rejection_reason TEXT,

    -- Verification checklist
                                        cac_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                        id_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                        ownership_verified BOOLEAN NOT NULL DEFAULT FALSE,
                                        contact_verified BOOLEAN NOT NULL DEFAULT FALSE,

    -- Priority and escalation
                                        priority INTEGER NOT NULL DEFAULT 1, -- 0=Low, 1=Normal, 2=High, 3=Urgent
                                        is_escalated BOOLEAN NOT NULL DEFAULT FALSE,
                                        escalated_at TIMESTAMPTZ,
                                        escalation_reason TEXT,

    -- Expected review time (24-48 hours default)
                                        expected_review_by TIMESTAMPTZ NOT NULL,

    -- Audit fields
                                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                                        CONSTRAINT fk_business_claim_request_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_business_claim_request_business_id ON business_claim_request(business_id);
CREATE INDEX IF NOT EXISTS idx_business_claim_request_status ON business_claim_request(status);
CREATE INDEX IF NOT EXISTS idx_business_claim_request_priority ON business_claim_request(priority);
CREATE INDEX IF NOT EXISTS idx_business_claim_request_expected_review ON business_claim_request(expected_review_by);
CREATE INDEX IF NOT EXISTS idx_business_claim_request_is_escalated ON business_claim_request(is_escalated) WHERE is_escalated = TRUE;

-- ============================================
-- External Source Integration
-- ============================================
CREATE TABLE IF NOT EXISTS external_source (
                                 id UUID PRIMARY KEY,
                                 business_id UUID NOT NULL,

    -- Source details
                                 source_type INTEGER NOT NULL, -- 0=Twitter, 1=Instagram, 2=Facebook, 10=Chowdeck, 11=Jumia, 12=JiJi, 20=GoogleMyBusiness, 21=TripAdvisor, 100=CsvUpload
                                 source_name VARCHAR(100) NOT NULL,
                                 source_url TEXT,
                                 source_account_id VARCHAR(255),

    -- Connection status
                                 status INTEGER NOT NULL DEFAULT 0, -- 0=Pending, 1=Connected, 2=Disconnected, 3=Error, 4=RateLimited, 5=TokenExpired
                                 connected_at TIMESTAMPTZ,
                                 last_sync_at TIMESTAMPTZ,
                                 next_sync_at TIMESTAMPTZ,
                                 last_sync_error TEXT,

    -- Sync settings
                                 auto_sync_enabled BOOLEAN NOT NULL DEFAULT TRUE,
                                 sync_interval_hours INTEGER NOT NULL DEFAULT 24,

    -- Statistics
                                 total_reviews_imported INTEGER NOT NULL DEFAULT 0,
                                 reviews_imported_last_sync INTEGER NOT NULL DEFAULT 0,

    -- Authentication (encrypted)
                                 access_token TEXT,
                                 refresh_token TEXT,
                                 token_expires_at TIMESTAMPTZ,

    -- Audit fields
                                 created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                 updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                 connected_by_user_id UUID,

                                 CONSTRAINT fk_external_source_business FOREIGN KEY (business_id) REFERENCES business(id) ON DELETE CASCADE,
                                 CONSTRAINT uk_external_source_business_type UNIQUE (business_id, source_type)
);

CREATE INDEX IF NOT EXISTS idx_external_source_business_id ON external_source(business_id);
CREATE INDEX IF NOT EXISTS idx_external_source_status ON external_source(status);
CREATE INDEX IF NOT EXISTS idx_external_source_next_sync ON external_source(next_sync_at) WHERE auto_sync_enabled = TRUE AND status = 1;

-- ============================================
-- BS-005 & BS-006: Update business_settings table
-- ============================================
ALTER TABLE business_settings
    ADD COLUMN IF NOT EXISTS reviews_private_enabled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS private_reviews_reason TEXT,
    ADD COLUMN IF NOT EXISTS dnd_mode_reason TEXT,
    ADD COLUMN IF NOT EXISTS dnd_extension_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS dnd_mode_message TEXT,
    ADD COLUMN IF NOT EXISTS auto_response_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS auto_response_enabled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS external_sources_connected INTEGER NOT NULL DEFAULT 0;

-- Create indexes for business settings
CREATE INDEX IF NOT EXISTS idx_business_settings_dnd_mode_expires ON business_settings(dnd_mode_expires_at) WHERE dnd_mode_enabled = TRUE;
CREATE INDEX IF NOT EXISTS idx_business_settings_reviews_private ON business_settings(reviews_private) WHERE reviews_private = TRUE;
CREATE INDEX IF NOT EXISTS idx_business_settings_auto_response ON business_settings(auto_response_enabled) WHERE auto_response_enabled = TRUE;
