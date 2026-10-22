#!/bin/sh
set -eu

sed \
  -e "s|__VERSION_APP__|${VERSION_APP:-sin-etiqueta}|g" \
  -e "s|__HOSTNAME__|$(hostname)|g" \
  -e "s|__POD_IP__|${POD_IP:-no-disponible}|g" \
  /usr/share/nginx/html/index.html > /tmp/index.html
mv /tmp/index.html /usr/share/nginx/html/index.html
