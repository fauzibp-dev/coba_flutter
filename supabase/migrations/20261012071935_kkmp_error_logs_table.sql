CREATE TABLE IF NOT EXISTS public.client_error_logs (
id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
created_at timestamptz NOT NULL DEFAULT now(),
user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
severity text NOT NULL DEFAULT 'error',
source text NOT NULL,
screen text,
message text NOT NULL,
stack_trace text,
app_version text,
platform text,
fingerprint text
);
ALTER TABLE public.client_error_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.client_error_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.client_error_logs TO authenticated;
CREATE POLICY client_error_logs_superadmin_read ON public.client_error_logs FOR SELECT TO authenticated USING (public.is_platform_super_admin());
CREATE INDEX client_error_logs_time_idx ON public.client_error_logs(created_at DESC);
CREATE INDEX client_error_logs_actor_idx ON public.client_error_logs(user_id, created_at DESC);
