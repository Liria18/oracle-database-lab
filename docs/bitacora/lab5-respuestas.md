# Lab 5 — Oracle DBA Workflow II · Respuestas

Alumno: Jose Liria · Issue #9 · Rama `chore/9-oracle-dba-workflow-ii`
Evidencias en `docs/bitacora/lab5/evidencia/{script,spool,config}` (abreviado `E/`).

---

## 1. Preguntas de comprobación

### A y B · Punto de partida y banco de medida

**1. Paso 6 de lab4-final frente a lab3-final.**
En ambas copias el paso 6 dice «ninguno» (`archivos_fuera_del_volumen=0` en los dos manifiestos), pero el inventario muestra la diferencia. En `lab3-final`, los 5 datafiles de negocio estaban en `/opt/oracle/product/26ai/dbhomeFree/dbs/` (dentro del ORACLE_HOME). Contaron como «dentro» solo porque en esta imagen `dbs` es un enlace simbólico al volumen (`/opt/oracle/oradata/dbconfig/FREE/dbs`) y el script resuelve la ruta real con `readlink -f`. En `lab4-final` están en `/opt/oracle/oradata/FREE/FREEPDB1/` (`E/script/20261027T180039Z_00-backup-lab4.script.log`). Esto demuestra dos cosas: el script juzga la ubicación REAL y no la aparente, y la reubicación del Lab 4 sacó los datafiles de una ruta frágil (mezclados con SPFILE y password file, persistentes solo gracias a un enlace propio de la imagen) y los llevó a una ruta estándar y explícita del volumen. En otra imagen sin ese enlace, la copia de lab3 habría perdido esos 5 archivos.

**2. bfr de CLIENTE y PEDIDO.**
- CLIENTE: 100 000 / 1517 = **66** filas por bloque (R = 102 bytes).
- PEDIDO: 1 000 000 / 5320 = **188** filas por bloque (R = 32 bytes).

Fuente: `E/script/20261027T181953Z_01-perfil-tiendasur.script.log`. PEDIDO cabe casi el triple porque su fila mide un tercio (32 frente a 102 bytes): el bfr depende del tamaño de fila.

Reto: contando con DBMS_ROWID, PEDIDO tiene 5220 bloques con filas (mínimo 2, media 191,6, máximo 200) frente a 5320 en `BLOCKS` (`E/script/20261027T182053Z_01-reto-bfr.script.log`). `BLOCKS` incluye bloques sin filas bajo la HWM (cabecera del segmento y bitmaps de ASSM). El bloque con 2 filas es el último de la carga.

**3. ¿Por qué se mide la segunda ejecución?**
La primera incluye trabajo que solo se hace una vez: el análisis (hard parse), cargar bloques en la caché y la limpieza diferida de bloques tras la carga. La segunda mide el trabajo estable de la sentencia. Ejemplo: `prueba_pk` da 4 lecturas lógicas en caliente (`E/script/20261027T181954Z_01-herramienta-medir.script.log`).

### C y D · Anatomía y tipos de índice

**4. IX_PED_CLIENTE.**
Altura 3, 2216 hojas, 6 ramas, fo real = (2216 + 6 − 1) / 6 = **370** y fo máximo = 8028 / 14,8 = **543** (`E/script/20261027T182727Z_02-anatomia-indice.script.log`). Con mil millones de filas tendría unas 2 208 969 hojas y **altura 4**, es decir, 5 lecturas para encontrar una fila.

Reto: había predicho que UX_CLI_EMAIL tendría unas 417 hojas y altura 2. Lo medido fue 501 hojas y altura 3 (`E/script/20261027T184240Z_02-reto-ux-cli-email.script.log`). La entrada de hoja ocupa 35,9 bytes y no 30, y el fo máximo con claves de texto baja a 441: 501 hojas no caben bajo una sola raíz. El mapa de PK_CLIENTE sale al 99,6 % porque se llenó durante la carga con claves crecientes (divisiones 90/10). UX_CLI_EMAIL sale al 89,6 % porque se creó después de la carga (construcción ordenada con PCTFREE 10).

