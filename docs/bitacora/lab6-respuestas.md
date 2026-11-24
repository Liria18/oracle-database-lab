# Lab 6 · Respuestas (E033)

## Partes A-C · Rol operativo, parámetros y estados

### 1.
En la Parte B la lista de turno dio 4 errores ORA- en 24 h (`*_01-turno.script.log`, sección 4). Casi todos son ORA-00800 «Set Priority Failed» de LGWR, que salen en cada arranque porque el contenedor no deja cambiar la prioridad de los procesos (el ADR lo agrupa en el problema 1, ORA 800, con 38 incidentes en `*_07-adr-trazas`). El número por sí solo no es una alarma: hay que compararlo con la línea base y ver qué errores son. 4 errores conocidos y repetidos son ruido; 1 error nuevo sí habría que mirarlo.

### 2.
La ventana WEDNESDAY_WINDOW empieza a las 22:00 (`byhour=22`) y dura 4 h, hasta las 02:00 (`*_01-automatizacion`, sección 2). En ella corren las tres tareas de AutoTask, todas ENABLED: auto optimizer stats collection, auto space advisor y sql tuning advisor.

### 3.
Después del `ALTER SYSTEM SET db_files = 250 SCOPE = SPFILE`, V$SPPARAMETER mostraba 250 con ISSPECIFIED TRUE, pero V$PARAMETER seguía en 200 (`*_02-parametros`, sección 5). El SPFILE es lo que se va a leer en el próximo arranque y V$PARAMETER es lo que está en uso ahora. Sin el RESET, en el siguiente reinicio la instancia habría arrancado con db_files = 250 sin que nadie lo hubiera planificado.

### 4.
RESET quita el parámetro del SPFILE y lo deja en su valor por defecto. Para db_files era correcto porque antes no estaba fijado: en `config/*_02-init_desde_spfile.ora` no aparece ninguna línea de db_files. Para processes no habría valido, porque sí estaba fijado a mano: la línea `*.processes=200`. Un RESET lo habría dejado en el valor por defecto en vez de en 200; la vuelta atrás correcta sería `ALTER SYSTEM SET processes = 200 SCOPE = SPFILE`.

### 5.
C##OPS_RO recibió ORA-01109: database not open al entrar por el servicio freepdb1 (`*_02-estados-pdb`, sección 4). La instancia decía «Database opened» porque eso se refiere a la CDB (CDB$ROOT), pero FREEPDB1 se quedó en MOUNTED porque no tenía estado guardado. Por eso después se hizo OPEN + SAVE STATE.

## Partes D-E · Servicios, sesiones y diccionario

### 6.
SID 17, serial 22973, SPID 2937 y evento PL/SQL lock timer (`*_03-sesiones`, sección 3). USERNAME solo dice APP_ACADEMIA, que es igual para todas las sesiones de la aplicación. MODULE (matriculas) y ACTION (cierre-periodo) dicen qué parte de la aplicación está trabajando, y CLIENT_IDENTIFIER (ana.garcia@ucam) dice para qué usuario final lo hace.

### 7.
Tras el CANCEL SQL quedaba 1 transacción abierta: se canceló el SLEEP (ORA-01013), pero la sesión siguió viva («sigo viva») con el UPDATE pendiente. Tras el KILL SESSION hubo 0 sesiones vivas y la fila 101 quedó en ACTIVO, porque al terminar la sesión Oracle deshizo su UPDATE sin confirmar (`*_03-sesiones`, secciones 4 y 5).

### 8.
common_user_prefix = C## (`*_03-cuenta-app`). Una cuenta común tiene que empezar por C##, como C##OPS_RO. Por eso APP_ACADEMIA, sin prefijo, es local (COMMON = NO) y solo existe en FREEPDB1.

### 9.
Datos de `*_04-tres-miradas`:

| Mirada | USER_TABLES | ALL_TABLES (ADMIN_ACADEMIA) | ALL_USERS | DBA_USERS | CDB_USERS | V$DATAFILE |
|---|---|---|---|---|---|---|
| C##OPS_RO en CDB$ROOT | 0 | 0 | 37 | 37 | con 1: 37 · con 3: 47 | 17 |
| C##OPS_RO por freepdb1 | 0 | 0 | 47 | 47 | con 3: 47 | 10 |
| APP_ACADEMIA por academia_app | 0 | 1 | 47 | ORA-00942 | ORA-00942 | ORA-00942 |

Una diferencia: el mismo usuario C##OPS_RO ve en CDB_USERS dos contenedores desde la raíz (37 y 47, porque tiene CONTAINER_DATA = ALL), pero desde freepdb1 solo ve el suyo (47). APP_ACADEMIA no tiene privilegios de catálogo, así que las vistas DBA_, CDB_ y V$ le dan ORA-00942.

### 10.
5288 lecturas lógicas por recorrido (52 881 en total para 10 recorridos) y 0,27 s de DB time (`*_04-deltas`, sección 4). El DB CPU fue de 0,25 s, casi igual que el DB time. Eso quiere decir que la carga pasó casi todo el tiempo en CPU leyendo bloques de memoria y apenas esperó por I/O ni por otras cosas.

## Partes F-G · Espacio y acceso

