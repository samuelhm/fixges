BEGIN;

CREATE OR REPLACE FUNCTION set_actualizado_en()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END;
$$;

CREATE TABLE usuario (
    id                  BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre              TEXT         NOT NULL,
    apellido            TEXT         NOT NULL,
    telefono            VARCHAR(30)  NOT NULL,
    correo_electronico  VARCHAR(254) NOT NULL,
    direccion           TEXT         NOT NULL,
    codigo_postal       VARCHAR(5)   NOT NULL,
    poblacion           TEXT         NOT NULL,
    provincia           TEXT         NOT NULL,
    dni_nif_cif         VARCHAR(20),
    notas               TEXT,
    bloqueado           BOOLEAN      NOT NULL DEFAULT false,
    creado_en           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT ck_usuario_codigo_postal
        CHECK (codigo_postal ~ '^[0-9]{5}$')
);

CREATE UNIQUE INDEX ux_usuario_correo_electronico
    ON usuario (lower(btrim(correo_electronico)));

CREATE UNIQUE INDEX ux_usuario_dni_nif_cif
    ON usuario (upper(btrim(dni_nif_cif)))
    WHERE dni_nif_cif IS NOT NULL;

CREATE TRIGGER trg_usuario_actualizado_en
    BEFORE UPDATE ON usuario
    FOR EACH ROW
    EXECUTE FUNCTION set_actualizado_en();

COMMIT;
