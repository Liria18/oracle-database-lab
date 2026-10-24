#!/usr/bin/env bash
# Constantes del proyecto. No incluir contraseñas en este archivo.

export CONT_NAME="oralab-26ai"
export VOL_NAME="oralab-26ai-data"
export IMG="container-registry.oracle.com/database/free:latest"
export PORT_DB=1521
export PORT_ORDS=8181
export SERVICE_CDB="FREE"
export SERVICE_PDB="FREEPDB1"
export BACKUP_DIR="$(pwd)/backups"
export EVID="docs/bitacora/evidencia"

ts() { date -u +%Y%m%dT%H%M%SZ; }

# ORDS: servidor web instalado en Ubuntu, fuera del contenedor de Oracle.
export ORDS_HOME="/opt/oracle/ords"
export ORDS_CONFIG="/etc/ords/config"
export ORDS_LOGS="/var/log/ords"
export ORDS_PORT=8080
# Lab 4: operación del entorno (backup/restauración y evidencia por laboratorio)
export HELPER_IMG="ubuntu:24.04"          # imagen auxiliar con GNU tar para copiar el volumen
export DATA_ROOT="/opt/oracle/oradata"    # punto de montaje del volumen dentro del contenedor
export EVID_LAB4="docs/bitacora/lab4/evidencia"   # evidencia del Lab 4: script/, spool/, config/