**5. ROWID en la hoja de PK_CLIENTE.**
La entrada `row#0 ... data:(6): 00 00 03 1b 00 00` con la clave `c1 02` (el número 1) se descompone así:
- 4 bytes de bloque: 0x0000031B = **795**.
- 2 bytes de fila (ranura): **0**.

Coincide con `DBMS_ROWID` del cliente 1: bloque 795, ranura 0 (`E/config/20261027T182727Z_02-volcado-indice.trc.txt`). No aparece el número de archivo porque TBS_TIENDASUR es BIGFILE: tiene un único archivo, así que los 4 bytes son todos número de bloque. Tampoco hace falta el número de objeto, porque un índice no particionado apunta a una sola tabla.

**6. Tres pruebas de la Parte D** (`E/script/20261027T184439Z_03-tipos-indice.script.log`):
- **Único (Q13):** 1486 lecturas sin índice (recorrido completo) frente a **3** con UX_CLI_DNI. Además impide el duplicado: ORA-00001 + ORA-03301.
- **Compuesto y cubriente (Q7):** 15 lecturas (+ SORT) con IX_PED_CLIENTE, 7 con (id_cliente, fecha) y **3** con el cubriente. Igualdad y después rango devuelve las filas ya ordenadas; el cubriente ni siquiera va a la tabla.
- **Bitmap (Q14):** 4073 lecturas frente a **528** con BITMAP AND de 4 bitmaps. El bitmap de región ocupa 114 hojas frente a 1954 del B-tree.

### E y F · Agrupamiento, equilibrio y sargabilidad

**7. Clustering factor.**
IX_PED_FECHA tiene CF = **5220**, cerca de los 5320 bloques, porque los pedidos se cargaron en orden de fecha: filas vecinas en el índice son vecinas en disco. IX_PED_CLIENTE tiene CF = **999 041**, cerca de 1 000 000 filas, porque id_cliente se repartió al azar: casi cada entrada salta de bloque. El cálculo a mano con LAG sobre el ROWID da exactamente lo mismo (`E/script/20261027T184554Z_04-agrupamiento-equilibrio.script.log`). Un REBUILD **no** lo arregla: el CF depende del orden de las filas en la tabla. Habría que reordenar la tabla, y eso empeoraría el CF de la fecha.

**8. Punto de equilibrio** (gráfica `docs/bitacora/lab5/img/04-curva-equilibrio.png`). La tabla entera cuesta 5232 lecturas.
- **CF malo:** al 0,5 % lee 4875 y al 1 % lee 9920, así que cruza entre el 0,5 % y el 1 %. La fórmula 1/bfr = 1/188 da **0,53 %**.
- **Optimizador:** cambia a recorrido completo entre el 0,1 % y el 0,2 %. La fórmula con disco, (1/188) · (1/5), da **0,11 %**: supone que la lectura aleatoria es más cara.
- **CF bueno:** al 50 % lee 3938 y al 100 % lee 7875, así que solo pierde al final, cuando lee la tabla entera más el índice entero.

**9. Q4b ('Gonz%').**
Es sargable (un rango por el principio de la cadena) y usa IX_CLI_APELLIDOS, pero devuelve 2056 filas (2,1 %) y lee **2024** bloques frente a 1486 del recorrido completo (`E/script/20261027T184902Z_05-sargabilidad.script.log`). Los apellidos no están ordenados en disco (CF malo), así que cada fila es un bloque distinto, y el 2,1 % supera el umbral 1/bfr de CLIENTE (1/66 ≈ 1,5 %).

