-- Ensure payment_status column exists (idempotent)
ALTER TABLE subscription_invoice
    ADD COLUMN IF NOT EXISTS payment_status TEXT;

-- Ensure error column exists (used by SubscriptionInvoiceWithError)
ALTER TABLE subscription_invoice
    ADD COLUMN IF NOT EXISTS error TEXT;

-- Index for billing table query (business_id + newest-first)
CREATE INDEX IF NOT EXISTS idx_sub_invoice_business_created
    ON subscription_invoice(business_id, created_at DESC);