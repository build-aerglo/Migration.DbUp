-- ============================================================================
-- Migration 023: Helpful Vote System
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.helpful_vote (
                                                   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.review(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_helpful_vote_user_review UNIQUE (review_id, user_id)
    );

CREATE INDEX IF NOT EXISTS idx_helpful_vote_review_id ON public.helpful_vote(review_id);
CREATE INDEX IF NOT EXISTS idx_helpful_vote_user_id ON public.helpful_vote(user_id);
CREATE INDEX IF NOT EXISTS idx_helpful_vote_created_at ON public.helpful_vote(created_at);

-- Function to prevent self-voting
CREATE OR REPLACE FUNCTION public.prevent_self_vote()
RETURNS TRIGGER AS $$
DECLARE
v_reviewer_id UUID;
BEGIN
SELECT reviewer_id INTO v_reviewer_id FROM public.review WHERE id = NEW.review_id;
IF v_reviewer_id IS NOT NULL AND v_reviewer_id = NEW.user_id THEN
        RAISE EXCEPTION 'Users cannot vote on their own reviews';
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
DROP TRIGGER IF EXISTS trigger_prevent_self_vote ON public.helpful_vote;
CREATE TRIGGER trigger_prevent_self_vote
    BEFORE INSERT ON public.helpful_vote
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_self_vote();
END $$;

-- Function to update helpful count in review table
CREATE OR REPLACE FUNCTION public.update_review_helpful_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
UPDATE public.review
SET helpful_count = helpful_count + 1
WHERE id = NEW.review_id;
RETURN NEW;
ELSIF TG_OP = 'DELETE' THEN
UPDATE public.review
SET helpful_count = GREATEST(helpful_count - 1, 0)
WHERE id = OLD.review_id;
RETURN OLD;
END IF;
RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
DROP TRIGGER IF EXISTS trigger_update_review_helpful_count ON public.helpful_vote;
CREATE TRIGGER trigger_update_review_helpful_count
    AFTER INSERT OR DELETE ON public.helpful_vote
        FOR EACH ROW
        EXECUTE FUNCTION public.update_review_helpful_count();
END $$;

COMMENT ON TABLE public.helpful_vote IS 'Tracks helpful votes on reviews with fraud prevention';