Reto, revisión de código (`E/script/20261027T185332Z_05-reto-revision.script.log`):
- `SUBSTR(telefono,1,3)='600' OR UPPER(apellidos)='GIL'` rompe la regla 1 (función sobre la columna) y la regla 5 (OR). Hace un recorrido completo: **1487** lecturas.
- Además tiene un bug: `apellidos` guarda los dos apellidos, así que `UPPER(apellidos)='GIL'` devuelve 0 filas y se pierden 6121 clientes cuyo segundo apellido es Gil.
- Reescrita como `telefono LIKE '600%' OR apellidos = :apellidos`, con índice en cada columna: **722** lecturas (BITMAP OR).

### G y H · Coste de escritura y mantenimiento

**10. Bloques modificados por INSERT** (`E/script/20261027T185444Z_06-indices.script.log`):

| Escenario | Índices | Bloques por fila |
|---|---|---|
| Hoy | 4 | **10,2** |
| Propuesta del compañero | 9 | **20,2** |
| V005 | 5 | **12,1** |

Rechazados:
- **IX_PED_CANAL:** 3 valores, el 33 % de la tabla por valor; no es viable y no se usó.
- **IX_PED_ESTADO:** 4 valores, el 25 % por valor. Q12 se resuelve mejor con el parcial IX_PED_PENDIENTES (54 hojas frente a 2933).
- **IX_PED_FEC_CLI:** sin usos en MONITORING USAGE.
- **IX_PED_CLI_FEC:** sustituido por el cubriente (Q7: 3 lecturas frente a 7).

Además, V005 retiró IX_PED_CLIENTE (es prefijo del cubriente, que sigue protegiendo la clave ajena) e IX_PED_IMPORTE (sin usos; invisible, Q2 siguió en 328 lecturas). Se conservó **IX_PED_CP**: Q3 baja de 5232 a 106 lecturas.

**11. Gráficos de la Parte H** (`E/script/20261027T185556Z_07*`):
- **50/50 (IX_AZAR):** 595 divisiones, 0 de ellas 90/10. Ocupación 75,4 %, histograma repartido entre el 40 y el 99 % y mapa irregular (`==-====-==#===---…`).
- **90/10 (IX_CRECIENTE):** 398 divisiones, todas 90/10. Hojas al 99,9 % y mapa todo `#`.
- **Patrón cola (IX_COLA):** 224 hojas vacías (0-9 %) a la izquierda y llenas a la derecha (`[      …=#####]`). 70 619 entradas borradas (41 %), y el siguiente mensaje cuesta 226 lecturas frente a 2.

**12. Remedio en producción, en horario de servicio.** **COALESCE**: funciona en línea, sin bloquear, y resuelve el síntoma (425 → 201 hojas, siguiente mensaje 226 → 2 lecturas). SHRINK SPACE solo si además quiero devolver espacio (4 → 1,69 MB). REBUILD ONLINE pide el doble de espacio y genera mucho redo. La cura de diseño es particionar por fecha y vaciar particiones enteras.

### I a L · SCN, control files, redo y FRA

**13. Qué compara Oracle al abrir.**
El SCN de checkpoint de cada datafile según el control file (`v$datafile.checkpoint_change#`) con el SCN de checkpoint de la cabecera del propio archivo (`v$datafile_header.checkpoint_change#`). En mi evidencia, ambos valían 8413115 (sincronizado) y, tras el CHECKPOINT, 8419075 los dos (`E/script/20261027T185655Z_08-scn-checkpoint.script.log`). Si la cabecera es más antigua, ese archivo necesita recuperación de medios. Si la base no se cerró limpia (no hay SCN de parada), hace recuperación de instancia.

**14. Multiplexar en el mismo volumen.**
Protege de la pérdida o corrupción de **un archivo**: en el simulacro B, el arranque se paró con ORA-00205 y bastó copiar control01 sobre control03. **No** protege de perder el volumen o disco, porque las 3 copias están en `/opt/oracle/oradata/FREE/`. Tampoco de un error lógico, que se escribiría en las 3 a la vez. En producción, cada copia va en un disco o controlador distinto (o en grupos ASM distintos, +DATA y +FRA), además de autobackup del control file con RMAN.

