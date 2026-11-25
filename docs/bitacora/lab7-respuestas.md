# Laboratorio 7 · Respuestas · E033

## Parte B · C01 · Más sesiones no es más rendimiento
1. Con 1 sesión, 6,3 llamadas/s y p95 de 167,9 ms; con 8 sesiones, 14,8 llamadas/s y p95 de 986,9 ms (`20261125T173422Z_C01_entender.txt`). Con 2 sesiones, 13,0 llamadas/s y p95 de 189 ms (`20261125T173719Z_C01_validar.txt`). Recomiendo 2 sesiones, igual que CPU_COUNT: dan el 88 % del throughput de 8 con una p95 cinco veces menor. En mi equipo la tanda de 8 rinde algo más que en la referencia porque WSL deja a Oracle algo más de 2 CPU (128 de 367 muestras en CPU), y el primer intento con 2 sesiones se quedó en el 79 % porque arrancó con la máquina todavía cargada.
2. Domina `resmgr:cpu quantum`, con 239 de 367 muestras (65,1 %), y AAS 8,9 con CPU_COUNT 2 (`20261125T173422Z_C01_diagnosticar.txt`). En Oracle Free el Resource Manager limita la instancia a 2 CPU: las sesiones que sobran no trabajan, esperan turno de CPU. Es cola, no trabajo.
3. N = X · R con mis tres tandas (`20261125T173720Z_C01_observar.txt`): 6,3 × 0,155 s = 1,0 (1 sesión); 13,0 × 0,1515 s = 2,0 (2 sesiones); 14,8 × 0,5288 s = 7,8 (8 sesiones). Se cumple: con 8 sesiones el throughput casi no sube y lo que crece es el tiempo de respuesta.

## Parte C · C03 · Literales y análisis completos
1. Con literales: 5066 hard parses y 3450 ms para 5000 fichas. Con variables de enlace: 29 hard parses y 290 ms. Con CURSOR_SHARING = FORCE: 28 hard parses y 500 ms (`20261125T173801Z_C03_validar.txt` y `20261125T173803Z_C03_observar.txt`). Con literales el 84 % del tiempo era análisis (`20261125T173800Z_C03_diagnosticar.txt`).
2. FORCE cambia el literal por `:"SYS_B_0"` sin tocar la aplicación, pero lo hace con todos los literales, también con los que dan selectividad al optimizador, y deja el defecto escondido. Es un parche mientras llega la cura (variables en el código). En V$SQL lo delata una sola FORCE_MATCHING_SIGNATURE (14573098645096361820) con 765 SQL_ID distintos ejecutados una vez cada uno.

## Parte C · C04 · El informe que se desborda a TEMP
1. Antes: 5456 bloques escritos y leídos en TEMP, una pasada (1 PASS) y 6180 ms. Después: informe completo con PGA automática en 1320 ms y 0 bloques de TEMP, y TOP 100 en 150 ms, OPTIMAL y sin TEMP (`20261125T173814Z_C04_solucionar.txt`). El disparador de logon `T6.C04_LEGADO` ponía `workarea_size_policy = MANUAL` y `sort_area_size = 1 MB` a la cuenta de informes (`20261125T173812Z_C04_diagnosticar.txt`).
2. Ordenar un millón de filas necesitaba unos 48 MB en memoria y con la política MANUAL solo tenía 1 MB, así que se fue a disco. El TOP 100 es un SORT ORDER BY STOPKEY: solo guarda las 100 mejores filas mientras lee, y eso cabe en KB (`20261125T173815Z_C04_observar.txt`).

## Parte D · C07 · EXPLAIN PLAN frente al plan real
1. `filter(TO_NUMBER("CODIGO_POSTAL")=:B1)` en un TABLE ACCESS FULL de PEDIDO (`20261125T173929Z_C07_diagnosticar.txt`). La V1 pasa un NUMBER (Peeked Binds: `:B1 (NUMBER): 30038`) y la columna es VARCHAR2, así que Oracle convierte la columna en cada fila y el índice IX_T6_PED_CP ya no sirve.
2. V1: 5227 lecturas por búsqueda y p95 de 72,2 ms. V2: 95 lecturas y p95 de 1 ms (`20261125T173930Z_C07_validar.txt`). EXPLAIN PLAN no ejecuta ni conoce el tipo de la variable (la trata como texto), por eso predijo el índice. DISPLAY_CURSOR enseña lo que pasó de verdad.

