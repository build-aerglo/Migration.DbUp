-- ============================================================================
-- Migration 020: Business Reply System
-- Description: Creates tables for business reply management, moderation,
--              and warning system
-- ============================================================================

-- Business Reply Table
CREATE TABLE IF NOT EXISTS public.business_reply (
                                                     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.review(id) ON DELETE CASCADE,
    business_id UUID NOT NULL,
    responder_id UUID NOT NULL,
    reply_body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE,
                                                             is_auto_approved BOOLEAN NOT NULL DEFAULT FALSE,

                                                             -- Constraints
                                                             CONSTRAINT chk_business_reply_body_length CHECK (
                                                             char_length(reply_body) >= 10 AND char_length(reply_body) <= 1000
    ),
    CONSTRAINT chk_business_reply_status CHECK (
                                                   status IN ('PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED')
    ),
    -- One reply per review
    CONSTRAINT uq_business_reply_review UNIQUE (review_id)
    );

-- Reply Moderation Rules
CREATE TABLE IF NOT EXISTS public.reply_moderation_rule (
                                                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_type VARCHAR(50) NOT NULL,
    pattern TEXT NOT NULL,
    description TEXT,
    severity VARCHAR(20) NOT NULL DEFAULT 'WARNING',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_reply_moderation_severity CHECK (
                                                       severity IN ('WARNING', 'BLOCK', 'SUSPEND')
    )
    );

-- Reply Warning Table (tracks violations)
CREATE TABLE IF NOT EXISTS public.reply_warning (
                                                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    reply_id UUID REFERENCES public.business_reply(id) ON DELETE SET NULL,
    violation_type VARCHAR(50) NOT NULL,
    description TEXT,
    warning_level INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,

                                                           CONSTRAINT chk_reply_warning_level CHECK (warning_level BETWEEN 1 AND 3)
    );

-- Reply Suspension Table
CREATE TABLE IF NOT EXISTS public.reply_suspension (
                                                       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    reason TEXT NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
                             is_active BOOLEAN NOT NULL DEFAULT TRUE,
                             created_by VARCHAR(255),

    CONSTRAINT chk_reply_suspension_dates CHECK (ends_at > started_at)
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_business_reply_review_id ON public.business_reply(review_id);
CREATE INDEX IF NOT EXISTS idx_business_reply_business_id ON public.business_reply(business_id);
CREATE INDEX IF NOT EXISTS idx_business_reply_status ON public.business_reply(status);
CREATE INDEX IF NOT EXISTS idx_business_reply_created_at ON public.business_reply(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reply_warning_business_id ON public.reply_warning(business_id);
CREATE INDEX IF NOT EXISTS idx_reply_warning_created_at ON public.reply_warning(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reply_suspension_business_id ON public.reply_suspension(business_id);
CREATE INDEX IF NOT EXISTS idx_reply_suspension_active ON public.reply_suspension(business_id, is_active)
    WHERE is_active = TRUE;

-- Trigger for updated_at
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'trg_business_reply_updated_at'
    ) THEN
CREATE TRIGGER trg_business_reply_updated_at
    BEFORE UPDATE ON public.business_reply
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();
END IF;
END $$;

-- Insert default moderation rules
INSERT INTO public.reply_moderation_rule (rule_type, pattern, description, severity)
VALUES
    ('BLACKLIST_WORD', 'idiot|stupid|moron|fool|dumb', 'Offensive language targeting reviewer', 'BLOCK'),
    ('BLACKLIST_WORD', 'lawsuit|sue|court|lawyer', 'Legal threat language', 'WARNING'),
    ('PERSONAL_INFO', '\b\d{10,11}\b', 'Phone number pattern', 'BLOCK'),
    ('PERSONAL_INFO', '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', 'Email pattern', 'BLOCK'),
    ('EXTERNAL_LINK', 'https?://[^\s]+', 'External URL', 'WARNING'),
    ('ABUSE', 'kill|threat|harm|attack|hurt', 'Threatening language', 'SUSPEND')
    ON CONFLICT DO NOTHING;

-- Comments
COMMENT ON TABLE public.business_reply IS 'Business responses to reviews with approval workflow';
COMMENT ON TABLE public.reply_moderation_rule IS 'Pattern-based moderation rules for reply content';
COMMENT ON TABLE public.reply_warning IS 'Warning tracking for businesses violating reply guidelines';
COMMENT ON TABLE public.reply_suspension IS 'Active suspensions preventing businesses from replying';
COMMENT ON COLUMN public.business_reply.status IS 'PENDING: Awaiting approval, APPROVED: Published, REJECTED: Blocked, SUSPENDED: User suspended';
COMMENT ON COLUMN public.reply_warning.warning_level IS '1=Rejected, 2=Warning, 3=Suspended';

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Migration 020: Business reply system created successfully';
END $$;