CREATE OR REPLACE FUNCTION public.capture_client_error(p_source text,p_message text,p_stack text DEFAULT NULL,p_screen text DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $f$
DECLARE v_id bigint;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF (SELECT count(*) FROM public.client_error_logs WHERE user_id=auth.uid() AND created_at>now()-interval '1 hour') > 100 THEN RETURN NULL; END IF;
 INSERT INTO public.client_error_logs (user_id,source,message,stack_trace,screen)
 VALUES(auth.uid(),left(coalesce(p_source,'flutter'),80),left(coalesce(p_message,'error'),1200),left(coalesce(p_stack,''),5000),left(coalesce(p_screen,''),120))
 RETURNING id INTO v_id;
 RETURN v_id;
END
$f$;
REVOKE ALL ON FUNCTION public.capture_client_error(text,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.capture_client_error(text,text,text,text) TO authenticated;
