#!/usr/bin/env bash
set -euo pipefail

source scripts/deployment/env/00-config.sh

echo "Descarga o confirmación de la imagen"
docker pull "$IMG"

echo
echo "Imagen local y su digest (versión exacta instalada)"
docker images --digests container-registry.oracle.com/database/free