## Parte D · C08 · E-Rows frente a A-Rows
1. Antes: E-Rows 3 y A-Rows 56 en CLIENTE. Después del grupo de columnas: E-Rows 50 y A-Rows 56 (`20261125T173934Z_C08_validar.txt`). Se separan por primera vez en la línea 3, TABLE ACCESS BY INDEX ROWID BATCHED de CLIENTE, donde se aplica `filter("C"."COMUNIDAD"='COM09')` (`20261125T173933Z_C08_diagnosticar.txt`). Todo lo de encima hereda el error: 28 pedidos estimados frente a 599 reales.
2. Supone que ciudad y comunidad son independientes y multiplica: 100 000 × 1/2000 × 1/18 ≈ 2,9. Pero cada ciudad está en una sola comunidad (MAX_COMUNIDADES_POR_CIUDAD = 1), así que el filtro de comunidad no quita nada. El grupo de columnas `SYS_STUBJHRJ63BYYQ61EBQAQU2TM_` cuenta las 2000 combinaciones reales (`20261125T173935Z_C08_observar.txt`).

## Parte E · C12 · Estadísticas obsoletas
1. Las estadísticas decían 100 filas en CARRITO y había 200 100 (`20261125T174019Z_C12_entender.txt`). Antes: NESTED LOOPS con 200 000 visitas al índice PK_T6_PEDIDO y 212 364 lecturas. Después de recoger: HASH JOIN y 5925 lecturas (`20261125T174021Z_C12_validar.txt`).
2. La tarea automática solo recoge en la ventana de mantenimiento (WEDNESDAY_WINDOW a las 22:00, 4 h) y con STALE_PERCENT 10 (`20261125T174022Z_C12_observar.txt`). Una carga de madrugada deja las estadísticas mal hasta la noche siguiente. Debe recoger el propio proceso de carga, con GATHER_TABLE_STATS al terminar.

## Parte E · C13 · El ciclo de estadísticas con red
1. `SET_TABLE_PREFS PUBLISH = FALSE` y recogida con histograma en ESTADO: DBA_TAB_PENDING_STATS muestra las pendientes. Las probé en mi sesión con `optimizer_use_pending_statistics = TRUE` y estimaban 185 277, igual que las reales (antes 250 000). Publiqué con PUBLISH_PENDING_STATS y volví a PUBLISH = TRUE (DBA_TAB_STATISTICS con STALE = NO). DBA_TAB_STATS_HISTORY guarda 31 días; RESTORE_TABLE_STATS devolvió ESTADO a NONE, y LOCK_TABLE_STATS dejó STATTYPE_LOCKED = ALL (`20261125T174035Z_C13_solucionar.txt` y `20261125T174045Z_C13_observar.txt`).
2. ORA-20005: object statistics are locked (stattype = ALL). Si de verdad hay que recoger, se hace con `force => TRUE` o con UNLOCK_TABLE_STATS antes, como decisión consciente.

## Parte E · C14 · El índice invisible
1. Antes: 5265 lecturas y 20,7 ms por apertura. Después: 118 lecturas y 0,4 ms (`20261125T174056Z_C14_validar.txt`). Creé IX_T6_C14_PEND (estado, canal, fecha_pedido) INVISIBLE ONLINE, lo probé solo en mi sesión con `optimizer_use_invisible_indexes = TRUE` (INDEX RANGE SCAN, 116 buffers) y después lo hice VISIBLE (`20261125T174055Z_C14_solucionar.txt`).
2. Cambiar el canal de 20 000 pedidos generó 9008 KB de redo sin el índice, 10 403 KB con él INVISIBLE y 10 402 KB VISIBLE (`20261125T174104Z_C14_observar.txt`). Un índice invisible se mantiene igual en cada DML: el optimizador no lo usa, pero cuesta lo mismo al escribir.

