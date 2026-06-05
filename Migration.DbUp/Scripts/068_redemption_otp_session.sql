-- ============================================================
-- 068 — Redemption OTP Session Guard
-- Short-lived, server-side proof-of-presence sessions for the airtime
-- points redemption flow (Architecture Decision 10). A valid JWT alone is
-- not sufficient: POST /api/Points/redeem returns 403 unless an active
-- verified row exists here. Code is delivered to the user's verified email
-- (default) or phone (Redemption:OtpChannel=sms).
-- ============================================================

CREATE TABLE IF NOT EXISTS redemption_otp_session (
    id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID        NOT NULL,
    verified        BOOLEAN     NOT NULL DEFAULT FALSE,
    verified_at     TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ NOT NULL,
    used            BOOLEAN     NOT NULL DEFAULT FALSE,
    used_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_redemption_otp_session PRIMARY KEY (id)
);

COMMENT ON TABLE  redemption_otp_session                IS 'Short-lived server-side sessions proving the user passed an SMS OTP challenge before redeeming points.';
COMMENT ON COLUMN redemption_otp_session.verified       IS 'TRUE once the user enters the correct OTP. Only verified=TRUE sessions unblock /api/Points/redeem.';
COMMENT ON COLUMN redemption_otp_session.expires_at     IS 'Session expires 10 minutes after creation.';
COMMENT ON COLUMN redemption_otp_session.used           IS 'Set TRUE after a successful redemption. One OTP challenge = one redemption.';

-- One verified, unused session per user. NOTE: expires_at > NOW() is intentionally
-- NOT in the index predicate — Postgres requires partial-index predicates to be
-- IMMUTABLE and NOW() is STABLE (error 42P17). Expiry is enforced at query time in
-- GetActiveVerifiedAsync; InitiateChallengeAsync clears stale rows via DeleteByUserIdAsync
-- before each new challenge, so the verified+unused uniqueness guarantee is preserved.
CREATE UNIQUE INDEX IF NOT EXISTS uidx_redemption_otp_session_active_user
    ON redemption_otp_session (user_id)
    WHERE verified = TRUE AND used = FALSE;

CREATE INDEX IF NOT EXISTS idx_redemption_otp_session_user_expires
    ON redemption_otp_session (user_id, expires_at DESC);
