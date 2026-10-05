alter table public.order_items
  add column if not exists campaign_variant_id uuid
    references public.product_variants(id) on delete set null;

create index if not exists order_items_campaign_variant_idx
  on public.order_items(campaign_variant_id);

create or replace function public.create_checkout_v2(
 p_address_id uuid,
 p_payment_method text,
 p_shipping_method text,
 p_voucher_code text default null,
 p_notes text default null,
 p_client_request_id uuid default null
) returns uuid
 language plpgsql
 security definer
 set search_path='public'
as $$
declare
 v_quote jsonb; v_cart uuid; v_store uuid; v_order uuid; v_order_number text; v_payment uuid; v_due timestamptz; r record;
 v_inventory uuid; v_campaign uuid; v_campaign_variant uuid; v_campaign_price numeric; v_price numeric; v_base numeric;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_payment_method not in ('cod','manual_transfer') then raise exception 'Unsupported payment method'; end if;
 if p_client_request_id is not null then
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':'||p_client_request_id::text,0));
  select id into v_order from public.orders where user_id=auth.uid() and client_request_id=p_client_request_id;
  if v_order is not null then return v_order; end if;
 end if;
 v_quote:=public.quote_checkout_v2(p_address_id,p_shipping_method,p_voucher_code);
 v_store:=(v_quote->>'store_id')::uuid;
 select id into v_cart from public.carts where user_id=auth.uid();
 if p_payment_method='manual_transfer' then
  select now()+make_interval(mins=>coalesce(manual_payment_timeout_minutes,120)) into v_due from public.store_settings where store_id=v_store;
  v_due:=coalesce(v_due,now()+interval '2 hours');
 end if;
 v_order_number:='SM-'||to_char(now(),'YYYYMMDD')||'-'||lpad(nextval('public.order_number_seq')::text,6,'0');
 insert into public.orders(order_number,user_id,store_id,status,payment_status,payment_method,shipping_method,subtotal,discount_amount,shipping_cost,total_amount,voucher_id,address_snapshot,customer_notes,client_request_id,payment_due_at,reservation_expires_at)
 select v_order_number,auth.uid(),v_store,'pending_payment','pending',p_payment_method,p_shipping_method,
  (v_quote->>'subtotal')::numeric,(v_quote->>'discount')::numeric,(v_quote->>'shipping')::numeric,(v_quote->>'total')::numeric,
  nullif(v_quote->>'voucher_id','')::uuid,(select to_jsonb(a.*) from public.addresses a where a.id=p_address_id and a.user_id=auth.uid()),p_notes,p_client_request_id,v_due,v_due
 returning id into v_order;

 for r in
  select ci.*,p.name product_name,p.sku product_sku,p.price base_price,pv.name variant_name,pv.sku variant_sku,pv.price_override
  from public.cart_items ci join public.products p on p.id=ci.product_id left join public.product_variants pv on pv.id=ci.variant_id where ci.cart_id=v_cart
 loop
  select i.id into v_inventory from public.inventory i where i.product_id=r.product_id and ((r.variant_id is null and i.variant_id is null) or i.variant_id=r.variant_id) for update;
  if v_inventory is null or (select available_qty from public.inventory where id=v_inventory)<r.quantity then raise exception 'Stock not enough for %',r.product_name; end if;

  v_base:=coalesce(r.price_override,r.base_price);
  v_price:=v_base; v_campaign:=null; v_campaign_variant:=null; v_campaign_price:=null;
  select cp.promo_price,cp.campaign_id,cp.variant_id into v_campaign_price,v_campaign,v_campaign_variant
  from public.campaign_products cp join public.campaigns c on c.id=cp.campaign_id
  where cp.product_id=r.product_id and (cp.variant_id is null or cp.variant_id=r.variant_id) and cp.promo_price is not null
    and c.status='active' and c.starts_at<=now() and (c.ends_at is null or c.ends_at>=now())
    and (cp.quota is null or cp.sold_qty+r.quantity<=cp.quota)
    and (
      cp.per_user_limit is null or
      coalesce((
        select sum(oi.quantity)
        from public.order_items oi
        join public.orders o on o.id=oi.order_id
        where o.user_id=auth.uid()
          and o.status not in ('cancelled','refunded')
          and oi.campaign_id=cp.campaign_id
          and oi.product_id=cp.product_id
          and (cp.variant_id is null or oi.campaign_variant_id=cp.variant_id)
      ),0)+r.quantity<=cp.per_user_limit
    )
  order by c.priority desc,cp.variant_id is not null desc,cp.promo_price asc limit 1 for update of cp;

  if v_campaign_price is not null and v_campaign_price <= v_base then
    v_price:=v_campaign_price;
  else
    v_campaign:=null; v_campaign_variant:=null;
  end if;

  insert into public.order_items(order_id,product_id,variant_id,product_name,variant_name,sku,unit_price,quantity,subtotal,original_unit_price,campaign_id,campaign_variant_id)
  values(v_order,r.product_id,r.variant_id,r.product_name,r.variant_name,coalesce(r.variant_sku,r.product_sku),v_price,r.quantity,v_price*r.quantity,v_base,v_campaign,v_campaign_variant);
  update public.inventory set available_qty=available_qty-r.quantity,reserved_qty=reserved_qty+case when p_payment_method='manual_transfer' then r.quantity else 0 end where id=v_inventory;
  insert into public.inventory_reservations(order_id,product_id,variant_id,quantity,status,expires_at)
  values(v_order,r.product_id,r.variant_id,r.quantity,case when p_payment_method='manual_transfer' then 'active' else 'committed' end,v_due);
  insert into public.inventory_movements(store_id,product_id,variant_id,movement_type,quantity,note,reference_id,actor_id)
  values(v_store,r.product_id,r.variant_id,case when p_payment_method='manual_transfer' then 'reservation' else 'sale' end,-r.quantity,case when p_payment_method='manual_transfer' then 'Checkout reservation' else 'COD sale' end,v_order,auth.uid());
  if v_campaign is not null then
    update public.campaign_products
      set sold_qty=sold_qty+r.quantity
      where campaign_id=v_campaign and product_id=r.product_id
        and ((v_campaign_variant is null and variant_id is null) or variant_id=v_campaign_variant);
  end if;
 end loop;
 insert into public.payments(order_id,method,status,amount) values(v_order,p_payment_method,'pending',(v_quote->>'total')::numeric) returning id into v_payment;
 insert into public.order_status_history(order_id,status,note,actor_id) values(v_order,'pending_payment','Order created',auth.uid());
 if nullif(v_quote->>'voucher_id','') is not null then insert into public.voucher_usages(voucher_id,user_id,order_id,discount_amount) values((v_quote->>'voucher_id')::uuid,auth.uid(),v_order,(v_quote->>'discount')::numeric); end if;
 insert into public.shipments(order_id,store_id,shipping_method,provider,status,internal_delivery_code)
 values(v_order,v_store,p_shipping_method,case when p_shipping_method='pickup' then 'store_pickup' else 'internal' end,'pending','DLV-'||upper(substr(replace(v_order::text,'-',''),1,10)));
 insert into public.shipment_events(shipment_id,status,description,actor_id)
 select id,'pending','Fulfillment created',auth.uid() from public.shipments where order_id=v_order;
 delete from public.cart_items where cart_id=v_cart;
 if p_payment_method='cod' then
  update public.orders set status='confirmed' where id=v_order;
  insert into public.order_status_history(order_id,status,note,actor_id) values(v_order,'confirmed','COD order confirmed',auth.uid());
 end if;
 return v_order;
end;
$$;

create or replace function public.sync_order_reservations_after_status()
 returns trigger
 language plpgsql
 security definer
 set search_path='public'
as $$
begin
 if new.status='confirmed' and old.status='paid' then
  update public.inventory_reservations set status='committed',updated_at=now() where order_id=new.id and status='active';
 end if;
 if new.status='cancelled' and old.status<>'cancelled' then
  update public.inventory_reservations set status='released',updated_at=now() where order_id=new.id and status='active';
  update public.campaign_products cp
    set sold_qty=greatest(0,cp.sold_qty-oi.quantity)
    from public.order_items oi
    where oi.order_id=new.id
      and oi.campaign_id=cp.campaign_id
      and oi.product_id=cp.product_id
      and ((oi.campaign_variant_id is null and cp.variant_id is null) or oi.campaign_variant_id=cp.variant_id);
 end if;
 return new;
end;
$$;

grant execute on function public.create_checkout_v2(uuid,text,text,text,text,uuid) to authenticated;
revoke execute on function public.sync_order_reservations_after_status() from public,anon,authenticated;
