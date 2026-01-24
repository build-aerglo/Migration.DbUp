-- ======================================================
-- 005 - Seed Initial Data
-- ======================================================

INSERT INTO public.category (id, name) VALUES
                                           ('0199d4ef-ca22-7970-a8d2-579518a5030d', 'Finance'),
                                           ('0199d4ef-ca22-7970-a8d2-57965e57ebb3', 'Retail'),
                                           ('0199d4ef-ca22-7970-a8d2-57977439b317', 'Tourism')
    ON CONFLICT DO NOTHING;

INSERT INTO public.category (id, name, parent_category_id) VALUES
                                                               ('0199d4ef-ca22-7970-a8d2-5798afd24081', 'Bank', '0199d4ef-ca22-7970-a8d2-579518a5030d'),
                                                               ('0199d4ef-ca22-7970-a8d2-57992bb164a8', 'E-commerce', '0199d4ef-ca22-7970-a8d2-57965e57ebb3')
    ON CONFLICT DO NOTHING;

INSERT INTO public.business (id, name, website) VALUES
                                                    ('0199d4ef-ca22-7970-a8d2-57945c1f4673', 'Shoprite', 'https://shoprite.com'),
                                                    ('0199d4ef-ca22-7970-a8d2-579a4e225266', 'Paga', 'https://paga.com'),
                                                    ('0199d4ef-ca22-7970-a8d2-579b94abdc68', 'KFC', 'https://kfc.com')
    ON CONFLICT DO NOTHING;

INSERT INTO public.business_category (business_id, category_id) VALUES
                                                                    ('0199d4ef-ca22-7970-a8d2-57945c1f4673', '0199d4ef-ca22-7970-a8d2-57992bb164a8'),
                                                                    ('0199d4ef-ca22-7970-a8d2-57945c1f4673', '0199d4ef-ca22-7970-a8d2-57977439b317'),
                                                                    ('0199d4ef-ca22-7970-a8d2-579a4e225266', '0199d4ef-ca22-7970-a8d2-579518a5030d'),
                                                                    ('0199d4ef-ca22-7970-a8d2-579b94abdc68', '0199d4ef-ca22-7970-a8d2-57977439b317')
    ON CONFLICT DO NOTHING;
