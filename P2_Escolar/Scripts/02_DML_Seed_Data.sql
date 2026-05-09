/* 
===========================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE 2.1: Datos de Control - Seed Data
AUTOR: Alberto Dzib
VERSIÓN: 2.2 (Enterprise Load Simulation)
DESCRIPCIÓN: 
    - Inserción de catálogos base (Departamentos, Profesores, Cursos).
    - Carga de Alumnos con datos compuestos en 'MetaData_ETL' (Fecha | Estatus | Promedio).
    - Registro de transacciones iniciales para validación de PK/FK.
    - Uso de métricas de performance estandarizadas.
============================================================================================================
*/

USE P2_EscolarDB;
GO

SET NOCOUNT ON;
-- Suprime el mensaje: "(1 filas afectadas)".
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();

BEGIN TRY
----------------------------------------------------------------------------------------------------------------
--- -- Control: esquema y tabla de checkpoints (Bandera para el Stress_Test).
----------------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1
        FROM sys.schemas s
        JOIN sys.tables t ON s.schema_id = t.schema_id
        WHERE s.name = 'Control' AND t.name = 'Checkpoints'
    )
    BEGIN
        EXEC('CREATE SCHEMA Control');
        CREATE TABLE Control.Checkpoints (
            Entidad NVARCHAR(50) PRIMARY KEY,
            UltimoID INT NOT NULL DEFAULT(0),
            FechaActualizacion DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
        );
    END;

--- -- ---------------------------------------------------------------------------------------------------------
--- -- Control: Asegurar que Inscripciones tenga CursoID (necesario para FK en Calificaciones).
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID('Operaciones.Inscripciones') AND name = 'CursoID'
    )
    BEGIN
        ALTER TABLE Operaciones.Inscripciones
        ADD CursoID INT NULL;

        ALTER TABLE Operaciones.Inscripciones
        ADD CONSTRAINT FK_Ins_Curso FOREIGN KEY (CursoID) REFERENCES Catalogos.Cursos(CursoID);
    END;
    
--- -- ---------------------------------------------------------------------------------------------------------
--- -- 1. POBLAR DEPARTAMENTOS.
--- -- ---------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1
    FROM Catalogos.Departamentos)
        BEGIN
        INSERT INTO Catalogos.Departamentos
            (Nombre, PresupuestoAnual)
        VALUES
            ('Departamento de Ciencias Sociales', 500000.00),
            ('Departamento de Ingenierías', 300000.00),
            ('Departamento de Humanidades y Comunicación:', 450000.00),
            ('Departamento de Ciencias Biomédicas', 250000.00);
        PRINT '✅ Catálogo: Departamentos insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 2. POBLAR PROFESORES (Relacionados con Deptos).
--- -- ---------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1
    FROM Catalogos.Profesores)
        BEGIN
        INSERT INTO Catalogos.Profesores
            ( Nombre, Email, DeptoID)
        VALUES
            ('Dr. Julián Pérez', 'julian.perez@escolar.edu', 1),
            ('Mtra. Elena Gómez', 'elena.gomez@escolar.edu', 1),
            ('Dr. Roberto Isaac', 'roberto.isaac@escolar.edu', 2),
            ('Lic. Ana Martínez', 'ana.martinez@escolar.edu', 3);
        PRINT '✅ Catálogo: Profesores insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 3. POBLAR CURSOS.
--- -- ---------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1
    FROM Catalogos.Cursos)
        BEGIN
        INSERT INTO Catalogos.Cursos
            (Nombre, Creditos)
        VALUES
            ('Desarrollo Humano', 8),
            ('Programación', 6),
            ('Análisis de Algoritmos', 7),
            ('Ética Profesional', 4);
        PRINT '✅ Catálogo: Cursos insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 4. RELACIÓN CARRERA-DEPARTAMENTOS.
--- -- ---------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1
    FROM Catalogos.Carreras)
        BEGIN
        INSERT INTO Catalogos.Carreras
            (NombreCarrera, DeptoID)
        VALUES
            ('Psicología', 1),
            ('Antropología', 1),
            ('Ciencia Política', 1),
            -- 1 = Departamento de Ciencias Sociales.
            ('Ingeniería en Sistemas', 2),
            ('Ingeniería Industrial', 2),
            ('Ingeniería Electrónica', 2),
            -- 2 = Departamento de Ingenierías.
            ('Comunicación Social', 3),
            ('Historia', 3),
            ('Historia', 3),
            -- 3 = Departamento de Humanidades y Comunicación.
            ('Odontología', 4),
            ('Medicina', 4),
            ('Nutrición', 4);
        -- 4 = Departamento de Ciencias Biomédica.
        PRINT '✅ Catálogo: Carreras insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 5. POBLAR ALUMNOS (Dato Maestro con Metadata ETL).
