# AGENTS.md

> Contexto operativo para agentes de código. **Lee este archivo antes de explorar el repositorio.**
> No necesitas revisar todos los archivos: aquí está el mapa y las referencias a la documentación detallada.
>
> Última actualización: **2026-10-28**.
>
> **Regla obligatoria:** si un cambio modifica la arquitectura, la infraestructura, el esquema de datos,
> las redes, los puertos, las versiones de imágenes, las variables de entorno o los comandos de arranque,
> actualiza este archivo en el mismo cambio. No dejes `AGENTS.md` desactualizado.

---

## 1. Qué es Fixges

Software de gestión interna para una empresa de servicios técnicos (SAT) de electrónica.

Estado actual: **esqueleto de infraestructura**, no una aplicación funcional.
Hay backend, base de datos y frontend mínimos, pero **no hay lógica de negocio**: no existen CRUD,
autenticación, ni conexión del backend a PostgreSQL.

La documentación detallada está en:

- `README.md` — visión general, arranque y despliegue.
- `backend/README.md` — API y Dockerfiles.
- `database/README.md` — tablas, columnas, ENUM, índices y volumen.
- `frontend/README.md` — nginx, rutas y proxy.

---

## 2. Stack y versiones fijas

**No usar `latest`.** Todas las imágenes están fijadas por parche y variante de sistema operativo.

| Servicio   | Tecnología                              | Imagen / versión                                  | Carpeta     |
|------------|-----------------------------------------|---------------------------------------------------|-------------|
| Backend    | ASP.NET Core Minimal API, .NET 10, C#   | `mcr.microsoft.com/dotnet/sdk:10.0.403-noble`     | `backend/`  |
| Backend    | Runtime                                 | `mcr.microsoft.com/dotnet/aspnet:10.0.9-noble`    | `backend/`  |
| Base datos | PostgreSQL 18                           | `postgres:18.6-alpine3.24`                        | `database/` |
| Frontend   | nginx + HTML estático                   | `nginx:1.30.6-alpine3.24`                         | `frontend/` |
| Orquestación | Docker Compose v2                     | —                                                 | raíz        |

---

## 3. Qué hay y qué no hay

### Hay

- `compose.yml` como base común + `compose.dev.yml` y `compose.prod.yml` como overrides explícitos.
- `Makefile` con atajos `make dev`, `make prod`, `make down`, etc.
- Backend .NET 10 con un único endpoint: `GET /health` → `Healthy` (200).
- PostgreSQL 18 con volumen persistente y scripts de inicialización.
- Dos tablas: `usuario` (clientes) y `solicitudes` (reparaciones).
- Frontend nginx que sirve `index.html` y proxea `/api/*` hacia el backend.
- Healthchecks de Docker para los tres servicios.
- Redes separadas (`db_net`, `web_net`) y red externa `red_proxy` en producción.
- Plantillas de entorno `.env.dev.example` y `.env.prod.example`.

### No hay

- Autenticación, autorización, sesiones, login ni gestión de usuarios de aplicación.
- CRUD ni endpoints de negocio. El único endpoint es `/health`.
- Conexión del backend a PostgreSQL: no hay connection string, Npgsql ni Entity Framework.
- Migraciones de base de datos. Los `.sql` de `database/init/` solo se ejecutan con el volumen vacío.
- Tests unitarios, de integración o E2E.
- CI/CD, pipeline de build, despliegue automatizado ni backups.
- Configuración de Nginx Proxy Manager ni certificados TLS dentro del repositorio.
- Framework de frontend, bundler, router, cliente HTTP ni build de JavaScript.
- CORS, rate limiting, CSRF, OpenAPI/Swagger, métricas o tracing.
- Correo, SMS, subida de archivos o integraciones externas.
- Máquina de estados para `solicitudes.estado`: solo existe el valor por defecto `recibido`.

> Importante: la tabla `usuario` representa **clientes del SAT**, no cuentas de autenticación.

---

## 4. Estructura

