revoke all on function public.create_manager_products_from_store_order() from public, anon, authenticated;
revoke all on function public.sync_manager_digital_catalog_from_product() from public, anon, authenticated;
grant execute on function public.manager_create_sale_atomic(jsonb,jsonb,jsonb) to authenticated;