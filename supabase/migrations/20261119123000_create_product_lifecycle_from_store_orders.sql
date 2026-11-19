alter table public.manager_products
  add column if not exists source_order_id bigint,
  add column if not exists source_order_item_index integer;

create unique index if not exists manager_products_source_order_item_uidx
  on public.manager_products(source_order_id, source_order_item_index)
  where source_order_id is not null and source_order_item_index is not null;

alter table public.manager_subscriptions
  add column if not exists source_order_id bigint,
  add column if not exists source_order_item_index integer;

create unique index if not exists manager_subscriptions_source_order_item_uidx
  on public.manager_subscriptions(source_order_id, source_order_item_index)
  where source_order_id is not null and source_order_item_index is not null;

create or replace function public.create_manager_products_from_store_order()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_item jsonb;
  v_index integer := 0;
  v_product public.products%rowtype;
  v_phone text;
  v_customer_id uuid;
  v_duration integer;
  v_name text;
begin
  if new.status = 'dibatalkan' or jsonb_typeof(new.order_items) is distinct from 'array' then
    return new;
  end if;

  v_phone := regexp_replace(coalesce(new.customer_contact, ''), '[^0-9]', '', 'g');
  if left(v_phone, 1) = '0' then v_phone := '62' || substr(v_phone, 2); end if;
  if v_phone = '' then return new; end if;

  select id into v_customer_id
  from public.manager_customers
  where user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid
    and phone = v_phone
  limit 1;

  if v_customer_id is null then
    insert into public.manager_customers(user_id, name, phone)
    values ('58310a62-39b5-409e-aabd-0820417e72cb'::uuid,
      coalesce(nullif(btrim(new.customer_name), ''), 'Pelanggan'), v_phone)
    returning id into v_customer_id;
  end if;

  for v_item in select value from jsonb_array_elements(new.order_items)
  loop
    v_index := v_index + 1;
    v_name := coalesce(nullif(btrim(v_item->>'product_name'), ''), nullif(btrim(v_item->>'name'), ''));
    select * into v_product
    from public.products p
    where p.archived = false
      and ((nullif(v_item->>'product_id','') is not null and p.id = (v_item->>'product_id')::bigint)
        or (v_name is not null and lower(p.name) = lower(v_name)))
    order by case when nullif(v_item->>'product_id','') is not null and p.id = (v_item->>'product_id')::bigint then 0 else 1 end
    limit 1;

    if found and v_product.duration_days > 0 then
      v_duration := v_product.duration_days;
      insert into public.manager_products(
        user_id, customer_id, customer_name, phone, product_name, variant,
        purchase_date, duration_days, expiry_date, purchase_price, selling_price,
        notes, source_order_id, source_order_item_index
      ) values (
        '58310a62-39b5-409e-aabd-0820417e72cb'::uuid,
        v_customer_id, coalesce(nullif(btrim(new.customer_name), ''), 'Pelanggan'),
        v_phone, v_product.name, nullif(v_item->>'variant',''),
        (new.created_at at time zone 'Asia/Jakarta')::date, v_duration,
        (new.created_at at time zone 'Asia/Jakarta')::date + v_duration,
        v_product.cost,
        coalesce(nullif(v_item->>'unit_price','')::numeric, v_product.price),
        'Dibuat otomatis dari pesanan #' || new.id,
        new.id, v_index
      )
      on conflict (source_order_id, source_order_item_index)
        where source_order_id is not null and source_order_item_index is not null
      do nothing;

      insert into public.manager_subscriptions(
        user_id, customer_id, sale_item_id, product_name, account_identifier,
        started_at, expires_at, status, reminder_enabled, notes,
        source_order_id, source_order_item_index
      )
      select
        '58310a62-39b5-409e-aabd-0820417e72cb'::uuid,
        v_customer_id, si.id, v_product.name, v_phone,
        (new.created_at at time zone 'Asia/Jakarta')::date,
        (new.created_at at time zone 'Asia/Jakarta')::date + v_duration,
        'active', true, 'Dibuat otomatis dari pesanan #' || new.id,
        new.id, v_index
      from public.manager_sale_items si
      where si.source_order_item_index = v_index
        and si.sale_id in (
          select s.id from public.manager_sales s
          where s.source_table = 'sales_orders' and s.source_order_id = new.id
        )
      on conflict (source_order_id, source_order_item_index)
        where source_order_id is not null and source_order_item_index is not null
      do nothing;
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists sales_orders_create_manager_products on public.sales_orders;
create trigger sales_orders_create_manager_products
after insert on public.sales_orders
for each row execute function public.create_manager_products_from_store_order();