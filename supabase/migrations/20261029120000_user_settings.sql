-- Ajustes de cada cuenta que se sincronizan entre dispositivos. De momento, solo la moneda.
--
-- Una fila por usuario, con las mismas marcas de tiempo y last-write-wins que categories y expenses
-- (ver la migración inicial). Si no hay fila, la cuenta aún no ha elegido moneda y la app la pregunta.

create table public.user_settings (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  currency text not null check (currency in ('EUR', 'USD', 'GBP', 'CNY', 'JPY', 'MXN', 'CHF', 'CAD', 'ARS', 'COP')),
  updated_at timestamptz not null,
  server_updated_at timestamptz not null default now()
);

create trigger user_settings_apply_sync_write
before insert or update on public.user_settings
for each row execute function public.apply_sync_write();

alter table public.user_settings enable row level security;

create policy "Ajustes propios: leer" on public.user_settings
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Ajustes propios: crear" on public.user_settings
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Ajustes propios: modificar" on public.user_settings
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on public.user_settings from anon;
revoke delete, truncate on public.user_settings from authenticated;
