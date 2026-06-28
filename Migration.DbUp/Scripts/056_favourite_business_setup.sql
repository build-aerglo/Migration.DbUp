CREATE TABLE IF NOT EXISTS public.favourite_business (
                                    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
                                    user_id     UUID        NOT NULL,
                                    business_id UUID        NOT NULL,
                                    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                                    CONSTRAINT uq_favourite_business UNIQUE (user_id, business_id)
);

CREATE INDEX IF NOT EXISTS idx_fav_biz_user_id ON public.favourite_business(user_id);
CREATE INDEX IF NOT EXISTS idx_fav_biz_business_id ON public.favourite_business(business_id);