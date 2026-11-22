alter table public.manager_product_templates
  add column if not exists stock_quantity integer not null default 0;

create or replace function public.sync_manager_digital_catalog_from_product()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_admin_id uuid := '58310a62-39b5-409e-aabd-0820417e72cb'::uuid;
begin
  if new.archived = false then
    insert into public.manager_product_templates (
      user_id, source_product_id, name, category, description, variant,
      cost_price, sale_price, stock_status, stock_quantity, is_active, duration_days
    ) values (
      v_admin_id, new.id, new.name, new.category, nullif(new.description, ''),
      null, new.cost, new.price,
      case when new.stock <= 0 then 'out_of_stock' else 'available' end,
      greatest(coalesce(new.stock,0),0), true, greatest(coalesce(new.duration_days,0),0)
    )
    on conflict (source_product_id) where source_product_id is not null
    do update set
      name = excluded.name,
      category = excluded.category,
      description = excluded.description,
      cost_price = excluded.cost_price,
      sale_price = excluded.sale_price,
      stock_status = excluded.stock_status,
      stock_quantity = excluded.stock_quantity,
      is_active = excluded.is_active,
      duration_days = excluded.duration_days,
      updated_at = now();
  else
    update public.manager_product_templates
    set is_active = false, stock_quantity = 0, stock_status = 'out_of_stock', updated_at = now()
    where source_product_id = new.id;
  end if;
  return new;
end;
$function$;

update public.products set updated_at = updated_at where archived = false;