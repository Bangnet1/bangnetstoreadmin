create or replace function public.manager_update_sale_atomic(p_sale_id uuid,p_item jsonb,p_payment jsonb default null)
returns void language plpgsql security definer set search_path=public,pg_temp
as $function$
declare
 v_uid uuid:=auth.uid(); v_sale public.manager_sales%rowtype; v_item public.manager_sale_items%rowtype;
 v_product public.manager_product_templates%rowtype; v_customer public.manager_customers%rowtype;
 v_qty numeric; v_price numeric; v_cost numeric; v_discount numeric; v_total numeric; v_paid numeric:=0;
 v_method text; v_duration integer:=0; v_expiry date; v_start date;
begin
 if v_uid is null or v_uid<>'58310a62-39b5-409e-aabd-0820417e72cb'::uuid then raise exception 'Akses ditolak' using errcode='42501'; end if;
 select * into v_sale from public.manager_sales where id=p_sale_id and user_id=v_uid for update;
 if not found then raise exception 'Transaksi tidak ditemukan' using errcode='P0002'; end if;
 if v_sale.source_table is not null then raise exception 'Transaksi impor tidak dapat diedit di Manager. Edit dari sumber Admin Store.' using errcode='42501'; end if;
 select * into v_item from public.manager_sale_items where sale_id=p_sale_id and user_id=v_uid for update;
 if not found or (select count(*) from public.manager_sale_items where sale_id=p_sale_id)<>1 then raise exception 'Edit hanya tersedia untuk transaksi dengan satu item' using errcode='22023'; end if;
 select * into v_product from public.manager_product_templates where id=nullif(p_item->>'product_template_id','')::uuid and user_id=v_uid and is_active=true;
 if not found then raise exception 'Produk katalog tidak tersedia' using errcode='22023'; end if;
 v_qty:=(p_item->>'quantity')::numeric; v_price:=(p_item->>'unit_price')::numeric; v_cost:=(p_item->>'unit_cost')::numeric; v_discount:=coalesce((p_item->>'line_discount')::numeric,0);
 if v_qty is null or v_qty<=0 or v_qty<>trunc(v_qty) or v_price is null or v_price<0 or v_cost is null or v_cost<0 or v_discount<0 or v_discount>v_qty*v_price then raise exception 'Jumlah, harga, modal, atau diskon tidak valid' using errcode='22023'; end if;
 v_total:=v_qty*v_price-v_discount;
 if p_payment is not null then v_paid:=(p_payment->>'amount')::numeric; v_method:=coalesce(nullif(p_payment->>'method',''),'cash'); if v_paid is null or v_paid<=0 or v_paid>v_total then raise exception 'Nominal pembayaran tidak valid' using errcode='22023'; end if; end if;
 update public.manager_sales set subtotal=v_qty*v_price,discount=v_discount,total=v_total,status=case when v_paid>=v_total and v_total>0 then 'paid' when v_paid>0 then 'partially_paid' else 'confirmed' end,updated_at=now() where id=p_sale_id;
 update public.manager_sale_items set product_template_id=v_product.id,product_name=v_product.name,variant=v_product.variant,quantity=v_qty,unit_cost=v_cost,unit_price=v_price,line_discount=v_discount where id=v_item.id;
 delete from public.manager_payments where sale_id=p_sale_id and user_id=v_uid;
 if p_payment is not null then insert into public.manager_payments(user_id,sale_id,amount,method,status) values(v_uid,p_sale_id,v_paid,v_method,'completed'); end if;
 select * into v_customer from public.manager_customers where id=v_sale.customer_id and user_id=v_uid;
 v_duration:=greatest(coalesce(v_product.duration_days,0),0);
 if v_duration>0 then
   v_start:=(v_sale.sale_date at time zone 'Asia/Jakarta')::date; v_expiry:=v_start+v_duration;
   update public.manager_products set product_name=v_product.name,variant=v_product.variant,duration_days=v_duration,purchase_date=v_start,expiry_date=v_expiry,purchase_price=v_cost,selling_price=v_price,updated_at=now()
   where user_id=v_uid and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
   update public.manager_subscriptions set product_name=v_product.name,started_at=v_start,expires_at=v_expiry,updated_at=now()
   where user_id=v_uid and sale_item_id=v_item.id;
 else
   delete from public.manager_products where user_id=v_uid and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
   delete from public.manager_subscriptions where user_id=v_uid and sale_item_id=v_item.id;
 end if;
end;
$function$;

create or replace function public.manager_delete_sale_atomic(p_sale_id uuid)
returns void language plpgsql security definer set search_path=public,pg_temp
as $function$
declare v_uid uuid:=auth.uid(); v_sale public.manager_sales%rowtype; v_item_id uuid;
begin
 if v_uid is null or v_uid<>'58310a62-39b5-409e-aabd-0820417e72cb'::uuid then raise exception 'Akses ditolak' using errcode='42501'; end if;
 select * into v_sale from public.manager_sales where id=p_sale_id and user_id=v_uid for update;
 if not found then raise exception 'Transaksi tidak ditemukan' using errcode='P0002'; end if;
 if v_sale.source_table is not null then raise exception 'Transaksi impor tidak dapat dihapus di Manager. Hapus dari sumber Admin Store.' using errcode='42501'; end if;
 for v_item_id in select id from public.manager_sale_items where sale_id=p_sale_id and user_id=v_uid loop
   delete from public.manager_subscriptions where user_id=v_uid and sale_item_id=v_item_id;
 end loop;
 delete from public.manager_products where user_id=v_uid and notes='Dibuat otomatis dari invoice '||v_sale.invoice_number;
 delete from public.manager_sales where id=p_sale_id and user_id=v_uid;
end;
$function$;
revoke all on function public.manager_update_sale_atomic(uuid,jsonb,jsonb) from public,anon;
revoke all on function public.manager_delete_sale_atomic(uuid) from public,anon;
grant execute on function public.manager_update_sale_atomic(uuid,jsonb,jsonb) to authenticated;
grant execute on function public.manager_delete_sale_atomic(uuid) to authenticated;