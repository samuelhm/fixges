# Frontend - nginx

Sirve un `index.html` estático con `nginx:1.30.6-alpine3.24` y hace de proxy para la API.

## Rutas

| Ruta        | Destino                                   |
|-------------|-------------------------------------------|
| `/`         | `public/index.html`                       |
| `/api/...`  | `http://backend:8080/...` (red interna)   |

El prefijo `/api` se elimina al reenviar: `GET /api/health` → `GET /health`.

## Puertos

- Desarrollo: se publica en el host según `FRONTEND_PORT` (80 por defecto).
- Producción: no publica puertos. Nginx Proxy Manager llega al contenedor por la
  red externa `red_proxy`, usando el alias `fixges-web` en el puerto 80.

## Archivos

```text
frontend/
├── Dockerfile
├── nginx.conf
└── public/index.html
```

## Desarrollo

El HTML se monta como bind mount, por lo que los cambios se ven al recargar.
Si se modifica `nginx.conf`, reiniciar el contenedor para recargar la configuración.
