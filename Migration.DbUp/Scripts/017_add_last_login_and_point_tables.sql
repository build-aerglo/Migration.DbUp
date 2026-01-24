-- ============================================================================
-- User Service Database Schema Migration
-- Enhances the Points System with login tracking, point rules,
--  point multipliers, and airtime redemption
-- ============================================================================

-- ============================================================================
-- STEP 1: Add last_login tracking to users table
-- ============================================================================
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_users_last_login ON users(last_login);

COMMENT ON COLUMN users.last_login IS 'Timestamp of user last login for streak tracking';

-- ============================================================================
-- STEP 2: Rename column in user_points for clarity
-- ============================================================================
-- Change last_activity_date to last_login_date
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_points' 
        AND column_name = 'last_activity_date'
    ) THEN
ALTER TABLE user_points RENAME COLUMN last_activity_date TO last_login_date;
END IF;
END $$;

COMMENT ON COLUMN user_points.last_login_date IS 'Last login date for streak tracking (reset after 14 days gap)';

-- ============================================================================
-- STEP 3: Create POINT RULES table
-- ============================================================================
CREATE TABLE IF NOT EXISTS point_rules (
                                           id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action_type VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(500) NOT NULL,
    base_points_non_verified DECIMAL(10, 2) NOT NULL,
    base_points_verified DECIMAL(10, 2) NOT NULL,
    conditions JSONB,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id)
    );

CREATE INDEX IF NOT EXISTS idx_point_rules_action_type ON point_rules(action_type);
CREATE INDEX IF NOT EXISTS idx_point_rules_is_active ON point_rules(is_active);

COMMENT ON TABLE point_rules IS 'Defines point rules for different actions (reference/audit only)';
COMMENT ON COLUMN point_rules.action_type IS 'Type: review_body_short, review_image, milestone_25_reviews, etc.';
COMMENT ON COLUMN point_rules.conditions IS 'JSON object with rule-specific conditions (e.g., min_length, max_images)';

-- ============================================================================
-- STEP 4: Create POINT MULTIPLIERS table
-- ============================================================================
CREATE TABLE IF NOT EXISTS point_multipliers (
                                                 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    multiplier DECIMAL(5, 2) NOT NULL,
    action_types TEXT[],
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),

    CONSTRAINT chk_multiplier_positive CHECK (multiplier > 0),
    CONSTRAINT chk_dates CHECK (end_date > start_date)
    );

CREATE INDEX IF NOT EXISTS idx_point_multipliers_dates ON point_multipliers(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_point_multipliers_is_active ON point_multipliers(is_active);

COMMENT ON TABLE point_multipliers IS 'Special event multipliers for bonus point periods (e.g., 2x points weekend)';
COMMENT ON COLUMN point_multipliers.multiplier IS 'Point multiplier (e.g., 2.0 for 2x points, 1.5 for 1.5x points)';
COMMENT ON COLUMN point_multipliers.action_types IS 'Array of action types this applies to (NULL = all actions)';

-- ============================================================================
-- STEP 5: Create POINT REDEMPTIONS table
-- ============================================================================
CREATE TABLE IF NOT EXISTS point_redemptions (
                                                 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    points_redeemed DECIMAL(10, 2) NOT NULL,
    amount_in_naira DECIMAL(10, 2) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    transaction_reference VARCHAR(255),
    provider_response TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,

                                                   CONSTRAINT chk_points_positive CHECK (points_redeemed > 0),
    CONSTRAINT chk_amount_positive CHECK (amount_in_naira > 0),
    CONSTRAINT chk_status CHECK (status IN ('pending', 'completed', 'failed'))
    );

CREATE INDEX IF NOT EXISTS idx_point_redemptions_user_id ON point_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_point_redemptions_status ON point_redemptions(status);
CREATE INDEX IF NOT EXISTS idx_point_redemptions_created_at ON point_redemptions(created_at DESC);

COMMENT ON TABLE point_redemptions IS 'Tracks point redemptions for airtime purchases';
COMMENT ON COLUMN point_redemptions.status IS 'Status: pending, completed, failed';
COMMENT ON COLUMN point_redemptions.transaction_reference IS 'AfricaTalking transaction reference';

-- ============================================================================
-- STEP 6: Add UPDATE triggers for new tables
-- ============================================================================
CREATE OR REPLACE TRIGGER trg_point_rules_updated_at
    BEFORE UPDATE ON point_rules
                                              FOR EACH ROW
                                              EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER trg_point_multipliers_updated_at
    BEFORE UPDATE ON point_multipliers
                      FOR EACH ROW
                      EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER trg_point_redemptions_updated_at
    BEFORE UPDATE ON point_redemptions
                      FOR EACH ROW
                      EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- STEP 7: Seed DEFAULT POINT RULES
-- ============================================================================
INSERT INTO point_rules (action_type, description, base_points_non_verified, base_points_verified, conditions, is_active)
VALUES
    -- Review Body Points (based on length)
    ('review_body_short', 'Review body ≤50 characters', 2.0, 3.0, '{"min_length": 20, "max_length": 50}'::jsonb, true),
    ('review_body_medium', 'Review body 51-150 characters', 3.0, 4.5, '{"min_length": 51, "max_length": 150}'::jsonb, true),
    ('review_body_long', 'Review body 151-500 characters', 5.0, 6.5, '{"min_length": 151, "max_length": 500}'::jsonb, true),
    ('review_body_extra_long', 'Review body 500+ characters', 6.0, 7.5, '{"min_length": 500}'::jsonb, true),

    -- Image Points
    ('review_image', 'Per image attached to review (max 3)', 3.0, 4.5, '{"max_images": 3}'::jsonb, true),

    -- Milestone Points
    ('milestone_referral', 'Referral bonus (referred user completed 3 approved reviews)', 50.0, 75.0, '{"required_reviews": 3}'::jsonb, true),
    ('milestone_100_day_streak', '100-day consecutive login streak', 100.0, 150.0, '{"required_days": 100}'::jsonb, true),
    ('milestone_25_reviews', '25 approved reviews milestone', 20.0, 30.0, '{"required_reviews": 25}'::jsonb, true),
    ('milestone_100_helpful_votes', '100 total helpful votes received across all reviews', 50.0, 75.0, '{"required_votes": 100}'::jsonb, true),
    ('milestone_loyalty', '500 days member + 10 approved reviews', 500.0, 750.0, '{"required_days": 500, "required_reviews": 10}'::jsonb, true)
    ON CONFLICT (action_type) DO NOTHING;

-- ============================================================================
-- STEP 8: Update point_transactions comment for new transaction types
-- ============================================================================
COMMENT ON COLUMN point_transactions.transaction_type IS 'Type: earn, deduct, bonus, milestone, redeem';
COMMENT ON COLUMN point_transactions.reference_type IS 'Type of reference: review, referral, streak, milestone, helpful_vote, redemption';

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================