## Parte F · C17 · INC-604 con AWR, ASH y ADDM
1. SLI: p95 de la búsqueda por código postal. SLO: p95 < 20 ms. Antes: 103,1 ms con 3744 búsquedas. Después: 0,5 ms con 35 570 búsquedas y la misma carga (`20261125T174547Z_C17_validar.txt`). Usé las instantáneas AWR 29 y 30, que cubren exactamente la carga V1 (`20261125T174342Z_C17_entender.txt`).
2. ASH: 0dbx7196jdajy con 274 muestras ON CPU. AWR: 313,6 s y 5244 lecturas por ejecución. ADDM: Top SQL con el 96,87 % de la actividad y la recomendación de lanzar el SQL Tuning Advisor (`20261125T174345Z_C17_diagnosticar.txt`). Ninguno decía por qué; eso lo dio el plan real con `filter(TO_NUMBER("CODIGO_POSTAL")=:B1)`. El único cambio fue desplegar la V2 (BUSCAR_CP_V2, parámetro VARCHAR2): 93 lecturas por ejecución.

## Parte F · C18 · SQL Plan Management
1. Lunes: plan 1767728868 con 194 lecturas por ejecución. Martes: plan 2571571058 con 5227 lecturas, mismo SQL_ID 8hn59jfgw00y7 (`20261125T174600Z_C18_entender.txt`). Con la línea base cargada desde AWR (SQL_PLAN_0a27u7nan424ba00b9863): plan 1767728868 y 193 lecturas, sin tocar las estadísticas (`20261125T174602Z_C18_validar.txt`).
2. La evolución probó el plan nuevo (recorrido completo, AUTO-CAPTURE) y no lo aceptó: salió 0,1049 veces peor que el de la línea base, así que se queda con ACC = NO (`20261125T174603Z_C18_observar.txt`). Quedaba pendiente la causa: la preferencia METHOD_OPT = FOR ALL COLUMNS SIZE 1 de PEDIDO, que borra el histograma de ESTADO en cada recogida. La corregí en mi incidente INC-608.

## Parte G · Incidente 1 · INC-605
- **Síntoma (con números):** el informe de cestas abandonadas tarda más desde la carga. Las estadísticas de CESTA decían 100 filas y había 183 100 (183 000 nuevas), y el informe unía con bucles anidados (`20261125T174908Z_INC-605_verificar.txt`).
- **Playbook y pasos seguidos (herramientas y vistas):** PB-3 · El plan cambió. `incidente INC-605 pistas`, la primera verificación y `t6 estad CESTA` (`20261125T174909Z_t6-estad.txt`), que muestra las estadísticas bloqueadas (STATTYPE_LOCKED = ALL) y obsoletas.
- **Causa raíz:** las estadísticas de CESTA se recogieron con 100 filas y se bloquearon. La tarea automática se salta las tablas bloqueadas, así que la carga de 183 000 filas nunca llegó a las estadísticas.
- **Arreglo aplicado (órdenes exactas) y por qué ese:** `DBMS_STATS.UNLOCK_TABLE_STATS('T6', 'CESTA')` y `DBMS_STATS.GATHER_TABLE_STATS('T6', 'CESTA', no_invalidate => FALSE)` (`20261125T174914Z_INC-605_arreglo.txt`). Quito el bloqueo en vez de usar `force`, porque CESTA crece en cada carga y bloquearla fue el error.
- **Verificación (archivo de evidencia con todo OK):** `20261125T174914Z_INC-605_verificar.txt`: 183 100 filas en las estadísticas y 183 100 reales, el informe une con HASH JOIN y ya no hay bloqueo.
- **Prevención (qué evitaría que se repita):** que el proceso de carga recoja las estadísticas de CESTA al terminar y no bloquear tablas que crecen; solo se bloquean tablas de trabajo con estadísticas representativas.

