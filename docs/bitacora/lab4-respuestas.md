# Lab 4 — Respuestas

Todas las rutas de evidencia son relativas a `docs/bitacora/lab4/evidencia/`. Abreviaturas: `00` = `script/20261024T110508Z_00-backup-lab3.script.log`, `05-sql` = `spool/20261024T112623Z_05-instancia-y-base.spool.log`, etc. (el número es el de la evidencia).

## Hallazgos iniciales del diagnóstico (Parte A)

- Archivos FUERA del volumen en la copia: **0** (`00`, sección 3, y `manifiesto.txt`: `archivos_fuera_del_volumen=0`).
- Motivo: V000 creó los 5 datafiles `TBS_*` con ruta relativa y sin OMF (`db_create_file_dest` vacío, `01` sección 5), así que Oracle los creó en `$ORACLE_HOME/dbs`. En esta imagen `$ORACLE_HOME/dbs` es un enlace simbólico a `/opt/oracle/oradata/dbconfig/FREE/dbs`, dentro del volumen (`01`, sección B: «DENTRO del volumen, pero en carpeta no estándar»).
- Siguen siendo un defecto: carpeta no estándar y dependencia de un enlace de la imagen. Corregido en la Parte C (`03-reubicar`).
- Hallazgo adicional: la base está en **ARCHIVELOG** (el enunciado espera NOARCHIVELOG) y sin FRA (`01` sección 2; `07-lectura`: `db_recovery_file_dest` vacío). Por eso aparecen procesos ARCn (`09-sql`, sección 3: 4 procesos) y redo archivados (`11-sql`: 6 archivos, 375 MB).

### Informe de diagnóstico (reto de la Parte A)

1. Datafiles de negocio en carpeta no estándar mediante un enlace de la imagen — riesgo medio (sobreviven a `docker rm`, pero una actualización de imagen podría romperlo) — 1.º, porque es la base de la prueba de persistencia.
2. Contraseñas de los 5 propietarios en V000 (historial de Git) — riesgo alto — 2.º, invalidarlas con V003.
3. `sys/<contraseña>` en la línea de comandos de 08 — riesgo alto — 3.º, 08 v2 con `/ as sysdba`.
4. Puerto 8181 publicado sin servicio — riesgo bajo — 4.º, 05 v2.
5. ARCHIVELOG sin FRA — riesgo medio (los archivados crecen sin control) — se documenta y se trabaja en el Lab 5.

### Reto de la Parte B: ¿dar el rol DBA a C##OPS_RO?

- Riesgo 1: con DBA la cuenta puede modificar y borrar objetos de cualquier esquema; un error en una consulta de monitorización o una credencial filtrada se convierte en un incidente de escritura.
- Riesgo 2: DBA incluye privilegios `ANY` de escritura y de administración de usuarios, así que quien robe la cuenta puede crear cuentas nuevas y escalar privilegios.
- Lo correcto para leer el alert log es un GRANT puntual: `GRANT SELECT ON sys.v_$diag_alert_ext TO c##ops_ro CONTAINER = ALL;` (`11-ampliar`: `C##OPS_RO V_$DIAG_ALERT_EXT SELECT YES`). La verificación final comprueba que la cuenta no tiene privilegios `ANY` de escritura (`16`: TODO OK).

---

## Preguntas de comprobación

### Respaldo y diagnóstico (A)

**1. ¿Por qué la copia de la Parte A es consistente? ¿Qué pasaría si se tomara con la base abierta?**
Se tomó tras `SHUTDOWN IMMEDIATE` (`00`, sección 4: «Database closed / dismounted / ORACLE instance shut down»): Oracle hizo un checkpoint final, todos los datafiles comparten el mismo SCN en su cabecera y no hay transacciones a medias, así que se puede abrir sin aplicar redo. Con la base abierta, cada archivo se copiaría en un instante distinto (cabeceras con SCN diferentes y bloques a medio escribir): sería inconsistente y solo serviría con ARCHIVELOG y una recuperación con RMAN.

