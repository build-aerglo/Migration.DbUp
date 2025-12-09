CREATE TABLE IF NOT EXISTS public.business_tags (
                                                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    tag_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_business_id FOREIGN KEY (business_id)
    REFERENCES public.business (id) ON DELETE CASCADE,
    CONSTRAINT fk_tag_id FOREIGN KEY (tag_id)
    REFERENCES public.category_tags (id) ON DELETE CASCADE
    );

-- CREATE TABLE IF NOT EXISTS public.business_socials (
--                                                        business_id UUID NOT NULL,
--                                                        whatsapp TEXT DEFAULT NULL,
--                                                        instagram TEXT DEFAULT NULL,
--                                                        twitter TEXT DEFAULT NULL,
--                                                        facebook TEXT DEFAULT NULL,
--                                                        created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
--     updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
--     CONSTRAINT fk_business_category_business FOREIGN KEY (business_id)
--     REFERENCES public.business (id) ON DELETE CASCADE
--     );