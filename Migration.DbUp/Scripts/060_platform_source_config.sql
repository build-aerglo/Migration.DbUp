-- ============================================================
-- 053 — Platform Source Config
-- Clereview admin layer. Controls which external source types
-- are available platform-wide. Seeds Google as the first source.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.platform_source_config (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_type         VARCHAR(50) NOT NULL UNIQUE,
    display_name        VARCHAR(100) NOT NULL,
    is_globally_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    requires_oauth      BOOLEAN NOT NULL DEFAULT FALSE,
    oauth_scope         TEXT,
    config_schema       JSONB,
    notes               TEXT,
    enabled_at          TIMESTAMP WITH TIME ZONE,
    disabled_at         TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_platform_source_enabled
    ON public.platform_source_config(is_globally_enabled)
    WHERE is_globally_enabled = TRUE;

-- Seed: Google is the first enabled source
INSERT INTO public.platform_source_config
    (source_type, display_name, is_globally_enabled, requires_oauth, oauth_scope, enabled_at)
VALUES
    ('GOOGLE_MY_BUSINESS', 'Google Business Reviews', TRUE, TRUE,
     'https://www.googleapis.com/auth/business.manage', NOW())
ON CONFLICT (source_type) DO NOTHING;

COMMENT ON TABLE public.platform_source_config IS
    'Clereview admin layer. Controls which external source types are available platform-wide.';
