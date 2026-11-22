create or replace function public.manager_create_sale_atomic(p_sale jsonb,p_item jsonb,p_payment jsonb default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp
as $function$
declare
 v_user_id uuid:=auth.uid(); v_sale_id uuid; v_sale_item_id uuid;
 v_customer_id uuid; v_customer_name text; v_customer_phone text; v_customer_email text;
 v_customer_opted_out boolean:=false; v_phone text;
 v_product_template_id uuid; v_product_name text; v_variant text; v_duration integer:=0;
 v_quantity numeric; v_unit_price numeric; v_unit_cost numeric; v_discount numeric;
 v_subtotal numeric; v_total numeric; v_paid numeric:=0; v_payment_method text;
 v_invoice_number text; v_sale_status text;
 v_start_date date:=(now() at time zone 'Asia/Jakarta')::date; v_expiry_date date;
begin
 if v_user_id is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_sale is null or p_item is null then raise exception 'Sale and item payloads are required' using errcode='22023'; end if;
 v_customer_id:=nullif(p_sale->>'customer_id','')::uuid;
 v_product_template_id:=nullif(p_item->>'product_template_id','')::uuid;
 v_invoice_number:=nullif(btrim(p_sale->>'invoice_number'),'');
 v_quantity:=(p_item->>'quantity')::numeric; v_unit_price:=(p_item->>'unit_price')::numeric;
 v_unit_cost:=(p_item->>'unit_cost')::numeric; v_discount:=coalesce((p_item->>'line_discount')::numeric,0);
 v_subtotal:=v_quantity*v_unit_price; v_total:=v_subtotal-v_discount;
 if v_product_template_id is null then raise exception 'Catalog product is required' using errcode='22023'; end if;
 if v_invoice_number is null or length(v_invoice_number)>80 then raise exception 'Invalid invoice number' using errcode='22023'; end if;
 if v_quantity is null or v_quantity<=0 or v_quantity<>trunc(v_quantity) then raise exception 'Quantity must be a positive whole number' using errcode='22023'; end if;
 if v_unit_price is null or v_unit_price<0 or v_unit_cost is null or v_unit_cost<0 then raise exception 'Invalid unit price or cost' using errcode='22023'; end if;
 if v_discount<0 or v_discount>v_subtotal then raise exception 'Invalid discount' using errcode='22023'; end if;

 if v_customer_id is null then
   v_customer_name:=nullif(btrim(p_sale->>'customer_name'),'');
   v_phone:=regexp_replace(coalesce(p_sale->>'customer_phone',''),'[^0-9]','','g');
   if left(v_phone,1)='0' then v_phone:='62'||substr(v_phone,2); end if;
   v_customer_email:=nullif(btrim(p_sale->>'customer_email'),'');
   v_customer_opted_out:=coalesce((p_sale->>'customer_opted_out')::boolean,false);
   if v_customer_name is null or length(v_customer_name)>150 or v_phone !~ '^62[0-9]{8,15}$' then
     raise exception 'Nama dan nomor WhatsApp pelanggan baru wajib valid' using errcode='22023';
   end if;
   insert into public.manager_customers(user_id,name,phone,email,opted_out,notes)
   values(v_user_id,v_customer_name,v_phone,v_customer_email,v_customer_opted_out,nullif(p_sale->>'customer_notes',''))
   on conflict(user_id,phone) do update set
     name=excluded.name,
     email=coalesce(excluded.email,manager_customers.email),
     opted_out=excluded.opted_out,
     notes=coalesce(excluded.notes,manager_customers.notes),
     updated_at=now()
   returning id,name,phone into v_customer_id,v_customer_name,v_customer_phone;
 else
   select c.name,c.phone into v_customer_name,v_customer_phone from public.manager_customers c
   where c.id=v_customer_id and c.user_id=v_user_id;
   if not found then raise exception 'Customer not found or access denied' using errcode='42501'; end if;
 end if;

 select p.name,p.variant,p.duration_days into v_product_name,v_variant,v_duration
 from public.manager_product_templates p
 where p.id=v_product_template_id and p.user_id=v_user_id and p.is_active=true and p.stock_status<>'out_of_stock';
 if not found then raise exception 'Catalog product unavailable or access denied' using errcode='22023'; end if;
 if p_payment is not null then
   v_paid:=(p_payment->>'amount')::numeric; v_payment_method:=coalesce(nullif(p_payment->>'method',''),'cash');
   if v_paid is null or v_paid<=0 or v_paid>v_total then raise exception 'Invalid payment amount' using errcode='22023'; end if;
 end if;
 v_sale_status:=case when v_paid>=v_total and v_total>0 then 'paid' when v_paid>0 then 'partially_paid' else 'confirmed' end;
 insert into public.manager_sales(user_id,customer_id,invoice_number,status,subtotal,discount,total,notes)
 values(v_user_id,v_customer_id,v_invoice_number,v_sale_status,v_subtotal,v_discount,v_total,nullif(p_sale->>'notes','')) returning id into v_sale_id;
 insert into public.manager_sale_items(user_id,sale_id,product_template_id,product_name,variant,quantity,unit_cost,unit_price,line_discount)
 values(v_user_id,v_sale_id,v_product_template_id,v_product_name,v_variant,v_quantity,v_unit_cost,v_unit_price,v_discount) returning id into v_sale_item_id;
 if v_duration>0 then
   v_expiry_date:=v_start_date+v_duration;
   insert into public.manager_products(user_id,customer_id,customer_name,phone,product_name,variant,purchase_date,duration_days,expiry_date,purchase_price,selling_price,notes)
   values(v_user_id,v_customer_id,v_customer_name,v_customer_phone,v_product_name,v_variant,v_start_date,v_duration,v_expiry_date,v_unit_cost,v_unit_price,'Dibuat otomatis dari invoice '||v_invoice_number);
   insert into public.manager_subscriptions(user_id,customer_id,sale_item_id,product_name,account_identifier,started_at,expires_at,status,reminder_enabled,notes)
   values(v_user_id,v_customer_id,v_sale_item_id,v_product_name,v_customer_phone,v_start_date,v_expiry_date,'active',true,'Dibuat otomatis dari invoice '||v_invoice_number);
 end if;
 if p_payment is not null then insert into public.manager_payments(user_id,sale_id,amount,method,status) values(v_user_id,v_sale_id,v_paid,v_payment_method,'completed'); end if;
 return v_sale_id;
end;
$function$;