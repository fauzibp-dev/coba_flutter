DROP FUNCTION IF EXISTS public.capture_client_error(text,text,text,text);
CREATE FUNCTION public.capture_client_error(
  p_source text, p_message text, p_stack text DEFAULT NULL,
  p_screen text DEFAULT NULL, p_severity text DEFAULT 'error',
  p_app_version text DEFAULT '1.5.4', p_platform text DEFAULT 'flutter'
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $$
DECLARE v_id bigint;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required' USING ERRCODE='42501'; END IF;
 IF (SELECT count(*) FROM public.client_error_logs WHERE user_id=auth.uid() AND created_at>now()-interval '1 hour') >= 100 THEN RETURN NULL; END IF;
 INSERT INTO public.client_error_logs
   (user_id,severity,source,message,stack_trace,screen,app_version,platform)
 VALUES (
   auth.uid(),
   CASE WHEN p_severity IN ('error','fatal','warning') THEN p_severity ELSE 'error' END,
   left(coalesce(p_source,'flutter'),80),
   left(regexp_replace(coalesce(p_message,'Unknown error'), '[[:alnum:]._%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}', '[email]', 'gi'),1200),
   left(regexp_replace(coalesce(p_stack,''),'/Users/[^/[:space:]]+','/Users/[user]','g'),5000),
   left(coalesce(p_screen,''),120),
   left(coalesce(p_app_version,''),30),
   left(coalesce(p_platform,''),40)
 ) RETURNING id INTO v_id;
 RETURN v_id;
END
$$;
REVOKE ALL ON FUNCTION public.capture_client_error(text,text,text,text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.capture_client_error(text,text,text,text,text,text,text) TO authenticated;
