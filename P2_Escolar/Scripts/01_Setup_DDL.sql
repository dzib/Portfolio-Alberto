/* 
===========================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 1.1 (SQL) - Arquitectura de Datos e Integridad Referencial
AUTOR: Alberto Dzib
VERSIÓN: 2.2 (Retrofitting)
DESCRIPCIÓN: 
    - Implementación de esquemas segmentados (Catalogos, Operaciones).
    - Implementación de esquemas de generacion y control (Control, Support).
    - Preparación de columnas para normalización 1NF (Metadata_ETL).
    - Aplicación de Constraints Nominados para garantizar la calidad de los datos.
    - Aplicación de estándares PascalCase y Constraints nominados.
    - Aplicación de index para facilitar consultas tipicas.
    - Implementación de DATETIME2 para auditar registros y facilitar procesos de limpieza (Data Cleansing). 
===========================================================================================================
*/

-- ---------------------------------------------------------------------------------------------------------
-- 1. GESTIÓN DE BASE DE DATOS (IDEMPOTENCIA).
-- ---------------------------------------------------------------------------------------------------------
USE master;
GO

SET NOCOUNT gitON;                     -- Para reducir tiempo se suprime el mensaje de "(1 filas afectadas)".

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'P2_EscolarDB')
BEGIN
    ALTER DATABASE P2_EscolarDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE P2_EscolarDB;
END;
GO

CREATE DATABASE P2_EscolarDB;
GO

USE P2_EscolarDB;
GO

-- ---------------------------------------------------------------------------------------------------------
-- 2. CREACIÓN DE ESQUEMAS MAESTROS Y OPERATIVOS.
-- ---------------------------------------------------------------------------------------------------------
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME(); -- Para métricas de tiempo de ejecución.

BEGIN TRY
    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Catalogos')
    BEGIN
        EXEC('CREATE SCHEMA Catalogos');
        PRINT '✅ Esquema [Catalogos] creado.';
    END;

    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Operaciones')
    BEGIN 
        EXEC('CREATE SCHEMA Operaciones');
        PRINT '✅ Esquema [Operaciones] creado.';
    END;

-- -------------------------------------------------------------------------------------------------------------
-- 3. Control: ESQUEMA CONTROL (Banderas de ejecución).
--- ------------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Control')
    BEGIN
        EXEC('CREATE SCHEMA Control');
        PRINT '✅ Esquema [Control] creado.';
    END;

    -- Tabla de logging
    IF OBJECT_ID('Control.LoadLog','U') IS NULL
    BEGIN
        CREATE TABLE Control.LoadLog (
            LoadLogID INT IDENTITY(1,1) PRIMARY KEY,
            RunNumber INT,
            Entidad NVARCHAR(100),
            BatchOffset BIGINT,
            RowsAffected INT,
            Estado NVARCHAR(20),
            Fecha DATETIME2 DEFAULT SYSUTCDATETIME(),
            Mensaje NVARCHAR(4000) NULL,
            DurationMs BIGINT NULL,
            CpuMs BIGINT NULL,
            RowsRead BIGINT NULL,
            RowsWritten BIGINT NULL
        );
        PRINT '✅ Tabla [Control.LoadLog] creada.';
    END;

    -- Tabla de métricas
    IF OBJECT_ID('Control.Metrics','U') IS NULL
    BEGIN
        CREATE TABLE Control.Metrics (
            MetricID INT IDENTITY(1,1) PRIMARY KEY,
            MetricDate DATETIME2,
            MetricName NVARCHAR(200),
            MetricValue SQL_VARIANT,
            Notes NVARCHAR(2000)
        );
        PRINT '✅ Tabla [Control.Metrics] creada.';
    END;