**15. Estados del redo** (`E/script/20261027T190002Z_10-redo.script.log`):
- **CURRENT:** LGWR escribe en él (grupo 3 y luego el 1).
- **ACTIVE:** ya no es el actual, pero sus cambios aún no están todos en los datafiles; haría falta para una recuperación de instancia (grupos 2 y 3 tras los cambios de log).
- **INACTIVE:** sus cambios ya están en los datafiles y, en ARCHIVELOG, está archivado; se puede reutilizar.

Rechazos:
- 4a, borrar el grupo CURRENT: **ORA-01623**.
- 4b, borrar un miembro del CURRENT: **ORA-01609**.
- 4c: en mi entorno hay 3 grupos, y borrar uno dejaría 2, que Oracle permite. Adapté el script para no ejecutarlo. Con 2 grupos daría **ORA-01567**, porque el mínimo son 2 grupos por hilo.

Reto K: a las 18 h hubo 9 cambios de log con grupos de 200 MB (unos 1,8 GB de redo) (`E/script/20261027T190002Z_10-reto-dimensionar.script.log`). Para que esa carga produzca como mucho 4 cambios, harían falta ≥ 450 MB por grupo, es decir, **512 MB**. Comandos (sin ejecutar):

```sql
ALTER DATABASE ADD LOGFILE GROUP 4 ('/opt/oracle/oradata/FREE/redo04.log','/opt/oracle/oradata/FREE/redo04b.log') SIZE 512M;
ALTER DATABASE ADD LOGFILE GROUP 5 ('/opt/oracle/oradata/FREE/redo05.log','/opt/oracle/oradata/FREE/redo05b.log') SIZE 512M;
ALTER DATABASE ADD LOGFILE GROUP 6 ('/opt/oracle/oradata/FREE/redo06.log','/opt/oracle/oradata/FREE/redo06b.log') SIZE 512M;
ALTER SYSTEM SWITCH LOGFILE;   -- hasta que 1, 2 y 3 no sean CURRENT
ALTER SYSTEM CHECKPOINT;       -- hasta que estén INACTIVE y archivados
ALTER DATABASE DROP LOGFILE GROUP 1;
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;
-- y borrar redo0{1,2,3}{,b}.log del disco
```

**16. Cadena de causas de la FRA llena** (`E/script/20261027T190239Z_11-fra-llena-2.script.log`):
1. La FRA se reduce a 2 MB.
2. **ORA-19815** avisa del 91 % y luego del 100 % usado.
3. Al archivar, **ORA-19809** (límite superado).
4. ARCn no puede archivar: **ORA-16038** (log 3, secuencia 24).
5. El grupo queda `ARCHIVED = NO`.
6. Cuando LGWR da la vuelta y necesita ese grupo, no puede reutilizarlo: las sesiones esperan en *log file switch (archiving needed)* y las conexiones nuevas reciben ORA-00257. La base deja de aceptar cambios.

Al devolver la FRA a 4 GB, ARCn reintentó solo y archivó la 24. La primera ejecución no lo reprodujo porque la FRA estaba vacía y el archivado de 1,8 MB cupo en 2 MB (`…190209Z_11-fra-llena.script.log`).

### M a P · Undo, WAL y simulacros

**17. «Lectores no bloquean a escritores»** (`E/script/20261027T190303Z_12-lectura-consistente.script.log`):
1. A cambia la fila 101 a EGRESADO sin confirmar y B lee **ACTIVO**: la imagen anterior, reconstruida con el undo.
2. La transacción de A usa 1 bloque y 1 registro de undo (segmento 9).
3. A tiene un bloqueo TM modo 3 sobre la tabla y TX modo 6 sobre la fila.
4. Ninguna lectura de B esperó. Solo esperó al intentar **escribir** (`FOR UPDATE WAIT 3`): ORA-00054.

Solo un escritor bloquea a otro escritor.

