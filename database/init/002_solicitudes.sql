BEGIN;

CREATE TYPE estado_solicitud_enum AS ENUM (
    'recibido',
    'presupuesto_aceptado',
    'reparado',
    'cobrado',
    'enviado'
);

CREATE TYPE horario_preferido_enum AS ENUM (
    'manana',
    'tarde'
);

CREATE TYPE metodo_pago_enum AS ENUM (
    'bizum',
    'tarjeta',
    'transferencia',
    'contra_reembolso'
);

CREATE TABLE solicitudes (
    id                   BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id           BIGINT       NOT NULL REFERENCES usuario (id) ON DELETE RESTRICT,
    dispositivo          VARCHAR(100) NOT NULL,
    marca                VARCHAR(100) NOT NULL,
    modelo               VARCHAR(100) NOT NULL,
    direccion            TEXT         NOT NULL,
    codigo_postal        VARCHAR(5)   NOT NULL,
    poblacion            TEXT         NOT NULL,
    provincia            TEXT         NOT NULL,
    averia               TEXT         NOT NULL,
    acepta_condiciones   BOOLEAN      NOT NULL,
    horario_preferido    horario_preferido_enum,
    notas_internas       TEXT,
    trabajo_realizado    TEXT,
    estado               estado_solicitud_enum NOT NULL DEFAULT 'recibido',
    precio_presupuestado NUMERIC(10, 2),
    metodo_pago          metodo_pago_enum,
    pagado               BOOLEAN      NOT NULL DEFAULT false,
    creado_en            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT ck_solicitudes_codigo_postal
        CHECK (codigo_postal ~ '^[0-9]{5}$'),
    CONSTRAINT ck_solicitudes_acepta_condiciones
        CHECK (acepta_condiciones),
    CONSTRAINT ck_solicitudes_precio_presupuestado
        CHECK (precio_presupuestado IS NULL OR precio_presupuestado >= 0)
);

CREATE INDEX ix_solicitudes_usuario_id
    ON solicitudes (usuario_id);

CREATE INDEX ix_solicitudes_estado
    ON solicitudes (estado);

CREATE TRIGGER trg_solicitudes_actualizado_en
    BEFORE UPDATE ON solicitudes
    FOR EACH ROW
    EXECUTE FUNCTION set_actualizado_en();

COMMIT;
