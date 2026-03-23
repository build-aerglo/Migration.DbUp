ALTER TABLE users
    ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS public.review_summary (
                                                     business_id  UUID PRIMARY KEY REFERENCES business(id) ON DELETE CASCADE,
    log          JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at   TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at   TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
    );

CREATE TABLE IF NOT EXISTS public.registration_verification
(
    id uuid PRIMARY KEY NOT NULL DEFAULT gen_random_uuid(),
    username citext,
    email citext NOT NULL,
    token text,
    user_type VARCHAR(20),
    expiry timestamp without time zone NOT NULL,
    CONSTRAINT fk_registeration_verification_email FOREIGN KEY (email)
    REFERENCES public.users (email) ON DELETE CASCADE
    );

ALTER TABLE registration_verification
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();
    

CREATE INDEX IF NOT EXISTS idx_registeration_verification_email ON public.registration_verification (email);
CREATE INDEX IF NOT EXISTS idx_registeration_verification_token ON public.registration_verification (token);