**2. ¿Para qué sirven `manifiesto.txt` y `SHA256SUMS`? ¿Qué comprueba `restaurar-estado.sh` antes de tocar nada?**
`manifiesto.txt` describe la copia: etiqueta `lab3-final`, fecha `20261024T110623Z`, contenedor, volumen, imagen, commit `f4d6764`, tipo «copia en frío consistente» y `archivos_fuera_del_volumen=0`. `SHA256SUMS` guarda la huella de cada archivo para detectar corrupción o manipulación (`sha256sum --check` dio OK en los cuatro archivos). `restaurar-estado.sh` verifica primero esas sumas; si alguna falla se detiene sin tocar el volumen. Después pide escribir el nombre del volumen como confirmación.

**3. Define RPO y RTO con los datos de tu propia copia.**
RPO (cuántos datos puedo perder): todo lo hecho después de la copia del 24-10-2026 a las 11:06 UTC; por ejemplo, la reubicación, V002 y V003 se perderían si restaurase ahora esa copia. RTO (cuánto tardo en volver a dar servicio): lo que tarda `restaurar-estado.sh` en descomprimir 585 MB y arrancar. La copia completa (parada, compresión y arranque) tardó unos 2 minutos (carpeta `110448Z`, manifiesto `110623Z`, y `healthy` a los 10 s del arranque, `00` sección 8); la restauración será del mismo orden, aproximadamente 1-2 minutos. Se medirá con exactitud en el simulacro del Lab 5.

