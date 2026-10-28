# Fixges

Software de gestión interna para una empresa de servicios técnicos (SAT) de electrónica.

Este repositorio contiene únicamente el esqueleto de infraestructura: tres servicios
independientes, cada uno en su propia carpeta, orquestados con Docker Compose.

> Contexto para agentes de código: [`AGENTS.md`](AGENTS.md).

## Stack

| Servicio   | Tecnología                                | Carpeta      |
|------------|-------------------------------------------|--------------|
| Backend    | ASP.NET Core Minimal API (.NET 10 / C#)   | `backend/`   |
| Base datos | PostgreSQL 18                             | `database/`  |
| Frontend   | nginx + HTML estático                     | `frontend/`  |

Versiones fijadas (sin `latest`):

- `mcr.microsoft.com/dotnet/sdk:10.0.403-noble`
- `mcr.microsoft.com/dotnet/aspnet:10.0.9-noble`
- `postgres:18.6-alpine3.24`
- `nginx:1.30.6-alpine3.24`

## Estructura

```text
.
├── AGENTS.md              # Contexto para agentes de código
├── compose.yml            # Base común (no ejecutar solo)
├── compose.dev.yml        # Override de desarrollo
├── compose.prod.yml       # Override de producción
├── Makefile               # Atajos para dev/prod
├── .env.dev.example       # Variables de desarrollo (sin secretos reales)
├── .env.prod.example      # Plantilla de variables de producción
├── backend/
│   ├── Dockerfile         # Imagen de producción (multi-stage, usuario no root)
│   ├── Dockerfile.dev     # Imagen de desarrollo (dotnet watch)
│   ├── Fixges.Api/        # Proyecto .NET
│   └── README.md
├── database/
│   ├── Dockerfile         # postgres + scripts de init
│   ├── init/*.sql         # Se ejecutan solo al crear el volumen
│   └── README.md
└── frontend/
    ├── Dockerfile
    ├── nginx.conf         # Sirve el estático y proxea /api
    ├── public/index.html
    └── README.md
```

## Requisitos

- Docker Engine y Docker Compose v2 (`docker compose`).
- Para producción: red externa `red_proxy` y Nginx Proxy Manager ya funcionando
  en el host (no forman parte de este repositorio).

## Desarrollo

```bash
make dev
```

La primera vez copia `.env.dev.example` a `.env.dev` automáticamente.

| Recurso                | URL / conexión                              |
|------------------------|---------------------------------------------|
| Frontend               | http://localhost:80                         |
| API a través de nginx  | http://localhost/api/health                 |
| API directa            | Solo dentro de Docker: `http://backend:8080/health` |
| PostgreSQL desde host  | `127.0.0.1:5432` (credenciales de `.env.dev`) |

Comandos útiles:

```bash
make ps            # estado de los contenedores
make logs          # logs en vivo
make down          # bajar el stack
make reset-dev     # bajar y BORRAR el volumen de PostgreSQL
make config-dev    # validar/mostrar la configuración resultante
```

Sin `make`, el equivalente es:

```bash
docker compose --env-file .env.dev -f compose.yml -f compose.dev.yml up --build
```

Notas de desarrollo:

- El backend corre con `dotnet watch` sobre `./backend` (hot reload).
- El HTML de `frontend/public` se refleja al instante.
- Si cambias `frontend/nginx.conf`, reinicia el servicio:
  `docker compose --env-file .env.dev -f compose.yml -f compose.dev.yml restart frontend`
- El puerto web se puede cambiar con `FRONTEND_PORT` en `.env.dev`.

## Producción

1. Crear el archivo de entorno y cambiar la contraseña:

   ```bash
   cp .env.prod.example .env.prod
   # editar .env.prod y establecer POSTGRES_PASSWORD
   ```

2. Comprobar que existe la red externa creada por Nginx Proxy Manager
   (ya verificada en `ventomarket.store`, donde NPM y `fixware-frontend` la usan):

   ```bash
   docker network inspect red_proxy
   ```

3. Levantar el stack:

   ```bash
   make prod
   ```

4. En Nginx Proxy Manager, crear un *Proxy Host*:

   - Scheme: `http`
   - Forward Hostname / IP: `fixges-web`
   - Forward Port: `80`
   - (El alias `fixges-web` solo existe en la red `red_proxy`.)

En producción:

- El frontend **no publica puertos** en el host; el puerto 80/443 pertenece a NPM.
- PostgreSQL y el backend **no publican ningún puerto**.
- PostgreSQL solo está en `db_net`; el backend en `db_net` + `web_net`.
- El backend no es accesible directamente desde Internet: solo por la red interna
  y, de forma controlada, a través del proxy `/api` del frontend.

Comandos:

```bash
make logs-prod
make down-prod
make config-prod
```

## Diferencia entre development y production

| Aspecto                | Development                              | Production                                  |
|------------------------|------------------------------------------|---------------------------------------------|
| Archivos Compose       | `compose.yml` + `compose.dev.yml`        | `compose.yml` + `compose.prod.yml`          |
| Imagen del backend     | `Dockerfile.dev` (`dotnet watch`)        | `Dockerfile` (Release, usuario no root)     |
| Código                 | Bind mount con hot reload                | Copiado dentro de la imagen                 |
| Puerto del frontend    | `FRONTEND_PORT` (80 por defecto)         | Ninguno; se llega por `red_proxy`           |
| Puerto de PostgreSQL   | `127.0.0.1:5432`                         | Ninguno                                     |
| Red externa `red_proxy`| No                                       | Sí, con alias `fixges-web`                  |
| Reinicio               | Manual                                   | `unless-stopped`                            |
| Variables              | `.env.dev`                               | `.env.prod`                                 |

## Base de datos

Los scripts de `database/init/*.sql` se copian dentro de la imagen y PostgreSQL los
ejecuta **solo la primera vez** que se inicializa el volumen `pgdata`.

Tablas iniciales, un archivo por tabla:

- `usuario`: clientes con datos de contacto, documento opcional y bloqueo.
- `solicitudes`: reparaciones, con FK obligatoria a `usuario` y dirección de
  servicio propia.

Los estados, horarios y métodos de pago usan tipos `ENUM` nativos de PostgreSQL.
El detalle de columnas, restricciones e índices está en `database/README.md`.

- Desarrollo: `make reset-dev` elimina el volumen y fuerza la re-ejecución.
- Producción: **nunca** ejecutar `docker compose ... down -v`; perderías los datos.

## Healthchecks

- Backend: `GET /health` → `Healthy` (200).
- Frontend: `GET /` → 200.
- PostgreSQL: `pg_isready`.

## Seguridad y pendientes

- `.env.dev` y `.env.prod` están ignorados por git; solo se versionan las plantillas.
- Las contraseñas se pasan por variables de entorno. Para endurecer producción se
  puede migrar a Docker secrets o a un gestor de secretos.
- TLS termina en Nginx Proxy Manager.
- Todavía no hay autenticación, CORS ni acceso del frontend a datos reales.
- El único endpoint del backend es `/health`; el resto de la API se añadirá después.
- `/api/*` se publica a través del frontend; al añadir endpoints reales habrá que
  protegerlos con autenticación y validar qué se expone.
