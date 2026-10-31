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

mkdir -p "$DATOS/k3s" "$DATOS/pv" /var/lib/rancher/k3s /etc/rancher/k3s /etc/docker

# K3s no admite un data-dir propio con SELinux: se usa su ruta estándar, montada sobre el USB.
grep -q " /var/lib/rancher/k3s " /etc/fstab || echo "$DATOS/k3s /var/lib/rancher/k3s none bind,x-systemd.requires-mounts-for=$DATOS 0 0" >> /etc/fstab
systemctl daemon-reload
if ! mountpoint -q /var/lib/rancher/k3s; then
  # Una instalación anterior tiene sus contenedores bajo el data-dir del USB.
  if [[ -x /usr/local/bin/k3s-killall.sh ]]; then
    K3S_DATA_DIR="$DATOS/k3s" /usr/local/bin/k3s-killall.sh || true
  fi
  mount /var/lib/rancher/k3s
fi

install -m 0644 "$RAIZ/config/k3s-config.yaml" /etc/rancher/k3s/config.yaml
install -m 0644 "$RAIZ/config/registries.yaml" /etc/rancher/k3s/registries.yaml
install -m 0644 "$RAIZ/config/daemon.json" /etc/docker/daemon.json
install -D -m 0644 "$RAIZ/config/traefik-gateway.yaml" /var/lib/rancher/k3s/server/manifests/traefik-gateway.yaml

dnf install -y curl ca-certificates docker git nfs-utils cifs-utils openssh-clients

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-port=6443/tcp
  firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
  firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16
  firewall-cmd --reload
fi

systemctl enable --now docker
systemctl disable --now swap-create@zram0.service 2>/dev/null || true
swapoff -a || true

if ! command -v k3s >/dev/null; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true sh -
fi
# Las etiquetas dependen de la política k3s-selinux, que instala el paso anterior.
if selinuxenabled 2>/dev/null; then
  restorecon -R /var/lib/rancher/k3s
fi
systemctl enable k3s
systemctl restart k3s

until kubectl get nodes >/dev/null 2>&1; do sleep 2; done
# K3s instala Traefik y las CRD de Gateway API con Helm; instalarlas aparte hace fallar el chart.
# Se quitan las que haya dejado una versión anterior de este instalador.
kubectl delete gatewayclass -l 'app.kubernetes.io/managed-by!=Helm' --field-selector metadata.name=traefik 2>/dev/null || true
kubectl get crd -l 'app.kubernetes.io/managed-by!=Helm' -o name | { grep gateway.networking.k8s.io || true; } | xargs -r kubectl delete
echo "Esperando a Traefik..."
timeout 600 sh -c 'until kubectl get deployment traefik -n kube-system >/dev/null 2>&1; do sleep 2; done' || {
  echo "Traefik no se instaló. Revise: kubectl logs -n kube-system job/helm-install-traefik-crd" >&2
  exit 1
}
kubectl rollout status deployment/traefik -n kube-system --timeout=300s

usermod -aG docker "${SUDO_USER:-$USER}" || true
chmod 644 /etc/rancher/k3s/k3s.yaml
ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

echo "Instalación terminada. Abra una nueva sesión (o use newgrp docker) y ejecute ./scripts/encender.sh basicos."
