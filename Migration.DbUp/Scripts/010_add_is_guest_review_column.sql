-- Add is_guest_review column to track guest vs authenticated reviews
ALTER TABLE public.review
    ADD COLUMN IF NOT EXISTS is_guest_review BOOLEAN DEFAULT FALSE NOT NULL;

-- Update existing records: set is_guest_review = true where reviewer_id is null
UPDATE public.review
SET is_guest_review = TRUE
WHERE reviewer_id IS NULL;

-- Create index for filtering by guest/auth reviews
CREATE INDEX IF NOT EXISTS idx_review_is_guest ON public.review(is_guest_review);

COMMENT ON COLUMN public.review.is_guest_review IS 'Flag indicating if review was submitted by guest user (true) or authenticated user (false)';