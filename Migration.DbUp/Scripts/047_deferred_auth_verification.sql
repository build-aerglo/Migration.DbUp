-- Migration 047: Deferred Authentication Verification
-- Adds is_verification_pending (bool gate) and verified_at (audit timestamp)
-- to the review table. These are orthogonal to the Status column.
-- Status = content quality (moderation verdict)
-- is_verification_pending = user account gate

ALTER TABLE review
    ADD COLUMN IF NOT EXISTS is_verification_pending BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS verified_at             TIMESTAMPTZ         NULL;

-- Partial index for the activation query.
-- UserService calls ReviewService on verify; this index makes that query O(pending) not O(all reviews).
CREATE INDEX IF NOT EXISTS ix_review_verification_pending
    ON review (reviewer_id, is_verification_pending)
    WHERE is_verification_pending = TRUE;

-- Comment for future maintainers
COMMENT ON COLUMN review.is_verification_pending IS
    'True while the reviewer has not yet verified their email account.
    Reviews with this flag are excluded from all public queries,
    Bayesian ratings, and SignalR feeds regardless of their Status.';

COMMENT ON COLUMN review.verified_at IS
    'Timestamp when the user verified their account and this review was activated.
    NULL while is_verification_pending = TRUE.';
