CREATE TABLE IF NOT EXISTS public.ad_spaces (
                                                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    amount DECIMAL(18,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

-- One row per slot per week. max_count slots are created per week so that
-- multiple concurrent bookings are supported.
CREATE TABLE IF NOT EXISTS public.ad_booking_dates (
                                                       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ad_space_id UUID NOT NULL REFERENCES ad_spaces(id) ON DELETE CASCADE,
    week_start TIMESTAMPTZ NOT NULL,
    week_end TIMESTAMPTZ NOT NULL,
    slot_number INT NOT NULL DEFAULT 1,
    status VARCHAR(50) NOT NULL DEFAULT 'unbooked',
    reserved_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

-- One row per slot booked.
CREATE TABLE IF NOT EXISTS public.ad_bookings (
                                                  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_group_id UUID NOT NULL,
    date_slot_id UUID NOT NULL REFERENCES ad_booking_dates(id),
    ad_space_id UUID NOT NULL REFERENCES ad_spaces(id),
    booking_type VARCHAR(100) NOT NULL,
    book_status VARCHAR(50) NOT NULL DEFAULT 'reserved',
    manager_email VARCHAR(255) NOT NULL,
    manager_id UUID,
    booking_metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

CREATE TABLE IF NOT EXISTS public.ad_payments (
                                                  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL,
    reference VARCHAR(255),
    platform VARCHAR(100) NOT NULL DEFAULT 'paystack',
    payment_status VARCHAR(50) NOT NULL DEFAULT 'pending',
    payment_url TEXT,
    ad_space_id UUID NOT NULL REFERENCES ad_spaces(id),
    booking_group_id UUID NOT NULL,
    payload JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

CREATE INDEX IF NOT EXISTS idx_ad_booking_dates_ad_space_id
    ON ad_booking_dates(ad_space_id);

CREATE INDEX IF NOT EXISTS idx_ad_booking_dates_status
    ON ad_booking_dates(status);

CREATE INDEX IF NOT EXISTS idx_ad_booking_dates_week_start
    ON ad_booking_dates(week_start);

CREATE INDEX IF NOT EXISTS idx_ad_booking_dates_reserved_until
    ON ad_booking_dates(reserved_until)
    WHERE reserved_until IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ad_bookings_booking_group_id
    ON ad_bookings(booking_group_id);

CREATE INDEX IF NOT EXISTS idx_ad_bookings_date_slot_id
    ON ad_bookings(date_slot_id);

CREATE INDEX IF NOT EXISTS idx_ad_bookings_ad_space_id
    ON ad_bookings(ad_space_id);

CREATE INDEX IF NOT EXISTS idx_ad_payments_reference
    ON ad_payments(reference);

CREATE INDEX IF NOT EXISTS idx_ad_payments_booking_group_id
    ON ad_payments(booking_group_id);

CREATE TABLE IF NOT EXISTS public.ad_requirements (
                                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    type VARCHAR(100) NOT NULL,
    height INT,
    length INT,
    validation JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

CREATE INDEX IF NOT EXISTS idx_ad_requirements_requirement_id
    ON ad_requirements(id);

CREATE TABLE IF NOT EXISTS public.ad_space_requirements (
                                                            ad_space_id UUID NOT NULL REFERENCES ad_spaces(id) ON DELETE CASCADE,
    requirement_id UUID NOT NULL REFERENCES ad_requirements(id) ON DELETE CASCADE,
    PRIMARY KEY (ad_space_id, requirement_id)
    );

CREATE INDEX IF NOT EXISTS idx_ad_space_requirements_requirement_id
    ON ad_space_requirements(requirement_id);

CREATE TABLE IF NOT EXISTS public.ad_types (
                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_id VARCHAR(100) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    max_count INT NOT NULL DEFAULT 1,
    pages_displayed_on TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

CREATE INDEX IF NOT EXISTS idx_ad_types_type_id
    ON public.ad_types(type_id);

ALTER TABLE public.ad_spaces
    ADD COLUMN IF NOT EXISTS ad_type_id UUID
    REFERENCES ad_types(id) ON DELETE RESTRICT;