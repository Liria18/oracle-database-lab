# Lab 4 — Informe de autopsia de la instancia

Fuente: `docs/bitacora/lab4/evidencia/spool/*_15-autopsia-instancia.spool.log` (ejecutado como C##OPS_RO, solo lectura).

## Hallazgos

| Sección | Hallazgo | Evidencia (valor exacto) | Riesgo | Acción | Prioridad |
|---|---|---|---|---|---|
| 1 · 4 | ARCHIVELOG activo, pero sin FRA configurada | `LOG_MODE=ARCHIVELOG`, `db_recovery_file_dest` vacío, `db_recovery_file_dest_size=0`, 7 archived logs (574 MB) | Los redo archivados crecen sin límite ni gestión y no hay copias RMAN que los aprovechen: pueden llenar el disco y detener la base | Configurar FRA con tamaño máximo y política de copias (Lab 5) | Alta |
| 4 | Control files y redo sin multiplexar | 2 control files en `/opt/oracle/oradata/FREE/`; 3 miembros de redo (1 por grupo) | Punto único de fallo: perder ese disco o un miembro de redo deja la base sin poder abrir o sin recuperación completa | Multiplexar control files y redo en otra ubicación (Lab 5) | Alta |
| 4 | ADR fuera del volumen | `diagnostic_dest=/opt/oracle` (el volumen está en `/opt/oracle/oradata`) | El alert log y las trazas se pierden al recrear el contenedor: ya se perdió el historial anterior a la prueba de persistencia | Llevar `diagnostic_dest` al volumen o centralizar los logs | Media |
| 6 | Cuatro esquemas sin estadísticas | `ALTURA_MAX` vacía en ADMIN_CLINICA, ADMIN_FINTECH, ADMIN_LOGISTICA y ADMIN_RETAIL | El optimizador elige planes de ejecución a ciegas | `DBMS_STATS.GATHER_SCHEMA_STATS` en cada esquema | Media |
| 2 | PGA cerca de su objetivo | `maximum PGA allocated=509 MB` frente a `aggregate PGA target=512 MB` | Con más carga, las ordenaciones irán a TEMP (más lentas) | Vigilar `v$pgastat` y `over allocation count` antes de subir el objetivo | Baja |
| 6 | 2 índices de ADMIN_ACADEMIA con factor de agrupamiento cercano al número de filas | `CF_CERCANO_A_FILAS=2` | Índices caros en búsquedas por rango | Analizarlos en el Lab 5 | Baja |
| 10 | ORA-00800 en el alert log | 4 veces, última 2026-10-24 11:26 | Ninguno: aviso «soft» del contenedor (no puede subir la prioridad de VKTM/LGWR) | Documentar como ruido conocido y excluir de alertas | Baja |
| 10 | ORA-65025 y ORA-959 en el alert log | ORA-65025 a las 11:35 y ORA-959 a las 11:38 | Ninguno: provocados por el propio laboratorio: ORA-65025 en el ciclo de vida de PDB (Parte I) y ORA-959 en `DROP TABLESPACE IF EXISTS tbs_lab4` de `13-capacidad.sql` (Parte L), que limpia un tablespace que aún no existía | Ninguna; confirmado en el bloque del alert log | — |
| 5 · 7 | Correcto: tablespaces de negocio con techo y sin cuentas propias con DBA | TBS_* con `MB_MAXIMO=1024` y uso máximo 2,3 %; ninguna cuenta de la casa con rol DBA | — | Mantener | — |

## Resumen para dirección

1. La base funciona y los fallos heredados del Lab 3 (archivos mal ubicados, contraseñas expuestas, puerto abierto) están corregidos.
2. El riesgo principal es la protección ante fallos: copias, archivos críticos sin duplicar y registros que se pierden al recrear el contenedor.
3. Se resolverá en el Lab 5 configurando el área de recuperación, duplicando los archivos críticos y midiendo el tiempo de recuperación.
