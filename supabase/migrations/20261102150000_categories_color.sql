-- 1.12.0: las categorías vuelven a poder tener color, opcional. color guarda el de la paleta de la app
-- (CategoryPaletteColor: «red», «teal»…) o uno personalizado como «#RRGGBB»; null es sin color.
--
-- Solo se limita la longitud, sin comprobar el formato, como con icon: la app trata un valor que no
-- reconoce como sin color. Los móviles con la 1.11.0 o anteriores siguen sincronizando: no envían la
-- columna, así que el upsert no la toca y el color se conserva.

alter table public.categories
  add column color text check (char_length(color) <= 50);
