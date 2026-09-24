# Lab 2 — Respuestas de comprobación

**Repositorio:** oracle-database-lab  
**Issue relacionado:** Closes #3

## 1. ¿Por qué un Issue sin criterios de aceptación es un problema?

Porque no permite saber de forma objetiva cuándo el trabajo está terminado. Aunque la descripción parezca clara, cada persona puede interpretarla de forma diferente. Los criterios de aceptación convierten el Issue en una lista verificable para el Autor y el Reviewer.

## 2. Explica la diferencia entre `Refs #N` y `Closes #N`.

`Refs #N` crea una referencia entre un commit o Pull Request y un Issue, pero no lo cierra. `Closes #N`, `Fixes #N` o `Resolves #N` indican que el cambio resuelve el Issue y GitHub lo cerrará cuando ese cambio se integre en `main`.

## 3. ¿Qué ocurre si haces `git push` directamente sobre una rama `main` protegida?

Normalmente GitHub rechaza el push e indica que los cambios deben realizarse mediante un Pull Request. En nuestra prueba, la cuenta administradora pudo omitir la regla y GitHub mostró un aviso de `Bypassed rule violations`; después se creó un commit de reversión para eliminar el cambio de prueba.

## 4. ¿Qué riesgo tiene aprobar un PR sin mirar los archivos?

Se podrían integrar errores, cambios accidentales, secretos, problemas de seguridad o cambios que no cumplen los criterios de aceptación. La descripción del PR no sustituye la revisión del diff en `Files changed`.

## 5. Si el reviewer pide un cambio, ¿hay que abrir un Pull Request nuevo?

No. El Autor debe corregir el cambio en la misma branch, hacer un nuevo commit y ejecutar `git push`. El Pull Request existente se actualiza automáticamente con el nuevo commit y conserva todo el contexto de la conversación y la revisión.

## 6. Diferencia entre Merge commit, Squash and merge y Rebase and merge

Un Merge commit conserva los commits de la branch y añade un commit de fusión. Squash and merge combina todos los commits de la branch en un solo commit. Rebase and merge reaplica los commits sobre `main` sin crear un commit de merge. Para commits como `wip`, `fix`, `fix2` y `ok ya`, usaría Squash and merge para mantener `main` limpio.

## 7. ¿Por qué borrar una branch tras el merge no elimina el trabajo?

Porque, tras el merge, los cambios ya forman parte del historial de `main`. La branch solo es un puntero a esos commits; eliminarla no elimina los commits que ya fueron integrados.

## 8. ¿Qué información debe contener un Pull Request?

Como mínimo debe incluir un resumen del cambio, los cambios realizados, cómo se ha probado y el Issue relacionado. Una estructura recomendable es: Summary, Changes, Testing y Related Issue.

## 9. ¿Qué le falta a un comentario como “esto está mal”?

Le falta indicar qué problema se ha encontrado, por qué importa, si bloquea el merge y cómo solucionarlo. Un ejemplo útil sería:

> issue (blocking): El README no enlaza a CONTRIBUTING.md, por lo que no se cumple el criterio de aceptación. Añade el enlace y verifica que funciona.

## 10. Diferencia entre proteger `main` y acordar no hacer push directo

Un acuerdo verbal depende de que las personas lo recuerden y lo cumplan. Una regla de protección se aplica técnicamente en GitHub y puede exigir Pull Request, revisiones y aprobaciones antes de permitir la integración.

## 11. Diferencia entre `issue: (blocking)` y `nitpick: (if-minor)`

`issue: (blocking)` identifica un problema que debe resolverse antes de aprobar el Pull Request. Por ejemplo:

> issue (blocking): El enlace apunta a una ruta inexistente y debe corregirse antes del merge.

`nitpick: (if-minor)` indica una mejora menor que no debe bloquear por sí sola:

> nitpick: (if-minor): Sería más consistente utilizar el mismo estilo de puntuación en todas las listas.

## 12. ¿Qué versión SemVer dispara un commit `feat!`?

Un commit `feat!` indica un cambio que rompe la compatibilidad con versiones anteriores. Por ello provoca un incremento MAJOR, por ejemplo de `2.1.0` a `3.0.0`.

## 13. ¿Por qué un Draft Pull Request puede ahorrar tiempo?

Porque permite recibir feedback sobre el enfoque general antes de invertir mucho tiempo en detalles, pruebas y documentación. Si el diseño es incorrecto, se corrige pronto y con un coste menor, aplicando el principio Fail Fast.