-- ============================================================================
-- Migration 024: Review Edit History
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.review_edit_history (
                                                          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.review(id) ON DELETE CASCADE,
    edit_number INTEGER NOT NULL,
    previous_star_rating DECIMAL(2,1),
    previous_review_body TEXT,
    previous_photo_urls TEXT[],
    new_star_rating DECIMAL(2,1),
    new_review_body TEXT,
    new_photo_urls TEXT[],
    edited_by_user_id UUID,
    edited_by_email VARCHAR(255),
    edit_reason VARCHAR(255),
    ip_address VARCHAR(45),
    user_agent TEXT,
    validation_status VARCHAR(20),
    validation_result JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_review_edit_validation_status CHECK (
                                                           validation_status IN ('PENDING', 'APPROVED', 'REJECTED', 'FLAGGED')
    )
    );

CREATE INDEX IF NOT EXISTS idx_review_edit_history_review_id ON public.review_edit_history(review_id);
CREATE INDEX IF NOT EXISTS idx_review_edit_history_created_at ON public.review_edit_history(created_at DESC);

-- Function to enforce 3-day edit window
CREATE OR REPLACE FUNCTION public.check_edit_window()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT created_at FROM public.review WHERE id = NEW.review_id) < NOW() - INTERVAL '3 days' THEN
        RAISE EXCEPTION 'Reviews can only be edited within 3 days of creation';
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
DROP TRIGGER IF EXISTS trigger_check_edit_window ON public.review_edit_history;
CREATE TRIGGER trigger_check_edit_window
    BEFORE INSERT ON public.review_edit_history
    FOR EACH ROW
    EXECUTE FUNCTION public.check_edit_window();
END $$;

-- Function to track review edits
CREATE OR REPLACE FUNCTION public.track_review_edit()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.review_body != NEW.review_body OR OLD.star_rating != NEW.star_rating OR 
       OLD.photo_urls IS DISTINCT FROM NEW.photo_urls THEN
        IF NOT OLD.is_edited THEN
            NEW.original_review_body := OLD.review_body;
END IF;
        NEW.is_edited := TRUE;
        NEW.edit_count := OLD.edit_count + 1;
        NEW.last_edited_at := NOW();
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
DROP TRIGGER IF EXISTS trigger_track_review_edit ON public.review;
CREATE TRIGGER trigger_track_review_edit
    BEFORE UPDATE ON public.review
    FOR EACH ROW
    EXECUTE FUNCTION public.track_review_edit();
END $$;

COMMENT ON TABLE public.review_edit_history IS 'Complete audit trail of review edits';
