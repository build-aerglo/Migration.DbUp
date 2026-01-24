-- ============================================================================
-- Migration 021: Dispute Management System
-- Description: Creates tables for review dispute handling and resolution
-- ============================================================================

-- Dispute Categories Reference
CREATE TABLE IF NOT EXISTS public.dispute_category (
                                                       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    requires_evidence BOOLEAN NOT NULL DEFAULT TRUE,
    priority INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_dispute_category_priority CHECK (priority BETWEEN 1 AND 3)
    );

-- Main Dispute Table
CREATE TABLE IF NOT EXISTS public.dispute (
                                              id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.review(id) ON DELETE CASCADE,
    business_id UUID NOT NULL,
    category_id UUID NOT NULL REFERENCES public.dispute_category(id),
    filed_by_user_id UUID NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    explanation TEXT NOT NULL,
    evidence_urls TEXT[],
    business_plan VARCHAR(20) NOT NULL,

    -- Resolution fields
    resolution_notes TEXT,
    resolved_by_user_id UUID,
    resolved_at TIMESTAMP WITH TIME ZONE,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    review_created_at TIMESTAMP WITH TIME ZONE NOT NULL,

                                                             -- Constraints
                                                             CONSTRAINT chk_dispute_status CHECK (
                                                             status IN ('PENDING', 'UNDER_REVIEW', 'INFORMATION_REQUESTED',
                                                             'UPHELD', 'DISMISSED', 'ESCALATED', 'WITHDRAWN')
    ),
    CONSTRAINT chk_dispute_explanation_length CHECK (
                                                        char_length(explanation) >= 50 AND char_length(explanation) <= 2000
    ),
    CONSTRAINT chk_dispute_review_age CHECK (
                                                created_at - review_created_at <= INTERVAL '15 days'
                                            )
    );

-- Dispute Comments (for back-and-forth communication)
CREATE TABLE IF NOT EXISTS public.dispute_comment (
                                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispute_id UUID NOT NULL REFERENCES public.dispute(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_type VARCHAR(20) NOT NULL,
    comment_body TEXT NOT NULL,
    attachment_urls TEXT[],
    is_internal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_dispute_comment_user_type CHECK (
                                                       user_type IN ('BUSINESS', 'REVIEWER', 'SUPPORT', 'ADMIN')
    ),
    CONSTRAINT chk_dispute_comment_length CHECK (
                                                    char_length(comment_body) >= 1 AND char_length(comment_body) <= 2000
    )
    );

-- Dispute Status History
CREATE TABLE IF NOT EXISTS public.dispute_status_history (
                                                             id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dispute_id UUID NOT NULL REFERENCES public.dispute(id) ON DELETE CASCADE,
    previous_status VARCHAR(30),
    new_status VARCHAR(30) NOT NULL,
    changed_by_user_id UUID NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
    );

-- Monthly Dispute Usage Tracking
CREATE TABLE IF NOT EXISTS public.dispute_usage (
                                                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    month_year VARCHAR(7) NOT NULL,
    dispute_count INTEGER NOT NULL DEFAULT 0,
    plan_limit INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_dispute_usage_business_month UNIQUE (business_id, month_year)
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dispute_review_id ON public.dispute(review_id);
CREATE INDEX IF NOT EXISTS idx_dispute_business_id ON public.dispute(business_id);
CREATE INDEX IF NOT EXISTS idx_dispute_status ON public.dispute(status);
CREATE INDEX IF NOT EXISTS idx_dispute_category_id ON public.dispute(category_id);
CREATE INDEX IF NOT EXISTS idx_dispute_created_at ON public.dispute(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_dispute_pending ON public.dispute(status, created_at)
    WHERE status IN ('PENDING', 'UNDER_REVIEW');
CREATE INDEX IF NOT EXISTS idx_dispute_comment_dispute_id ON public.dispute_comment(dispute_id);
CREATE INDEX IF NOT EXISTS idx_dispute_comment_created_at ON public.dispute_comment(created_at);
CREATE INDEX IF NOT EXISTS idx_dispute_history_dispute_id ON public.dispute_status_history(dispute_id);
CREATE INDEX IF NOT EXISTS idx_dispute_usage_business_id ON public.dispute_usage(business_id);
CREATE INDEX IF NOT EXISTS idx_dispute_usage_month ON public.dispute_usage(month_year);

-- Triggers for updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trg_dispute_updated_at'
    ) THEN
CREATE TRIGGER trg_dispute_updated_at
    BEFORE UPDATE ON public.dispute
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trg_dispute_usage_updated_at'
    ) THEN
CREATE TRIGGER trg_dispute_usage_updated_at
    BEFORE UPDATE ON public.dispute_usage
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
END IF;
END $$;

-- Insert default dispute categories
INSERT INTO public.dispute_category (code, name, description, requires_evidence, priority)
VALUES
    ('INAPPROPRIATE_LANGUAGE', 'Inappropriate Language',
     'Review contains profanity, hate speech, or offensive content', TRUE, 2),
    ('FAKE_SPAM', 'Fake/Spam',
     'Review appears to be fake, spam, or from a bot', TRUE, 2),
    ('PRIVATE_INFORMATION', 'Private Information',
     'Review contains personal or private information', TRUE, 3),
    ('CONFLICT_OF_INTEREST', 'Conflict of Interest',
     'Review is from a competitor, former employee, or someone with personal bias', TRUE, 1),
    ('LEGAL_CONCERNS', 'Legal Concerns',
     'Review contains defamatory, libelous, or legally actionable content', TRUE, 3),
    ('FACTUALLY_INCORRECT', 'Factually Incorrect',
     'Review contains demonstrably false claims about the business', TRUE, 1),
    ('NOT_A_CUSTOMER', 'Not a Customer',
     'Reviewer was never a customer or visited the business', TRUE, 2),
    ('OFF_TOPIC', 'Off Topic',
     'Review is not about the business or its services', TRUE, 1)
    ON CONFLICT (code) DO NOTHING;

-- Comments
COMMENT ON TABLE public.dispute IS 'Business disputes of reviews with resolution workflow';
COMMENT ON TABLE public.dispute_category IS 'Predefined categories for dispute reasons';
COMMENT ON TABLE public.dispute_comment IS 'Communication thread between business, reviewer, and support';
COMMENT ON TABLE public.dispute_status_history IS 'Audit trail of dispute status changes';
COMMENT ON TABLE public.dispute_usage IS 'Monthly tracking of disputes filed (for plan limit enforcement)';
COMMENT ON COLUMN public.dispute.status IS 'Dispute lifecycle: PENDING → UNDER_REVIEW → UPHELD/DISMISSED';
COMMENT ON COLUMN public.dispute.business_plan IS 'Business subscription plan (BASIC/PREMIUM/ENTERPRISE) at time of dispute';
COMMENT ON COLUMN public.dispute_comment.is_internal IS 'Internal notes only visible to support/admin staff';

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Migration 021: Dispute management system created successfully';
END $$;