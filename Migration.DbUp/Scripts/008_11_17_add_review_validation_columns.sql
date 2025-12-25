ALTER TABLE public.review
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'PENDING',
    ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45),
    ADD COLUMN IF NOT EXISTS device_id VARCHAR(100),
    ADD COLUMN IF NOT EXISTS geolocation VARCHAR(255),
    ADD COLUMN IF NOT EXISTS user_agent TEXT,
    ADD COLUMN IF NOT EXISTS validation_result JSONB,
    ADD COLUMN IF NOT EXISTS validated_at TIMESTAMP WITHOUT TIME ZONE;

-- Add constraint to ensure valid status values
ALTER TABLE public.review
    ADD CONSTRAINT chk_review_status
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'FLAGGED'));

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_review_status ON public.review(status);
CREATE INDEX IF NOT EXISTS idx_review_ip_device ON public.review(ip_address, device_id);
CREATE INDEX IF NOT EXISTS idx_review_created_at ON public.review(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_review_business_status ON public.review(business_id, status);

-- Composite index for frequency checks
CREATE INDEX IF NOT EXISTS idx_review_frequency
    ON public.review(reviewer_id, email, ip_address, device_id, created_at DESC);

-- Partial index for approved reviews only (most common query)
CREATE INDEX IF NOT EXISTS idx_review_approved
    ON public.review(business_id, created_at DESC)
    WHERE status = 'APPROVED';

-- Index for spike detection
CREATE INDEX IF NOT EXISTS idx_review_business_rating
    ON public.review(business_id, star_rating, created_at DESC);

COMMENT ON COLUMN public.review.status IS 'Validation status: PENDING, APPROVED, REJECTED, FLAGGED';
COMMENT ON COLUMN public.review.ip_address IS 'User IP address for Vpn detection';
COMMENT ON COLUMN public.review.device_id IS 'User device ID';
COMMENT ON COLUMN public.review.geolocation IS 'User location';
COMMENT ON COLUMN public.review.user_agent IS 'Browser user agent string';
COMMENT ON COLUMN public.review.validation_result IS 'JSON containing validation details (errors, warnings, level)';
COMMENT ON COLUMN public.review.validated_at IS 'Timestamp when validation completed';

CREATE TABLE IF NOT EXISTS public.category_tags (
                                                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    category_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_category_id FOREIGN KEY (category_id)
    REFERENCES public.category (id) ON DELETE CASCADE
    );

CREATE TABLE IF NOT EXISTS public.business_claims (
                                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    role VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(100) NOT NULL,
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_business_id FOREIGN KEY (business_id)
    REFERENCES public.business (id) ON DELETE CASCADE
    );

ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS business_status VARCHAR(100) NOT NULL DEFAULT 'approved';