**18. Undo por tipo de DML** (`E/script/20261027T190332Z_12-undo-y-redo.script.log`):

| DML de 10 000 filas | Undo | Redo de su ROLLBACK |
|---|---|---|
| INSERT | 142 bloques (1136 KB) | 355 KB |
| UPDATE | 71 bloques (568 KB) | 751 KB |
| DELETE | **427 bloques (3416 KB)** | **4701 KB** |

El undo de un INSERT solo dice «borra este ROWID». El de un DELETE guarda la fila entera y sus entradas de índice para poder reinsertarla. El ROLLBACK genera redo porque deshacer es aplicar cambios a bloques, y todo cambio de bloque se protege con redo.

**19. Durabilidad** (`E/script/20261027T190408Z_13-lgwr-dbwn.script.log`):
- **Justo después del COMMIT:** 1779 KB de redo escritos por LGWR, 0 bloques escritos por DBWn y 231 bloques sucios en la caché. La garantía está en el **redo log en línea**.
- **Después del CHECKPOINT:** DBWn escribió 346 bloques y quedan 0 sucios. Los cambios ya están en los **datafiles**, y ese redo deja de hacer falta para una recuperación de instancia.

**20. Simulacro A** (`E/script/20261027T190458Z_14a-caida-instancia.script.log`):
- **Roll forward:** el alert log muestra *Beginning crash recovery*, *Recovery starting at … logseq 26 … scn 8422684*, *read 18 KB redo, 28 data blocks need recovery* y *Completed crash recovery*. SMON reaplica todo el redo, el confirmado (102) y el no confirmado (103), incluido el redo del undo.
- **Roll back:** después, el undo deshace lo no confirmado. Resultado: 102 = **EGRESADO** (sobrevive porque el COMMIT ya estaba en el redo) y 103 = **ACTIVO** (deshecho).

**21. Simulacros C y D.**
- **C:** RTO **61 s**, restaurando la copia en frío de todo el volumen con la base parada. RPO = todo lo posterior a la copia (aquí 1 s, en la vida real horas) (`…190604Z_14c-simulacro-restauracion.script.log`).
- **D:** RTO **12 s** y RPO **0** (`…191340Z_14d-perdida-datafile.script.log`). RMAN restaura un solo archivo y aplica el redo archivado y el en línea posteriores a la copia, así que la fila 104 sobrevivió como EGRESADO.

Son tan distintos por lo que se restaura (la base entera frente a un archivo) y por si hay redo para avanzar desde la copia: en C la copia en frío no tiene «hacia delante»; en D, ARCHIVELOG lo permite. En D, Oracle cerró FREEPDB1 (ORA-01089 / ORA-63999), así que toda la PDB estuvo caída esos 12 s, pero el CDB siguió abierto.

**22. Errores ORA- del bloque 5 del runbook** (`E/spool/20261027T191533Z_15-healthcheck.spool.log`):

| Error | Clasificación |
|---|---|
| ORA-01113, ORA-01110, ORA-63999 (19:13) | **Efecto del laboratorio:** simulacro D, datafile 16 borrado a propósito |
| ORA-00202 / ORA-205 (19:05) | **Efecto del laboratorio:** simulacro B, control03.ctl borrado |
| ORA-00800 *Set Priority Failed* (LGWR, VKTM) | **Ruido conocido:** el contenedor Docker no tiene permiso para subir la prioridad de esos procesos; aparece en cada arranque y no afecta al servicio |
| Incidente real | **Ninguno** |

---

## 2. Tabla de simulacros (game day)

| Simulacro | Fallo | Recuperación | RTO | RPO |
|---|---|---|---|---|
| A | SHUTDOWN ABORT | Automática (SMON: roll forward + roll back) | segundos (lo que tarda STARTUP) | 0 (lo confirmado sobrevive) |
| B | Borrado de control03.ctl | Copiar control01 → control03, MOUNT, OPEN | segundos | 0 |
| C | DROP TABLE … PURGE | Restaurar la copia en frío del volumen | **61 s** | todo lo posterior a la copia |
| D | Borrado de academia01.dbf | RMAN RESTORE + RECOVER DATAFILE | **12 s** | **0** |