-- -------------------------------------------------------------------------------------------------------------
-- 4. CREAMOS  ESQUEMAS COMO TABLAS DE APOYO PARA LA CARGA DE SEMESTRES Y TEMAS.
--- ------------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Support')
    BEGIN
        EXEC('CREATE SCHEMA Support');
        PRINT '✅ Esquema [Support] creado.';
    END;
    -- Ciclos (persistente)
    IF OBJECT_ID('Support.Ciclos','U') IS NULL
    BEGIN
        CREATE TABLE Support.Ciclos (
            CicloID INT IDENTITY(1,1) PRIMARY KEY,
            Ciclo NVARCHAR(20) NOT NULL UNIQUE,
            FechaInicio DATE NULL,
            FechaFin DATE NULL
        );
        -- (6 ciclos con fechas).
        INSERT INTO Support.Ciclos (Ciclo, FechaInicio, FechaFin)
        VALUES
            ('2024-1', '2024-01-01', '2024-06-30'),
            ('2024-2', '2024-07-01', '2024-12-31'),
            ('2025-1', '2025-01-01', '2025-06-30'),
            ('2025-2', '2025-07-01', '2025-12-31'),
            ('2026-1', '2026-01-01', '2026-06-30'),
            ('2026-2', '2026-07-01', '2026-12-31');

        PRINT '✅ Support.Ciclos creado y poblado.';
    END
    -- Semestres (1..6) mapeados a Ciclos.
    IF OBJECT_ID('Support.Semestres','U') IS NULL
    BEGIN
        CREATE TABLE Support.Semestres (
            SemestreID INT IDENTITY(1,1) PRIMARY KEY,
            SemestreNumero INT NOT NULL UNIQUE,
            CicloID INT NOT NULL REFERENCES Support.Ciclos(CicloID)
        );

        -- Se mapea SemestreNumero 1 al 6 para generar el orden de los ciclos.
        INSERT INTO Support.Semestres (SemestreNumero, CicloID)
        SELECT ROW_NUMBER() OVER (ORDER BY CicloID) AS SemestreNumero, CicloID
        FROM Support.Ciclos
        ORDER BY CicloID;

        PRINT '✅ Support.Semestres creado y poblado (1 al 6).';
    END

    -- Creamos la diversificación de tipos de temas (Teoría Aplicada, Laboratorio, Seminario).
    IF OBJECT_ID('Support.TemaTipos','U') IS NULL
    BEGIN
        CREATE TABLE Support.TemaTipos (
            TemaTipoID INT IDENTITY(1,1) PRIMARY KEY,
            TipoNombre NVARCHAR(100) NOT NULL UNIQUE
        );

        INSERT INTO Support.TemaTipos (TipoNombre)
        VALUES ('Teoría Aplicada'), ('Laboratorio'), ('Seminario');

        PRINT '✅ Support.TemaTipos creado y poblado.';
    END
    -- Temas variantes (estructura vacía; poblado en 02_DML). (estructura, FK a Semestres y TemaTipos, UNIQUE constraint).
    IF OBJECT_ID('Support.TemasVariantes','U') IS NULL
    BEGIN
        CREATE TABLE Support.TemasVariantes (
            TemaVarID INT IDENTITY(1,1) PRIMARY KEY,
            SemestreID INT NOT NULL REFERENCES Support.Semestres(SemestreID),
            TemaTipoID INT NOT NULL REFERENCES Support.TemaTipos(TemaTipoID),
            VarianteIndex INT NOT NULL,
            Nombre NVARCHAR(200) NOT NULL,
            CONSTRAINT UQ_TemaVar UNIQUE (SemestreID, TemaTipoID, VarianteIndex)
        );

        PRINT '✅ Support.TemasVariantes creado (vacío).';
    END

--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 5. UTILIDADES: SEQUENCE y TABLA NUMBERS.
--- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- Paso 5.1. Secuencia genérica para poblar dbo.Numbers
--- -- -------------------------------------------------------------------------------------------------------------------------
-- Se crea una SEQUENCE de Numbers para generar valores únicos y rápidos.
    IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'SeqNumbers' AND schema_id = SCHEMA_ID('dbo'))
    BEGIN
        CREATE SEQUENCE dbo.SeqNumbers
            AS BIGINT
            START WITH 1
            INCREMENT BY 1
            NO CACHE; -- Para el entorno de pruebas evita gaps; en producción se debe considerar CACHE.
    END;
-- -- -------------------------------------------------------------------------------------------------------------------------
-- -- Paso 5.2. Tabla Numbers (universal para generar filas auxiliares) y persistente temporal remplazando a sys.all_columns.
-- -- -------------------------------------------------------------------------------------------------------------------------
    IF OBJECT_ID('dbo.Numbers', 'U') IS NULL
    BEGIN
        CREATE TABLE dbo.Numbers (n BIGINT PRIMARY KEY);
    END;
-- -- -------------------------------------------------------------------------------------------------------------------------
-- -- Paso 5.3. Poblar tabla Numbers con 1 millón de registros.
-- -- -------------------------------------------------------------------------------------------------------------------------
    TRUNCATE TABLE dbo.Numbers;
    ;WITH Tally AS (
        SELECT TOP (1000000)
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
        FROM sys.all_objects a
        CROSS JOIN sys.all_objects b  -- multiplica filas para alcanzar el tamaño deseado
    )
    INSERT INTO dbo.Numbers (n)
    SELECT n FROM Tally;

    PRINT 'Tabla dbo.Numbers poblada con 1,000,000 registros (ROW_NUMBER).';


