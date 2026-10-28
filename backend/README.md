# Backend - Fixges.Api

API mínima en ASP.NET Core (.NET 10) con un único endpoint de salud.

## Endpoint

| Método | Ruta      | Respuesta          |
|--------|-----------|--------------------|
| GET    | `/health` | `Healthy` (200)    |

También es accesible a través del frontend como `GET /api/health`.

## Imágenes Docker

- `Dockerfile`: producción. Build multi-stage, configuración `Release`, usuario
  no root (`$APP_UID`) y solo el runtime de ASP.NET Core.
- `Dockerfile.dev`: desarrollo. SDK completo + `dotnet watch` sobre el código
  montado desde el host.

## Ejecución local (opcional, sin Docker)

Requiere el SDK de .NET 10:

```bash
dotnet run --project Fixges.Api/Fixges.Api.csproj
# http://localhost:5080/health
```

En el flujo normal no hace falta: `make dev` levanta todo en contenedores.

## Estructura

```text
backend/
├── Dockerfile
├── Dockerfile.dev
├── Fixges.Api.sln
└── Fixges.Api/
    ├── Fixges.Api.csproj
    ├── Program.cs
    ├── appsettings.json
    ├── appsettings.Development.json
    └── Properties/launchSettings.json
```
