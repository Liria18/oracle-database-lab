# Runbook — Pérdida de un datafile (FREEPDB1)

## Síntoma
- Consultas fallan con `ORA-01116` (error opening file n), `ORA-01110` (data file n: ruta) y `ORA-27041` (unable to open file, "No such file or directory").
- Desde 21c Oracle puede cerrar la PDB entera al detectar el fallo de medio: `ORA-63999` en el alert log y `ORA-01089` en las sesiones.

## Comprobaciones previas (no tocar nada hasta tenerlas)
1. Modo de archivado: `SELECT log_mode FROM v$database;` → debe ser `ARCHIVELOG`. Si no, no hay recuperación completa: escalar.
2. Qué archivo: alert log (`/opt/oracle/diag/rdbms/free/FREE/trace/alert_FREE.log`) → número `n` y ruta.
3. Hay copia: `rman target /` → `LIST BACKUP OF DATAFILE n;`
4. Estado de la PDB: `SELECT name, open_mode FROM v$pdbs;`

## Camino 1 — la PDB sigue en READ WRITE (solo cae ese tablespace)
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE n OFFLINE;
```
```
RMAN> RESTORE DATAFILE n;
RMAN> RECOVER DATAFILE n;
```
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE n ONLINE;
```

## Camino 2 — Oracle cerró la PDB (MOUNTED tras ORA-63999)
1. Esperar a que `v$pdbs` muestre `MOUNTED` (no lanzar RESTORE mientras se está cerrando).
2. `RMAN> RESTORE DATAFILE n;` y `RMAN> RECOVER DATAFILE n;`
3. `ALTER SESSION SET CONTAINER = FREEPDB1; ALTER DATABASE DATAFILE n ONLINE;`
4. `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;`

## Verificación
- `SELECT name, open_mode FROM v$pdbs;` → FREEPDB1 `READ WRITE`.
- `SELECT file#, status FROM v$datafile WHERE file# = n;` → `ONLINE`.
- Fila de control posterior a la copia (p. ej. `aca_estudiantes` id 104) con su último valor confirmado → RPO = 0.

## Avisar
- Al responsable de guardia y al propietario del esquema afectado al empezar (impacto y RTO estimado) y al terminar (RTO real, RPO).
- Abrir incidencia con la causa del disco y programar una nueva copia RMAN completa.

Referencia medida en el Lab 5 (simulacro D): RTO 12 s, RPO 0.
