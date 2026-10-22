#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/comun.sh"

version="${1:-v1}"
imagen="localhost:30500/utec/mi-app:${version}"
require_kubectl
"$RAIZ/scripts/encender.sh" registro
kubectl rollout status deployment/registro -n "$NAMESPACE" --timeout=120s

echo "Construyendo $imagen"
docker build --build-arg "VERSION_APP=$version" -t "mi-app:$version" "$RAIZ/app-ejemplo"
docker tag "mi-app:$version" "$imagen"
docker push "$imagen"

if kubectl get deployment mi-app -n "$NAMESPACE" >/dev/null 2>&1; then
  kubectl set image deployment/mi-app mi-app="$imagen" -n "$NAMESPACE"
else
  sed "s|localhost:30500/utec/mi-app:v1|$imagen|" "$RAIZ/app-ejemplo/despliegue.yaml" | kubectl apply -f -
fi
kubectl rollout status deployment/mi-app -n "$NAMESPACE" --timeout=180s
echo "Publicado y desplegado: $imagen"
