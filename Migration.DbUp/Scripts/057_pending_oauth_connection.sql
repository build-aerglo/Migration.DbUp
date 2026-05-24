CREATE TABLE IF NOT EXISTS public.pending_oauth_connection (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    opaque_token            VARCHAR(100) NOT NULL UNIQUE,
    business_id             UUID NOT NULL,
    user_id                 UUID NOT NULL,
    account_id              VARCHAR(255) NOT NULL,
    encrypted_refresh_token TEXT NOT NULL,
    locations_json          TEXT NOT NULL,
    expires_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '10 minutes'),
    created_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pending_oauth_opaque
    ON public.pending_oauth_connection(opaque_token)
    WHERE expires_at > NOW();
