create or replace function public.manager_update_sale_atomic(
 p_sale_id uuid,p_item jsonb,p_payment jsonb
) returns void language plpgsql security definer set search_path=public,pg_temp
as $function$
declare
 v_user uuid:=auth.uid(); v_sale public.manager_sales%rowtype;
 v_item public.manager_sale_items%rowtype;
 v_template public.manager_product_templates%rowtype;
 v_qty numeric; v_price numeric; v_cost numeric; v_discount numeric; v_total numeric; v_paid numeric:=0;
 v_duration integer; v_start date; v_expiry date; v_count integer; v_method text;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_sale from public.manager_sales where id=p_sale_id and user_id=v_user for update;
 if not found then raise exception 'Transaksi tidak ditemukan atau akses ditolak' using errcode='42501'; end if;
 if v_sale.source_table='sales_orders' or v_sale.source_order_id is not null then raise exception 'Pesanan dari website toko tidak dapat diedit dari Manager' using errcode='42501'; end if;
 select count(*) into v_count from public.manager_sale_items where sale_id=p_sale_id and user_id=v_user;
 if v_count<>1 then raise exception 'Edit hanya tersedia untuk transaksi dengan satu item produk' using errcode='22023'; end if;
 select * into v_item from public.manager_sale_items where sale_id=p_sale_id and user_id=v_user for update;
 if p_item is null then raise exception 'Detail produk wajib diisi' using errcode='22023'; end if;
 v_qty:=(p_item->>'quantity')::numeric; v_price:=(p_item->>'unit_price')::numeric; v_cost:=(p_item->>'unit_cost')::numeric; v_discount:=coalesce((p_item->>'line_discount')::numeric,0);
 if v_qty is null or v_qty<=0 or v_qty<>trunc(v_qty) or v_price is null or v_price<0 or v_cost is null or v_cost<0 or v_discount<0 or v_discount>v_qty*v_price then raise exception 'Jumlah, harga, modal, atau diskon tidak valid' using errcode='22023'; end if;
 select * into v_template from public.manager_product_templates where id=(p_item->>'product_template_id')::uuid and user_id=v_user and is_active=true;
 if not found then raise exception 'Produk katalog tidak ditemukan atau tidak aktif' using errcode='22023'; end if;
 v_total:=v_qty*v_price-v_discount;
 select count(*) into v_count from public.manager_payments where sale_id=p_sale_id and user_id=v_user;
 if v_count>1 then raise exception 'Transaksi memiliki beberapa riwayat pembayaran; edit pembayaran perlu pemeriksaan admin' using errcode='22023'; end if;
 v_paid:=coalesce((p_payment->>'amount')::numeric,0);
 if v_paid<0 or v_paid>v_total then raise exception 'Nominal pembayaran tidak valid' using errcode='22023'; end if;
 v_method:=coalesce(nullif(p_payment->>'method',''), 'cash');
 update public.manager_sales set subtotal=v_qty*v_price,discount=v_discount,total=v_total,status=case when v_paid>=v_total and v_total>0 then 'paid' when v_paid>0 then 'partially_paid' else 'confirmed' end,updated_at=now() where id=p_sale_id;
 update public.manager_sale_items set product_template_id=v_template.id,product_name=v_template.name,variant=v_template.variant,quantity=v_qty,unit_cost=v_cost,unit_price=v_price,line_discount=v_discount where id=v_item.id;
 if v_count=1 and v_paid>0 then
   update public.manager_payments set amount=v_paid,method=v_method,status='completed',paid_at=now() where sale_id=p_sale_id and user_id=v_user;
 elsif v_count=1 and v_paid=0 then
   delete from public.manager_payments where sale_id=p_sale_id and user_id=v_user;
 elsif v_count=0 and v_paid>0 then
   insert into public.manager_payments(user_id,sale_id,amount,method,status) values(v_user,p_sale_id,v_paid,v_method,'completed');
 end if;
 select duration_days into v_duration from public.manager_product_templates where id=v_template.id;
 v_start:=coalesce(v_sale.sale_date at time zone 'Asia/Jakarta',now() at time zone 'Asia/Jakarta')::date;
 v_expiry:=v_start+greatest(coalesce(v_duration,0),0);
 if v_duration>0 then
   update public.manager_products set product_name=v_template.name,variant=v_template.variant,duration_days=v_duration,expiry_date=v_expiry,purchase_price=v_cost,selling_price=v_price,updated_at=now() where user_id=v_user and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
   update public.manager_subscriptions set product_name=v_template.name,started_at=v_start,expires_at=v_expiry,updated_at=now() where user_id=v_user and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
 else
   delete from public.manager_subscriptions where user_id=v_user and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
   delete from public.manager_products where user_id=v_user and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
 end if;
end;$function$;

create or replace function public.manager_delete_sale_atomic(p_sale_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp
as $function$
declare v_user uuid:=auth.uid(); v_sale public.manager_sales%rowtype;
begin
 if v_user is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_sale from public.manager_sales where id=p_sale_id and user_id=v_user for update;
 if not found then raise exception 'Transaksi tidak ditemukan atau akses ditolak' using errcode='42501'; end if;
 if v_sale.source_table='sales_orders' or v_sale.source_order_id is not null then raise exception 'Pesanan dari website toko tidak dapat dihapus dari Manager' using errcode='42501'; end if;
 delete from public.manager_subscriptions where user_id=v_user and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
 delete from public.manager_products where user_id=v_user and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
 delete from public.manager_sales where id=p_sale_id and user_id=v_user;
end;$function$;
revoke all on function public.manager_update_sale_atomic(uuid,jsonb,jsonb) from public,anon;
revoke all on function public.manager_delete_sale_atomic(uuid) from public,anon;
grant execute on function public.manager_update_sale_atomic(uuid,jsonb,jsonb) to authenticated;
grant execute on function public.manager_delete_sale_atomic(uuid) to authenticated;