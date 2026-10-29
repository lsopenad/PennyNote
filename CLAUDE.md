# CLAUDE.md

## Skills del proyecto

Las skills del proyecto están en `.claude/skills/`. Antes de escribir o revisar código, comprueba cuáles hay disponibles y carga con la herramienta Skill **todas** las que cubran el área de la tarea, según la descripción de cada una. Lee solo las `references/` relevantes.

Si se añaden, quitan o actualizan skills, este fichero no necesita cambios.

## Versiones: el proyecto manda

Las skills pueden asumir versiones de Swift, Xcode o iOS más recientes que las del proyecto. Antes de aplicar sus recomendaciones, lee las versiones reales en `project.yml` (`SWIFT_VERSION`, `deploymentTarget` y versiones de paquetes) y respétalas:

- No uses APIs que superen esas versiones sin `#available`, ni cambies versiones sin consultarlo.
- Las recomendaciones que exijan versiones superiores se proponen como mejora aparte, no se aplican durante la tarea.
- Si una regla de una skill choca con el código o las convenciones existentes, prevalece el proyecto; indícalo.
