CREATE TABLE IF NOT EXISTS public.business_branches (
                                                      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    branch_name TEXT,
    branch_street TEXT,
    branch_citytown TEXT,
    branch_state TEXT,
    branch_status VARCHAR(100) NOT NULL DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_business_id FOREIGN KEY (business_id)
    REFERENCES public.business (id) ON DELETE CASCADE
    );

ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS business_street TEXT;

ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS business_citytown TEXT;

ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS business_state TEXT;

ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS review_summary TEXT;