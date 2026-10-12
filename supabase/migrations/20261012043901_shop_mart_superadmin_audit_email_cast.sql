-- Final Super Admin RETURN QUERY correction: auth.users.email is varchar,
-- while the audit RPC contract returns actor_email text.
CREATE OR REPLACE FUNCTION public.superadmin_audit_logs(p_limit integer DEFAULT 200)
RETURNS TABLE(id bigint, store_id uuid, store_name text, actor_email text, action text, entity_type text, entity_id text, old_value jsonb, new_value jsonb, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth'
AS $function$
BEGIN
  IF NOT public.is_platform_super_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT a.id,a.store_id,s.name,u.email::text,a.action,a.entity_type,a.entity_id,a.old_value,a.new_value,a.created_at
  FROM public.audit_logs a
  LEFT JOIN public.stores s ON s.id=a.store_id
  LEFT JOIN auth.users u ON u.id=a.actor_id
  ORDER BY a.created_at DESC LIMIT greatest(1,least(coalesce(p_limit,200),500));
END;
$function$;
