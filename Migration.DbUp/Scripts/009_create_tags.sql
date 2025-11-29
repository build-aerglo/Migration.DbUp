CREATE TABLE IF NOT EXISTS public.category_tags (
                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    category_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    CONSTRAINT fk_category_id FOREIGN KEY (category_id)
    REFERENCES public.category (id) ON DELETE CASCADE
    );

-- INSERT INTO category_tags (category_id, name) VALUES
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Fine-Dining'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Bukka'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Bakery'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Pastries'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Bar'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Night-life'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Local-Flavour'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Intercontinental'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Buffet'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Affordable'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Vegetarian'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Italian'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Deserts'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Premium'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Kids-Friendly'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Romantic'),
--                                     ('0199d4ef-ca22-7970-a8d2-579818a5030d', 'Business');
-- 
-- INSERT INTO category_tags (category_id, name) VALUES
--                                                   ('0199d4ef-ca22-7970-a8d2-57995e57ebb3', 'Malls'),
--                                                   ('0199d4ef-ca22-7970-a8d2-57995e57ebb3', 'Online-store'),
--                                                   ('0199d4ef-ca22-7970-a8d2-57995e57ebb3', 'Physical-Store'),
--                                                   ('0199d4ef-ca22-7970-a8d2-57995e57ebb3', 'Personal-Shopper');
-- 
-- INSERT INTO category_tags (category_id, name) VALUES
--                                                   ('0199d4ef-ca22-7970-a8d2-57007439b317', 'Travel agencies'),
--                                                   ('0199d4ef-ca22-7970-a8d2-57007439b317', 'Bnb'),
--                                                   ('0199d4ef-ca22-7970-a8d2-57007439b317', 'Hotels'),
--                                                   ('0199d4ef-ca22-7970-a8d2-57007439b317', 'Tour Guide');

-- INSERT INTO category_tags (category_id, name) VALUES
--                                                   ('0199d4ef-ca22-7970-a8d2-570118a5030d', 'Travel agencies'),
--                                                   ('0199d4ef-ca22-7970-a8d2-570118a5030d', 'Bnb'),
--                                                   ('0199d4ef-ca22-7970-a8d2-570118a5030d', 'Hotels'),
--                                                   ('0199d4ef-ca22-7970-a8d2-570118a5030d', 'Tour Guide');