ALTER TABLE public.business
    ADD COLUMN IF NOT EXISTS id_verified BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS id_verification_url TEXT,
    ADD COLUMN IF NOT EXISTS id_verification_type VARCHAR(100),
    ADD COLUMN IF NOT EXISTS id_verification_number VARCHAR(100),
    ADD COLUMN IF NOT EXISTS id_verification_on TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.business_verification
    ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS id_verified BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS id_verification_url TEXT DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS id_verification_status VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_business_verification_status ON public.business(id_verification_type);
CREATE INDEX IF NOT EXISTS idx_business_verified_status ON public.business_verification(id_verified);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_channel ON public.notifications(channel);
CREATE INDEX IF NOT EXISTS idx_notifications_requested_at ON public.notifications(requested_at);

-- Create the otp table for one-time passwords
CREATE TABLE IF NOT EXISTS public.otp (
    otp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                          id TEXT NOT NULL,
                                          code VARCHAR(6) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
    );

-- Create index for faster OTP lookups
CREATE INDEX IF NOT EXISTS idx_otp_id ON public.otp(id);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON public.otp(expires_at);

-- Create the password_reset_requests table
CREATE TABLE IF NOT EXISTS public.password_reset_requests (
    reset_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                              id TEXT NOT NULL,
                                                              created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
                             );

-- Create index for password reset requests
CREATE INDEX IF NOT EXISTS idx_password_reset_requests_expires_at ON public.password_reset_requests(expires_at);
CREATE INDEX IF NOT EXISTS idx_password_reset_requests_id ON public.password_reset_requests(id);

CREATE TABLE IF NOT EXISTS public.id_verification_request (
                                                               id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                            business_id UUID REFERENCES business(id) ON DELETE CASCADE,
    id_verification_number VARCHAR(100) DEFAULT NULL,
    id_verification_type VARCHAR(100) NOT NULL,
    id_verification_url TEXT DEFAULT NULL,
    id_verification_name TEXT DEFAULT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
    );

CREATE INDEX IF NOT EXISTS idx_verification_requests_id ON public.id_verification_request(business_id);
CREATE INDEX IF NOT EXISTS idx_verification_requests_created_at ON public.id_verification_request(created_at);
CREATE INDEX IF NOT EXISTS idx_verification_requests_verification_type ON public.id_verification_request(id_verification_type);

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS login_type VARCHAR(50);
ALTER TABLE public.business_verification ADD COLUMN IF NOT EXISTS verification_progress DECIMAL(10, 1) DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_users_login_type ON public.users(login_type);