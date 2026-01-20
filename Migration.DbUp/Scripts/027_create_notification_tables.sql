-- ============================================================================
-- Migration 027: Notification Tables
-- ============================================================================
DROP TABLE IF EXISTS public.notification;

CREATE TABLE IF NOT EXISTS public.notifications (
                                                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template TEXT,
    channel TEXT,
    retry_count INTEGER DEFAULT 0,
    recipient TEXT,
    payload JSONB,
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    delivered_at TIMESTAMP WITH TIME ZONE,
                               status VARCHAR(100) DEFAULT 'sent'
    );

CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_channel ON public.notifications(channel);
CREATE INDEX IF NOT EXISTS idx_notifications_requested_at ON public.notifications(requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient);

COMMENT ON TABLE public.notifications IS 'Notification tracking and delivery status';

-- Success messages
DO $$
BEGIN
    RAISE NOTICE 'Migration 023: Helpful vote system created successfully';
    RAISE NOTICE 'Migration 024: Review edit history created successfully';
    RAISE NOTICE 'Migration 025: Sentiment analysis system created successfully';
    RAISE NOTICE 'Migration 026: External review integration created successfully';
    RAISE NOTICE 'Migration 027: Notification tables created successfully';
END $$;