--- -- ---------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1
    FROM Catalogos.Alumnos)
        BEGIN
        INSERT INTO Catalogos.Alumnos
            (Nombre, CarreraID, Email, FechaNacimiento, MetaData_ETL)
        VALUES
            ('Juan Carlos Luna | VIP', 1, 'juan.luna@test.com', '2002-05-15', '2025-01-10 | Regular | 8.5'),
            ('Sofia Reyes | Beca', 2, 'sofia.reyes@test.com', '2001-11-20', '2023-08-15 | Regular | 9.2'),
            ('Andrea Diaz | Beca', 3, 'andrea.diaz@test.com', '2000-01-20', '2024-06-10 | Irregular | 7.8'),
            ('Miguel Angel Sosa | Deporte', 4, 'migue.sosa@test.com', '2003-02-10', '2025-01-10 | Condicionado | 7.4');
        PRINT '✅ Catálogo: Alumnos (Legacy Style) insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 6. RELACIÓN CURSOS-PROFESORES (Asignación Académica)..
--- -- ---------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1
    FROM Catalogos.CursosProfesores )  -- (Tabla Muchos a Muchos).
        BEGIN
        INSERT INTO Catalogos.CursosProfesores
            (CursoID, ProfesorID, CicloLectivo)
        VALUES
            (1, 1, '2025-1'),
            -- Julián en Psicología en en Desarrollo Humano.
            (2, 2, '2025-1'),
            -- Elena en Ingeniería en Programación.
            (4, 4, '2025-1');
        -- Departamento de Ciencias Biomédica en Etica Profesional.
        PRINT '✅ Relación: Cursos-Profesores establecida.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 7. OPERACIONES (Materias , Inscripciones y Calificaciones).
--- -- ---------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1
    FROM Operaciones.Materias) -- (Uniendo Alumnos con sus Materias).
        BEGIN
            -- Asignar materias a profesores existentes (ejemplo simple)
        INSERT INTO Operaciones.Materias (Nombre, Creditos, ProfesorID)
        SELECT 'Materia ' + CAST(ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS VARCHAR(5)),
            (ABS(CHECKSUM(NEWID())) % 4) + 3,  -- créditos 3-6
            P.ProfesorID
        FROM Catalogos.Profesores P
        WHERE P.ProfesorID IS NOT NULL;
        PRINT '✅ Operaciones: Materias iniciales registradas.';
    END

        IF NOT EXISTS (SELECT 1
    FROM Operaciones.Inscripciones) 
        BEGIN
        INSERT INTO Operaciones.Inscripciones
            (AlumnoID, MateriaID, CicloEscolar, NotaFinal)
        VALUES
            (1, 1, '2025-1', NULL),
            -- Juan Carlos inscrito en Materia 1
            (2, 2, '2025-1', NULL);
        PRINT '✅ Operaciones: Inscripciones iniciales registradas.';
    END

        IF NOT EXISTS (SELECT 1
    FROM Operaciones.Calificaciones)  -- Calificaciones registros por parcial (p. ej. Parcial 1, Parcial 2).
        BEGIN
        INSERT INTO Operaciones.Calificaciones
            (AlumnoID, CursoID, Nota)
        VALUES
            (1, 1, 85.00),
            (2, 2, 95.0);
        PRINT '✅ Operaciones: Calificaciones parciales registradas.';
    END

---- -- --------------------------------------------------------------------------------------------------------
--- -- 8. ACTUALIZACIÓN DE CONTROL (Checkpoints con los máximos actuales).
--- -- ---------------------------------------------------------------------------------------------------------
    -- Alumnos
    MERGE Control.Checkpoints AS C
    USING (SELECT 'Alumnos' AS Entidad, ISNULL(MAX(AlumnoID),0) AS UltimoID FROM Catalogos.Alumnos) AS S
    ON C.Entidad = S.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = S.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (S.Entidad, S.UltimoID, SYSUTCDATETIME());

    -- Profesores
    MERGE Control.Checkpoints AS C
    USING (SELECT 'Profesores' AS Entidad, ISNULL(MAX(ProfesorID),0) AS UltimoID FROM Catalogos.Profesores) AS S
    ON C.Entidad = S.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = S.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (S.Entidad, S.UltimoID, SYSUTCDATETIME());

    -- Cursos
    MERGE Control.Checkpoints AS C
    USING (SELECT 'Cursos' AS Entidad, ISNULL(MAX(CursoID),0) AS UltimoID FROM Catalogos.Cursos) AS S
    ON C.Entidad = S.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = S.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (S.Entidad, S.UltimoID, SYSUTCDATETIME());

    -- Materias
    MERGE Control.Checkpoints AS C
    USING (SELECT 'Materias' AS Entidad, ISNULL(MAX(MateriaID),0) AS UltimoID FROM Operaciones.Materias) AS S
    ON C.Entidad = S.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = S.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (S.Entidad, S.UltimoID, SYSUTCDATETIME());

---- -- --------------------------------------------------------------------------------------------------------
--- -- 9. MÉTRICAS DE EJECUCIÓN.
--- -- ---------------------------------------------------------------------------------------------------------
    PRINT '=========================================================';
    PRINT '✅ Fase 2.1: Datos iniciales de P2 cargados con éxito.';
    PRINT '⏱️ Tiempo de ejecución: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME()) AS VARCHAR) + ' ms.';
    PRINT '=========================================================';

END TRY
BEGIN CATCH
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '❌ Error en Script 02: ' + ERROR_MESSAGE();
    PRINT '📍 Línea: ' + CAST(ERROR_LINE() AS VARCHAR);
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

    IF @@TRANCOUNT > 0 ROLLBACK; -- Seguridad transaccional
END CATCH

GO