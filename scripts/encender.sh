#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/comun.sh"

objetivo="${1:-basicos}"
require_kubectl
kubectl apply -f "$RAIZ/manifiestos/00-base/namespace.yaml"

while IFS= read -r servicio; do
  echo "Aplicando y encendiendo: $servicio"
  kubectl apply -f "$(manifiesto "$servicio")"
  if kubectl get deployment "$servicio" -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl scale deployment "$servicio" -n "$NAMESPACE" --replicas=1
  fi
done < <(expandir_servicios "$objetivo")

echo "Servicios solicitados. Consulte ./scripts/estado.sh para seguir el arranque."
