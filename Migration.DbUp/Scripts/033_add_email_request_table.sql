-- Email update requests table
CREATE TABLE IF NOT EXISTS public.email_update_requests (
                                       id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                       business_id UUID NOT NULL,
                                       email VARCHAR(255) NOT NULL,
                                       reason TEXT,
                                       created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_business_id FOREIGN KEY (business_id)
    REFERENCES public.business (id) ON DELETE CASCADE
);

ALTER TABLE public.business_claim_request ADD COLUMN IF NOT EXISTS business_category UUID NOT NULL;

CREATE INDEX idx_email_update_requests_business_id ON email_update_requests(business_id);
CREATE INDEX idx_email_update_requests_email ON email_update_requests(email);

CREATE TABLE IF NOT EXISTS public.subscription_invoice (
                                                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL,
    subscription_id UUID NOT NULL,
    email VARCHAR(255) NOT NULL,
    platform VARCHAR(100) NOT NULL DEFAULT 'paystack',
    reference TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'pending',
    payment_status VARCHAR(50) DEFAULT 'pending',
    payment_url VARCHAR(1000),
    is_annual BOOLEAN DEFAULT FALSE
    );

CREATE INDEX idx_subscription_invoice_business_id ON subscription_invoice(business_id);
CREATE INDEX idx_subscription_invoice_subscription_id ON subscription_invoice(subscription_id);
CREATE INDEX idx_subscription_invoice_status ON subscription_invoice(status);
CREATE INDEX idx_subscription_invoice_reference ON subscription_invoice(reference);
CREATE INDEX idx_subscription_invoice_platform ON subscription_invoice(platform);