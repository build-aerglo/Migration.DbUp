CREATE TABLE IF NOT EXISTS public.favourite_business (
                                    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
                                    user_id     UUID        NOT NULL,
                                    business_id UUID        NOT NULL,
                                    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                    CONSTRAINT uq_favourite_business UNIQUE (user_id, business_id)
);

CREATE INDEX IF NOT EXISTS idx_fav_biz_user_id ON public.favourite_business(user_id);
CREATE INDEX IF NOT EXISTS idx_fav_biz_business_id ON public.favourite_business(business_id);

CREATE TABLE IF NOT EXISTS public.business_broadcast (
                                                         id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id       UUID        NOT NULL,
    title             TEXT        NOT NULL,
    message           TEXT        NOT NULL,
    status            TEXT        NOT NULL DEFAULT 'Pending',
    total_recipients  INT         NOT NULL DEFAULT 0,
    sent_count        INT         NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at      TIMESTAMPTZ
    );

CREATE INDEX IF NOT EXISTS idx_business_broadcast_status ON public.business_broadcast (status);
CREATE INDEX IF NOT EXISTS idx_business_broadcast_business_id ON public.business_broadcast (business_id);