## Parte G · Incidente 2 · INC-608
- **Síntoma (con números):** el informe de pedidos en estado P leía la tabla entera. El optimizador estimaba 250 000 filas y eran 20 000, y ESTADO no tenía histograma (`20261125T175117Z_INC-608_verificar.txt`).
- **Playbook y pasos seguidos (herramientas y vistas):** PB-3 · El plan cambió. `incidente INC-608 pistas`, la primera verificación y `t6 estad PEDIDO` (`20261125T175118Z_t6-estad.txt`): histograma NONE en ESTADO, preferencia METHOD_OPT = FOR ALL COLUMNS SIZE 1 y una recogida reciente en el historial.
- **Causa raíz:** la preferencia de tabla METHOD_OPT = FOR ALL COLUMNS SIZE 1 hace que cada recogida, también la nocturna, borre el histograma de ESTADO. Sin histograma reparte las filas por igual entre los 4 estados.
- **Arreglo aplicado (órdenes exactas) y por qué ese:** `SET_TABLE_PREFS('T6', 'PEDIDO', 'METHOD_OPT', 'FOR ALL COLUMNS SIZE 1 FOR COLUMNS ESTADO SIZE 254')`, y después el runbook RB-2: PUBLISH = FALSE, GATHER_TABLE_STATS, prueba con `optimizer_use_pending_statistics = TRUE` (estimación de 20 000 con IX_T6_PED_ESTADO), PUBLISH_PENDING_STATS y PUBLISH = TRUE (`20261125T175135Z_INC-608_arreglo.txt`). Cambio la preferencia porque recoger sin más lo habría arreglado solo hasta la noche siguiente.
- **Verificación (archivo de evidencia con todo OK):** `20261125T175143Z_INC-608_verificar.txt`: estimación de 20 000 filas frente a 20 000 reales, histograma FREQUENCY y METHOD_OPT con ESTADO SIZE 254.
- **Prevención (qué evitaría que se repita):** revisar y documentar las preferencias de las tablas críticas (DBMS_STATS.GET_PREFS) antes de cambiarlas, y una comprobación que avise si una columna con datos sesgados pierde su histograma.

## Parte G · Incidente 3 · INC-610
- **Síntoma (con números):** varias pantallas cambiaron de plan a la vez. La V2 de la búsqueda por código postal ya no usaba IX_T6_PED_CP (`20261125T175434Z_INC-610_verificar.txt`).
- **Playbook y pasos seguidos (herramientas y vistas):** PB-3 · El plan cambió: si cambian muchos planes a la vez, la causa es común. `t6 salud` en VERDE (AAS 0,2), así que no era carga (`20261125T175435Z_t6-salud.txt`). En V$SYSTEM_PARAMETER con ISDEFAULT = FALSE no salió nada desde la PDB, pero V$SPPARAMETER mostró optimizer_index_cost_adj = 4100 guardado en el SPFILE de la PDB (`20261125T175435Z_INC-610_diagnostico.txt`).
- **Causa raíz:** un cambio de parámetro a nivel de PDB con SCOPE = BOTH: optimizer_index_cost_adj = 4100 hace que todo acceso por índice parezca 41 veces más caro, así que el optimizador elige recorridos completos en todas las consultas.
- **Arreglo aplicado (órdenes exactas) y por qué ese:** `ALTER SYSTEM SET optimizer_index_cost_adj = 100 SCOPE = MEMORY;` y `ALTER SYSTEM RESET optimizer_index_cost_adj SCOPE = SPFILE;` en FREEPDB1 (`20261125T175441Z_INC-610_arreglo.txt`). El primero lo corrige ya; el RESET lo quita del SPFILE de la PDB para que no vuelva tras un reinicio. Cambiarlo solo en mi sesión no habría arreglado nada.
- **Verificación (archivo de evidencia con todo OK):** `20261125T175440Z_INC-610_verificar.txt`: valor 100, nada en el SPFILE de la PDB y la V2 vuelve a usar IX_T6_PED_CP.
- **Prevención (qué evitaría que se repita):** ningún cambio de parámetros del optimizador sin ticket y sin medir antes y después, y una comprobación periódica de V$SPPARAMETER en la PDB que avise de parámetros del optimizador fuera de su valor por defecto.

## Parte H · Reflexión
1. El cambio con más mejora y menos riesgo fue el tipo de dato de la búsqueda por código postal (C07 y C17): un solo cambio en la llamada, sin tocar la base, pasó de 5244 a 93 lecturas por ejecución y la p95 de 103,1 ms a 0,5 ms, atendiendo 35 570 búsquedas en lugar de 3744 con la misma carga (`20261125T174547Z_C17_validar.txt`).
2. No he hecho casos sin ★.
