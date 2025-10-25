-- ======================================================
-- 002 - User Microservice Entities
-- ======================================================

CREATE TABLE IF NOT EXISTS public.users
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    username citext NOT NULL,
    email citext,
    phone varchar(20),
    user_type text NOT NULL,
    join_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    address text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT users_pkey PRIMARY KEY (id),
    CONSTRAINT users_email_key UNIQUE (email),
    CONSTRAINT users_username_key UNIQUE (username),
    CONSTRAINT users_created_by_fkey FOREIGN KEY (created_by)
    REFERENCES public.users (id) ON DELETE SET NULL,
    CONSTRAINT users_updated_by_fkey FOREIGN KEY (updated_by)
    REFERENCES public.users (id) ON DELETE SET NULL,
    CONSTRAINT users_user_type_check CHECK (
                                               user_type IN ('end_user', 'business_user', 'support_user')
    )
    );

COMMENT ON TABLE public.users IS 'Stores all system users (end_user, business_user, support_user).';
COMMENT ON COLUMN public.users.user_type IS 'Defines user category.';

CREATE INDEX IF NOT EXISTS idx_users_user_type ON public.users (user_type);

CREATE OR REPLACE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON public.users
                      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------
-- END USER
CREATE TABLE IF NOT EXISTS public.end_user
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    social_media text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT end_user_pkey PRIMARY KEY (id),
    CONSTRAINT fk_end_user_user FOREIGN KEY (user_id)
    REFERENCES public.users (id) ON DELETE CASCADE
    );

CREATE OR REPLACE TRIGGER trg_end_user_updated_at
    BEFORE UPDATE ON public.end_user
                      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------
-- SUPPORT USER
CREATE TABLE IF NOT EXISTS public.support_user
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT support_user_pkey PRIMARY KEY (id),
    CONSTRAINT fk_support_user_user FOREIGN KEY (user_id)
    REFERENCES public.users (id) ON DELETE CASCADE
    );

CREATE OR REPLACE TRIGGER trg_support_user_updated_at
    BEFORE UPDATE ON public.support_user
                      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ------------------------------------------------------
-- BUSINESS REPS
CREATE TABLE IF NOT EXISTS public.business_reps
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    business_id uuid NOT NULL,
    user_id uuid NOT NULL,
    branch_name text,
    branch_address text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT business_reps_pkey PRIMARY KEY (id),
    CONSTRAINT business_reps_user_id_fkey FOREIGN KEY (user_id)
    REFERENCES public.users (id) ON DELETE CASCADE
    );

CREATE OR REPLACE TRIGGER trg_business_reps_updated_at
    BEFORE UPDATE ON public.business_reps
                      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
