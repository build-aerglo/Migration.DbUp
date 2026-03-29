-- exists but not in migration
CREATE TABLE IF NOT EXISTS public.business_auto_response (
                                                             id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    positive_response TEXT DEFAULT NULL,
    neutral_response TEXT DEFAULT NULL,
    negative_response TEXT DEFAULT NULL,
    allow_auto_response BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_business_id FOREIGN KEY (business_id)
    REFERENCES public.business (id) ON DELETE CASCADE
    );

ALTER TABLE public.business_claim_request
    ADD COLUMN IF NOT EXISTS id_number VARCHAR(100),
    ADD COLUMN IF NOT EXISTS id_type VARCHAR(50),
    ADD COLUMN IF NOT EXISTS requires_reverification BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS reverification_reason TEXT;

ALTER TABLE public.business_claim_request
    ADD COLUMN IF NOT EXISTS personal_id_document_url TEXT;

ALTER TABLE public.business_claim_request
    ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

ALTER TABLE public.business_claim_request
    ADD COLUMN IF NOT EXISTS appeal_count INTEGER DEFAULT 0;

ALTER TABLE public.category
    ADD COLUMN IF NOT EXISTS icon VARCHAR(20);

ALTER TABLE public.review
    ADD COLUMN IF NOT EXISTS flagged_by VARCHAR(20);
