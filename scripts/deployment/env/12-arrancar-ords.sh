#!/usr/bin/env bash
set -euo pipefail

source scripts/deployment/env/00-config.sh

ORDS="${ORDS_HOME}/bin/ords"
LOG="${ORDS_LOGS}/ords-serve.log"
URL="http://localhost:${ORDS_PORT}/ords/sql-developer"

if [[ ! -x "$ORDS" ]]; then
  echo "ERROR: no existe el ejecutable de ORDS: $ORDS" >&2
  exit 1
fi

if tmux has-session -t ords 2>/dev/null; then
  echo "Ya existe la sesión tmux ords; no se inicia otra."
else
  tmux new-session -d -s ords \
    "exec \"$ORDS\" --config \"$ORDS_CONFIG\" serve >> \"$LOG\" 2>&1"
  echo "ORDS arrancando en segundo plano."
fi

code=000
for ((i=1; i<=30; i++)); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL") || code=000
  if [[ "$code" == 200 || "$code" == 302 ]]; then
    break
  fi
  sleep 2
done

echo "Database Actions responde con HTTP $code"
ss -tlnp | grep -E "[:.]${ORDS_PORT}[[:space:]]" || true

if [[ "$code" != 200 && "$code" != 302 ]]; then
  echo "ERROR: ORDS no respondió correctamente; revisa $LOG" >&2
  exit 1
fi