-- ---------------------------------------------------------------------------------------------------------
-- 6. TABLAS MAESTRAS (ESQUEMA CATALOGOS).
-- ---------------------------------------------------------------------------------------------------------
    CREATE TABLE Catalogos.Departamentos (
        DeptoID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(150) NOT NULL,
        PresupuestoAnual DECIMAL(15,2) CONSTRAINT CHK_PresupuestoPos CHECK (PresupuestoAnual >= 0),
        CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
    );

    CREATE TABLE Catalogos.Profesores (
        ProfesorID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(150) NOT NULL,
        Email NVARCHAR(150) CONSTRAINT UQ_Prof_Email UNIQUE,
        DeptoID INT CONSTRAINT FK_Prof_Depto FOREIGN KEY REFERENCES Catalogos.Departamentos(DeptoID),
        MetaData_ETL NVARCHAR(MAX),
        IsActive BIT DEFAULT 1,
        Sexo CHAR(1) CONSTRAINT CHK_Prof_Sexo CHECK (Sexo IN ('M','F'))
    );

    CREATE INDEX IX_Profesores_Depto 
    ON Catalogos.Profesores(DeptoID);

    CREATE TABLE Catalogos.Carreras (
        CarreraID INT IDENTITY(1,1) PRIMARY KEY,
        NombreCarrera VARCHAR(150) NOT NULL,
        DeptoID INT CONSTRAINT FK_Carreras_Deptos FOREIGN KEY REFERENCES Catalogos.Departamentos(DeptoID)
    ); -- Vinculamos la Carrera al Departamento (Facultad).

    CREATE INDEX IX_Carreras_Depto
    ON Catalogos.Carreras(DeptoID);

    CREATE TABLE Catalogos.Alumnos (
        AlumnoID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(150) NOT NULL,
        CarreraID INT CONSTRAINT FK_Alumnos_Carreras FOREIGN KEY REFERENCES Catalogos.Carreras(CarreraID),
        DeptoID INT CONSTRAINT FK_Alumnos_Deptos FOREIGN KEY REFERENCES Catalogos.Departamentos(DeptoID),
        Email NVARCHAR(150) CONSTRAINT UQ_Alu_Email UNIQUE,
        FechaNacimiento DATE,
        Sexo CHAR(1) CONSTRAINT CHK_Alu_Sexo CHECK (Sexo IN ('M','F')),
        -- Columna Legacy para la Fase 4: FechaIngreso | Estatus | Promedio".
        MetaData_ETL NVARCHAR(MAX),
        -- Columna Destino (single-Pass ETL Ready).
        FechaIngreso DATE,
        EstatusAcademico NVARCHAR(50),
        PromedioHistorico DECIMAL(5,2),
        CreateAt DATETIME2 DEFAULT SYSUTCDATETIME()
    );

    CREATE INDEX IX_Alumnos_Carrera
    ON Catalogos.Alumnos(CarreraID);
    CREATE INDEX IX_Alumnos_Depto
    ON Catalogos.Alumnos(DeptoID);

    -- Cursos oficiales
    CREATE TABLE Catalogos.Cursos (
        CursoID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(150) NOT NULL,
        Descripcion NVARCHAR(300) NOT NULL,
        Creditos INT CONSTRAINT CK_Creditos CHECK (Creditos BETWEEN 6 AND 12),
        Nivel NVARCHAR(50) NOT NULL,
        DeptoID INT NOT NULL CONSTRAINT FK_Cursos_Depto FOREIGN KEY REFERENCES Catalogos.Departamentos(DeptoID)
    );

    CREATE INDEX IX_Cursos_Depto
    ON Catalogos.Cursos(DeptoID);

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 7. TABLAS OPERATIVAS (ESQUEMA OPERACIONES).
--- -- ---------------------------------------------------------------------------------------------------------
    CREATE TABLE Operaciones.Materias (
        MateriaID INT PRIMARY KEY IDENTITY(1,1),
        CursoID INT NOT NULL CONSTRAINT FK_Mat_Curso FOREIGN KEY REFERENCES Catalogos.Cursos(CursoID),
        ProfesorID INT NOT NULL CONSTRAINT FK_Mat_Prof FOREIGN KEY REFERENCES Catalogos.Profesores(ProfesorID),
        CicloEscolar NVARCHAR(20) NOT NULL CONSTRAINT CHK_Mat_Ciclo CHECK (CicloEscolar LIKE '[0-9][0-9][0-9][0-9]-[12]'),
        Grupo NVARCHAR(5) NOT NULL,
        Nombre NVARCHAR(150) NOT NULL,
        Creditos INT CONSTRAINT CHK_Materias_Creditos CHECK (Creditos >= 0),
    );

    CREATE INDEX IX_Materias_Curso 
    ON Operaciones.Materias(CursoID);
    CREATE INDEX IX_Materias_Profesor 
    ON Operaciones.Materias(ProfesorID);
    CREATE INDEX IX_Materias_Ciclo 
    ON Operaciones.Materias(CicloEscolar);

    -- Inscripción de alumno en materia ofertada
    CREATE TABLE Operaciones.Inscripciones (
        InscripcionID INT PRIMARY KEY IDENTITY(1,1),
        AlumnoID INT NOT NULL CONSTRAINT FK_Ins_Alu FOREIGN KEY REFERENCES Catalogos.Alumnos(AlumnoID),
        MateriaID INT NOT NULL CONSTRAINT FK_Ins_Mat FOREIGN KEY REFERENCES Operaciones.Materias(MateriaID),
        NotaFinal DECIMAL(5,2) NULL CONSTRAINT CHK_NotaRange CHECK (NotaFinal BETWEEN 0 AND 100),
        CONSTRAINT UQ_Ins_Alumno_Mat UNIQUE (AlumnoID, MateriaID)
    );

    -- Aplicación de  Índices para rendimiento en joins y búsquedas.
    CREATE INDEX IX_Inscripciones_Alumno
    ON Operaciones.Inscripciones(AlumnoID);
    CREATE INDEX IX_Inscripciones_Materia
    ON Operaciones.Inscripciones(MateriaID);