### Correcciones del Lab 3 (C, D)

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?**
En `$ORACLE_HOME/dbs` (`/opt/oracle/product/26ai/dbhomeFree/dbs/academia01.dbf`, etc.; `01` sección 4, FILE# 16-20), porque V000 usó una ruta relativa y, sin `DB_CREATE_FILE_DEST`, Oracle resuelve las rutas relativas desde `$ORACLE_HOME/dbs`. En mi imagen esa carpeta es un enlace al volumen (`dbconfig/FREE/dbs`), por eso no se perdían, pero estaban en una carpeta no estándar. `DB_CREATE_FILE_DEST=/opt/oracle/oradata` (OMF) lo habría evitado.

**5. ¿Por qué `ALTER TABLESPACE ... RENAME DATAFILE` no basta para mover un archivo?**
Porque solo cambia la ruta que guarda el control file; no copia ni mueve nada en disco. Por eso `03-reubicar` primero pone el tablespace `OFFLINE NORMAL`, copia el archivo con `cp -p`, después hace `RENAME`, lo pone `ONLINE` (Oracle valida la cabecera del archivo nuevo) y solo entonces borra el original (`03-reubicar`, pasos a-d).

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?**
V000 ya se aplicó: una migración aplicada es historia y editarla haría que el repositorio no describa lo que realmente se ejecutó (migraciones solo hacia delante). Borrar la contraseña del archivo no sirve porque sigue en el historial de Git; invalidarla con `ALTER USER ... NO AUTHENTICATION` hace que ya no funcione. Lo comprobé: `admin_academia` con la contraseña de V000 da `ORA-01017`, y V003 muestra las 5 cuentas con `AUTHENTICATION_TYPE = NONE` (`04-V003`).

**7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?**
Demuestra que todo el estado de la base vive en el volumen: se borró el contenedor (`docker rm`), se recreó con 05 v2 (contenedor nuevo `e80caab80b6e`) y los 5 tablespaces y las 14 tablas seguían igual (`03-persistencia`, secciones 1 y 4). Se ejecuta después de reubicar porque, si los datafiles hubieran estado en la capa del contenedor, `docker rm` los habría destruido. Además confirma que ya no se publica el 8181 (sección 5: solo `1521/tcp`).

### Instancia, arranque y parámetros (E, F)

**8. Con tus evidencias: tres datos que pertenecen a la instancia y tres que pertenecen a la base de datos.**
Instancia (`05-sql` y `05-so`): `HOST_NAME = e80caab80b6e` (cambió desde `846079d08b90` en `01` al recrear el contenedor), `ARRANCADA = 2026-10-24 11:15:13` y la SGA de 1536 MB con 60 procesos de background `db_*_FREE`. Base de datos: `DBID = 1509902213` (no cambió al recrear el contenedor, `15`), `CREADA = 2026-07-05` y sus archivos: 16 datafiles (4034 MB), 3 miembros de redo y 2 control files.

**9. ¿Qué lee Oracle en NOMOUNT, en MOUNT y en OPEN? Relaciónalo con ORA-01507 y ORA-01219.**
NOMOUNT: lee el SPFILE, reserva la SGA y arranca los procesos; `v$parameter` ya responde, pero `v$database` da **ORA-01507** porque todavía no ha leído el control file. MOUNT: abre los control files y conoce la estructura (`v$database` muestra `MOUNTED ARCHIVELOG`, 16 datafiles conocidos), pero `dba_tables` da **ORA-01219** porque el diccionario está en el tablespace SYSTEM, cuyo datafile sigue cerrado. OPEN: abre datafiles y redo online (`06-etapas`).

**10. Diferencia entre `v$parameter` y `v$spparameter` con el ejemplo de `db_files` de tu evidencia.**
`v$parameter` es el valor en memoria (el que usa la instancia ahora) y `v$spparameter` lo escrito en el SPFILE (lo que se usará en el próximo arranque). Con `SCOPE=SPFILE`, `db_files` quedó `200` en memoria y `300` en el SPFILE: cambio pendiente. Tras `RESET`, el SPFILE quedó «(no especificado)» y el parámetro vuelve a su valor por defecto (`07-cambios`, bloque 3).

**11. ¿Por qué PROCESSES rechaza el cambio en memoria aunque `v$parameter` lo marque IMMEDIATE?**
`07-lectura` muestra `processes ... SYS_MOD = IMMEDIATE`, pero `ALTER SYSTEM SET processes = 250 SCOPE = MEMORY` da `ORA-02097` / `ORA-02095` (`07-cambios`, bloque 4). PROCESSES dimensiona estructuras de la SGA que se reservan al arrancar, así que en la práctica es estático: se cambia con `SCOPE=SPFILE` y reinicio. La metadata orienta; la prueba decide.

### Memoria y procesos (G, H)

**12. ¿Qué modelo de gestión de memoria usa tu instancia? Justifícalo con tres parámetros.**
ASMM (gestión automática de la memoria compartida): `memory_target = 0` y `memory_size = 0` (no hay AMM), `sga_target = 1536M` (Oracle reparte la SGA entre buffer cache, shared pool y large pool) y `pga_aggregate_target = 512M` (la PGA se gestiona aparte). `db_cache_size = 0` y `shared_pool_size = 0` significan «sin mínimo fijado» (`08-memoria`, sección 1). El reparto actual: buffer cache 992 MB, shared pool 416 MB (sección 4).

**13. Explica las cifras de tu experimento de caché: lecturas lógicas, físicas y tasa de acierto.**
Ronda 1 (caché fría): 359 lógicas y 262 físicas; ronda 2 (caché caliente): 247 lógicas y 0 físicas (`08-cache`). Toda lectura física termina en una lógica (el bloque se trae a la caché y se lee desde ahí). En la ronda 1 hay más lógicas y físicas que bloques (244) porque, tras el FLUSH, también hubo que leer la cabecera del segmento y bloques del diccionario para analizar la consulta. Al final quedan 245 bloques de la tabla en caché (244 + la cabecera del segmento, `v$bh`). Tasa de acierto: ronda 1 = 1 − 262/359 ≈ 27 %; ronda 2 = 1 − 0/247 = 100 %.

**14. Compara literales y variables de enlace con tus cifras de análisis y de V$SQL.**
1000 consultas con literales: 1051 análisis, 1008 duros, 600 ms de CPU de análisis y 650 ms en total. Con `:id`: 1 análisis duro, 0 ms de CPU y 10 ms en total (`08-parse`). En V$SQL, los literales dejaron 713 cursores distintos (26 314 KB de shared pool; el resto ya había sido expulsado), frente a 1 cursor con 1000 ejecuciones (39 KB). Las variables de enlace reutilizan el cursor y ahorran CPU y memoria.

**15. Relaciona el SPID de LGWR de `v$process` con el PID de `/proc`. ¿Por qué `docker top` muestra otro número?**
`v$process` da `LGWR SPID 1383` (`09-sql`) y `/proc` dentro del contenedor muestra `1383 db_lgwr_FREE` (`09-so`, sección 4): es el mismo proceso. `docker top` muestra el PID del anfitrión (por ejemplo, PMON aparece como 4748 en `05-so`, frente a SPID 1333 en `09-sql`) porque el contenedor tiene su propio espacio de nombres de PID.

### Contenedores (I)

**16. ¿Por qué SYS ve 16 datafiles desde la raíz y 9 desde FREEPDB1?**
Desde `CDB$ROOT`, `V$DATAFILE` muestra todos los contenedores: CON_ID 1 = 4, CON_ID 2 (PDB$SEED) = 3 y CON_ID 3 (FREEPDB1) = 9, en total 16. Dentro de FREEPDB1 las mismas vistas solo devuelven la fila de su contenedor: CON_ID 3 = 9 (`10-que-ve`, secciones 1 y 2).

**17. ¿Por qué LAB4_ANALISTA recibe ORA-00942 y no «privilegios insuficientes» al consultar DBA_TABLES?**
Porque Oracle no revela la existencia de objetos que el usuario no puede ver: sin privilegio, la vista simplemente «no existe» para él (`ORA-00942: table or view "SYS"."DBA_TABLES" does not exist`, `10-que-ve`, 3a). Decir «sin privilegios» confirmaría que el objeto existe.

**18. ¿Qué diferencia hay entre C##LAB4_AUDITOR y C##OPS_RO? ¿Qué sentencia los igualaría?**
Los dos son comunes, pero C##LAB4_AUDITOR no tiene el atributo CONTAINER_DATA: desde la raíz solo ve CON_ID 1 (5 tablespaces) y CON_ID 0. C##OPS_RO tiene `DEFAULT_ATTR = Y, ALL_CONTAINERS = Y` y ve todas las PDB (`10-que-ve`, secciones 5 y 6). Los igualaría `ALTER USER c##lab4_auditor SET CONTAINER_DATA = ALL CONTAINER = CURRENT;`.

**19. ¿Qué ventaja tiene GRANT READ ANY TABLE ON SCHEMA frente a conceder tabla por tabla? ¿Y qué riesgo?**
Ventaja: un solo GRANT cubre todas las tablas del esquema, también las que se creen después, y se limita a ese esquema (LAB4_ANALISTA leyó las 3 tablas y 20 000 estudiantes de ADMIN_ACADEMIA, pero `admin_clinica` siguió dando ORA-00942 y el UPDATE dio `ORA-41900`; `10-que-ve`, sección 4). Riesgo: cualquier tabla nueva, aunque contenga datos sensibles, queda legible automáticamente sin que nadie lo revise.

**20. ¿Qué valor tiene COMMON_USER_PREFIX en tu base y qué consecuencia tuvo en el bloque 3a de 10-ciclo-vida-pdb?**
En mi base vale `C##` (`10-ciclo`, sección 3). Por eso `CREATE USER lab4_local` en la raíz falló con `ORA-65096: common user or role name must start with prefix C##` y no se creó ningún usuario común por error.

### Archivos (J)

**21. Clasifica los archivos de tu evidencia 11 en «son la base de datos» y «relacionados». ¿Dónde va el password file y por qué?**
Son la base de datos: 16 datafiles, 2 control files y 3 redo online (los tempfiles también, pero no se copian: se recrean). Relacionados: SPFILE, password file, ADR (alert log y trazas), 6 redo archivados y la configuración de red (`listener.ora`, `sqlnet.ora`, `tnsnames.ora`) (`11-sql`, secciones 1-3, y `11-so`). El password file es relacionado: no guarda datos, pero permite autenticar SYSDBA por red (`v$pwfile_users`: `SYS TRUE TRUE`). Vive en `$ORACLE_HOME/dbs/orapwFREE`, que en esta imagen apunta al volumen, así que entra en la copia.

**22. Explica por qué `academia01.dbf` mide 104 865 792 bytes en Linux si `v$datafile` dice 100 MB.**
100 MB = 104 857 600 bytes de bloques de datos. Linux muestra 104 865 792 = 104 857 600 + 8192: un bloque más, la cabecera del archivo (bloque 0) que Oracle añade y que no cuenta en el tamaño del datafile (`11-so`, sección 1, y `11-sql`).

**23. ¿Qué dos puntos únicos de fallo ves en los control files y en el redo de tu base?**
Los 2 control files están en la misma carpeta y disco (`/opt/oracle/oradata/FREE/control01.ctl` y `control02.ctl`), y cada grupo de redo tiene un solo miembro (`redo01-03.log`, 3 miembros para 3 grupos) (`11-sql`, sección 1). Perder ese disco o un miembro de redo deja la base sin poder abrir o sin recuperación completa.

**24. ¿Por qué el ADR fuera del volumen es un problema operativo aunque la base no pierda datos?**
`diagnostic_dest = /opt/oracle` deja el ADR en la capa del contenedor (`11-so`, sección 4: «NO: ... Al recrearlo, el alert log empieza de cero»). Al recrear el contenedor se pierde el historial de errores y trazas que se necesita para diagnosticar incidentes; de hecho, la autopsia solo ve errores posteriores a la prueba de persistencia.

### Bloque y fila (K)

**25. Descompón el ROWID de tu estudiante 101 en objeto, bloque y fila, y comprueba cada trozo con DBMS_ROWID.**
ROWID `AAAR2zAAAAAAAMOAAF` (`12-bloque`, sección 4), en base 64 (A=0 … Z=25, a=26 … z=51, 0=52 … 9=61):
- Objeto `AAAR2z` = 17·64² + 54·64 + 51 = **73139** = `DATA_OBJECT_ID` de ACA_ESTUDIANTES.
- Archivo `AAA` = 0: en un tablespace BIGFILE el ROWID no lleva número de archivo relativo; el archivo absoluto (16, `academia01.dbf`, `relative_fno 1024`) se obtiene con `ROWID_TO_ABSOLUTE_FNO`.
- Bloque `AAAAMO` = 12·64 + 14 = **782**.
- Fila `AAF` = **5**.
DBMS_ROWID (con `'BIGFILE'`) devuelve archivo 16, bloque 782 y fila 5: coincide.

**26. Del volcado: ¿qué significan nrow, fsbo, fseo y avsp? Demuestra que avsp = fseo − fsbo con tus números.**
`nrow = 90`: filas en el bloque. `fsbo = 0xc6`: inicio del espacio libre (fin del directorio de filas). `fseo = 0x427`: fin del espacio libre (donde empiezan los datos de las filas). `avsp = 0x361`: espacio disponible. 0x427 − 0xc6 = 1063 − 198 = 865 = 0x361 (`12-bloque`, sección 7 [B]).

**27. Explica la línea de la ITL con Lck = 90 y Flag --U-. ¿Qué es la limpieza diferida de bloques?**
La ITL 0x01 pertenece a la transacción `0x0003.00b.0000027a` que insertó las 90 filas del bloque (V002). `--U-` indica que la transacción ya confirmó (commit rápido con SCN de límite superior), pero `Lck = 90` muestra que las 90 filas siguen marcadas con su byte de bloqueo, porque Oracle no volvió al bloque a limpiarlas al hacer COMMIT. La limpieza diferida (delayed block cleanout) consiste en que la siguiente sesión que visite el bloque comprueba que la transacción terminó y limpia esas marcas.

**28. Calcula los 78 bytes de la fila 101 a partir de cabecera, bytes de longitud y datos.**
`tl: 78`, `cc: 7` (`12-bloque`, sección 7 [C]). Cabecera de fila: 3 bytes (flag, byte de bloqueo y número de columnas). Bytes de longitud: 7, uno por columna (todas miden menos de 250 bytes). Datos: 3 + 9 + 9 + 11 + 19 + 6 + 11 = 68 bytes (coincide con `BYTES_DE_DATOS_FILA_101 = 68`). Total: 3 + 7 + 68 = **78**.

### Capacidad y coste (L)

**29. Calcula bfr y b de ACA_ESTUDIANTES con la fórmula de la Unidad 3 y explica por qué la tabla real tiene 244 bloques.**
bfr = ⌊(8192 − 96) · (1 − 0,10) / 76⌋ = ⌊7286,4 / 76⌋ = 95 filas/bloque; b = ⌈20 000 / 95⌉ = 211 bloques (`13-capacidad`, sección 3). La tabla real tiene 244 porque: la cabecera real del bloque es mayor (con 122 bytes y 2 bytes de directorio por fila sale bfr = 93 y b = 216); las filas no miden todas 76 bytes, así que el llenado real va de 68 a 95 filas por bloque (media 86,6 en 231 bloques con filas, sección 2); y bajo la HWM hay bloques casi vacíos y bloques de gestión de ASSM (13 bloques con 75-100 % libre y 1 con 25-50 %, `12-bloque` sección 6): 231 + 13 = 244.

**30. Con tus cifras de 5a, 5b y 5c, ¿cuánto cuesta una lectura lógica, una física aleatoria y un bloque secuencial?**
Lógica: 2,28 µs. Física aleatoria: 10,4 µs. Secuencial: 25,3 ms / 4595 bloques ≈ 5,5 µs por bloque (Bw = 1418 MB/s). Cociente c_sec/c_aleat = 0,53, y el umbral de rentabilidad del índice queda en el 0,62 % de las filas (`13-capacidad`, sección 5).

**31. Recalcula el umbral de rentabilidad de la sección 5d suponiendo un HDD (Bw = 150 MB/s, lat = 5 ms).**
c_sec por bloque = 8192 B / 150 MB/s ≈ 0,052 ms. c_aleat = 5 ms. Cociente = 0,052 / 5 ≈ 0,0104. Umbral = (1 / bfr) · cociente = (1 / 86) · 0,0104 ≈ 0,00012 = **0,012 % de las filas**. En un HDD el índice solo compensa si la consulta devuelve una fracción mínima de la tabla; con más filas gana el recorrido completo.

**32. ¿Por qué la «lectura física» sale en microsegundos en el contenedor? ¿Invalida eso el método?**
Porque muchas «lecturas físicas» de Oracle las sirve la caché de páginas de Linux: `FLUSH BUFFER_CACHE` vacía la caché de Oracle, no la del sistema operativo (`13-capacidad`, nota final; `v$system_event` muestra unos 88-90 µs por espera). No invalida el método: la fórmula y la forma de medir son las mismas; en producción, con almacenamiento real, las latencias saldrán del orden de 0,1-10 ms.

### Filas migradas y encadenadas (M)

**33. Diferencia migración y encadenamiento: causa, cómo se detecta y cómo se cura.**
Migración: una fila que cabía en su bloque crece con un UPDATE y ya no cabe; se muda a otro bloque y deja en el original solo la cabeza con un puntero (`fb: --H-----` con `nrid`, `14-filas`, sección 5). Encadenamiento: la fila no cabe en ningún bloque (ANCHA, ~12 000 bytes con bloques de 8 KB) y se reparte en trozos. Ambos se detectan con `ANALYZE ... LIST CHAINED ROWS` / `CHAIN_CNT` y con la estadística «table fetch continued row». La migración se cura reorganizando con un PCTFREE mayor (`ALTER TABLE ... MOVE`: CHAIN_CNT pasó de 1000 a 0 con PCTFREE 20); el encadenamiento solo se cura con un bloque mayor o rediseñando la tabla.

**34. Explica el 3,2 de lecturas lógicas por búsqueda de la sección 4 a partir del 20 % de filas migradas.**
Una búsqueda por clave normal cuesta 3 lecturas lógicas (los bloques del índice más el bloque de la tabla). Las filas migradas (20 %) necesitan una lectura extra para seguir el puntero: 3 + 0,20 · 1 = 3,2. Coincide con `table fetch continued row = 200` en 1000 búsquedas y 3200 lecturas lógicas (`14-filas`, sección 4).

**35. ¿Por qué ALTER TABLE ... MOVE deja el índice UNUSABLE? ¿Qué harías en producción?**
MOVE reescribe las filas en bloques nuevos y les da ROWID nuevos; el índice sigue apuntando a los ROWID antiguos, así que queda `UNUSABLE` (`PK_MIGRA UNUSABLE`, `14-filas`, sección 7) hasta reconstruirlo (`ALTER INDEX ... REBUILD`, después `VALID`). En producción usaría `ALTER TABLE ... MOVE ONLINE`, que mantiene los índices válidos y no bloquea el DML.

### Autopsia y trabajo profesional (N, O)

**36. Elige tres hallazgos de tu autopsia y escribe para cada uno riesgo, acción y prioridad.**
(Detalle completo en `docs/bitacora/lab4-autopsia.md`.)
1. ARCHIVELOG sin FRA (7 archivados, 574 MB; `db_recovery_file_dest_size = 0`) — riesgo: los archivados crecen sin control y pueden llenar el disco — acción: configurar FRA con tamaño máximo y copias RMAN (Lab 5) — prioridad alta.
2. Control files y redo sin multiplexar (2 control files en la misma carpeta, 1 miembro por grupo) — riesgo: punto único de fallo — acción: multiplexar en otra ubicación (Lab 5) — prioridad alta.
3. Cuatro esquemas sin estadísticas (ALTURA_MAX vacía en CLINICA, FINTECH, LOGISTICA y RETAIL) — riesgo: planes de ejecución a ciegas — acción: `DBMS_STATS.GATHER_SCHEMA_STATS` — prioridad media.

**37. ¿Por qué C##OPS_RO y no SYSTEM para observar? ¿Qué no puede hacer C##OPS_RO?**
Por mínimo privilegio: para mirar no hace falta poder modificar, y un despiste o una credencial filtrada con SYSTEM pueden borrar o cambiar datos. C##OPS_RO solo tiene `CREATE SESSION`, `SET CONTAINER`, `SELECT_CATALOG_ROLE`, `CONTAINER_DATA = ALL` y `SELECT` sobre `V_$DIAG_ALERT_EXT`. No puede hacer DML ni DDL, ni crear usuarios, ni arrancar o parar la base, ni cambiar parámetros (la verificación final comprueba que no tiene privilegios `ANY` de escritura).

**38. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?**
1. Las contraseñas de los 5 propietarios de esquema escritas en V000 (y en el historial de Git): invalidadas con V003 (`NO AUTHENTICATION`).
2. La contraseña de SYS en la línea de comandos (`sys/<contraseña>@...` en 08, visible con `ps` y en el historial): sustituida por `/ as sysdba` en 08 v2. Además, 05 v2 ya no pasa `ORACLE_PWD` al reutilizar el volumen y C##OPS_RO recibe su contraseña por la entrada estándar desde `config/.env`.

---

## Preguntas tipo examen

| P | Respuesta | Justificación |
|---|---|---|
| P1 | A, D | Tras SHUTDOWN IMMEDIATE la copia es consistente (mismo SCN, sin redo pendiente) y se abre con STARTUP; no exige ARCHIVELOG ni RMAN (`00`). |
| P2 | B | En Standard Edition no hay MOVE DATAFILE online; el método offline es OFFLINE, copia, RENAME y ONLINE (`03-reubicar`). |
| P3 | A, C | STARTUP_TIME es de la instancia y cambia en cada arranque; CREATED es la fecha de creación de la base (2026-07-05 en `05-sql`). El DBID no cambia al recrear el contenedor. |
| P4 | A, C | En NOMOUNT la instancia ya tiene el SPFILE en memoria (v$parameter respondió en `06-etapas`) y es la etapa para CREATE CONTROLFILE. |
| P5 | B | ALTER DATABASE ARCHIVELOG exige la base en MOUNT. |
| P6 | B | Con SPFILE, el SCOPE por defecto es BOTH: memoria y SPFILE. |
| P7 | C | PROCESSES no es modificable por PDB: ORA-65040 (`07-cambios`, bloque 5). |
| P8 | A, C | Se arranca con un PFILE bueno y se regenera el SPFILE con CREATE SPFILE FROM PFILE. |
| P9 | B | Con SGA_TARGET > 0 manda ASMM y DB_CACHE_SIZE actúa como mínimo. |
| P10 | A, D | El área de ordenación y la memoria de sesión (en servidor dedicado) están en la PGA; shared pool, log buffer y buffer cache son SGA. |
| P11 | C | El COMMIT espera a que LGWR escriba el redo en los redo logs online. |
| P12 | B, D | PMON y SMON son obligatorios (aparecen en `09-sql`); ARC0 solo existe en ARCHIVELOG. |
| P13 | B | Dentro de una PDB, V$DATAFILE solo devuelve su CON_ID: 3 con 9 archivos (`10-que-ve`). |
| P14 | B | CONTAINER_DATA = ALL es lo que permite ver todas las PDB desde la raíz (`10-que-ve`, sección 6). |
| P15 | A, D | El privilegio de esquema incluye las tablas futuras y no abre otros esquemas (ORA-00942 en admin_clinica, `10-que-ve`). |
| P16 | B, D | Control files y redo online forman la base; password file, SPFILE y alert log son relacionados (`11-sql`). |
| P17 | C | Sin ARCHIVELOG ni multiplexación, solo queda restaurar la última copia y se pierde lo posterior. |
| P18 | B | Sin 'BIGFILE', la función reparte los bits como en SMALLFILE; con 'BIGFILE' sale el bloque 782 (`12-bloque`). |
| P19 | A, B | PCTFREE reserva espacio para que las filas crezcan con UPDATE y el bloque deja de aceptar INSERT al bajar de ese margen. |
| P20 | B | bfr = ⌊(8192 − 96) · 0,9 / 180⌋ = ⌊40,48⌋ = 40; b = 2 000 000 / 40 = 50 000. |
| P21 | B | «db file scattered read» son lecturas multibloque a la caché (`13-capacidad`, sección 6). |
| P22 | A, C | LIST CHAINED ROWS identifica las filas y MOVE ONLINE con más PCTFREE cura la migración (`14-filas`). DBMS_STATS no calcula CHAIN_CNT. |
| P23 | B | 12 000 bytes no caben en un bloque de 8 KB: encadenada, y MOVE no lo arregla (ANCHA, `14-filas`, sección 6). |
| P24 | B | Cuenta común de solo lectura con CONTAINER_DATA y el GRANT puntual del alert log, como C##OPS_RO. |
| P25 | B | PDB$SEED es la plantilla de solo lectura (PDB_LAB4 se creó desde ella, `10-ciclo`). |
| P26 | C | Un nombre con C## en una PDB da ORA-65094 (`10-ciclo`, 3b). |
| P27 | B | Primero CLOSE IMMEDIATE y después DROP ... INCLUDING DATAFILES; abierta da ORA-65025 (`10-ciclo`, sección 5). |
| P28 | A, C | V$DATAFILE y V$LOG leen el control file, disponible en MOUNT; las DBA_/CDB_ necesitan el diccionario. |
| P29 | A | KCC es la capa del control file: V$LOG lee X$KCCLE (`10-diccionario`, sección 4). |
| P30 | B | Las CDB_ existen en la raíz y en cada PDB; desde una PDB solo devuelven sus filas (`10-que-ve`, sección 2). |
| P31 | B | Los tempfiles no se respaldan: se recrean (`11-sql`, sección 6). |
| P32 | B | La instancia ya leyó el SPFILE al arrancar y sigue funcionando; se recrea con CREATE SPFILE FROM MEMORY. |
| P33 | B | V$PWFILE_USERS (`11-sql`, sección 4). |
| P34 | A, B | La cabecera del bloque contiene la ITL y el directorio de filas (`12-bloque`, [A] y [B]). |
| P35 | B | AUTOALLOCATE empieza con extensiones de 64 KB (8 bloques) y luego de 1 MB (16 de 64 KB y después 1024 KB en `12-bloque`, sección 3). |
| P36 | B | ASSM gestiona el espacio libre de los bloques con mapas de bits (`12-bloque`, sección 1: SSM AUTO). |
| P37 | B | Desde 23ai el tablespace por defecto es BIGFILE y gestionado localmente (`12-bloque`: BIG = YES). |
| P38 | A | 0 lecturas físicas significa que todos los bloques ya estaban en la buffer cache. |
| P39 | A, B | Más PCTFREE y filas más largas reducen las filas por bloque. |
| P40 | B | FLUSH BUFFER_CACHE afecta a toda la instancia: todas las sesiones vuelven a leer de disco. |
| P41 | B | La migrada cabía y se mudó al crecer; la encadenada no cabe en ningún bloque. |
| P42 | A | El índice UNUSABLE se reconstruye con REBUILD, o se evita usando MOVE ONLINE (`14-filas`, sección 7). |
| P43 | A | V$DIAG_ALERT_EXT (`11-sql`, sección 5). |
| P44 | A, B | Ampliar espacio (datafile o MAXSIZE) y averiguar qué segmentos crecen y por qué. |
| P45 | A, B | Todas las PDB comparten la SGA, los procesos de background y los redo online; el undo es local por defecto. |
| P46 | B | Sin SET CONTAINER, el usuario local recibe ORA-01031 (`10-que-ve`, 3c). |
