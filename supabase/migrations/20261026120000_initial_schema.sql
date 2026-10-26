-- Esquema inicial de PennyNote: categorías y gastos por usuario, con sincronización last-write-wins.
--
-- Cada fila lleva dos marcas de tiempo:
--   updated_at         la pone el móvil al modificar la fila; decide qué versión gana (last-write-wins).
--   server_updated_at  la pone el servidor al escribir; los móviles piden "lo cambiado desde X" con ella,
--                      porque el reloj de cada móvil puede ir adelantado o atrasado.
-- Los borrados son lógicos (is_deleted) para que lleguen al resto de dispositivos.

create table public.categories (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  symbol_name text not null check (char_length(symbol_name) between 1 and 100),
  sort_order integer not null,
  color_name text check (char_length(color_name) <= 50),
  is_deleted boolean not null default false,
  updated_at timestamptz not null,
  server_updated_at timestamptz not null default now()
);

create table public.expenses (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  amount numeric not null check (amount > 0 and amount < 1000000000),
  date timestamptz not null,
  title text not null default '' check (char_length(title) <= 500),
  payment_method text not null check (payment_method in ('cash', 'card', 'transfer', 'other')),
  category_id uuid references public.categories (id) on delete set null,
  is_deleted boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  server_updated_at timestamptz not null default now()
);

create index categories_user_sync_idx on public.categories (user_id, server_updated_at);
create index expenses_user_sync_idx on public.expenses (user_id, server_updated_at);
create index expenses_category_idx on public.expenses (category_id);

-- Mantiene server_updated_at, impide cambiar el dueño de una fila y aplica last-write-wins: si llega
-- una versión más antigua que la guardada (otro móvil la modificó después), se descarta sin error.
create function public.apply_sync_write() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at < old.updated_at then
      return null;
    end if;
    new.user_id := old.user_id;
  end if;
  new.server_updated_at := now();
  return new;
end;
$$;

create trigger categories_apply_sync_write
before insert or update on public.categories
for each row execute function public.apply_sync_write();

create trigger expenses_apply_sync_write
before insert or update on public.expenses
for each row execute function public.apply_sync_write();

-- Un gasto solo puede apuntar a una categoría del mismo usuario.
create function public.check_expense_category_owner() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.category_id is not null and not exists (
    select 1 from public.categories c where c.id = new.category_id and c.user_id = new.user_id
  ) then
    raise exception 'La categoría % no pertenece al usuario', new.category_id
      using errcode = '23503';
  end if;
  return new;
end;
$$;

create trigger expenses_check_category_owner
before insert or update of category_id on public.expenses
for each row execute function public.check_expense_category_owner();

-- Cada usuario solo ve y modifica sus filas. No hay política de DELETE: los borrados son lógicos y
-- las filas solo desaparecen al borrar la cuenta (on delete cascade).
alter table public.categories enable row level security;
alter table public.expenses enable row level security;

create policy "Categorías propias: leer" on public.categories
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Categorías propias: crear" on public.categories
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Categorías propias: modificar" on public.categories
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "Gastos propios: leer" on public.expenses
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Gastos propios: crear" on public.expenses
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Gastos propios: modificar" on public.expenses
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Sin sesión no hay nada que hacer en estas tablas.
revoke all on public.categories, public.expenses from anon;
revoke delete, truncate on public.categories, public.expenses from authenticated;

-- "Borrar mi cuenta y mis datos": borra el usuario de Auth y, en cascada, sus categorías y gastos.
-- security definer porque un usuario normal no puede escribir en auth.users; solo actúa sobre auth.uid().
create function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'No hay sesión iniciada' using errcode = '42501';
  end if;
  delete from auth.users where id = current_user_id;
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
