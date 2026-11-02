-- 1.10.0: el icono de una categoría puede ser un símbolo SF («fork.knife») o un emoji («🍕»), así que
-- symbol_name pasa a llamarse icon; y las categorías dejan de tener color. Se hace de una vez, sin
-- periodo de transición: un móvil con la 1.9.1 o anterior deja de sincronizar las categorías hasta
-- que se actualice.

alter table public.categories rename column symbol_name to icon;
alter table public.categories rename constraint categories_symbol_name_check to categories_icon_check;

alter table public.categories drop column color_name;
