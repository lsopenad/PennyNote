-- Después de la 1.10.0: el icono de una categoría solo puede ser uno de los símbolos del catálogo de la app
-- (CategorySymbolCatalog). Los emojis de la 1.10.0 y los símbolos retirados pasan a tag.fill.
-- updated_at no se toca: el trigger pone server_updated_at y los móviles bajan la fila, pero un cambio
-- suyo aún sin subir (posterior) sigue ganando; ese ya sube con el icono cambiado por la app.
--
-- No se añade un check con la lista: un móvil que siga en la 1.10.0 puede subir un emoji y dejaría de
-- sincronizar. La app cambia los que lleguen al bajarlos y los vuelve a subir.

update public.categories
set icon = 'tag.fill'
where icon <> all (array[
  'fork.knife', 'cup.and.saucer.fill', 'mug.fill', 'wineglass.fill', 'birthday.cake.fill',
  'takeoutbag.and.cup.and.straw.fill', 'carrot.fill', 'cart.fill', 'basket.fill', 'bag.fill',
  'tshirt.fill', 'shoe.fill', 'gift.fill', 'tag.fill', 'scissors', 'car.fill', 'bus.fill',
  'tram.fill', 'airplane', 'ferry.fill', 'bicycle', 'scooter', 'fuelpump.fill',
  'parkingsign.circle.fill', 'suitcase.fill', 'beach.umbrella.fill', 'house.fill', 'sofa.fill',
  'bed.double.fill', 'refrigerator.fill', 'washer.fill', 'lightbulb.fill', 'powerplug.fill',
  'drop.fill', 'flame.fill', 'wifi', 'wrench.and.screwdriver.fill', 'key.fill', 'cross.case.fill',
  'pills.fill', 'heart.fill', 'stethoscope', 'dumbbell.fill', 'figure.run', 'gamecontroller.fill',
  'film.fill', 'tv.fill', 'music.note', 'ticket.fill', 'theatermasks.fill', 'book.fill',
  'camera.fill', 'soccerball', 'party.popper.fill', 'person.fill', 'person.2.fill',
  'figure.and.child.holdinghands', 'pawprint.fill', 'graduationcap.fill', 'briefcase.fill',
  'banknote.fill', 'creditcard.fill', 'building.columns.fill', 'chart.line.uptrend.xyaxis',
  'doc.text.fill', 'shield.fill', 'iphone', 'laptopcomputer', 'star.fill', 'ellipsis.circle.fill'
]);
