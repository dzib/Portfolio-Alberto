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

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 1. POBLAR DEPARTAMENTOS.
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Departamentos)
        BEGIN
        INSERT INTO Catalogos.Departamentos
            (Nombre, PresupuestoAnual)
        VALUES
            ('Departamento de Ciencias Sociales', 500000.00),
            ('Departamento de Ingenierías', 300000.00),
            ('Departamento de Humanidades y Comunicación', 450000.00),
            ('Departamento de Ciencias Biomédicas', 250000.00);
        PRINT '✅ Catálogo: Departamentos insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 2. POBLAR PROFESORES (Relacionados con Deptos).
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Profesores)
    BEGIN
        INSERT INTO Catalogos.Profesores
            ( Nombre, Email, DeptoID, MetaData_ETL, IsActive, Sexo)
        VALUES
            ('Dr. Julián Pérez', 'julian.perezUNI00@escolar.edu', 1, 'GEN_001 | TIEMPO_COMPLETO', 1 , 'M'),
            ('Mtra. Elena Gómez', 'elena.gomezUNI00@escolar.edu', 1, 'GEN_002 | MEDIO_TIEMPO', 1, 'F'),
            ('Dr. Roberto Isaac', 'roberto.isaacUNI00@escolar.edu', 2, 'GEN_003 | INVITADO', 0, 'M'),
            ('Lic. Ana Martínez', 'ana.martinezUNI00@escolar.edu', 3, 'GEN_004 | TIEMPO_COMPLETO', 1, 'F');
        PRINT '✅ Catálogo: Profesores insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 3. POBLAR CURSOS.
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Cursos)
    BEGIN
        INSERT INTO Catalogos.Cursos
            (Nombre, Descripcion, Creditos, Nivel, DeptoID)
        VALUES
            ('Desarrollo Humano', 'Curso de introductorio al la historia Humana.', 11, 'Introductorio', 1),       -- Ciencias Sociales.
            ('Programación', 'Curso práctico de ingeniería aplicada.', 8, 'Introductorio', 2),                    -- Ingenierías.
            ('Ética Profesional', 'Curso de humanidades y desarollo Profesional.', 9, 'Intermedio', 3),           -- Humanidades.
            ('Biología', 'Curso de ciencias biomédicas y salud.', 10, 'Avanzado', 4)                              -- Ciencias Biomédicas.
        PRINT '✅ Catálogo: Cursos insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 4. RELACIÓN CARRERA-DEPARTAMENTOS.
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Carreras)
    BEGIN
        INSERT INTO Catalogos.Carreras
            (NombreCarrera, DeptoID)
        VALUES
            ('Psicología', 1),                          -- CarreraID = 1 = Departamento de Ciencias Sociales.
            ('Antropología', 1),                        -- CarreraID = 2 = Departamento de Ciencias Sociales.    
            ('Ciencia Política', 1),                    -- CarreraID = 3 = Departamento de Ciencias Sociales.    
            -- 1 = Departamento de Ciencias Sociales.
            ('Ingeniería en Sistemas', 2),              -- CarreraID = 4 = Departamento de Ingenierías.
            ('Ingeniería Industrial', 2),               -- CarreraID = 5 = Departamento de Ingenierías.   
            ('Ingeniería Electrónica', 2),              -- CarreraID = 6 = Departamento de Ingenierías.
            -- 2 = Departamento de Ingenierías.
            ('Comunicación Social', 3),                 -- CarreraID = 7 = Departamento de Humanidades y Comunicación.
            ('Antropología', 3),                            -- CarreraID = 8 = Departamento de Humanidades y Comunicación.
            ('Trabajo Social', 3),                            -- CarreraID = 9 = Departamento de Humanidades y Comunicación.
            -- 3 = Departamento de Humanidades y Comunicación.
            ('Odontología', 4),                         -- CarreraID = 10 = Departamento de Ciencias Biomédicas.
            ('Medicina', 4),                            -- CarreraID = 11 = Departamento de Ciencias Biomédicas.
            ('Nutrición', 4);                           -- CarreraID = 12 = Departamento de Ciencias Biomédicas.
        -- 4 = Departamento de Ciencias Biomédica.
        PRINT '✅ Catálogo: Carreras insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 5. POBLAR ALUMNOS (Dato Maestro con Metadata ETL).
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Alumnos)
    BEGIN
        INSERT INTO Catalogos.Alumnos
            (Nombre, CarreraID, DeptoID, Email, FechaNacimiento, Sexo, MetaData_ETL)
        VALUES
            ('Juan Carlos Luna | VIP', 1, 1, 'juan.lunaUNI_@escolar.edu', '2002-05-15', 'M', '2025-01-10 | Regular | 85.5'),
            ('Sofia Reyes | Beca', 4, 2, 'sofia.reyesUNI_@escolar.edu', '2001-11-20', 'F', '2023-08-15 | Regular | 90.2'),
            ('Andrea Diaz | Beca', 7, 3, 'andrea.diazUNI_@escolar.edu', '2000-01-20', 'F', '2024-06-10 | Irregular | 78.8'),
            ('Miguel Angel Sosa | Deporte', 8, 4, 'migue.sosaUNI_@escolar.edu', '2003-02-10', 'M', '2025-01-10 | Condicionado | 70.4');
        PRINT '✅ Catálogo: Alumnos (Legacy Style) insertado.';
    END

