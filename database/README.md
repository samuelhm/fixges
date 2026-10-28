# Base de datos - PostgreSQL 18

Servicio basado en `postgres:18.6-alpine3.24`. No publica puertos en producción.

## Esquema inicial

Un archivo por tabla:

- `001_usuario.sql`: usuarios/clientes y función compartida `set_actualizado_en()`.
- `002_solicitudes.sql`: solicitudes de reparación y sus tipos ENUM.

### `usuario`

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| `id` | `BIGINT` | no | Identity, PK |
| `nombre` | `TEXT` | no | |
| `apellido` | `TEXT` | no | |
| `telefono` | `VARCHAR(30)` | no | Admite prefijos y separadores |
| `correo_electronico` | `VARCHAR(254)` | no | Único sin distinguir mayúsculas |
| `direccion` | `TEXT` | no | |
| `codigo_postal` | `VARCHAR(5)` | no | Exactamente 5 dígitos |
| `poblacion` | `TEXT` | no | |
| `provincia` | `TEXT` | no | |
| `dni_nif_cif` | `VARCHAR(20)` | sí | Único cuando se informa |
| `notas` | `TEXT` | sí | |
| `bloqueado` | `BOOLEAN` | no | Por defecto `false` |
| `creado_en` | `TIMESTAMPTZ` | no | Por defecto `now()` |
| `actualizado_en` | `TIMESTAMPTZ` | no | Actualizado por trigger |

### `solicitudes`

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| `id` | `BIGINT` | no | Identity, PK |
| `usuario_id` | `BIGINT` | no | FK a `usuario(id)`, `ON DELETE RESTRICT` |
| `dispositivo` | `VARCHAR(100)` | no | Tipo de dispositivo |
| `marca` | `VARCHAR(100)` | no | |
| `modelo` | `VARCHAR(100)` | no | |
| `direccion` | `TEXT` | no | Dirección de servicio/recogida |
| `codigo_postal` | `VARCHAR(5)` | no | Exactamente 5 dígitos |
| `poblacion` | `TEXT` | no | |
| `provincia` | `TEXT` | no | |
| `averia` | `TEXT` | no | Descripción de la avería |
| `acepta_condiciones` | `BOOLEAN` | no | Debe ser `true` |
| `horario_preferido` | `horario_preferido_enum` | sí | `manana` o `tarde` |
| `notas_internas` | `TEXT` | sí | |
| `trabajo_realizado` | `TEXT` | sí | |
| `estado` | `estado_solicitud_enum` | no | Por defecto `recibido` |
| `precio_presupuestado` | `NUMERIC(10,2)` | sí | No negativo |
| `metodo_pago` | `metodo_pago_enum` | sí | |
| `pagado` | `BOOLEAN` | no | Por defecto `false` |
| `creado_en` | `TIMESTAMPTZ` | no | Por defecto `now()` |
| `actualizado_en` | `TIMESTAMPTZ` | no | Actualizado por trigger |

### Valores ENUM

- `estado_solicitud_enum`: `recibido`, `presupuesto_aceptado`, `reparado`,
  `cobrado`, `enviado`.
- `horario_preferido_enum`: `manana` (mañana), `tarde`.
- `metodo_pago_enum`: `bizum`, `tarjeta`, `transferencia`, `contra_reembolso`.

Los valores se guardan sin acentos para simplificar su uso desde la aplicación;
las etiquetas visibles se traducen en el frontend.

### Índices

- `ux_usuario_correo_electronico`: único por `lower(btrim(correo))`.
- `ux_usuario_dni_nif_cif`: único por `upper(btrim(dni))` cuando no es nulo.
- `ix_solicitudes_usuario_id`: acelerar la relación con usuario.
- `ix_solicitudes_estado`: filtros por estado.

> El código postal se valida como 5 dígitos (España). Si se necesita soportar
> direcciones internacionales, habrá que relajar esa restricción.

## Inicialización

Los archivos `init/*.sql` se copian a `/docker-entrypoint-initdb.d/` dentro de la
imagen. PostgreSQL los ejecuta, en orden alfabético, **solo cuando el volumen de
datos está vacío** (primera inicialización). En arranques posteriores se ignoran.

Para forzar su re-ejecución en desarrollo:

```bash
make reset-dev
```

> `reset-dev` borra el volumen y todos los datos. No usar en producción.

## Volumen

PostgreSQL 18 cambió `PGDATA` a `/var/lib/postgresql/18/docker`, por eso el
volumen `pgdata` se monta en `/var/lib/postgresql` (directorio padre).

## Conexión

- Desde otro contenedor: host `db`, puerto `5432`.
- Desde el host, solo en desarrollo: `127.0.0.1:5432`.
- Credenciales: variables `POSTGRES_DB`, `POSTGRES_USER` y `POSTGRES_PASSWORD`
  definidas en `.env.dev` / `.env.prod`.

> Las variables `POSTGRES_*` solo se aplican al inicializar el volumen. Si se
> cambian después, el usuario y la contraseña existentes no se modifican.

## Agregar scripts

Crear nuevos archivos en `database/init/` con prefijo numérico, por ejemplo
`003_clientes.sql`. Recordar que solo se ejecutan con el volumen vacío.