-- Tabla: una asistencia por día
    CREATE TABLE Operaciones.Asistencias (
        AsistenciaID INT PRIMARY KEY IDENTITY(1,1),
        InscripcionID INT NOT NULL CONSTRAINT FK_Asis_Ins FOREIGN KEY REFERENCES Operaciones.Inscripciones(InscripcionID) ON DELETE CASCADE,
        AlumnoID INT NOT NULL CONSTRAINT FK_Asis_Alu FOREIGN KEY REFERENCES Catalogos.Alumnos(AlumnoID),
        CursoID INT NOT NULL CONSTRAINT FK_Asis_Curso FOREIGN KEY REFERENCES Catalogos.Cursos(CursoID),
        FechaAsistencia DATE NOT NULL DEFAULT CAST(GETDATE() AS DATE),
        Presente BIT DEFAULT 1
    );
    CREATE INDEX IX_Asistencias_Alumno 
    ON Operaciones.Asistencias(AlumnoID);
    CREATE INDEX IX_Asistencias_Curso 
    ON Operaciones.Asistencias(CursoID);
-- Índice único para evitar más de una asistencia por día.
    CREATE UNIQUE INDEX UX_Asistencias_Inscripcion_Dia
    ON Operaciones.Asistencias(InscripcionID, FechaAsistencia);

    -- Calificaciones registros por parcial (p. ej. Parcial 1, Parcial 2).
    CREATE TABLE Operaciones.Calificaciones ( 
        CalificacionID INT IDENTITY(1,1) PRIMARY KEY,
        InscripcionID INT NOT NULL CONSTRAINT FK_Cal_Ins FOREIGN KEY REFERENCES Operaciones.Inscripciones(InscripcionID) ON DELETE CASCADE,
        ParcialNumero TINYINT NOT NULL CONSTRAINT CHK_Cal_Parcial CHECK (ParcialNumero BETWEEN 1 AND 3),
        Nota DECIMAL(5,2) NOT NULL CONSTRAINT CK_Cal_Nota CHECK (Nota BETWEEN 0 AND 100),
        MetaData_ETL NVARCHAR(MAX),
        FechaAplicacion DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_Cal_Ins_Parcial UNIQUE (InscripcionID, ParcialNumero)
    );
    CREATE INDEX IX_Calificaciones_Inscripcion 
    ON Operaciones.Calificaciones(InscripcionID);

    CREATE INDEX IX_Calificaciones_Inscripcion 
    ON Operaciones.Calificaciones(InscripcionID);

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 8. LOG DE EJECUCIÓN Y CIERRE DE BLOQUE
--- -- ---------------------------------------------------------------------------------------------------------
    PRINT '=====================================================';
    PRINT '✅ FASE 1: 🚀 Arquitectura P2_Escolar Creada con Éxito';
    PRINT '⏱️ Tiempo de ejecución: ' + CAST(DATEDIFF(MS, @StartTime, SYSUTCDATETIME()) AS VARCHAR) + ' ms';
    PRINT '=====================================================';

END TRY
BEGIN CATCH
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '❌ Error en la ejecución: ' + ERROR_MESSAGE();
    PRINT '📍 Línea: ' + CAST(ERROR_LINE() AS VARCHAR);
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

    IF @@TRANCOUNT > 0 ROLLBACK; -- Seguridad transaccional
    THROW;
END CATCH;
GO