-- -- ---------------------------------------------------------------------------------------------------------
--- -- 6. OPERACIONES (Materias , Inscripciones, Asistencias y Calificaciones).
--- -- ---------------------------------------------------------------------------------------------------------
    DECLARE @CiclosCSV NVARCHAR(400) = '2024-1,2024-2,2025-1,2025-2,2026-1,2026-2';
    -- Convertir CSV de ciclos a tabla
    DECLARE @Ciclos TABLE (CicloEscolar NVARCHAR(20));
    INSERT INTO @Ciclos (CicloEscolar)
    SELECT value FROM STRING_SPLIT(@CiclosCSV, ',');

    -- Grupos A-C
    DECLARE @Grupos TABLE (Grupo NVARCHAR(5));
    INSERT INTO @Grupos (Grupo) VALUES ('A'), ('B');

    IF NOT EXISTS (SELECT 1 FROM Operaciones.Materias)
    BEGIN
    -- Asignar materias a profesores existentes (ejemplo simple).
        INSERT INTO Operaciones.Materias (Nombre, Creditos, ProfesorID, CursoID, CicloEscolar, Grupo)
        SELECT 
            C.Nombre + ' - ' + Cy.value + ' - Grupo ' + G.Grupo + ' - ' + P.Nombre,
            C.Creditos,
            P.ProfesorID,
            C.CursoID,
            Cy.value,
            G.Grupo
        FROM Catalogos.Cursos C
        CROSS JOIN STRING_SPLIT(@CiclosCSV, ',') Cy
        CROSS JOIN @Grupos G
        INNER JOIN Catalogos.Profesores P ON C.DeptoID = P.DeptoID;
        
        PRINT '✅ Operaciones: Materias masivas (con grupos A-B) registradas.';
    END

        IF NOT EXISTS (SELECT 1
    FROM Operaciones.Inscripciones) 
        BEGIN
        INSERT INTO Operaciones.Inscripciones
            (AlumnoID, MateriaID, NotaFinal)
        VALUES
            (1, 1, NULL),
            -- Juan Carlos inscrito en Materia 1
            (1, 2, NULL);
        PRINT '✅ Operaciones: Inscripciones iniciales registradas.';
    END

        IF NOT EXISTS (SELECT 1
    FROM Operaciones.Asistencias)
        BEGIN
        INSERT INTO Operaciones.Asistencias
            (InscripcionID, AlumnoID, CursoID, FechaAsistencia, Presente)
        VALUES
            (1, 1, 1, '2025-01-15', 1),
            (2, 2, 2, '2025-01-15', 1);
        PRINT '✅ Operaciones: Asistencias iniciales registradas.';
    END

        IF NOT EXISTS (SELECT 1
    FROM Operaciones.Calificaciones)  -- Calificaciones registros por parcial (p. ej. Parcial 1, Parcial 2).
        BEGIN
        INSERT INTO Operaciones.Calificaciones
            (InscripcionID, ParcialNumero, Nota, MetaData_ETL)
        VALUES
            (1, 1, 85.00, NULL),
            (1, 2, 95.00, NULL);
        PRINT '✅ Operaciones: Calificaciones parciales registradas.';
    END

---- -- --------------------------------------------------------------------------------------------------------
--- -- 7. ACTUALIZACION DE CONTROL (Checkpoints con los máximos actuales).
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

    MERGE Control.Checkpoints AS CkpI
    USING (SELECT 'Inscripciones' AS Entidad, ISNULL(MAX(InscripcionID),0) AS UltimoID FROM Operaciones.Inscripciones) AS SI
    ON CkpI.Entidad = SI.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = SI.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (SI.Entidad, SI.UltimoID, SYSUTCDATETIME());

    MERGE Control.Checkpoints AS CkpC
    USING (SELECT 'Calificaciones' AS Entidad, ISNULL(MAX(CalificacionID),0) AS UltimoID FROM Operaciones.Calificaciones) AS SCal
    ON CkpC.Entidad = SCal.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = SCal.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (SCal.Entidad, SCal.UltimoID, SYSUTCDATETIME());

    MERGE Control.Checkpoints AS CkpA
    USING (SELECT 'Asistencias' AS Entidad, ISNULL(MAX(AsistenciaID),0) AS UltimoID FROM Operaciones.Asistencias) AS SEn
    ON CkpA.Entidad = SEn.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = SEn.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (SEn.Entidad, SEn.UltimoID, SYSUTCDATETIME());

---- -- --------------------------------------------------------------------------------------------------------
--- -- 8. MÉTRICAS DE EJECUCIÓN.
--- -- ---------------------------------------------------------------------------------------------------------
    PRINT '=========================================================';
    PRINT '✅ Fase 2.2: Datos iniciales de P2 cargados con éxito.';
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