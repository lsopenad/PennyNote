-- La app ofrece todas las monedas ISO 4217 en uso que conoce iOS y respeta las que ya se han retirado,
-- así que aquí solo se comprueba el formato del código. Una lista cerrada obligaría a migrar cada vez
-- que iOS añada o quite una moneda, y mientras tanto la elegida no se podría sincronizar.

alter table public.user_settings drop constraint user_settings_currency_check;

alter table public.user_settings
  add constraint user_settings_currency_check check (currency ~ '^[A-Z]{3}$');
