-- Shop Mart v1.5 Android UAT runtime remediation (2026-10-12).
-- Qualify aggregate columns: orders and order_items both contain subtotal.
CREATE OR REPLACE FUNCTION public.superadmin_commerce_analytics(p_days integer DEFAULT 30)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_since timestamptz := now() - make_interval(days => greatest(1, least(coalesce(p_days, 30), 365)));
  v jsonb;
BEGIN
  IF NOT public.is_platform_super_admin() THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  SELECT jsonb_build_object(
    'since', v_since,
    'orders', count(*),
    'paid_orders', count(*) FILTER (WHERE o.payment_status = 'paid'),
    'revenue', coalesce(sum(o.total_amount) FILTER (WHERE o.payment_status = 'paid'), 0),
    'aov', coalesce(avg(o.total_amount) FILTER (WHERE o.payment_status = 'paid'), 0),
    'cancelled', count(*) FILTER (WHERE o.status = 'cancelled'),
    'completed', count(*) FILTER (WHERE o.status = 'completed'),
    'customers', count(DISTINCT o.user_id)
  )
  INTO v FROM public.orders o WHERE o.created_at >= v_since;

  RETURN v || jsonb_build_object(
    'top_products', coalesce((
      SELECT jsonb_agg(t)
      FROM (
        SELECT oi.product_name,
               sum(oi.quantity) AS qty,
               sum(oi.subtotal) AS sales
        FROM public.order_items oi
        JOIN public.orders o ON o.id = oi.order_id
        WHERE o.created_at >= v_since AND o.status <> 'cancelled'
        GROUP BY oi.product_name
        ORDER BY qty DESC
        LIMIT 10
      ) t
    ), '[]'::jsonb),
    'return_count', (SELECT count(*) FROM public.returns WHERE created_at >= v_since),
    'new_users', (SELECT count(*) FROM public.profiles WHERE created_at >= v_since),
    'low_stock', (SELECT count(*) FROM public.inventory WHERE available_qty <= low_stock_threshold)
  );
END;
$function$;

-- account_deletion_requests.user_id and profiles.id both refer to auth.users,
-- so there is no direct FK relationship for PostgREST resource embedding.
-- Use an explicit authorized join rather than changing referential integrity.
CREATE OR REPLACE FUNCTION public.superadmin_privacy_queue()
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_platform_super_admin() THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(
    jsonb_agg(
      to_jsonb(r) || jsonb_build_object(
        'profiles', CASE WHEN p.id IS NULL THEN NULL
                         ELSE jsonb_build_object('full_name', p.full_name, 'phone', p.phone)
                    END
      )
      ORDER BY r.requested_at DESC
    ), '[]'::jsonb
  )
  INTO v
  FROM public.account_deletion_requests r
  LEFT JOIN public.profiles p ON p.id = r.user_id;

  RETURN v;
END;
$function$;

REVOKE ALL ON FUNCTION public.superadmin_privacy_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.superadmin_privacy_queue() TO authenticated;

-- Flutter's PostgREST .stream() needs Realtime publication membership.
-- Keep existing RLS SELECT policy for per-conversation authorization.
DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  END IF;
END;
$migration$;
