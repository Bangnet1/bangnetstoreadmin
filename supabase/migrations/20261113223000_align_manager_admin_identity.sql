-- Align Manager row-level access with the authenticated admin account in the replacement Supabase project.
-- This migration changes only policy predicates; it does not alter or delete table data.

alter policy manager_admin_only on public.manager_app_settings using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_campaign_recipients using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_campaigns using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_cash_accounts using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_cashbook_entries using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_customer_tag_links using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_customer_tags using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_customers using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_expenses using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_journal_entries using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_journal_lines using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_message_logs using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_message_reports using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_message_templates using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_payments using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_product_templates using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_products using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_reminder_history using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_sale_items using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_sales using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_scheduled_contents using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_subscriptions using (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (user_id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
alter policy manager_admin_only on public.manager_profiles using (id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid) with check (id = '58310a62-39b5-409e-aabd-0820417e72cb'::uuid);