### 11.
TBS_ACADEMIA_HIST: asignado 10 MB, libre 3,9 MB y máximo 40 MB (`*_05-almacenamiento`, sección 2). Para alertar usaría el porcentaje usado sobre el máximo (15,16 %, 776 de 5120 bloques), porque el tablespace crece solo hasta los 40 MB. El libre dentro de lo asignado engaña: puede ser poco aunque quede mucho sitio para crecer.

### 12.
El INSERT lo lanzó el DBA (SYS), pero el error ORA-01950 se refiere a CARGA_HIST, el dueño de la tabla: la cuota la paga el dueño del segmento, no quien inserta. El ORA-01536 salió porque CARGA_HIST tenía una cuota de 2 MB (2 097 152 bytes, 256 bloques), no porque faltara espacio en el tablespace. Ampliar el tablespace no habría servido: el límite era la cuota del usuario.

### 13.
Estuvo suspendida unos 13 s: empezó a las 19:04:48 y terminó a las 19:05:01 (`*_05-resumable`). DBA_RESUMABLE mostraba SUSPENDED con ORA-01536 y timeout 180. En el alert log quedaron dos líneas: «statement in resumable session 'carga-historico' was suspended due to…» y «…was resumed». Se arregló subiendo la cuota a 30 MB.

### 14.
Antes: 20 000 filas, 2944 bloques y 23 MB. Tras el DELETE: 2000 filas, pero los mismos 2944 bloques y 23 MB. Tras el SHRINK SPACE: 2000 filas, 304 bloques y 2,4 MB, y la cuota usada bajó a 2,4 MB (`*_05-hwm-shrink`). El DELETE no devuelve espacio porque los bloques se quedan por debajo de la HWM, medio vacíos pero asignados al segmento. Hace falta ENABLE ROW MOVEMENT y SHRINK SPACE para compactar y bajar la HWM.

### 15.
DEFAULT: FAILED_LOGIN_ATTEMPTS 10, PASSWORD_LIFE_TIME 180, PASSWORD_GRACE_TIME 7, PASSWORD_LOCK_TIME 1, INACTIVE_ACCOUNT_TIME 365, REUSE_MAX y REUSE_TIME UNLIMITED, ROLLOVER 0 y VERIFY_FUNCTION NULL (`*_06-gobierno-acceso`, sección 1). En PRF_PERSONAS, 3 intentos fallidos porque una persona escribe su contraseña a mano y más de 3 fallos seguidos huelen a ataque. La función de verificación porque obliga a una contraseña compleja: «corta» dio ORA-28003. El bloqueo de 1 minuto es solo para el laboratorio.

### 16.
Ana tiene ROL_SECRETARIA_ACADEMIA, que incluye ROL_LECTURA_ACADEMIA, y ese rol tiene SELECT ANY TABLE ON SCHEMA admin_academia. Es un privilegio de esquema, así que cubre todas las tablas del esquema, también ACA_MATRICULAS: leyó 60 000 matrículas (`*_06-probar-acceso`). Al cambiar el nombre obtuvo ORA-41900: missing UPDATE privilege, porque solo tiene UPDATE sobre la columna ESTADO.

## Partes H-I · Objetos, diagnóstico y guardia

### 17.
Ampliar email_institucional invalidó V_CONTACTO_LAB6. Ampliar nombres invalidó V_ACTIVOS_LAB6 y, en cascada, F_TOTAL_ACTIVOS_LAB6, que depende de esa vista (`*_07-objetos`, secciones 3 y 4). Con la columna nueva todo siguió VALID porque Oracle controla las dependencias a nivel de columna: ningún objeto usaba esa columna.

### 18.
No. En el advisor de la SGA, con 3072 MB (factor 2) el ESTD_DB_TIME_FACTOR sigue en 1, así que no mejoraría nada (`*_07-memoria`, sección 5). En la PGA hay sobreasignaciones (OVERALLOC 2) con 128 y 256 MB y ninguna desde 384 MB, así que por debajo de 384 MB habría sobreasignaciones.

### 19.
247 lecturas lógicas: tkprof da query = 247 en la línea Fetch (`*_07-adr-trazas`, sección 5). En la traza lo dice la línea `FETCH #124309653392688:c=0,e=1993,p=0,cr=247,...`, donde cr son las lecturas consistentes.

### 20.
- INC-601: el SID 218 (ANA_GARCIA) esperaba `enq: TX - row lock contention` por el 56 (APP_ACADEMIA, idle) → `KILL SESSION '56,17938' IMMEDIATE` → secciones 1 a 4 vacías y fila 101 en ACTIVO.
- INC-602: academia_app con ARRANCADO = NO, ausente en lsnrctl y la aplicación con ORA-12514 → `DBMS_SERVICE.START_SERVICE('academia_app')` + SAVE STATE → READY en lsnrctl y app.sh conecta por academia_app.
- INC-603: APP_ACADEMIA en LOCKED (no TIMED) y la auditoría con `ALTER USER app_academia ACCOUNT LOCK` a las 19:11:17 → `ACCOUNT UNLOCK` → OPEN y app.sh conecta.

## Simulacro 1Z0-182 (letra · Parte)
S1: B · F
S2: C · C
S3: B · C
S4: B, C · C
S5: C · C
S6: B · C
S7: A · D
S8: B · D
S9: C · D
S10: C · D
S11: B · E
S12: A, C · E
S13: B · F
S14: A, C · F
S15: A, C · F
S16: B · F
S17: B · G
S18: B · G
S19: A, B · H
S20: B · H
S21: C · H
S22: C · I