```text
.
├── AGENTS.md              # Este archivo
├── README.md              # Documentación general
├── Makefile               # Atajos dev/prod
├── compose.yml            # Base común (no ejecutar solo)
├── compose.dev.yml        # Override de desarrollo
├── compose.prod.yml       # Override de producción
├── .env.dev.example       # Plantilla de desarrollo
├── .env.prod.example      # Plantilla de producción
├── backend/
│   ├── Dockerfile         # Producción: multi-stage, Release, usuario no root
│   ├── Dockerfile.dev     # Desarrollo: SDK + dotnet watch
│   ├── Fixges.Api.sln
│   └── Fixges.Api/
│       ├── Fixges.Api.csproj
│       ├── Program.cs     # Minimal API; solo MapHealthChecks("/health")
│       ├── appsettings*.json
│       └── Properties/launchSettings.json
├── database/
│   ├── Dockerfile         # postgres + copia de init/
│   ├── init/
│   │   ├── 001_usuario.sql       # Tabla usuario + función set_actualizado_en()
│   │   └── 002_solicitudes.sql   # ENUM + tabla solicitudes
│   └── README.md
└── frontend/
    ├── Dockerfile
    ├── nginx.conf         # Estático + proxy /api -> backend:8080
    └── public/index.html  # "Hola mundo"
```

---

## 5. Arranque

### Desarrollo

```bash
make dev
```

- Crea `.env.dev` desde `.env.dev.example` si no existe.
- Usa `compose.yml` + `compose.dev.yml`.
- Proyecto Compose: `fixges-dev`.
- Frontend: `http://localhost:80` (configurable con `FRONTEND_PORT`).
- API vía nginx: `http://localhost/api/health`.
- PostgreSQL desde el host: `127.0.0.1:5432` (credenciales de `.env.dev`).
- Backend con hot reload (`dotnet watch`) y HTML montado desde `frontend/public`.
- Cambios en `frontend/nginx.conf` requieren reiniciar el servicio `frontend`.

### Producción

```bash
cp .env.prod.example .env.prod
# Editar .env.prod y cambiar POSTGRES_PASSWORD
make prod
```

- Usa `compose.yml` + `compose.prod.yml`.
- Proyecto Compose: `fixges-prod`.
- **No publica ningún puerto** de frontend, backend ni PostgreSQL.
- El frontend se une a la red externa `red_proxy` con alias `fixges-web`.
- Nginx Proxy Manager (externo al repo) debe apuntar a `http://fixges-web:80`.
- `make prod` falla si detecta la contraseña de ejemplo `CAMBIAR_ESTA_CLAVE`.

### Reglas de Compose

- `compose.yml` **no está pensado para ejecutarse solo**; siempre se combina con un override.
- Mantener la separación explícita dev/prod. No usar `compose.override.yml` automático.
- No añadir `ports` al backend ni a PostgreSQL en producción.
- No ejecutar `docker compose ... down -v` en producción: borra el volumen de datos.

---

## 6. Topología de red

```text
Internet
  │ 80/443 (TLS termina en NPM)
  ▼
Nginx Proxy Manager  ── red externa red_proxy ──┐
  │ http://fixges-web:80                         │
  ▼                                             │
frontend (nginx)  ── web_net ──  backend:8080   │
  │                                 │           │
  │ /        -> index.html          │           │
  │ /api/*   -> backend:8080/*      │           │
  │                                 ▼           │
  │                              db:5432        │
  │                                 │           │
  └────────────── db_net ───────────┘           │
                                                │
                     frontend también en red_proxy
```

| Red          | Servicios                         | Notas |
|--------------|-----------------------------------|-------|
| `db_net`     | `db`, `backend`                   | PostgreSQL no es accesible desde el frontend |
| `web_net`    | `backend`, `frontend`             | Tráfico interno web/API |
| `red_proxy`  | `frontend` (prod), NPM            | Externa, definida fuera de este repo; alias `fixges-web` |

Reglas:

