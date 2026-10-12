-- Correct auth.users.email (varchar) -> RETURNS TABLE customer_email/email (text).
-- PostgreSQL PL/pgSQL RETURN QUERY does not implicitly cast varchar to text.
CREATE OR REPLACE FUNCTION public.superadmin_list_users(p_search text DEFAULT NULL::text)
RETURNS TABLE(user_id uuid, email text, full_name text, phone text, created_at timestamptz, is_super_admin boolean, memberships jsonb)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth'
AS $function$
BEGIN
  IF NOT public.is_platform_super_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT u.id, u.email::text, p.full_name, p.phone, u.created_at,
    EXISTS(SELECT 1 FROM public.platform_admins pa WHERE pa.user_id=u.id AND pa.is_active),
    COALESCE((SELECT jsonb_agg(jsonb_build_object('id',sm.id,'store_id',sm.store_id,'store_name',s.name,'role',sm.role) ORDER BY s.name)
      FROM public.store_members sm JOIN public.stores s ON s.id=sm.store_id WHERE sm.user_id=u.id),'[]'::jsonb)
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id=u.id
  WHERE p_search IS NULL OR btrim(p_search)='' OR coalesce(u.email,'') ILIKE '%'||btrim(p_search)||'%' OR coalesce(p.full_name,'') ILIKE '%'||btrim(p_search)||'%'
  ORDER BY u.created_at DESC LIMIT 200;
END;
$function$;

CREATE OR REPLACE FUNCTION public.superadmin_list_orders(p_store_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text)
RETURNS TABLE(id uuid, order_number text, store_id uuid, store_name text, customer_email text, status text, payment_status text, payment_method text, shipping_method text, total_amount numeric, created_at timestamptz, item_count bigint)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth'
AS $function$
BEGIN
  IF NOT public.is_platform_super_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT o.id,o.order_number,o.store_id,s.name,u.email::text,o.status,o.payment_status,o.payment_method,o.shipping_method,o.total_amount,o.created_at,
    (SELECT count(*) FROM public.order_items oi WHERE oi.order_id=o.id)
  FROM public.orders o JOIN public.stores s ON s.id=o.store_id
  LEFT JOIN auth.users u ON u.id=o.user_id
  WHERE (p_store_id IS NULL OR o.store_id=p_store_id) AND (p_status IS NULL OR p_status='' OR o.status=p_status)
  ORDER BY o.created_at DESC LIMIT 300;
END;
$function$;

CREATE OR REPLACE FUNCTION public.superadmin_list_returns(p_store_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(id uuid, order_id uuid, order_number text, store_id uuid, store_name text, customer_email text, reason text, description text, status text, created_at timestamptz, updated_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth'
AS $function$
BEGIN
  IF NOT public.is_platform_super_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT r.id,r.order_id,o.order_number,o.store_id,s.name,u.email::text,r.reason,r.description,r.status,r.created_at,r.updated_at
  FROM public.returns r JOIN public.orders o ON o.id=r.order_id JOIN public.stores s ON s.id=o.store_id
  LEFT JOIN auth.users u ON u.id=r.user_id
  WHERE p_store_id IS NULL OR o.store_id=p_store_id ORDER BY r.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.superadmin_list_conversations(p_store_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(id uuid, store_id uuid, store_name text, customer_id uuid, customer_email text, customer_name text, updated_at timestamptz, last_message text, last_message_at timestamptz, unread_count bigint)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','auth'
AS $function$
BEGIN
  IF NOT public.is_platform_super_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT c.id,c.store_id,s.name,c.customer_id,u.email::text,p.full_name,c.updated_at,
    (SELECT m.body FROM public.messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC LIMIT 1),
    (SELECT m.created_at FROM public.messages m WHERE m.conversation_id=c.id ORDER BY m.created_at DESC LIMIT 1),
    (SELECT count(*) FROM public.messages m WHERE m.conversation_id=c.id AND m.sender_id=c.customer_id AND NOT m.is_read)
  FROM public.conversations c
  JOIN public.stores s ON s.id=c.store_id
  LEFT JOIN auth.users u ON u.id=c.customer_id
  LEFT JOIN public.profiles p ON p.id=c.customer_id
  WHERE p_store_id IS NULL OR c.store_id=p_store_id
  ORDER BY coalesce((SELECT max(m.created_at) FROM public.messages m WHERE m.conversation_id=c.id),c.updated_at) DESC;
END;
$function$;
