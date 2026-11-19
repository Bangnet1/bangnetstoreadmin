alter table public.products
  add column if not exists duration_days integer not null default 0;

alter table public.products
  add constraint products_duration_days_nonnegative
  check (duration_days >= 0) not valid;

alter table public.manager_product_templates
  add column if not exists source_product_id bigint,
  add column if not exists duration_days integer not null default 0;

alter table public.manager_product_templates
  add constraint manager_product_templates_duration_days_nonnegative
  check (duration_days >= 0) not valid;

alter table public.manager_product_templates
  add constraint manager_product_templates_source_product_fk
  foreign key (source_product_id) references public.products(id) on delete set null;

create unique index if not exists manager_product_templates_source_product_uidx
  on public.manager_product_templates(source_product_id)
  where source_product_id is not null;

create or replace function public.sync_manager_digital_catalog_from_product()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_admin_id uuid := '58310a62-39b5-409e-aabd-0820417e72cb'::uuid;
begin
  if new.duration_days > 0 and new.archived = false then
    insert into public.manager_product_templates (
      user_id, source_product_id, name, category, description, variant,
      cost_price, sale_price, stock_status, is_active, duration_days
    ) values (
      v_admin_id, new.id, new.name, new.category, nullif(new.description, ''),
      null, new.cost, new.price,
      case when new.stock <= 0 then 'out_of_stock' else 'available' end,
      true, new.duration_days
    )
    on conflict (source_product_id) where source_product_id is not null
    do update set
      name = excluded.name,
      category = excluded.category,
      description = excluded.description,
      cost_price = excluded.cost_price,
      sale_price = excluded.sale_price,
      stock_status = excluded.stock_status,
      is_active = excluded.is_active,
      duration_days = excluded.duration_days,
      updated_at = now();
  else
    update public.manager_product_templates
    set is_active = false, updated_at = now()
    where source_product_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists products_sync_manager_digital_catalog on public.products;
create trigger products_sync_manager_digital_catalog
after insert or update of name, category, description, price, cost, stock, archived, duration_days
on public.products
for each row execute function public.sync_manager_digital_catalog_from_product();

insert into public.manager_product_templates (
  user_id, source_product_id, name, category, description, cost_price,
  sale_price, stock_status, is_active, duration_days
)
select
  '58310a62-39b5-409e-aabd-0820417e72cb'::uuid,
  p.id, p.name, p.category, nullif(p.description, ''), p.cost, p.price,
  case when p.stock <= 0 then 'out_of_stock' else 'available' end,
  true, p.duration_days
from public.products p
where p.duration_days > 0 and p.archived = false
on conflict (source_product_id) where source_product_id is not null
do update set
  name = excluded.name,
  category = excluded.category,
  description = excluded.description,
  cost_price = excluded.cost_price,
  sale_price = excluded.sale_price,
  stock_status = excluded.stock_status,
  is_active = excluded.is_active,
  duration_days = excluded.duration_days,
  updated_at = now();