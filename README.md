# Guía K3s sobre Fedora USB

Material práctico de Sistemas Operativos para desplegar servicios en un
clúster K3s de un solo nodo, instalado en Fedora Workstation que arranca desde
un USB. El estado de K3s y los datos de los servicios se conservan en
`/srv/k3s-persistente`.

## Inicio rápido

En Fedora instalado en el USB:

```bash
git clone https://github.com/jplorier/k3_lab.git
cd k3_lab
sudo ./scripts/instalar-k3s-usb.sh
newgrp docker
./scripts/encender.sh basicos
./scripts/construir-y-publicar.sh v1
./scripts/estado.sh
```

El instalador requiere conexión a Internet una vez, para instalar paquetes,
K3s y las CRD de Gateway API. Traefik y ServiceLB quedan habilitados: el
ejemplo web se publica en `http://localhost/` mediante Gateway API. Después,
los manifiestos, imágenes descargadas y volúmenes permanecen en el USB. Los
tamaños de PVC son solicitudes y `local-path` no reserva ese espacio por
adelantado. Antes de retirar la unidad, ejecutar:

```bash
./scripts/apagar.sh todos --motor
```

## Servicios y acceso local

| Servicio | Dirección |
| --- | --- |
| Registro Docker | `http://localhost:30500/v2/_catalog` |
| Aplicación de ejemplo | `http://localhost/` (Traefik + Gateway API) |
| SFTP | `sftp -P 30022 alumno@localhost` |
| Samba | `//localhost:30445/compartido` |
| NFSv4 | `localhost:/` (puerto 30049) |
| Asterisk SIP | `localhost:5060` |
| Gitea | `http://localhost:30300` |
| GitLab CE | `http://localhost:30080` |
| Uptime Kuma | `http://localhost:30301` |

Las credenciales incluidas son únicamente valores públicos de demostración; no
deben reutilizarse fuera de este entorno ni usarse con datos reales.

## Operación

`encender.sh` acepta un servicio, `basicos` o `todos`; `apagar.sh` acepta los
mismos valores y escala Deployments a cero sin borrar los PVC. `estado.sh`
muestra nodo, Pods, PVC y servicios; `probar-servicios.sh` hace comprobaciones
HTTP y TCP básicas.

Los documentos HTML de `moodle/` son fragmentos autocontenidos, con estilos en
línea, listos para pegar en una página Moodle. Se regeneran con:

```bash
python3 gen_enunciado.py
```
