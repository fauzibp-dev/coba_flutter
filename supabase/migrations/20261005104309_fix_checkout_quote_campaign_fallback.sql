create or replace function public.quote_checkout_v2(
 p_address_id uuid,
 p_shipping_method text,
 p_voucher_code text default null
) returns jsonb
 language plpgsql
 security definer
 set search_path='public'
as $$
declare
 v_cart uuid; v_store uuid; v_subtotal numeric:=0; v_discount numeric:=0; v_shipping numeric:=0; v_total numeric:=0;
 v_voucher public.vouchers%rowtype; v_usage int:=0; v_qty int:=0; v_eligible numeric:=0; r record;
 v_price numeric; v_campaign uuid; v_campaign_price numeric; v_items jsonb:='[]'::jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_shipping_method not in ('pickup','local_delivery') then raise exception 'Unsupported shipping method'; end if;
 select id into v_cart from public.carts where user_id=auth.uid();
 if v_cart is null or not exists(select 1 from public.cart_items where cart_id=v_cart) then raise exception 'Cart is empty'; end if;
 select p.store_id into v_store from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=v_cart limit 1;
 if exists(select 1 from public.cart_items ci join public.products p on p.id=ci.product_id where ci.cart_id=v_cart and p.store_id<>v_store) then raise exception 'Multi-store checkout is not enabled yet'; end if;
 for r in
  select ci.*,p.name product_name,p.price base_price,p.category_id,p.status,pv.price_override,pv.is_active variant_active,pv.name variant_name,i.available_qty
  from public.cart_items ci join public.products p on p.id=ci.product_id
  left join public.product_variants pv on pv.id=ci.variant_id
  left join public.inventory i on i.product_id=ci.product_id and ((ci.variant_id is null and i.variant_id is null) or i.variant_id=ci.variant_id)
  where ci.cart_id=v_cart
 loop
  if r.status<>'active' or (r.variant_id is not null and coalesce(r.variant_active,false)=false) then raise exception 'Product unavailable: %',r.product_name; end if;
  if coalesce(r.available_qty,0)<r.quantity then raise exception 'Stock not enough for %',r.product_name; end if;
  v_price:=coalesce(r.price_override,r.base_price); v_campaign:=null; v_campaign_price:=null;
  select cp.promo_price,cp.campaign_id into v_campaign_price,v_campaign
  from public.campaign_products cp join public.campaigns c on c.id=cp.campaign_id
  where cp.product_id=r.product_id and (cp.variant_id is null or cp.variant_id=r.variant_id)
    and cp.promo_price is not null and c.status='active' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>=now())
    and (cp.quota is null or cp.sold_qty+r.quantity<=cp.quota)
  order by c.priority desc,cp.variant_id is not null desc,cp.promo_price asc limit 1;
  if v_campaign_price is not null and v_campaign_price <= v_price then
    v_price:=v_campaign_price;
  else
    v_campaign:=null;
  end if;
  v_subtotal:=v_subtotal+(v_price*r.quantity); v_qty:=v_qty+r.quantity;
  v_items:=v_items||jsonb_build_array(jsonb_build_object('cart_item_id',r.id,'product_id',r.product_id,'variant_id',r.variant_id,'name',r.product_name,'variant_name',r.variant_name,'quantity',r.quantity,'unit_price',v_price,'campaign_id',v_campaign,'stock',r.available_qty));
 end loop;
 if p_voucher_code is not null and btrim(p_voucher_code)<>'' then
  select * into v_voucher from public.vouchers where store_id=v_store and upper(code)=upper(btrim(p_voucher_code)) and is_active and starts_at<=now() and (ends_at is null or ends_at>=now()) limit 1;
  if v_voucher.id is null then raise exception 'Voucher invalid or expired'; end if;
  if v_voucher.first_order_only and exists(select 1 from public.orders where user_id=auth.uid() and status not in ('cancelled','refunded')) then raise exception 'Voucher only valid for first order'; end if;
  if v_qty<v_voucher.minimum_quantity then raise exception 'Minimum quantity not reached'; end if;
  select count(*) into v_usage from public.voucher_usages where voucher_id=v_voucher.id and user_id=auth.uid();
  if v_usage>=v_voucher.usage_per_user then raise exception 'Voucher usage limit reached'; end if;
  if v_voucher.usage_limit is not null and (select count(*) from public.voucher_usages where voucher_id=v_voucher.id)>=v_voucher.usage_limit then raise exception 'Voucher quota exhausted'; end if;
  if exists(select 1 from public.voucher_products where voucher_id=v_voucher.id) or exists(select 1 from public.voucher_categories where voucher_id=v_voucher.id) then
    select coalesce(sum((x->>'unit_price')::numeric*(x->>'quantity')::int),0) into v_eligible
    from jsonb_array_elements(v_items) x
    join public.products p on p.id=(x->>'product_id')::uuid
    where exists(select 1 from public.voucher_products vp where vp.voucher_id=v_voucher.id and vp.product_id=p.id)
       or exists(select 1 from public.voucher_categories vc where vc.voucher_id=v_voucher.id and vc.category_id=p.category_id);
  else v_eligible:=v_subtotal; end if;
  if v_eligible<v_voucher.minimum_purchase then raise exception 'Minimum purchase not reached'; end if;
  if v_voucher.discount_type='fixed' then v_discount:=least(v_eligible,v_voucher.discount_value); else v_discount:=v_eligible*(v_voucher.discount_value/100); end if;
  if v_voucher.maximum_discount is not null then v_discount:=least(v_discount,v_voucher.maximum_discount); end if;
 end if;
 v_shipping:=public.calculate_shipping_fee(v_store,p_address_id,p_shipping_method,v_subtotal);
 if v_voucher.id is not null and v_voucher.free_shipping then v_shipping:=0; end if;
 v_total:=greatest(0,v_subtotal-v_discount+v_shipping);
 return jsonb_build_object('store_id',v_store,'items',v_items,'subtotal',v_subtotal,'discount',v_discount,'shipping',v_shipping,'total',v_total,'voucher_id',v_voucher.id,'voucher_title',v_voucher.title,'shipping_method',p_shipping_method);
end;
$$;

grant execute on function public.quote_checkout_v2(uuid,text,text) to authenticated;
