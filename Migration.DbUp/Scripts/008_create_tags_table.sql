-- INSERT INTO category (id, name) VALUES
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Food and Resturants'),
--                                     ('0199d4ef-ca22-7970-a8d2-57995e57ebb3', 'Shopping'),
--                                     ('0199d4ef-ca22-7970-a8d2-57007439b317', 'Hotels,BnB and vacation'),
--                                     ('0199d4ef-ca22-7970-a8d2-570118a5030d', 'Fashion and Baauty'),
--                                     ('0199d4ef-ca22-7970-a8d2-57025e57ebb3', 'Health and Wellness'),
--                                     ('0199d4ef-ca22-7970-a8d2-57037439b317', 'Education and Training');

CREATE TABLE IF NOT EXISTS public.category_tags (
                                                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    category_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_category_id FOREIGN KEY (category_id)
    REFERENCES public.category (id) ON DELETE CASCADE
    );