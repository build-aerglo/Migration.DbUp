CREATE TABLE IF NOT EXISTS business_mass_mail (
                                                  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    template          TEXT        NOT NULL,
    payload           TEXT        NOT NULL,
    status            TEXT        NOT NULL DEFAULT 'Pending',
    total_recipients  INT         NOT NULL DEFAULT 0,
    sent_count        INT         NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at      TIMESTAMPTZ
    );

CREATE INDEX IF NOT EXISTS idx_business_mass_mail_status ON business_mass_mail (status);