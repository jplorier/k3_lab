#!/usr/bin/env bash
# Instala los prerrequisitos y deja K3s usando el montaje persistente del USB.
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecute con sudo: sudo $0 [particion]" >&2
  exit 1
fi

RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DATOS=/srv/k3s-persistente
DISPOSITIVO="${1:-}"

if [[ -n "$DISPOSITIVO" ]]; then
  [[ -b "$DISPOSITIVO" ]] || { echo "No es un dispositivo de bloques: $DISPOSITIVO" >&2; exit 1; }
  mkdir -p "$DATOS"
  uuid="$(blkid -s UUID -o value "$DISPOSITIVO")"
  [[ -n "$uuid" ]] || { echo "La partición debe tener un sistema de archivos y UUID." >&2; exit 1; }
  grep -q " $DATOS " /etc/fstab || echo "UUID=$uuid $DATOS ext4 defaults,noatime,commit=60 0 2" >> /etc/fstab
  mountpoint -q "$DATOS" || mount "$DATOS"
else
  mkdir -p "$DATOS"
fi

mkdir -p "$DATOS/k3s" "$DATOS/pv" /etc/rancher/k3s /etc/docker
install -m 0644 "$RAIZ/config/k3s-config.yaml" /etc/rancher/k3s/config.yaml
install -m 0644 "$RAIZ/config/registries.yaml" /etc/rancher/k3s/registries.yaml
install -m 0644 "$RAIZ/config/daemon.json" /etc/docker/daemon.json
install -D -m 0644 "$RAIZ/config/traefik-gateway.yaml" /var/lib/rancher/k3s/server/manifests/traefik-gateway.yaml

dnf install -y curl ca-certificates docker git nfs-utils cifs-utils openssh-clients
systemctl enable --now docker
systemctl disable --now swap-create@zram0.service 2>/dev/null || true
swapoff -a || true

if ! command -v k3s >/dev/null; then
  curl -sfL https://get.k3s.io | sh -
else
  systemctl enable --now k3s
fi

until kubectl get nodes >/dev/null 2>&1; do sleep 2; done
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

usermod -aG docker "${SUDO_USER:-$USER}" || true
chmod 644 /etc/rancher/k3s/k3s.yaml
ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

echo "Instalación terminada. Abra una nueva sesión (o use newgrp docker) y ejecute ./scripts/encender.sh basicos."
