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