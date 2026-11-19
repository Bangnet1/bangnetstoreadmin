create or replace function public.create_manager_products_from_store_order()
returns trigger language plpgsql security definer set search_path=public,pg_temp
as $$
declare
  v_item jsonb; v_index integer:=0; v_product public.products%rowtype;
  v_phone text; v_customer_id uuid; v_duration integer; v_name text;
  v_sale_id uuid; v_sale_item_id uuid; v_template_id uuid;
  v_item_price numeric; v_item_cost numeric; v_item_qty numeric; v_invoice text;
begin
  if new.status='dibatalkan' or jsonb_typeof(new.order_items) is distinct from 'array' then return new; end if;
  v_phone:=regexp_replace(coalesce(new.customer_contact,''),'[^0-9]','','g');
  if left(v_phone,1)='0' then v_phone:='62'||substr(v_phone,2); end if;
  if v_phone='' then return new; end if;
  select id into v_customer_id from public.manager_customers
    where user_id='58310a62-39b5-409e-aabd-0820417e72cb'::uuid and phone=v_phone limit 1;
  if v_customer_id is null then
    insert into public.manager_customers(user_id,name,phone)
    values('58310a62-39b5-409e-aabd-0820417e72cb'::uuid,coalesce(nullif(btrim(new.customer_name),''),'Pelanggan'),v_phone)
    returning id into v_customer_id;
  end if;
  v_invoice:='BN-STORE-'||new.id::text;
  insert into public.manager_sales(user_id,customer_id,invoice_number,sale_date,status,subtotal,discount,total,notes,source_order_id,source_table)
  values('58310a62-39b5-409e-aabd-0820417e72cb'::uuid,v_customer_id,v_invoice,new.created_at,
    case when new.status in ('dibayar','diproses','dikirim','selesai') then 'paid' else 'confirmed' end,
    new.total_amount,0,new.total_amount,
    jsonb_build_object('customer_name',new.customer_name,'customer_contact',new.customer_contact,'original_status',new.status)::text,
    new.id,'sales_orders')
  on conflict(source_table,source_order_id) where source_order_id is not null do nothing returning id into v_sale_id;
  if v_sale_id is null then select id into v_sale_id from public.manager_sales where source_table='sales_orders' and source_order_id=new.id limit 1; end if;

  for v_item in select value from jsonb_array_elements(new.order_items) loop
    v_index:=v_index+1;
    v_name:=coalesce(nullif(btrim(v_item->>'product_name'),''),nullif(btrim(v_item->>'name'),''));
    select * into v_product from public.products p
    where p.archived=false and (
      (nullif(v_item->>'product_id','') is not null and p.id=(v_item->>'product_id')::bigint)
      or (v_name is not null and lower(p.name)=lower(v_name))
    )
    order by case when nullif(v_item->>'product_id','') is not null and p.id=(v_item->>'product_id')::bigint then 0 else 1 end
    limit 1;
    v_duration:=case when found then coalesce(v_product.duration_days,0) else 0 end;
    v_item_qty:=greatest(1,coalesce(nullif(v_item->>'quantity','')::numeric,1));
    v_item_price:=coalesce(nullif(v_item->>'unit_price','')::numeric,case when found then v_product.price else 0 end);
    v_item_cost:=case when found then v_product.cost else 0 end;
    v_template_id:=null;
    if found then
      select id into v_template_id from public.manager_product_templates
      where source_product_id=v_product.id and user_id='58310a62-39b5-409e-aabd-0820417e72cb'::uuid limit 1;
    end if;
    insert into public.manager_sale_items(user_id,sale_id,product_template_id,product_name,variant,quantity,unit_cost,unit_price,line_discount,source_order_item_index)
    values('58310a62-39b5-409e-aabd-0820417e72cb'::uuid,v_sale_id,v_template_id,
      coalesce(v_name,'Produk'),nullif(v_item->>'variant',''),v_item_qty,v_item_cost,v_item_price,0,v_index)
    on conflict(sale_id,source_order_item_index) where source_order_item_index is not null do nothing
    returning id into v_sale_item_id;
    if v_sale_item_id is null then
      select id into v_sale_item_id from public.manager_sale_items where sale_id=v_sale_id and source_order_item_index=v_index limit 1;
    end if;

    if v_duration>0 then
      insert into public.manager_products(user_id,customer_id,customer_name,phone,product_name,variant,purchase_date,duration_days,expiry_date,purchase_price,selling_price,notes,source_order_id,source_order_item_index)
      values('58310a62-39b5-409e-aabd-0820417e72cb'::uuid,v_customer_id,
        coalesce(nullif(btrim(new.customer_name),''),'Pelanggan'),v_phone,v_product.name,nullif(v_item->>'variant',''),
        (new.created_at at time zone 'Asia/Jakarta')::date,v_duration,
        (new.created_at at time zone 'Asia/Jakarta')::date+v_duration,v_item_cost,v_item_price,
        'Dibuat otomatis dari pesanan #'||new.id,new.id,v_index)
      on conflict(source_order_id,source_order_item_index) where source_order_id is not null and source_order_item_index is not null do nothing;
      insert into public.manager_subscriptions(user_id,customer_id,sale_item_id,product_name,account_identifier,started_at,expires_at,status,reminder_enabled,notes,source_order_id,source_order_item_index)
      values('58310a62-39b5-409e-aabd-0820417e72cb'::uuid,v_customer_id,v_sale_item_id,v_product.name,v_phone,
        (new.created_at at time zone 'Asia/Jakarta')::date,(new.created_at at time zone 'Asia/Jakarta')::date+v_duration,
        'active',true,'Dibuat otomatis dari pesanan #'||new.id,new.id,v_index)
      on conflict(source_order_id,source_order_item_index) where source_order_id is not null and source_order_item_index is not null do nothing;
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.create_manager_products_from_store_order() from public,anon,authenticated;