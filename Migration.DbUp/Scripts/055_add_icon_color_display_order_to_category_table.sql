ALTER TABLE category
    ADD COLUMN IF NOT EXISTS icon          VARCHAR(100),
    ADD COLUMN IF NOT EXISTS color         VARCHAR(20),
    ADD COLUMN IF NOT EXISTS display_order INT NOT NULL DEFAULT 0;

-- Seed display_order for existing rows so they have a stable initial order
UPDATE category
SET display_order = sub.rn
    FROM (
  SELECT id, ROW_NUMBER() OVER (ORDER BY name) AS rn FROM category
) sub
WHERE category.id = sub.id;

CREATE INDEX IF NOT EXISTS idx_category_display_order ON category(display_order);