- El backend **nunca** publica puertos. Solo es accesible por la red interna.
- El backend se alcanza desde Internet únicamente a través de `/api/*` del frontend/NPM.
- PostgreSQL solo está en `db_net`; no lo conectes a `web_net` ni a `red_proxy`.
- Si añades un servicio, decide explícitamente a qué redes pertenece y actualiza esta sección.

---

## 7. Backend

- ASP.NET Core Minimal API, `net10.0`, sin paquetes NuGet externos.
- `Program.cs` solo registra health checks y mapea `GET /health`.
- El healthcheck de Docker usa `curl` contra `http://127.0.0.1:8080/health`; por eso `curl` se instala en las imágenes.
- Producción: `backend/Dockerfile`, build multi-stage, configuración `Release`, usuario no root `$APP_UID`, puerto 8080.
- Desarrollo: `backend/Dockerfile.dev`, SDK completo, `dotnet watch`, código montado desde el host.
- En Compose, `backend` depende de que `db` esté sana, pero **el backend todavía no abre conexión a la base de datos**.
- `ASPNETCORE_ENVIRONMENT` es `Development` en dev y `Production` en prod.
- El backend escucha en `http://+:8080` dentro del contenedor.

Al añadir endpoints:

- Mapearlos en el backend sin el prefijo `/api` si quieres reutilizar el proxy actual (ej. `/solicitudes` se expone como `/api/solicitudes`).
- Si cambias esa convención, actualiza `frontend/nginx.conf`, `frontend/README.md` y este archivo.
- No expongas el backend directamente al host; mantén el acceso por el frontend.

---

## 8. Base de datos

- PostgreSQL 18 con volumen Docker `pgdata`.
- **PostgreSQL 18 cambió `PGDATA`** a `/var/lib/postgresql/18/docker`; por eso el volumen se monta en `/var/lib/postgresql`, no en `/var/lib/postgresql/data`.
- Los scripts de `database/init/*.sql` se copian dentro de la imagen y se ejecutan **solo cuando el volumen está vacío**.
- En desarrollo, `make reset-dev` borra el volumen y fuerza la re-ejecución.
- En producción no hay estrategia de migraciones todavía. Cambiar un `.sql` existente **no actualiza** una base ya inicializada.

### Tablas

- `usuario`: clientes del SAT. ID identity, datos de contacto obligatorios, `dni_nif_cif` y `notas` opcionales, `bloqueado` por defecto `false`.
- `solicitudes`: reparaciones. FK obligatoria `usuario_id` → `usuario(id)` con `ON DELETE RESTRICT`; dispositivo/marca/modelo separados; dirección de servicio propia; `acepta_condiciones` obligatoriamente `true`; `estado` por defecto `recibido`; `pagado` por defecto `false`.

### Tipos ENUM

- `estado_solicitud_enum`: `recibido`, `presupuesto_aceptado`, `reparado`, `cobrado`, `enviado`.
- `horario_preferido_enum`: `manana` (se muestra como “mañana”), `tarde`.
- `metodo_pago_enum`: `bizum`, `tarjeta`, `transferencia`, `contra_reembolso`.

Los valores se guardan sin acentos para simplificar su uso desde la aplicación.

### Restricciones e índices relevantes

- Correo único por `lower(btrim(correo_electronico))`.
- `dni_nif_cif` único por `upper(btrim(...))` cuando no es nulo.
- Código postal español de exactamente 5 dígitos en ambas tablas.
- Precio `NUMERIC(10,2)` no negativo.
- Índices por `solicitudes.usuario_id` y `solicitudes.estado`.
- `creado_en` y `actualizado_en` en ambas tablas; `actualizado_en` se mantiene con el trigger `set_actualizado_en()`.

### Orden de inicialización

Los archivos se ejecutan por orden alfabético. `002_solicitudes.sql` depende de:

- La tabla `usuario` y la función `set_actualizado_en()`, definidas en `001_usuario.sql`.

Si añades tablas, usa el siguiente prefijo numérico (`003_...`) y respeta las dependencias.

### Al cambiar el esquema

