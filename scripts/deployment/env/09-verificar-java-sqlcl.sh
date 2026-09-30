#!/usr/bin/env bash
set -euo pipefail
echo "== Java =="
java -version 2>&1
echo
echo "== JAVA_HOME =="
echo "$JAVA_HOME"
echo
echo "== SQLcl =="
sql -version
