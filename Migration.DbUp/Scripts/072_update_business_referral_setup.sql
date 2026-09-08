CREATE TABLE IF NOT EXISTS public.business_referral_users (
                                                              id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name                  VARCHAR(255) NOT NULL,
    email                 VARCHAR(255) NOT NULL,
    phone                 VARCHAR(50)  NOT NULL,
    id_verification_url   TEXT         NOT NULL,
    referral_code         VARCHAR(50)  NOT NULL,
    status                VARCHAR(20)  NOT NULL DEFAULT 'active',
    blocked_reason        TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_business_referral_users_email UNIQUE (email),
    CONSTRAINT uq_business_referral_users_referral_code UNIQUE (referral_code)
    );

CREATE TABLE IF NOT EXISTS public.business_referrals (
                                                         id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    referral_id  UUID        NOT NULL REFERENCES public.business_referral_users(id),
    business_id  UUID        NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_business_referrals_business UNIQUE (business_id)
    );

CREATE INDEX IF NOT EXISTS idx_business_referrals_referral_id ON public.business_referrals(referral_id);
CREATE INDEX IF NOT EXISTS idx_business_referrals_status ON public.business_referrals(status);

COMMENT ON TABLE public.business_referral_users IS 'People/agents who can refer businesses and hold a CLEREVIEW-REF referral code';
COMMENT ON TABLE public.business_referrals IS 'Businesses registered against a business referral code, pending review by support';
        
ALTER TABLE public.business_referral_users
    ADD COLUMN IF NOT EXISTS decline_reason TEXT;

ALTER TABLE public.business_referral_users
    ALTER COLUMN status SET DEFAULT 'pending';

COMMENT ON COLUMN public.business_referral_users.decline_reason IS 'Optional reason support gave when declining an affiliate application';