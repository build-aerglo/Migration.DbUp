-- ======================================================
-- 004 - Reviews and Ratings
-- ======================================================

-- BUSINESS LOCATION
CREATE TABLE IF NOT EXISTS public.location (
                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );

CREATE OR REPLACE TRIGGER trg_location_updated_at
    BEFORE UPDATE ON public.location
                      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- REVIEW
CREATE TABLE IF NOT EXISTS public.review (
                                             id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    location_id UUID,
    reviewer_id UUID, -- null if guest
    email CITEXT, -- required if guest
    star_rating INT CHECK (star_rating BETWEEN 1 AND 5),
    review_body TEXT CHECK (char_length(review_body) BETWEEN 20 AND 500),
    photo_urls TEXT[], -- up to 3
    review_as_anon BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_review_business FOREIGN KEY (business_id)
    REFERENCES public.business (id) ON DELETE CASCADE,
    CONSTRAINT fk_review_location FOREIGN KEY (location_id)
    REFERENCES public.location (id) ON DELETE SET NULL,
    CONSTRAINT fk_review_user FOREIGN KEY (reviewer_id)
    REFERENCES public.users (id) ON DELETE SET NULL,
    CONSTRAINT chk_photo_limit CHECK (array_length(photo_urls, 1) <= 3)
    );

COMMENT ON TABLE public.review IS 'Stores user reviews of businesses, supports guest & registered reviewers.';

CREATE OR REPLACE TRIGGER trg_review_updated_at
    BEFORE UPDATE ON public.review
                              FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
