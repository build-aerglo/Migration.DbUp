ALTER TABLE public.ad_spaces DROP COLUMN IF EXISTS type;
ALTER TABLE public.ad_spaces DROP COLUMN IF EXISTS max_count;
ALTER TABLE public.ad_spaces DROP COLUMN IF EXISTS pages_displayed_on;

-- Master catalogue of validation types
CREATE TABLE IF NOT EXISTS public.ad_requirement_validations (
                                                                 id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

-- Links each ad_requirement to zero or more validation rules
CREATE TABLE IF NOT EXISTS public.ad_requirement_validation_rules (
                                                                      requirement_id UUID NOT NULL REFERENCES public.ad_requirements(id) ON DELETE CASCADE,
    validation_id  UUID NOT NULL REFERENCES public.ad_requirement_validations(id) ON DELETE CASCADE,
    PRIMARY KEY (requirement_id, validation_id)
    );

CREATE INDEX IF NOT EXISTS idx_ad_req_validation_rules_validation_id
    ON public.ad_requirement_validation_rules(validation_id);

-- The old inline JSONB column is superseded by the pivot table above
ALTER TABLE public.ad_requirements DROP COLUMN IF EXISTS validation;

ALTER TABLE public.business_branches
    ADD COLUMN IF NOT EXISTS branch_manager VARCHAR(255),
    ADD COLUMN IF NOT EXISTS contact_email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(100);

-- Add stable frontend identifier to ad_spaces.
-- Existing rows get their UUID as the initial space_id so the migration is non-destructive.
ALTER TABLE public.ad_spaces
    ADD COLUMN IF NOT EXISTS space_id VARCHAR(100);

ALTER TABLE public.ad_spaces
    ALTER COLUMN space_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_ad_spaces_space_id
    ON public.ad_spaces(space_id);

-- Admin review log: one row per booking group, created after payment is confirmed.
-- Status flow: pending-verification → approved | rejected
CREATE TABLE IF NOT EXISTS public.ad_booking_records (
                                                         id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_group_id UUID NOT NULL,
    ad_space_id      UUID NOT NULL REFERENCES public.ad_spaces(id),
    email            VARCHAR(255) NOT NULL,
    manager_id       UUID,
    status           VARCHAR(50) NOT NULL DEFAULT 'pending-verification',
    reject_reason    TEXT,
    reviewed_at      TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

CREATE INDEX IF NOT EXISTS idx_ad_booking_records_booking_group_id
    ON public.ad_booking_records(booking_group_id);

CREATE INDEX IF NOT EXISTS idx_ad_booking_records_status
    ON public.ad_booking_records(status);

ALTER TABLE public.ad_payments ADD COLUMN IF NOT EXISTS manager_id UUID;

CREATE INDEX IF NOT EXISTS idx_ad_payments_manager_id ON public.ad_payments(manager_id);