(El error leve de C, DROP sin PURGE, se resolvió con FLASHBACK TABLE TO BEFORE DROP en segundos y RPO 0.)

## 3. Retrospectiva sin culpables

- **Qué fue bien:** la copia `lab4-final` y la de antes del simulacro permitieron romper sin miedo. RMAN + ARCHIVELOG dieron RPO 0 en el simulacro D. `16-verificacion-final.sh` terminó TODO OK.
- **Qué no fue como se esperaba:**
  - La primera ejecución de la FRA llena no reprodujo el error (la FRA estaba vacía). Lo detecté por la ausencia de ORA-16038 y repetí.
  - El script de redo, en un entorno con 3 grupos, habría borrado un grupo real en la prueba 4c. Lo adapté antes de ejecutarlo.
  - Una imagen copiada desde Windows entró en Git con modo 755; lo corregí con `--amend`.
- **Mejoras:**
  - Redo de 512 MB por grupo.
  - Control files y miembros de redo en discos distintos.
  - Diagnostic dest (ADR) dentro del volumen para conservar el alert log.
  - Autobackup del control file y copias RMAN programadas.
  - Filtrar el ruido ORA-00800 en el runbook de salud.
- **Comparación de RTO:** C (61 s) frente a D (12 s). Recuperar al nivel de archivo con redo es más rápido y no pierde datos. La copia en frío completa queda como último recurso.

---

## 4. Simulacro de examen 1Z0-182

| Pregunta | Respuesta | Comprobado en |
|---|---|---|
| S1 | B | Parte E: CF ≈ filas en IX_PED_CLIENTE |
| S2 | A, C | Parte D (índice funcional, 4 lecturas) y Parte F (reescritura, 4 lecturas) |
| S3 | B | Parte F: `filter(TO_NUMBER("CODIGO_POSTAL")=30001)` |
| S4 | B | Parte D: Q14 con bitmaps |
| S5 | B | Parte D: Q6 con INDEX SKIP SCAN |
| S6 | B | Parte G: IX_PED_IMPORTE INVISIBLE |
| S7 | A, C | Parte H: COALESCE y SHRINK SPACE en línea |
| S8 | B | Parte H: el REVERSE hizo un recorrido completo para el rango (878 lecturas) |
| S9 | C | Parte G: el UPDATE de importe cuesta 6 bloques por fila con 4 y con 9 índices |
| S10 | B | Parte C: fo 543 (NUMBER) frente a 441 (email) |
| S11 | A, C | Parte D: Q15 con IOT, 3 lecturas |
| S12 | B | Parte I: control file frente a cabecera |
| S13 | C | Parte I |
| S14 | B, E | Parte O: simulacro B en NOMOUNT, `v$instance` = STARTED |
| S15 | B | Parte L (el script lo hace así cuando la base está en NOARCHIVELOG) |
| S16 | B | Parte K (teoría de estados del redo) |
| S17 | A, C | Parte M: lectura consistente y flashback query |
| S18 | B | Parte M: el redo describe también el undo |
| S19 | A | Parte N: tras el COMMIT, 0 bloques escritos por DBWn |
| S20 | A | Parte I: ESTIMATED_MTTR y fast_start_mttr_target |
| S21 | B | Parte L: FRA llena, ORA-16038 |
| S22 | B | Parte O: simulacro D, DATAFILE OFFLINE |
| S23 | B | Parte O (teoría: SYSTEM no puede ponerse OFFLINE con la base abierta) |
| S24 | B | Parte L / Unidad 4 |
| S25 | B, D | Parte M: undo_retention 900 y v$undostat |
| S26 | A | Parte L: v$recovery_area_usage |
