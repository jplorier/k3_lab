FROM nginx:1.27-alpine

ARG VERSION_APP=dev
ENV VERSION_APP=${VERSION_APP}
COPY sitio/index.html /usr/share/nginx/html/index.html
COPY entrypoint-info.sh /docker-entrypoint.d/40-info-laboratorio.sh
RUN chmod 755 /docker-entrypoint.d/40-info-laboratorio.sh
EXPOSE 80
