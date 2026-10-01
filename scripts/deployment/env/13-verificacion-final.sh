#!/usr/bin/env bash
set -euo pipefail

source scripts/deployment/env/00-config.sh
set -a
source config/.env
set +a
: "${ORACLE_PWD:?Falta ORACLE_PWD en config/.env}"

echo "1. Docker"
docker version --format 'Cliente {{.Client.Version}} | Motor {{.Server.Version}}'

echo "2. Imagen y digest"
docker images --digests "$IMG"

echo "3. Contenedor"
docker ps -a --filter "name=^/${CONT_NAME}$" \
  --format '{{.Names}} | {{.Status}} | {{.Ports}}'

echo "4. Volumen persistente"
docker volume ls --filter "name=^${VOL_NAME}$"

echo "5. Base de datos lista"
docker logs "$CONT_NAME" 2>&1 | grep 'DATABASE IS READY TO USE'

echo "6. Tablas de los entornos de negocio"
CONN="sys/${ORACLE_PWD}@localhost:${PORT_DB}/${SERVICE_PDB}"
docker exec -i "$CONT_NAME" sqlplus -s "$CONN" as sysdba <<'SQL'
WHENEVER SQLERROR EXIT SQL.SQLCODE
SET PAGESIZE 50
SELECT owner, COUNT(*) AS tablas
FROM dba_tables
WHERE owner LIKE 'ADMIN\_%' ESCAPE '\'
GROUP BY owner
ORDER BY owner;
EXIT
SQL
unset CONN

echo "7. Java"
java -version 2>&1 | head -n 1

echo "8. SQLcl"
sql -version

echo "9. Secretos fuera de Git"
git check-ignore -q config.env
git check-ignore -q config/.env
echo "OK: ambos archivos de secretos están ignorados"

echo "10. ORDS standalone"
code=$(curl -s -o /dev/null -w '%{http_code}' \
  "http://localhost:${ORDS_PORT}/ords/sql-developer")
echo "Database Actions: HTTP $code"
[[ "$code" == 200 || "$code" == 302 ]]