1. En desarrollo: añade un nuevo archivo `00X_<tabla>.sql` si es una tabla nueva, o define una estrategia de migración si es un cambio sobre una tabla existente.
2. Actualiza `database/README.md` (columnas, tipos, ENUM, índices).
3. Actualiza la sección de base de datos de este archivo.
4. Recuerda que los scripts init no se re-ejecutan sobre un volumen existente.

---

## 9. Frontend

- nginx fijo en `nginx:1.30.6-alpine3.24`.
- `public/index.html` es HTML estático; no hay framework ni build de JavaScript.
- `nginx.conf` sirve `/` con `try_files` hacia `index.html`.
- `/api/...` se proxea a `http://backend:8080/...` y **elimina el prefijo `/api`**:
  `GET /api/health` → `GET /health` en el backend.
- En desarrollo se montan `public/` y `nginx.conf`; en producción van dentro de la imagen.
- En producción no publica puertos: solo se llega por `red_proxy` con el alias `fixges-web`.

---

## 10. Configuración y secretos

- `.env.dev` y `.env.prod` están ignorados por git.
- Solo se versionan `.env.dev.example` y `.env.prod.example`.
- `make dev` crea `.env.dev` automáticamente si falta.
- `make prod` exige `.env.prod` y rechaza la contraseña de ejemplo.
- No commitear credenciales, tokens, claves SSH ni certificados.
- Si añades una variable de entorno, actualiza la plantilla correspondiente, el Compose y este archivo.

---

## 11. Validación rápida

```bash
# Configuración de desarrollo
docker compose --env-file .env.dev -f compose.yml -f compose.dev.yml config -q

# Configuración de producción (requiere .env.prod)
docker compose --env-file .env.prod -f compose.yml -f compose.prod.yml config -q

# Backend
dotnet build backend/Fixges.Api.sln -c Release

# API local, si tienes el runtime ASP.NET Core instalado
ASPNETCORE_URLS=http://127.0.0.1:5080 \
  dotnet run --project backend/Fixges.Api/Fixges.Api.csproj &
curl -fsS http://127.0.0.1:5080/health
```

Notas:

- El build real de imágenes se hace con `make dev` o `make prod`; no hay pipeline de CI.
- Si el SDK local está incompleto y falla `NETSDK1226`, se puede compilar con
  `-p:AllowMissingPrunePackageData=true`. Dentro de las imágenes de .NET no debería hacer falta.
- La validación de SQL puede hacerse con un parser de PostgreSQL o levantando el stack; no hay servidor local garantizado.

---

## 12. Reglas para cambios arquitectónicos

Antes de terminar cualquier cambio, revisa si afecta a alguno de estos puntos y **actualiza `AGENTS.md` si es así**:

- [ ] Añadir, eliminar o renombrar un servicio, contenedor o carpeta de servicio.
- [ ] Cambiar una imagen, versión, Dockerfile o estrategia dev/prod.
- [ ] Cambiar puertos publicados, redes, alias, dependencias o `depends_on`.
- [ ] Añadir o cambiar variables de entorno, secretos o archivos `.env`.
- [ ] Añadir o modificar tablas, columnas, tipos, ENUM, índices, triggers o restricciones.
- [ ] Introducir un sistema de migraciones (y retirar o adaptar la dependencia de `init/*.sql`).
- [ ] Añadir endpoints, autenticación, CORS, rate limiting u otra capa de API.
- [ ] Cambiar el proxy `/api`, el enrutado de nginx o la exposición pública.
- [ ] Añadir CI/CD, tests, observabilidad, backups o automatización de despliegue.
- [ ] Cambiar los comandos de arranque, validación o despliegue documentados.

Además:

- Mantén las versiones fijas; no introduzcas `latest`.
- No debilites el aislamiento: el backend y PostgreSQL no deben publicar puertos en producción.
- Si una decisión es temporal o queda pendiente, déjala explícita en la sección “Qué hay y qué no hay”.
- Actualiza también la fecha de “Última actualización” al modificar este archivo.
- No dupliques aquí todos los detalles: enlaza a los README de cada servicio y resume solo lo necesario para navegar el proyecto.
