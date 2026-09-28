SET ECHO OFF
SET FEEDBACK ON
SET LINESIZE 160
WHENEVER SQLERROR EXIT SQL.SQLCODE

SELECT instance_name, status FROM v$instance;
SELECT name, open_mode FROM v$database;
SELECT name, open_mode FROM v$pdbs ORDER BY name;

EXIT
