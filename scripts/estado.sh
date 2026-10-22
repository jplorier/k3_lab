#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/comun.sh"
require_kubectl

echo '== Nodo =='
kubectl get nodes -o wide
echo '== Pods =='
kubectl get pods -n "$NAMESPACE" -o wide
echo '== Servicios =='
kubectl get svc -n "$NAMESPACE"
echo '== Volúmenes persistentes =='
kubectl get pvc -n "$NAMESPACE"
echo '== Espacio persistente =='
df -h /srv/k3s-persistente
