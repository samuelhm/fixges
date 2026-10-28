FROM nginx:1.30.6-alpine3.24

# Sustituye la configuración por defecto (que solo servía /usr/share/nginx/html).
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY public/ /usr/share/nginx/html/

EXPOSE 80
