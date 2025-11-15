-- ======================================================
-- 006 - Business Settings Tables
-- ======================================================

-- Business Settings (Parent Rep Control)
CREATE TABLE IF NOT EXISTS public.business_settings (
                                                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                        business_id UUID NOT NULL UNIQUE,
                                                        reviews_private BOOLEAN NOT NULL DEFAULT FALSE,
                                                        dnd_mode_enabled BOOLEAN NOT NULL DEFAULT FALSE,
                                                        dnd_mode_enabled_at TIMESTAMP WITH TIME ZONE,
                                                        dnd_mode_expires_at TIMESTAMP WITH TIME ZONE,
                                                        created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
                                                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
                                                        modified_by_user_id UUID,
                                                        FOREIGN KEY (business_id) REFERENCES public.business (id) ON DELETE CASCADE
);

-- Business Rep Settings (Each Rep Controls Own)
CREATE TABLE IF NOT EXISTS public.business_rep_settings (
                                                            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                                                            business_rep_id UUID NOT NULL UNIQUE,
                                                            notification_preferences JSONB,
                                                            dark_mode BOOLEAN NOT NULL DEFAULT FALSE,
                                                            auto_response_templates JSONB,
                                                            disabled_access_usernames JSONB,
                                                            created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
                                                            updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
                                                            modified_by_user_id UUID,
                                                            FOREIGN KEY (business_rep_id) REFERENCES public.business_reps (id) ON DELETE CASCADE
);