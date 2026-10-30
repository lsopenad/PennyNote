-- Gastos recurrentes (1.6.0): plantillas que crean un gasto normal cada semana, mes o año.
--
-- Las plantillas siguen las mismas reglas que categories y expenses (ver la migración inicial):
-- updated_at decide qué versión gana, server_updated_at sirve para pedir lo cambiado y los borrados
-- son lógicos. Los gastos los crea el móvil, no el servidor; cada gasto apunta a su plantilla con
-- recurring_expense_id.

create table public.recurring_expenses (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  amount numeric not null check (amount > 0 and amount < 1000000000),
  title text not null default '' check (char_length(title) <= 500),
  payment_method text not null check (payment_method in ('cash', 'card', 'transfer', 'other')),
  category_id uuid references public.categories (id) on delete set null,
  frequency text not null check (frequency in ('weekly', 'monthly', 'yearly')),
  -- Primera repetición de la serie: las demás se calculan a partir de ella.
  start_date timestamptz not null,
  -- Siguiente repetición que falta por crear.
  next_date timestamptz not null,
  is_paused boolean not null default false,
  is_deleted boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  server_updated_at timestamptz not null default now()
);

create index recurring_expenses_user_sync_idx on public.recurring_expenses (user_id, server_updated_at);
create index recurring_expenses_category_idx on public.recurring_expenses (category_id);

create trigger recurring_expenses_apply_sync_write
before insert or update on public.recurring_expenses
for each row execute function public.apply_sync_write();

-- La misma comprobación que en expenses: solo categorías del mismo usuario.
create trigger recurring_expenses_check_category_owner
before insert or update of category_id on public.recurring_expenses
for each row execute function public.check_expense_category_owner();

alter table public.recurring_expenses enable row level security;

create policy "Recurrentes propios: leer" on public.recurring_expenses
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Recurrentes propios: crear" on public.recurring_expenses
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Recurrentes propios: modificar" on public.recurring_expenses
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

revoke all on public.recurring_expenses from anon;
revoke delete, truncate on public.recurring_expenses from authenticated;

-- Plantilla de la que viene cada gasto. Las versiones anteriores a la 1.6.0 no envían la columna: al
-- crear un gasto queda en NULL y al modificarlo se conserva la que tuviera.
alter table public.expenses
  add column recurring_expense_id uuid references public.recurring_expenses (id) on delete set null;

create index expenses_recurring_expense_idx on public.expenses (recurring_expense_id);

-- Un gasto solo puede apuntar a una plantilla del mismo usuario.
create function public.check_expense_recurring_owner() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.recurring_expense_id is not null and not exists (
    select 1 from public.recurring_expenses r where r.id = new.recurring_expense_id and r.user_id = new.user_id
  ) then
    raise exception 'El gasto recurrente % no pertenece al usuario', new.recurring_expense_id
      using errcode = '23503';
  end if;
  return new;
end;
$$;

create trigger expenses_check_recurring_owner
before insert or update of recurring_expense_id on public.expenses
for each row execute function public.check_expense_recurring_owner();
