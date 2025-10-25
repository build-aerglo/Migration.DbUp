-- ======================================================
-- 003 - Business Service Entities
-- ======================================================

CREATE TABLE IF NOT EXISTS public.category (
                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_parent_category FOREIGN KEY (parent_category_id)
    REFERENCES public.category (id) ON DELETE SET NULL
    );

CREATE TABLE IF NOT EXISTS public.business (
                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    parent_business_id UUID,
    is_branch BOOLEAN NOT NULL DEFAULT FALSE,
    website VARCHAR(255),
    avg_rating NUMERIC(3, 2) NOT NULL DEFAULT 0.00,
    review_count BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_parent_business FOREIGN KEY (parent_business_id)
    REFERENCES public.business (id) ON DELETE SET NULL
    );

CREATE TABLE IF NOT EXISTS public.business_category (
                                                        business_id UUID NOT NULL,
                                                        category_id UUID NOT NULL,
                                                        created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_business_category_business FOREIGN KEY (business_id)
    REFERENCES public.business (id) ON DELETE CASCADE,
    CONSTRAINT fk_business_category_category FOREIGN KEY (category_id)
    REFERENCES public.category (id) ON DELETE CASCADE,
    CONSTRAINT uk_business_category UNIQUE (business_id, category_id)
    );
