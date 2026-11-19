create or replace function public.admin_create_manual_order(
  p_customer_name text,
  p_customer_contact text,
  p_items jsonb,
  p_status text default 'menunggu_konfirmasi'
)
returns bigint
language plpgsql
set search_path=public
as $function$
declare
  v_item jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_unit_price bigint;
  v_subtotal bigint;
  v_total bigint:=0;
  v_product public.products%rowtype;
  v_order_items jsonb:='[]'::jsonb;
  v_order_id bigint;
  v_phone text;
begin
  if auth.uid() is null
     or auth.uid()<>'58310a62-39b5-409e-aabd-0820417e72cb'::uuid
     or lower(coalesce(auth.jwt()->>'email',''))<>'bangunwicaksono553@gmail.com' then
    raise exception 'Akses ditolak: hanya admin toko yang dapat mencatat pesanan manual' using errcode='42501';
  end if;
  if nullif(btrim(p_customer_name),'') is null or length(p_customer_name)>160 then
    raise exception 'Nama pelanggan wajib diisi (maksimal 160 karakter)' using errcode='22023';
  end if;
  if p_customer_contact is not null and length(p_customer_contact)>160 then
    raise exception 'Kontak pelanggan maksimal 160 karakter' using errcode='22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) is distinct from 'array'
     or jsonb_array_length(p_items)<1 or jsonb_array_length(p_items)>100 then
    raise exception 'Pesanan harus berisi 1 sampai 100 item' using errcode='22023';
  end if;
  if p_status is null or p_status not in ('menunggu_pembayaran','menunggu_konfirmasi','terjual','diproses','dikirim','dibayar','selesai','dibatalkan') then
    raise exception 'Status pesanan tidak valid' using errcode='22023';
  end if;
  v_phone:=regexp_replace(coalesce(p_customer_contact,''),'[^0-9]','','g');
  if left(v_phone,1)='0' then v_phone:='62'||substr(v_phone,2); end if;
  if v_phone<>'' and v_phone !~ '^62[0-9]{8,15}$' then
    raise exception 'Nomor WhatsApp pelanggan tidak valid' using errcode='22023';
  end if;
  for v_item in select value from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item) is distinct from 'object' then
      raise exception 'Format item pesanan tidak valid' using errcode='22023';
    end if;
    v_product_id:=(v_item->>'product_id')::bigint;
    v_quantity:=(v_item->>'quantity')::integer;
    v_unit_price:=(v_item->>'unit_price')::bigint;
    if v_product_id is null or v_quantity is null or v_quantity<1 or v_unit_price is null or v_unit_price<0 then
      raise exception 'Data produk, jumlah, atau harga tidak valid' using errcode='22023';
    end if;
    select * into v_product from public.products where id=v_product_id and archived=false for update;
    if not found then raise exception 'Produk tidak ditemukan atau sudah diarsipkan (ID %)',v_product_id using errcode='22023'; end if;
    if v_product.duration_days>0 and v_phone='' then
      raise exception 'Nomor WhatsApp wajib diisi untuk pesanan produk bermasa aktif' using errcode='22023';
    end if;
    if v_product.stock<v_quantity then
      raise exception 'Stok produk "%" tidak mencukupi. Stok tersedia: %, diminta: %',v_product.name,v_product.stock,v_quantity using errcode='22023';
    end if;
    v_subtotal:=v_quantity::bigint*v_unit_price;
    if v_subtotal>9000000000000000 or v_total>9000000000000000-v_subtotal then
      raise exception 'Total pesanan terlalu besar' using errcode='22003';
    end if;
    v_total:=v_total+v_subtotal;
    update public.products set stock=stock-v_quantity,updated_at=now() where id=v_product_id;
    v_order_items:=v_order_items||jsonb_build_array(jsonb_build_object(
      'product_id',v_product_id,'product_name',v_product.name,'quantity',v_quantity,
      'unit_price',v_unit_price,'subtotal',v_subtotal
    ));
  end loop;
  insert into public.sales_orders(order_items,total_amount,status,source,customer_name,customer_contact,updated_at)
  values(v_order_items,v_total,p_status,'manual_admin',btrim(p_customer_name),nullif(btrim(p_customer_contact),''),now())
  returning id into v_order_id;
  return v_order_id;
end;
$function$;