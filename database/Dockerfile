FROM postgres:18.6-alpine3.24

# Los scripts solo se ejecutan cuando el volumen de datos está vacío
# (primera inicialización del contenedor).
COPY init/ /docker-entrypoint-initdb.d/
