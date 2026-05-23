/* 
==============================================================================================================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 3 -  Stress Test & Data Quality Shield (Parametrizable).
AUTOR: Alberto Dzib
VERSIÓN: 2.3 (Retrofitting) - Script end-to-end para staging
DESCRIPCIÓN: 
    - Script de stress test adaptado para cargas grandes. Procesa inscripciones, asistencias y actualización de NotaFinal en lotes para reducir uso de log y evitar timeouts. 
    - Con generación determinista para asistencias y evita NEWID() en comprobaciones críticas.
    - Generación de datos no atómicos en columna Metadata_ETL para futuro proceso de limpieza.
================================================================================================================================================================================================
*/
USE P2_EscolarDB;
GO
--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- VARIABLES DE BUCLE Y MÉTRICAS PARA CONTROL.
--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET NOCOUNT ON;                                                 -- Para reducir tiempo se suprime el mensaje de "(1 filas afectadas)".
SET XACT_ABORT ON;                                              -- Para asegura que errores aborten la transacción.

-- ===================================
-- Parámetros (CONFIGURACIÓN GLOBAL).
-- ===================================
DECLARE
    @StartTime DATETIME2 = SYSUTCDATETIME(),
<<<<<<< HEAD
    @MaxRuns INT = 1,                                           -- Número de ejecuciones completas (runs).
    @CurrentRun INT = 1,
    @CurrentIterProf INT = 0,
    @TargetNew INT = 10000,                                     -- Objetivo de registros a insertar en el run.
    @BatchSize INT = 20000,                                      -- Parámetros de stress inserción masiva Tamaño de lote para operaciones pesadas.
    @PauseBetweenBatches VARCHAR(8) = '00:00:01';               -- Pausa entre lotes para reducir presión en el log y evitar timeouts Formato hh:mm:ss.
                                                            -- Pausa de 1 segundo entre lotes para reducir presión en el log y evitar timeouts.
>>>>>>> feature/P2-Executive-Diorama
DECLARE
    @InsertedTotalProf INT = 0,
    @InsertedTotalAlu INT = 0,
    @MaxIters INT = 500000,
    @MinAsis INT = 2, @MaxAsis INT = 4,                                                         -- Rango de asistencias por inscripción.
    @MinParciales INT = 2, @MaxParciales INT = 3,                                               -- Rango de parciales por inscripción.
    @TargetNewProf INT = 1000,                                                                  -- Volumen de profesores a generar.
    @TargetCursos INT = 500,                                                                    -- Cantidad de cursos a generar según necesidad.
    @TargetMaterias INT = 1000,                                                                 -- Número objetivo de materias.
    @TargetNewAlu INT = 80000,                                                                  -- Objetivo de carga masiva de alumnos para Inscripciones por run.
    @TargetInscripciones INT = 50000,                                                           -- Objetivo de incripciones total aproximado.
    @CiclosCSV NVARCHAR(400) = '2024-1,2024-2,2025-1,2025-2,2026-1,2026-2',                     -- Ciclos a inyectar en Inscripciones.
    @DefensiveCheckpointValue BIGINT = 0;                                                       -- PRIMERA LECTURA: defensivo = 0.

PRINT '--------------------------------------------------------------------------------------------------';
PRINT '🚀           Iniciando Stress Test en P2_EscolarDB ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
PRINT '--------------------------------------------------------------------------------------------------';
--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- 1. VALIDACIONES DE ESQUEMAS Y TABLAS DE CONTROL.
--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Control')
BEGIN
    RAISERROR('❌ Esquema [Control] faltante. Ejecuta 01_Setup primero.',16,1);
    RETURN;
END;

IF OBJECT_ID('Control.Checkpoints','U') IS NULL
BEGIN
    RAISERROR('❌ Tabla [Control.Checkpoints] faltante. Ejecuta 01_Setup primero.',16,1);
    RETURN;
END;

IF OBJECT_ID('Control.LoadLog','U') IS NULL
BEGIN
    RAISERROR('❌ Tabla [Control.LoadLog] faltante. Ejecuta 01_Setup primero.',16,1);
    RETURN;
END;

IF OBJECT_ID('Control.Metrics','U') IS NULL
BEGIN
    RAISERROR('❌ Tabla [Control.Metrics] faltante. Ejecuta 01_Setup primero.',16,1);
    RETURN;
END;

-- Validaciones de existencia de tablas críticas.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Catalogos')
    OR NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Operaciones')
BEGIN
    RAISERROR('❌ Esquemas [Catalogos] u [Operaciones] faltantes. Ejecuta 01_Setup primero.',16,1);
    RETURN;
END;
--- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- 2. LECTURA INICIAL DE CHECKPOINTS.
--- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- GENERAR UNA PRIMERA LECTURA: checkpoints actuales (defensivo: 0).
SELECT Entidad, ISNULL(UltimoID, @DefensiveCheckpointValue) AS UltimoID
FROM Control.Checkpoints;

--- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3. UTILIDADES: SEQUENCE y TABLA NUMBERS.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- -- Paso 3.1. Secuencia genérica para poblar dbo.Numbers
-- -- -------------------------------------------------------------------------------------------------------------------------
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
-- -- Paso 3.2. Tabla Numbers (universal para generar filas auxiliares) y persistente temporal remplazando a sys.all_columns.
-- -- -------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('dbo.Numbers', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Numbers (n BIGINT PRIMARY KEY);
END;
<<<<<<< HEAD
-- --------------------------------------------------------------------
-- Paso 3.3. Poblar tabla Numbers con 1 millón de registros.
-- --------------------------------------------------------------------
=======
-- -- -------------------------------------------------------------------------------------------------------------------------
    SELECT TOP (1000000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
)
INSERT INTO dbo.Numbers (n)
SELECT n FROM Tally;

PRINT 'Tabla dbo.Numbers poblada con 1,000,000 registros (ROW_NUMBER).';

-- Ajuste Opcional: deshabilitar índices no críticos para acelerar inserciones.
--  Aplicar Ajusta a nombres de índices si decides usarlo. Se debe reconstruir al final.
-- ALTER INDEX ALL ON Catalogos.Alumnos DISABLE;

<<<<<<< HEAD
-- --------------------------------------------------------------------
-- Paso 3.4. GENERACIÓN: De secuencias específicas por entidad manejada.
-- --------------------------------------------------------------------
=======
-- -- --------------------------------------------------------------------------------------------------------------------------
-- -- Paso 3.4. GENERACIÓN: De secuencias específicas por entidad manejada.
-- -- --------------------------------------------------------------------------------------------------------------------------
>>>>>>> feature/P2-Executive-Diorama

-- Alumnos.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'AlumnoSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.AlumnoSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

<<<<<<< HEAD
-- Cursos.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'CursoSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.CursoSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

-- CursosProfesores.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'CursoProfesorSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.CursoProfesorSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;
=======
-- Profesores.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'ProfesorSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.ProfesorSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;
>>>>>>> feature/P2-Executive-Diorama

-- Carreras.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'CarreraSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.CarreraSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

-- Departamentos.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'DepartamentoSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.DepartamentoSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

<<<<<<< HEAD
-- Profesores.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'ProfesorSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.ProfesorSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;
=======
-- Materias.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'MateriaSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.MateriaSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

-- Inscripciones.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'InscripcionSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.InscripcionSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;
>>>>>>> feature/P2-Executive-Diorama

-- Asistencias.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'AsistenciaSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.AsistenciaSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

-- Calificaciones.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'CalificacionSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.CalificacionSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

<<<<<<< HEAD
-- Inscripciones.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'InscripcionSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.InscripcionSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;

-- Materias.
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE name = 'MateriaSeq' AND schema_id = SCHEMA_ID('dbo'))
    CREATE SEQUENCE dbo.MateriaSeq AS BIGINT START WITH 1 INCREMENT BY 1 NO CACHE;


PRINT 'Todas las secuencias específicas creadas correctamente.';
--- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 4. PREPARACIÓN: MATERIALIZAR CATÁLOGOS EN TABLAS TEMPORALES (para determinismo y velocidad).
--- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#CarrList') IS NOT NULL DROP TABLE #CarrList;
SELECT CarreraID, DeptoID, ROW_NUMBER() OVER (ORDER BY CarreraID) AS CarrRow
INTO #CarrList
FROM Catalogos.Carreras;

IF OBJECT_ID('tempdb..#Cursos') IS NOT NULL DROP TABLE #Cursos;
SELECT CursoID, ROW_NUMBER() OVER (ORDER BY CursoID) AS CursoRow
INTO #Cursos
FROM Catalogos.Cursos;

IF OBJECT_ID('tempdb..#Materias') IS NOT NULL DROP TABLE #Materias;
SELECT MateriaID, ROW_NUMBER() OVER (ORDER BY MateriaID) AS MateriaRow
INTO #Materias
FROM Operaciones.Materias;

--Se genera inscripciones deterministas y capturar mapping con OUTPUT INTO #NewIns.
IF OBJECT_ID('tempdb..#NewIns') IS NOT NULL DROP TABLE #NewIns;
CREATE TABLE #NewIns (
    InscripcionID INT,
    AlumnoID INT,
    MateriaID INT,
<<<<<<< HEAD
    CursoID INT,
    CicloEscolar NVARCHAR(20)
=======
>>>>>>> feature/P2-Executive-Diorama
);

DECLARE @CursoCount INT = (SELECT COUNT(*) FROM #Cursos);
DECLARE @MateriaCount INT = (SELECT COUNT(*) FROM #Materias);
DECLARE @CarrCount INT = (SELECT COUNT(*) FROM #CarrList);
DECLARE @NewIns INT = (SELECT COUNT(*) FROM #NewIns);


IF @CarrCount = 0 OR @CursoCount = 0 OR @MateriaCount = 0
BEGIN
    RAISERROR('Faltan catálogos (Carreras/Cursos/Materias). Abortando.',16,1);
    RETURN;
END
<<<<<<< HEAD
PRINT 'Catalogos materializados: Cursos=' + FORMAT(@CursoCount, 'N0') + ' | Materias=' + FORMAT(@MateriaCount, 'N0') + ' | Carreras=' + FORMAT(@CarrCount, 'N0');

-- Temporales de apoyo
IF OBJECT_ID('tempdb..#MatList') IS NOT NULL DROP TABLE #MatList;
SELECT MateriaID, ROW_NUMBER() OVER (ORDER BY MateriaID) AS MatRow INTO #MatList FROM Operaciones.Materias;

IF OBJECT_ID('tempdb..#CursoList') IS NOT NULL DROP TABLE #CursoList;
SELECT CursoID, ROW_NUMBER() OVER (ORDER BY CursoID) AS CursoRow INTO #CursoList FROM Catalogos.Cursos;

IF OBJECT_ID('tempdb..#AluList') IS NOT NULL DROP TABLE #AluList;
SELECT AlumnoID,
    MetaData_ETL,
    ROW_NUMBER() OVER (ORDER BY AlumnoID) AS AluRow
INTO #AluList
FROM Catalogos.Alumnos;

-- Temporal para procesar inscripciónes parciales.
IF OBJECT_ID('tempdb..#ToProcessIns') IS NOT NULL DROP TABLE #ToProcessIns;
CREATE TABLE #ToProcessIns (InscripcionID INT PRIMARY KEY);

--- -------------------------------------------
--- -- 5. OUTER LOOP: runs (1..@MaxRuns).
--- -------------------------------------------
=======
PRINT 'Catalogos materializados: Cursos= ' + FORMAT(@CursoCount, 'N0') + ' | Materias= ' + FORMAT(@MateriaCount, 'N0') + ' | Carreras= ' + FORMAT(@CarrCount, 'N0');
--- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 5. OUTER LOOP: runs (1..@MaxRuns).
--- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
>>>>>>> feature/P2-Executive-Diorama
WHILE @CurrentRun <= @MaxRuns
BEGIN
    PRINT '-------------------------------------------------------------------------------------------------------------------------------------------';
    PRINT '     Iniciando Run ' + CAST(@CurrentRun AS VARCHAR(3)) + ' de ' + CAST(@MaxRuns AS VARCHAR(3)) + ' - ' + CONVERT(VARCHAR(30), SYSUTCDATETIME());
    PRINT '-------------------------------------------------------------------------------------------------------------------------------------------';

--- -- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 6. POBLADO: Departamentos con PresupuestoAnual. (Idempotente: solo inserta si no existe).
--- -- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    DECLARE @StartBatchDep DATETIME2 = SYSUTCDATETIME();

<<<<<<< HEAD
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 6. POBLADO: Departamentos con PresupuestoAnual. (Idempotente: solo inserta si no existe).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
=======
>>>>>>> feature/P2-Executive-Diorama
    BEGIN TRAN;
    BEGIN TRY
        PRINT '------------------------------------------------------------------------------------------------------------------------------------------';
        PRINT '🏢           Diversificando de Departamentos..' + CAST(SYSUTCDATETIME() AS VARCHAR);
        PRINT '------------------------------------------------------------------------------------------------------------------------------------------';

        IF NOT EXISTS (SELECT 1 FROM Catalogos.Departamentos WHERE Nombre IN (
            'Departamento de Ciencias Exactas y Naturales',
            'Departamento de Ciencias Económico-Administrativas',
            'Departamento de Artes y Diseño',
            'Departamento de Ciencias de la Salud Pública')
            )
        BEGIN
            INSERT INTO Catalogos.Departamentos (Nombre, PresupuestoAnual) VALUES
                ('Departamento de Ciencias Exactas y Naturales', 800000),
                ('Departamento de Ciencias Económico-Administrativas', 200000),
                ('Departamento de Artes y Diseño', 450000),
                ('Departamento de Ciencias de la Salud Pública', 150000);
        END
        DECLARE @DeptCount INT = (SELECT COUNT(*) FROM Catalogos.Departamentos);
<<<<<<< HEAD
        PRINT 'Departamentos actuales: ' + FORMAT(@DeptCount, 'N0') + ' (idempotente)';
        COMMIT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
        VALUES (@CurrentRun, 'Departamentos', 0, 1, 'COMMIT', 'Departamentos idempotentes creados');
=======
        PRINT 'Total de Departamentos: ' + FORMAT(@DeptCount, 'N0') + ' (idempotente)';
        
        DECLARE @RowsThisDep INT = @@ROWCOUNT;
        
        DECLARE @EndBatchDep DATETIME2 = SYSUTCDATETIME();
        DECLARE @DurationMsDep INT = DATEDIFF(MILLISECOND, @StartBatchDep, @EndBatchDep);
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje, DurationMs)
        VALUES (@CurrentRun, 'Departamentos', @DeptCount , @RowsThisDep, 'COMMIT', 'Departamentos idempotentes creados', @DurationMsDep);
        COMMIT;

>>>>>>> feature/P2-Executive-Diorama
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
        VALUES (@CurrentRun, 'Departamentos', 0, 0, 'ROLLBACK', ERROR_MESSAGE());
        THROW;
    END CATCH;

<<<<<<< HEAD
--- -------------------------------------------------------------------------
--- -- 7. GENERACIÓN DE PROFESORES (idempotente).
--- -------------------------------------------------------------------------
    -- Generación de profesores segura y por lotes.
    DECLARE @Entidad NVARCHAR(50) = 'Profesores';
    DECLARE @SeqName NVARCHAR(100) = 'dbo.ProfesorSeq';
    -- Calcular cuántos ya existen con prefijo de stress.
    DECLARE @Already INT = (SELECT COUNT(*) FROM Catalogos.Profesores WHERE Email LIKE '%prof%@escolar.edu');
    DECLARE @RemainingProf INT = CASE WHEN @TargetNewProf > @Already THEN @TargetNewProf - @Already ELSE 0 END;

    WHILE @RemainingProf > 0 AND @CurrentIterProf < @MaxIters
    BEGIN
=======
--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 7. GENERACIÓN DE CARRERAS.
--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '------------------------------------------------------------';
    PRINT '🎓        Insertando nuevas Carreras ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
    PRINT '------------------------------------------------------------';

    IF NOT EXISTS (SELECT 1 FROM Catalogos.Carreras WHERE DeptoID IN (5,6,7,8))
    BEGIN
        INSERT INTO Catalogos.Carreras (NombreCarrera, DeptoID)
        VALUES
            -- Departamento 5: Ciencias Exactas y Naturales
            ('Matemáticas', 5),
            ('Física', 5),
            ('Química', 5),

            -- Departamento 6: Ciencias Económico-Administrativas
            ('Economía y Finanzas', 6),
            ('Contaduría', 6),
            ('Administración de Empresas', 6),

            -- Departamento 7: Artes y Diseño
            ('Artes Visuales', 7),
            ('Diseño Gráfico', 7),
            ('Arquitectura', 7),

            -- Departamento 8: Ciencias de la Salud Pública
            ('Salud Ambiental', 8),
            ('Epidemiología', 8),
            ('Enfermería', 8);

        PRINT '✅ Catálogo: Carreras nuevas insertadas.';
    END
    ELSE
    BEGIN
        PRINT 'ℹ️     Carreras nuevas ya existen, no se insertaron duplicados.';

        TRUNCATE TABLE #CarrList;
        INSERT INTO #CarrList (CarreraID, DeptoID, CarrRow)
        SELECT CarreraID, DeptoID,
            ROW_NUMBER() OVER (ORDER BY CarreraID) AS CarrRow
        FROM Catalogos.Carreras

    END;

    -- Logging.
    INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
    VALUES (@CurrentRun, 'Carreras', (SELECT COUNT(*) FROM Catalogos.Carreras), 
            (SELECT COUNT(*) FROM Catalogos.Carreras WHERE DeptoID IN (5,6,7,8)), 
            'COMMIT', SYSUTCDATETIME(), 'Carreras nuevas insertadas para Deptos 5–8');

--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 8. GENERACIÓN DE PROFESORES (idempotente).
--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Generación de profesores segura y por lotes.
    DECLARE @Entidad NVARCHAR(50) = 'Profesores';
    DECLARE @SeqName NVARCHAR(100) = 'dbo.ProfesorSeq';
    -- Calcular cuántos ya existen con prefijo de stress.
    DECLARE @Already INT = (SELECT COUNT(*) FROM Catalogos.Profesores);
    DECLARE @RemainingProf INT = CASE WHEN @TargetNewProf > @Already THEN @TargetNewProf - @Already ELSE 0 END;

    WHILE @RemainingProf > 0 AND @CurrentIterProf < @MaxIters
        BEGIN
>>>>>>> feature/P2-Executive-Diorama
        SET @CurrentIterProf += 1;
        DECLARE @ThisBatchProf INT = CASE WHEN @RemainingProf < @BatchSize THEN @RemainingProf ELSE @BatchSize END;
        DECLARE @StartBatchProf DATETIME2 = SYSUTCDATETIME();

        -- Se reserva rango de IDs de la secuencia.
        DECLARE @RangeStartProf sql_variant, @RangeLastProf sql_variant;
        DECLARE @RangeStartBigintProf BIGINT, @RangeLastBigintProf BIGINT;

        EXEC sp_sequence_get_range 
            @sequence_name = @SeqName,
            @range_size = @ThisBatchProf,
            @range_first_value = @RangeStartProf OUTPUT,
            @range_last_value = @RangeLastProf OUTPUT;
        
        SET @RangeStartBigintProf = CONVERT(BIGINT, @RangeStartProf);
        SET @RangeLastBigintProf  = CONVERT(BIGINT, @RangeLastProf);

        BEGIN TRAN;
        BEGIN TRY
<<<<<<< HEAD
=======
            PRINT '----------------------------------------------------------------';
            PRINT '         Carga de Profesores ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
            PRINT '----------------------------------------------------------------'

            DECLARE @NombreBaseProf NVARCHAR(50) = ISNULL(CHOOSE(FLOOR(RAND()*2)+1, 'Profesor', 'Doctor'), 'Maestro');

>>>>>>> feature/P2-Executive-Diorama
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchProf) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM dbo.Numbers
            )
            INSERT INTO Catalogos.Profesores (Nombre, Email, DeptoID, MetaData_ETL, IsActive, Sexo)
            SELECT
                    @NombreBaseProf + '_ID_' + CAST(@RangeStartBigintProf + t.rn - 1 AS VARCHAR(20)) AS Nombre,
<<<<<<< HEAD
                    LOWER(@NombreBaseProf) + CAST(@RangeStartBigintProf + t.rn - 1 AS VARCHAR(20)) + '@escolar.edu' AS Email,
=======
                    LOWER(@NombreBaseProf) + 'UNI_' + CAST(@RangeStartBigintProf + t.rn - 1 AS VARCHAR(20)) + '@escolar.edu' AS Email,
>>>>>>> feature/P2-Executive-Diorama
                    ((t.rn - 1) % (SELECT COUNT(*) FROM Catalogos.Departamentos)) + 1 AS DeptoID,
                    CONCAT(
                        'GEN_', CAST(@RangeStartBigintProf + t.rn - 1 AS VARCHAR(20)),
                        ' | ',
                        CASE ((ABS(CHECKSUM(@RangeStartBigintProf + t.rn - 1)) % 3))
                            WHEN 0 THEN 'TIEMPO_COMPLETO' 
                            WHEN 1 THEN 'MEDIO_TIEMPO' 
                            ELSE 'INVITADO'
                        END
                    ) AS MetaData_ETL,
                    CASE ((ABS(CHECKSUM(@RangeStartBigintProf + t.rn - 1)) % 3))
                        WHEN 2 THEN 0 ELSE 1 END AS IsActive,  -- Invitados = 0, demás = 1.
                    CASE ((ABS(CHECKSUM(@RangeStartBigintProf + t.rn - 1)) % 2))
                        WHEN 0 THEN 'M' ELSE 'F' END AS Sexo   -- Aleatorio M/F.
                FROM ToGen t;
            
            DECLARE @RowsThisProf INT = @@ROWCOUNT;
            SET @InsertedTotalProf += @RowsThisProf;
            SET @RemainingProf -= @RowsThisProf;
            -- Actuakizar Logging.
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, @Entidad, @InsertedTotalProf, @RowsThisProf, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @CurrentIterProf, ' Target=', @TargetNewProf, ' Remaining=', @RemainingProf));
<<<<<<< HEAD
            DECLARE @LogID INT = SCOPE_IDENTITY();
=======
            DECLARE @LogIDProf INT = SCOPE_IDENTITY();
>>>>>>> feature/P2-Executive-Diorama

            COMMIT;

            DECLARE @EndBatchProf DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsProf INT = DATEDIFF(MILLISECOND, @StartBatchProf, @EndBatchProf);
<<<<<<< HEAD
            UPDATE Control.LoadLog SET DurationMs = @DurationMsProf WHERE LoadLogID = @LogID;

            PRINT 'Profesores insertados: ' + CAST(@RowsThisProf AS VARCHAR(10)) + 
                ' | Total: ' + CAST(@InsertedTotalProf AS VARCHAR(10)) + 
=======
            UPDATE Control.LoadLog SET DurationMs = @DurationMsProf WHERE LoadLogID = @LogIDProf;

            PRINT 'Profesores insertados: ' + FORMAT(@RowsThisProf, 'N0') + 
                ' | Total: ' + FORMAT(@InsertedTotalProf, 'N0') + 
>>>>>>> feature/P2-Executive-Diorama
                ' | Iter ' + CAST(@CurrentIterProf AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, @Entidad, @InsertedTotalProf, 0, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            PRINT 'ERROR en batch Profesores: ' + ERROR_MESSAGE();
<<<<<<< HEAD
=======
            THROW;
        END CATCH;
    END

    IF @RemainingProf > 0 AND @CurrentIterProf >= @MaxIters
        BEGIN
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, @Entidad, @InsertedTotalProf, @InsertedTotalProf, 'PARTIAL', SYSUTCDATETIME(),
                CONCAT('Max iterations reached=', @MaxIters, ' Remaining=', @RemainingProf));
        RAISERROR('Máximo de iteraciones alcanzado en carga de Profesores. Remaining=%d', 16, 1, @RemainingProf);
    END

    PRINT 'Carga Profesores finalizada. Total insertados: ' + FORMAT(@InsertedTotalProf,'N0') + ' Remaining=' + FORMAT(@RemainingProf,'N0');

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 9. DIVERSIFICACIÓN DE CURSOS CON NIVELES Y CARRERAS.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ============================
-- PREPARAR LISTAS AUXILIARES.
-- ============================
        -- Verificar dbo.Numbers existe y tiene suficientes filas
    IF OBJECT_ID('dbo.Numbers','U') IS NULL
        BEGIN
        RAISERROR('dbo.Numbers no existe. Crea y pobla dbo.Numbers antes de ejecutar este script.',16,1);
        RETURN;
    END;
-- Se aplican lista de departamentos (orden determinista).
    IF OBJECT_ID('tempdb..#DeptList') IS NOT NULL DROP TABLE #DeptList;
    SELECT DeptoID, ROW_NUMBER() OVER (ORDER BY DeptoID) AS DeptRow
    INTO #DeptList
    FROM Catalogos.Departamentos;

-- Lista de profesores activos con su carga actual (nº de materias asignadas).
    IF OBJECT_ID('tempdb..#ProfList') IS NOT NULL DROP TABLE #ProfList;
    SELECT 
        p.ProfesorID,
        p.DeptoID,
        p.Nombre,
        ROW_NUMBER() OVER (PARTITION BY p.DeptoID ORDER BY p.ProfesorID) AS ProfRow,
        COUNT(*) OVER (PARTITION BY p.DeptoID) AS ProfCountPerDept,
        ISNULL(m.MatCount, 0) AS CurrentMatCount
    INTO #ProfList
    FROM Catalogos.Profesores p
    LEFT JOIN (
        SELECT ProfesorID, COUNT(*) AS MatCount
        FROM Operaciones.Materias
        GROUP BY ProfesorID
    ) m ON m.ProfesorID = p.ProfesorID
    WHERE ISNULL(p.IsActive,1) = 1;  -- Para garantizar solo profesores activos.

-- Si no hay profesores, abortar para Materias.
    IF NOT EXISTS (SELECT 1 FROM #ProfList)
                BEGIN
        RAISERROR('No hay profesores activos para asignar materias. Crea profesores antes de ejecutar.', 16, 1);
            RETURN;
    END;
    
    PRINT '------------------------------------------------------------------------------------------------';
    PRINT '🏫           Diversificación de Cursos ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
    PRINT '------------------------------------------------------------------------------------------------';
    -- =============
    -- CURSOS.
    -- =============
    DECLARE @AlreadyCursos INT = (SELECT COUNT(*) FROM Catalogos.Cursos);
    DECLARE @RemainingCursos INT = CASE WHEN @TargetCursos > @AlreadyCursos THEN @TargetCursos - @AlreadyCursos ELSE 0 END;
    DECLARE @InsertedCursos INT = 0, @IterCursos INT = 0;

    WHILE @RemainingCursos > 0 AND @IterCursos < @MaxIters
        BEGIN
        SET @IterCursos += 1;
        DECLARE @ThisBatchCur INT = CASE WHEN @RemainingCursos < @BatchSize THEN @RemainingCursos ELSE @BatchSize END;
        DECLARE @StartBatchCur DATETIME2 = SYSUTCDATETIME();
        
        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchCur) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM dbo.Numbers
            )
            INSERT INTO Catalogos.Cursos (Nombre, Descripcion, Creditos, Nivel, DeptoID)
            SELECT
                CASE c.DeptoID
                    WHEN 1 THEN CONCAT('Desarrollo Humano - ', c.NombreCarrera)
                    WHEN 2 THEN CONCAT('Programación - ', c.NombreCarrera)
                    WHEN 3 THEN CONCAT('Ética Profesional - ', c.NombreCarrera)
                    WHEN 4 THEN CONCAT('Biología - ', c.NombreCarrera)
                    WHEN 5 THEN CONCAT('Métodos Numericos - ', c.NombreCarrera)
                    WHEN 6 THEN CONCAT('Contabilidad - ', c.NombreCarrera)
                    WHEN 7 THEN CONCAT('Dibujo - ', c.NombreCarrera)
                    WHEN 8 THEN CONCAT('Botánica - ', c.NombreCarrera)
                END AS Nombre,
                CASE c.DeptoID
                    WHEN 1 THEN 'Curso de introductorio al la historia Humana.'
                    WHEN 2 THEN 'Curso práctico de ingeniería aplicada.'
                    WHEN 3 THEN 'Curso de humanidades y desarollo Profesional.'
                    WHEN 4 THEN 'Curso de ciencias biomédicas y salud.'
                    WHEN 5 THEN 'Curso de ciencias exactas y naturales.'
                    WHEN 6 THEN 'Curso de economía y administración.'
                    WHEN 7 THEN 'Curso de artes visuales y diseño.'
                    WHEN 8 THEN 'Curso de salud pública y epidemiología.'
                END AS Descripcion,
                ((ABS(CHECKSUM(c.CarreraID + n.rn)) % 7) + 6) AS Creditos,  -- rango 6–12
                CASE ((ABS(CHECKSUM(c.CarreraID + n.rn))) % 3)
                    WHEN 0 THEN 'Introductorio'
                    WHEN 1 THEN 'Intermedio'
                    WHEN 2 THEN 'Avanzado'
                END AS Nivel,
                c.DeptoID
            FROM Catalogos.Carreras c
            CROSS APPLY (SELECT TOP 3 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn FROM dbo.Numbers) n; -- 3 cursos por carrera.

            DECLARE @RowsThisCur INT = @@ROWCOUNT;
            SET @InsertedCursos += @RowsThisCur;
            SET @RemainingCursos -= @RowsThisCur;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Cursos', @InsertedCursos, @RowsThisCur, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterCursos, ' Target=', @TargetCursos, ' Remaining=', @RemainingCursos));
            DECLARE @LogIDCur INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchCur DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsCur INT = DATEDIFF(MILLISECOND, @StartBatchCur, @EndBatchCur);
            UPDATE Control.LoadLog SET DurationMs = @DurationMsCur WHERE LoadLogID = @LogIDCur;

            PRINT 'Cursos insertados: ' + CAST(@RowsThisCur AS VARCHAR(10)) + ' | Total Cursos: ' + CAST(@InsertedCursos AS VARCHAR(10));
            IF @RowsThisCur = 0 BREAK; -- 🔒 Para evitar bucles infinitos.
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Cursos', @InsertedCursos, 0, 'ROLLBACK', SYSUTCDATETIME() ,CONCAT('Error generando Cursos: ', @err));
            RAISERROR('Error generando Cursos: %s',16,1,@err);
        END CATCH;
    END
    
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 10. GENERACIÓN DE MATERIAS DIVERSIFICADAS CON CICLOS, GRUPOS Y BALANCEO ROUND-ROBIN.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    -- ==============================================================
    -- MATERIAS (IDENTITY) - (con balanceo round‑robin por profesor).
    -- ==============================================================
    PRINT '-----------------------------------------------------------------------------';
    PRINT '📘       Generando Materias Congruentes ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
    PRINT '-----------------------------------------------------------------------------';
    DECLARE @AlreadyMaterias INT = (SELECT COUNT(*) FROM Operaciones.Materias);
    DECLARE @RemainingMaterias INT = CASE WHEN @TargetMaterias > @AlreadyMaterias THEN @TargetMaterias - @AlreadyMaterias ELSE 0 END;
    DECLARE @InsertedMaterias INT = 0, @IterMaterias INT = 0;

    -- Definir grupos A-C.
    DECLARE @Grupos TABLE (Grupo NVARCHAR(5));
    INSERT INTO @Grupos VALUES ('A'), ('B'), ('C');

    WHILE @RemainingMaterias > 0 AND @IterMaterias < @MaxIters
    BEGIN
        SET @IterMaterias += 1;
        DECLARE @ThisBatchMat INT = CASE WHEN @RemainingMaterias < @BatchSize THEN @RemainingMaterias ELSE @BatchSize END;
        DECLARE @StartBatchMat DATETIME2 = SYSUTCDATETIME();

        -- Tabla temporal para capturar incrementos por profesor en este batch.
        IF OBJECT_ID('tempdb..#InsertedProfCounts') IS NOT NULL DROP TABLE #InsertedProfCounts;
        CREATE TABLE #InsertedProfCounts (ProfesorID INT, Inc INT);

        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchMat) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM dbo.Numbers
            ),
            ProfPick AS (
                SELECT p.ProfesorID, p.DeptoID, p.Nombre,
                    ROW_NUMBER() OVER (PARTITION BY p.DeptoID ORDER BY p.CurrentMatCount, p.ProfesorID) AS ProfRow,
                    COUNT(*) OVER (PARTITION BY p.DeptoID) AS ProfCountPerDept
                FROM #ProfList p
            )
            INSERT INTO Operaciones.Materias (Nombre, Creditos, ProfesorID, CursoID, CicloEscolar, Grupo)
            OUTPUT inserted.ProfesorID, 1 INTO #InsertedProfCounts(ProfesorID, Inc)
            SELECT
                CONCAT(c.Nombre, ' - ', cy.value, ' - Grupo ', g.Grupo,' - ', p.Nombre) AS Nombre,
                c.Creditos, -- Se toman los valores de cursos.
                p.ProfesorID,
                c.CursoID,
                cy.value AS CicloEscolar,
                g.Grupo
            FROM Catalogos.Cursos c
            CROSS JOIN STRING_SPLIT(@CiclosCSV, ',') cy
            CROSS JOIN @Grupos g
            INNER JOIN ProfPick p ON p.DeptoID = c.DeptoID
            WHERE p.ProfRow = ((ABS(CHECKSUM(c.CursoID + CHECKSUM(cy.value) + CHECKSUM(g.Grupo))) % p.ProfCountPerDept) + 1)
                AND NOT EXISTS (
                    SELECT 1 FROM Operaciones.Materias m
                    WHERE m.CursoID = c.CursoID AND m.CicloEscolar = cy.value AND m.Grupo = g.Grupo AND m.ProfesorID = p.ProfesorID
                );

            DECLARE @RowsThisMat INT = @@ROWCOUNT;
            SET @InsertedMaterias += @RowsThisMat;
            SET @RemainingMaterias -= @RowsThisMat;

            -- Sumar incrementos por profesor y actualizar (round‑robin balanceado).
            ;WITH Incs AS (
                SELECT ProfesorID, SUM(Inc) AS IncCount
                FROM #InsertedProfCounts
                GROUP BY ProfesorID
            ),
            UpdatedLoads AS (
                SELECT pl.ProfesorID,
                    pl.DeptoID,
                    pl.Nombre,
                    pl.CurrentMatCount + ISNULL(i.IncCount, 0) AS NewLoad
                FROM #ProfList pl
                LEFT JOIN Incs i ON i.ProfesorID = pl.ProfesorID
            )
            -- Reconstruir #ProfList con nuevo orden por carga (menor carga primero).
            INSERT INTO #ProfList (ProfesorID, DeptoID, Nombre, ProfRow, ProfCountPerDept, CurrentMatCount)
            SELECT ProfesorID, DeptoID, Nombre,
                ROW_NUMBER() OVER (PARTITION BY DeptoID ORDER BY NewLoad, ProfesorID) AS ProfRow,
                COUNT(*) OVER (PARTITION BY DeptoID) AS ProfCountPerDept,
                NewLoad AS CurrentMatCount
            FROM UpdatedLoads;
            -- Logging del batch.
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Materias', @InsertedMaterias, @RowsThisMat, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterMaterias, ' Target=', @TargetMaterias, ' Remaining=', @RemainingMaterias));
            DECLARE @LogIDMat INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchMat DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsMat INT = DATEDIFF(MILLISECOND, @StartBatchMat, @EndBatchMat);
            UPDATE Control.LoadLog SET DurationMs = @DurationMsMat WHERE LoadLogID = @LogIDMat;

            PRINT 'Materias insertadas: ' + FORMAT(@RowsThisMat, 'N0') + ' | Total Materias: ' + FORMAT(@InsertedMaterias, 'N0');
            IF @RowsThisMat = 0 BREAK; -- 🔒 Para evitar bucles infinitos.
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            DECLARE @err2 NVARCHAR(4000) = ERROR_MESSAGE();
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Materias', @InsertedMaterias, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error generando materias: ', @err2));
            RAISERROR('Error generando Materias: %s',16,1,@err2);
    END CATCH;
    END

    PRINT 'Diversificación finalizada. Cursos insertados: ' + FORMAT(@InsertedCursos, 'N0') +
        ' | Materias insertadas: ' + FORMAT(@InsertedMaterias, 'N0');

    -- Limpieza de temporales
    IF OBJECT_ID('tempdb..#DeptList') IS NOT NULL DROP TABLE #DeptList;
    IF OBJECT_ID('tempdb..#ProfList') IS NOT NULL DROP TABLE #ProfList;
    IF OBJECT_ID('tempdb..#InsertedProfCounts') IS NOT NULL DROP TABLE #InsertedProfCounts;


--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 9. CARGA MASIVA DE ALUMNOS ( Usando sp_sequence_get_range (con conversión sql_variant -> bigint).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '----------------------------------------------------------------------------';
    PRINT '🚀         Generando alumnos ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
    PRINT '----------------------------------------------------------------------------';
    -- Asume que: dbo.Numbers, dbo.AlumnoSeq, #CarrList y Control.LoadLog existen y parámetros globales están definidos.
    -- Cuenta cuántos alumnos ya existen con el prefijo de stress (Para ajusta el filtro).
    DECLARE @NombreBase NVARCHAR(50) = 'UNI_'; -- Prefijo base para Nombre/Email.
    DECLARE @EmailDomain NVARCHAR(100) = '@escolar.edu';
    DECLARE @SeqNameAlu NVARCHAR(128) = N'dbo.AlumnoSeq';

    IF OBJECT_ID('dbo.Numbers','U') IS NULL
    BEGIN
        RAISERROR('dbo.Numbers no existe. Crea y pobla dbo.Numbers antes de ejecutar este script.',16,1);
        RETURN;
    END;

    -- Calcular cuántos ya existen con prefijo de stress.
    DECLARE @AlreadyAlu INT = (SELECT COUNT(*) FROM Catalogos.Alumnos);
    DECLARE @RemainingAlu INT = CASE WHEN @TargetNewAlu > @AlreadyAlu THEN @TargetNewAlu - @AlreadyAlu ELSE 0 END;

    PRINT 'Inicio carga Alumnos. Objetivo: ' + FORMAT(@TargetNewAlu, 'N0') + ' | Ya existen: ' + CAST(@AlreadyAlu AS VARCHAR(20));

    -- Loop controlado por objetivo y tope de iteraciones.
    WHILE @RemainingAlu > 0 AND @CurrentIterAlu < @MaxIters
    BEGIN
        SET @CurrentIterAlu += 1;
        DECLARE @ThisBatchAlu INT = CASE WHEN @RemainingAlu < @BatchSize THEN @RemainingAlu ELSE @BatchSize END;
        DECLARE @StartBatchAlu DATETIME2 = SYSUTCDATETIME();

        -- Reservamnos un rango de la sequencia en una sola llamada (outputs sql_variant).
        DECLARE @RangeStartAlu sql_variant, @RangeLastAlu sql_variant;
        DECLARE @RangeStartBigintAlu BIGINT, @RangeLastBigintAlu BIGINT;

        EXEC sp_sequence_get_range 
            @sequence_name = @SeqNameAlu,
            @range_size = @ThisBatchAlu ,
            @range_first_value = @RangeStartAlu OUTPUT,
            @range_last_value = @RangeLastAlu OUTPUT;

        -- Conversión explícita a BIGINT y uso exclusivo de las variables BIGINT.
        SET @RangeStartBigintAlu = CONVERT(BIGINT, @RangeStartAlu);
        SET @RangeLastBigintAlu  = CONVERT(BIGINT, @RangeLastAlu);

        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchAlu ) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM dbo.Numbers
            )
            INSERT INTO Catalogos.Alumnos (Nombre, CarreraID, DeptoID, Email, FechaNacimiento, Sexo, MetaData_ETL)
            SELECT
                @NombreBase + CAST(@RangeStartBigintAlu + t.rn - 1 AS VARCHAR(20)) AS Nombre,
                C.CarreraID,
                C.DeptoID,
                LOWER(@NombreBase) + CAST(@RangeStartBigintAlu + t.rn - 1 AS VARCHAR(20)) + @EmailDomain AS Email,
                CAST(DATEADD(DAY, -((ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1)) % 36500)), GETDATE()) AS DATE) AS FechaNacimiento,
                CASE (ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1 + 999)) % 2) WHEN 0 THEN 'M' ELSE 'F' END AS Sexo,
                -- MetaData_ETL consolida FechaIngreso | Estatus | Promedio para normalizar en Fase 4
                CONCAT(
                    CONVERT(VARCHAR(10), CAST(DATEADD(DAY, -((ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1 + 12345)) % 3650)), GETDATE()) AS DATE), 23),
                    ' | ',
                    CASE (ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1)) % 6)
                        WHEN 0 THEN 'ACTIVO' WHEN 1 THEN 'IRREGULAR' WHEN 2 THEN 'CONDICIONAL'
                        WHEN 3 THEN 'BAJA_TEMP' WHEN 4 THEN 'BAJA_DEFI' WHEN 5 THEN 'EGRESADO' END,
                    ' | ',
                    CAST( ( (ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1 + 54321)) % 401) / 100.0 ) + 6.00 AS VARCHAR(15))
                ) AS MetaData_ETL
            FROM ToGen t
            CROSS APPLY (SELECT ((t.rn - 1) % (SELECT COUNT(*) FROM #CarrList)) + 1 AS CarrRowCalc) rc
            JOIN #CarrList C ON C.CarrRow = rc.CarrRowCalc
            WHERE NOT EXISTS (
                SELECT 1 FROM Catalogos.Alumnos A
                WHERE A.Email = LOWER(@NombreBase) + CAST(@RangeStartBigintAlu + t.rn - 1 AS VARCHAR(20)) + @EmailDomain
            );

            DECLARE @RowsThisAlu INT = @@ROWCOUNT;
            SET @InsertedTotalAlu += @RowsThisAlu;
            SET @RemainingAlu -= @RowsThisAlu;
            -- Log con duración del batch (inserta y luego actualiza DurationMs).
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Alumnos', @InsertedTotalAlu, @RowsThisAlu, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @CurrentIterAlu, ' Target=', @TargetNewAlu, ' Remaining=', @RemainingAlu));
            DECLARE @LogIDAlu INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchAlu DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsAlu INT = DATEDIFF(MILLISECOND, @StartBatchAlu, @EndBatchAlu);

            -- Actualizar el registro de log con duración.
            UPDATE Control.LoadLog SET DurationMs = @DurationMsAlu WHERE LoadLogID = @LogIDAlu;

            PRINT 'Alumnos insertados en batch: ' + FORMAT(@RowsThisAlu, 'N0') +
                ' | Total insertados: ' + FORMAT(@InsertedTotalAlu, 'N0') +
                ' | Iter ' + CAST(@CurrentIterAlu AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Alumnos', @InsertedTotalAlu, 0, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            THROW;
        END CATCH;
    END
    -- Se deben Reconstruir índices si fueron deshabilitados.
    -- ALTER INDEX ALL ON Catalogos.Alumnos REBUILD;
    -- Aplicamos una seguridad adicional: si alcanzamos tope de iteraciones sin completar objetivo, loguear y alertar.
    IF @RemainingAlu > 0 AND @CurrentIterAlu >= @MaxIters
    BEGIN
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Alumnos', @InsertedTotalAlu, @InsertedTotalAlu, 'PARTIAL', SYSUTCDATETIME(),
                CONCAT('Max iterations reached=', @MaxIters, ' Remaining=', @RemainingAlu));
        RAISERROR('Máximo de iteraciones alcanzado en carga de alumnos. Remaining=%d', 16, 1, @RemainingAlu);
    END
    PRINT 'Carga Alumnos finalizada. Total insertados en este run: ' + FORMAT(@InsertedTotalAlu,'N0') + ' | Remaining=' + FORMAT(@RemainingAlu,'N0');

    IF OBJECT_ID('tempdb..#CarrList') IS NOT NULL DROP TABLE #CarrList;

--- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 11. GENERAR INSCRIPCIONES MASIVAS POR LOTES (OUTPUT -> #NewIns) SEGÚN ESTATUS DEL ALUMNO..
--- -- Usasando el Estatus desde CursosCount según MetaData_ETL para decidir cantidad de inscripciones por alumno. ACTIVO=6, IRREGULAR=4 a 5, CONDICIONAL=3 a 4 , EGRESADO/BAJA_TEMP/BAJA_DEFI -> 0
--- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Se distribuye inscripciones entre varios CiclosEscolares (lista parametrizable).
    -- Buscando evitar duplicados (AlumnoID, MateriaID, CursoID, CicloEscolar).
    PRINT '--------------------------------------------------------------------------------------------------';
    PRINT '🚀         Iniciando Inscripciones ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
    PRINT '--------------------------------------------------------------------------------------------------';

    -- Temporales de apoyo
    IF OBJECT_ID('tempdb..#AluList') IS NOT NULL DROP TABLE #AluList;
    SELECT AlumnoID, MetaData_ETL,
        UPPER(REPLACE(PARSENAME(REPLACE(MetaData_ETL,'|','.'),2),' ','')) AS EstatusNorm,
        ROW_NUMBER() OVER (ORDER BY AlumnoID) AS AluRow
    INTO #AluList
    FROM Catalogos.Alumnos;

    IF OBJECT_ID('tempdb..#MatList') IS NOT NULL DROP TABLE #MatList;
    SELECT MateriaID, CursoID, CicloEscolar,
        ROW_NUMBER() OVER (ORDER BY MateriaID) AS MatRow
    INTO #MatList
    FROM Operaciones.Materias;

    DECLARE @AluCount INT = (SELECT COUNT(*) FROM #AluList);
    DECLARE @MatCount INT = (SELECT COUNT(*) FROM #MatList);

    -- Control.
    DECLARE @AlreadyIns INT = (SELECT COUNT(*) FROM Operaciones.Inscripciones);
    DECLARE @RemainingIns INT = CASE WHEN @TargetInscripciones > @AlreadyIns THEN @TargetInscripciones - @AlreadyIns ELSE 0 END;
    DECLARE @InsertedIns INT = 0, @IterIns INT = 0;

    PRINT 'Inicio Inscripciónes. Objetivo: ' + FORMAT(@TargetInscripciones, 'N0') + ' | Ya existen: ' + CAST(@AlreadyIns AS VARCHAR(20));

-- Ayuda: análisis en de acuerdo a función del Estatus desde MetaData_ETL (simple, busca token).
-- Nota : MetaData_ETL tiene formato "FechaIngreso | ESTATUS | Promedio"
    WHILE @RemainingIns > 0 AND @IterIns < @MaxIters
    BEGIN
        SET @IterIns += 1;
        DECLARE @StartBatchIns DATETIME2 = SYSUTCDATETIME();

        BEGIN TRAN;
        BEGIN TRY
            ;WITH AluPlan AS (
                SELECT AlumnoID,
                    CASE EstatusNorm
                            WHEN 'ACTIVO' THEN 6
                            WHEN 'IRREGULAR' THEN ((ABS(CHECKSUM(AlumnoID)) % 2) + 4)
                            WHEN 'CONDICIONAL' THEN ((ABS(CHECKSUM(AlumnoID+7)) % 2) + 3)
                            ELSE 0
                    END AS NumMaterias
                FROM #AluList
            ),
            Expand AS (
                SELECT ap.AlumnoID, v.Seq
                FROM AluPlan ap
                CROSS APPLY (SELECT TOP (ap.NumMaterias) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Seq) v
            ),
            MapToMat AS (
                SELECT e.AlumnoID,
                    ((ABS(CHECKSUM(e.AlumnoID + e.Seq))) % (SELECT COUNT(*) FROM #MatList)) + 1 AS MatRowCalc
                FROM Expand e
            )
            INSERT INTO Operaciones.Inscripciones (AlumnoID, MateriaID, NotaFinal)
            OUTPUT inserted.InscripcionID, inserted.AlumnoID, inserted.MateriaID INTO #NewIns
            SELECT DISTINCT A.AlumnoID, M.MateriaID, NULL
            FROM MapToMat mt
            JOIN #AluList A ON A.AlumnoID = mt.AlumnoID
            JOIN #MatList M ON M.MatRow = mt.MatRowCalc
            WHERE NOT EXISTS (
                SELECT 1 FROM Operaciones.Inscripciones i
                WHERE i.AlumnoID = A.AlumnoID AND i.MateriaID = M.MateriaID
            );

            DECLARE @RowsThisIns INT = @@ROWCOUNT;
            SET @InsertedIns += @RowsThisIns;
            SET @RemainingIns -= @RowsThisIns;
            -- Log y checkpoint.
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Inscripciones',  @InsertedIns, @RowsThisIns, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterIns, ' TargetApprox=',  @TargetInscripciones, ' Remaining=', @RemainingIns));
            DECLARE @LogIDIns INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchIns DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsIns INT = DATEDIFF(MILLISECOND, @StartBatchIns, @EndBatchIns);
            UPDATE Control.LoadLog SET DurationMs = @DurationMsIns WHERE LoadLogID = @LogIDIns;

            PRINT '✅ Inscripciones insertadas en batch: ' + FORMAT(@RowsThisIns ,'N0') +
                ' | Total insertadas: ' + FORMAT(@InsertedIns,'N0') +
                ' | Iter ' + CAST(@IterIns AS VARCHAR(10));
            IF @RowsThisIns = 0 BREAK; -- 🔒 Para evitar bucles infinitos.
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            DECLARE @errIns NVARCHAR(4000) = ERROR_MESSAGE();
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Inscripciones', @InsertedIns, 0, 'ROLLBACK', SYSUTCDATETIME(),  CONCAT('Error generando Inscripciones: ', @errIns));
            RAISERROR('❌ Error generando Inscripciones: %s',16,1,@errIns);
        END CATCH;

    END
    PRINT 'Inscripciones generadas totales (aprox): ' + FORMAT(@InsertedIns, 'N0');

--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 12. INSERCION DE CALIFICACIÓNES PARCIALES POR INSCRIPCIONID (1-3 parciales por inscripción, evitando duplicados).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Se calcula NotaFinal como promedio simple y se actualiza en Operaciones.Inscripciones.
    PRINT '-----------------------------------------------------------------------------------------------';
    PRINT '📝           Generando Calificaciones Parciales ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
    PRINT '-----------------------------------------------------------------------------------------------';

    DECLARE @BatchSizeCal INT = 50000;
    DECLARE @MaxItersCal INT = 200000;
    
    -- Asegurar #NewInsCal existe (si no, tomar inscripciones recientes).
    IF OBJECT_ID('tempdb..#NewInsCal') IS NULL
    BEGIN
        SELECT TOP (100000) InscripcionID, AlumnoID, MateriaID INTO #NewInsCal
        FROM Operaciones.Inscripciones
        ORDER BY InscripcionID DESC;
    END;

    -- Lista de inscripciones a procesar (evita duplicados).
    IF OBJECT_ID('tempdb..#ToProcessIns') IS NOT NULL DROP TABLE #ToProcessIns;
    SELECT InscripcionID INTO #ToProcessIns
    FROM #NewInsCal
    WHERE InscripcionID NOT IN (SELECT DISTINCT InscripcionID FROM Operaciones.Calificaciones);

    
    DECLARE @TotalToProc INT = (SELECT COUNT(*) FROM #ToProcessIns);
    DECLARE @Processed INT = 0, @IterCal INT = 0;

    PRINT 'Inicio Calificaciones. Objetivo: ' + FORMAT(@TotalToProc,'N0');

    WHILE @Processed < @TotalToProc AND @IterCal < @MaxItersCal
    BEGIN
        SET @IterCal += 1;
        DECLARE @ThisBatchCal INT = CASE WHEN (@TotalToProc - @Processed) < @BatchSizeCal THEN (@TotalToProc - @Processed) ELSE @BatchSizeCal END;
        DECLARE @StartBatchCal DATETIME2 = SYSUTCDATETIME();
        
        BEGIN TRAN;
        BEGIN TRY
            ;WITH Pick AS (
                SELECT TOP (@ThisBatchCal) InscripcionID FROM #ToProcessIns ORDER BY InscripcionID
            ),
            GenPar AS (
                SELECT p.InscripcionID,
                    ((ABS(CHECKSUM(p.InscripcionID)) % 3) + 2) AS ParcalesToCreate -- Cada inscripción recibe entre 2 y 3 parciales generados determinísticamente.
                FROM Pick p
            ),
            Expand AS (
                SELECT g.InscripcionID, v.ParcialNum
                FROM GenPar g
                CROSS APPLY (VALUES (1),(2),(3)) v(ParcialNum)
                WHERE v.ParcialNum <= g.ParcalesToCreate
            )
            -- Insertar parciales evitando duplicados.
            INSERT INTO Operaciones.Calificaciones (InscripcionID, ParcialNumero, Nota, MetaData_ETL)
            SELECT e.InscripcionID, e.ParcialNumero,
                CAST(((ABS(CHECKSUM(e.InscripcionID + e.ParcialNumero)) % 401) / 100.0) + 6.00 AS DECIMAL(5,2)) AS Nota,
                CONCAT('GEN_CAL|P', e.ParcialNumero, '|I', CAST(e.InscripcionID AS VARCHAR(20))) AS MetaData_ETL
            FROM Expand e
            WHERE NOT EXISTS (
                SELECT 1 FROM Operaciones.Calificaciones c
                WHERE c.InscripcionID = e.InscripcionID AND c.ParcialNumero = e.ParcialNumero
            );

            -- Calcular NotaFinal como promedio simple de parciales insertados.
            ;WITH NewAvg AS (
                SELECT c.InscripcionID, AVG(CAST(c.Nota AS FLOAT)) AS AvgCal
                FROM Operaciones.Calificaciones c
                WHERE c.InscripcionID IN (SELECT InscripcionID FROM Pick)
                GROUP BY c.InscripcionID
            )
            UPDATE i
            SET i.NotaFinal = CAST(na.AvgCal AS DECIMAL(5,2))
            FROM Operaciones.Inscripciones i
            JOIN NewAvg na ON na.InscripcionID = i.InscripcionID;

            DECLARE @RowsCal INT = @@ROWCOUNT;
            SET @Processed += @ThisBatchCal;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Calificaciones', @Processed, @RowsCal, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterCal, ' BatchIns=', @ThisBatchCal, ' RowsCal=', @RowsCal));
            DECLARE @LogIDCal INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchCal DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsCal INT = DATEDIFF(MILLISECOND, @StartBatchCal, @EndBatchCal);
            UPDATE Control.LoadLog SET DurationMs = @DurationMsCal WHERE LoadLogID = @LogIDCal;

            PRINT 'Calificaciones insertadas en batch: ' + FORMAT(@RowsCal,'N0') +
                    ' | Total procesadas: ' + FORMAT(@Processed,'N0') +
                    ' | Iter ' + CAST(@IterCal AS VARCHAR(10));
            IF @RowsCal = 0 BREAK;
            WAITFOR DELAY @PauseBetweenBatches;

        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
                INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
                VALUES (@CurrentRun, 'Calificaciones', @Processed, 0, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            THROW;
        END CATCH;

    END

    PRINT 'Calificaciones procesadas totales (aprox): ' + CAST(@Processed AS VARCHAR(20));

--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 13. GENERAR ASISTENCIAS DETERMINISTAS POR LOTES (USANDO #NewIns PARA CONTROL DE FK).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '-----------------------------------------------------------------------------';
    PRINT '📅           Generando Asistencias ... ' + CAST(SYSUTCDATETIME() AS VARCHAR);
    PRINT '-----------------------------------------------------------------------------';

    DECLARE @SessionsPerIns INT = 12;  -- Sesiones por inscripción.
    DECLARE @BatchSizeAsis INT = @BatchSize;
    DECLARE @PauseBetweenBatchesAsis TIME = '00:00:01';
    DECLARE @CurrentRunAsis INT = 1;

    DECLARE @TotalIns INT = (SELECT COUNT(*) FROM #NewIns);
    DECLARE @ProcessedIns INT = 0, @IterAsis INT = 0;

    WHILE @ProcessedIns < @TotalIns AND @IterAsis < @MaxIters
    BEGIN
        SET @IterAsis += 1;
        DECLARE @ThisBatchAsis INT = CASE WHEN (@TotalIns - @ProcessedIns) < @BatchSizeAsis THEN (@TotalIns - @ProcessedIns) ELSE @BatchSizeAsis END;
        DECLARE @RowsAsis INT = 0;
        DECLARE @StartBatchAsis DATETIME2 = SYSUTCDATETIME();

        BEGIN TRAN;
        BEGIN TRY
            ;WITH Pick AS (
                SELECT TOP (@ThisBatchAsis) NI.InscripcionID, NI.AlumnoID, NI.MateriaID
                FROM #NewIns NI
                WHERE NI.InscripcionID NOT IN (SELECT DISTINCT InscripcionID FROM Operaciones.Asistencias)
                ORDER BY NI.InscripcionID
            ),
            MatInfo AS (
            SELECT p.InscripcionID, p.AlumnoID, p.MateriaID,
                    m.CursoID, m.CicloEscolar,
                    CASE WHEN RIGHT(m.CicloEscolar,1)='1'
                            THEN DATEFROMPARTS(CAST(LEFT(m.CicloEscolar,4) AS INT),1,1)
                            ELSE DATEFROMPARTS(CAST(LEFT(m.CicloEscolar,4) AS INT),7,1) END AS SemInicio,
                    CASE WHEN RIGHT(m.CicloEscolar,1)='1'
                            THEN DATEFROMPARTS(CAST(LEFT(m.CicloEscolar,4) AS INT),6,30)
                            ELSE DATEFROMPARTS(CAST(LEFT(m.CicloEscolar,4) AS INT),12,31) END AS SemFin
                FROM Pick p
                JOIN Operaciones.Materias m ON p.MateriaID = m.MateriaID
            ),
            Sessions AS (
                SELECT mi.InscripcionID, mi.AlumnoID, mi.MateriaID, mi.CursoID,
                    DATEADD(DAY, v.SessionOffset, mi.SemInicio) AS Fecha,
                    CASE WHEN (ABS(CHECKSUM(mi.InscripcionID + v.SessionOffset)) % 100) < 85 THEN 1 ELSE 0 END AS Presente -- Probabilidad de asistencia determinista (85% presente).
                FROM MatInfo mi
                CROSS APPLY (
                    SELECT TOP (@SessionsPerIns) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS SessionOffset
                    FROM dbo.Numbers
                ) v
                WHERE DATEADD(DAY, v.SessionOffset, mi.SemInicio) <= mi.SemFin
            )
            INSERT INTO Operaciones.Asistencias (InscripcionID, AlumnoID, CursoID, FechaAsistencia, Presente)
            SELECT s.InscripcionID, s.AlumnoID, s.CursoID, s.Fecha, s.Presente
            FROM Sessions s
            WHERE NOT EXISTS (
                SELECT 1 FROM Operaciones.Asistencias a
                WHERE a.InscripcionID = s.InscripcionID AND a.FechaAsistencia = s.Fecha
            );

            SET @RowsAsis = @@ROWCOUNT;
            SET @ProcessedIns += @ThisBatchAsis;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunAsis, 'Asistencias', @ProcessedIns, @RowsAsis, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterAsis, ' BatchIns=', @ThisBatchAsis, ' RowsAsis=', @RowsAsis));
            DECLARE @LogIDAsis INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchAsis DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsAsis INT = DATEDIFF(MILLISECOND, @StartBatchAsis, @EndBatchAsis);
            UPDATE Control.LoadLog SET DurationMs = @DurationMsAsis WHERE LoadLogID = @LogIDAsis;

            PRINT 'Asistencias insertadas en batch: ' + FORMAT(@RowsAsis,'N0') +
                ' | Total procesadas: ' + FORMAT(@ProcessedIns,'N0') +
                ' | Iter ' + CAST(@IterAsis AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunAsis, 'Asistencias', @ProcessedIns, @RowsAsis, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            PRINT 'ERROR en batch Asistencias: ' + ERROR_MESSAGE();
>>>>>>> feature/P2-Executive-Diorama
            THROW;
        END CATCH;
    END
    PRINT 'Asistencias generadas totales (aprox): ' + CAST(@ProcessedIns * @SessionsPerIns AS VARCHAR(20));

<<<<<<< HEAD
    IF @RemainingProf > 0 AND @CurrentIterProf >= @MaxIters
    BEGIN
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, @Entidad, @InsertedTotalProf, @InsertedTotalProf, 'PARTIAL', SYSUTCDATETIME(),
                CONCAT('Max iterations reached=', @MaxIters, ' Remaining=', @RemainingProf));
        RAISERROR('Máximo de iteraciones alcanzado en carga de Profesores. Remaining=%d', 16, 1, @RemainingProf);
    END

    PRINT 'Carga Profesores finalizada. Total insertados: ' + FORMAT(@InsertedTotalProf,'N0') + ' Remaining=' + FORMAT(@RemainingProf,'N0');

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 8. DIVERSIFICACIÓN DE CURSOS Y MATERIAS.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- ============================
-- PREPARAR LISTAS AUXILIARES.
-- ============================
        -- Verificar dbo.Numbers existe y tiene suficientes filas
    IF OBJECT_ID('dbo.Numbers','U') IS NULL
    BEGIN
        RAISERROR('dbo.Numbers no existe. Crea y pobla dbo.Numbers antes de ejecutar este script.',16,1);
        RETURN;
    END;
-- Se aplican lista de departamentos (orden determinista).
    IF OBJECT_ID('tempdb..#DeptList') IS NOT NULL DROP TABLE #DeptList;
    SELECT DeptoID, ROW_NUMBER() OVER (ORDER BY DeptoID) AS DeptRow
    INTO #DeptList
    FROM Catalogos.Departamentos;

-- Lista de profesores activos con su carga actual (nº de materias asignadas)
    IF OBJECT_ID('tempdb..#ProfList') IS NOT NULL DROP TABLE #ProfList;
    SELECT 
        p.ProfesorID,
        p.DeptoID,
        ROW_NUMBER() OVER (PARTITION BY p.DeptoID ORDER BY p.ProfesorID) AS ProfRow,
        COUNT(*) OVER (PARTITION BY p.DeptoID) AS ProfCountPerDept,
        ISNULL(m.MatCount, 0) AS CurrentMatCount
    INTO #ProfList
    FROM Catalogos.Profesores p
    LEFT JOIN (
        SELECT ProfesorID, COUNT(*) AS MatCount
        FROM Operaciones.Materias
        GROUP BY ProfesorID
    ) m ON m.ProfesorID = p.ProfesorID
    WHERE ISNULL(p.IsActive,1) = 1;  -- Para garantizar solo profesores activos.

-- Si no hay profesores, abortar para Materias,
    IF NOT EXISTS (SELECT 1 FROM #ProfList)
    BEGIN
        RAISERROR('No hay profesores activos para asignar materias. Crea profesores antes de ejecutar.', 16, 1);
        RETURN;
    END;
    
    -- =============
    -- CURSOS.
    -- =============
    DECLARE @AlreadyCursos INT = (SELECT COUNT(*) FROM Catalogos.Cursos);
    DECLARE @RemainingCursos INT = CASE WHEN @TargetCursos > @AlreadyCursos THEN @TargetCursos - @AlreadyCursos ELSE 0 END;
    DECLARE @InsertedCursos INT = 0, @IterCursos INT = 0;

    WHILE @RemainingCursos > 0 AND @IterCursos < @MaxIters
    BEGIN
        SET @IterCursos += 1;
        DECLARE @ThisBatchCur INT = CASE WHEN @RemainingCursos < @BatchSize THEN @RemainingCursos ELSE @BatchSize END;
        DECLARE @StartBatchCur DATETIME2 = SYSUTCDATETIME();
        
        -- Reservar rango para nombres (no para IDENTITY).
        DECLARE @RangeStartCur sql_variant, @RangeLastCur sql_variant;
        DECLARE @RangeStartBigintCur BIGINT;

        EXEC sp_sequence_get_range 
            @sequence_name = N'dbo.CursoSeq',
            @range_size = @ThisBatchCur,
            @range_first_value = @RangeStartCur OUTPUT,
            @range_last_value = @RangeLastCur OUTPUT;

        SET @RangeStartBigintCur = CONVERT(BIGINT, @RangeStartCur);

        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchCur) ROW_NUMBER() OVER (ORDER BY n) AS rn
                FROM dbo.Numbers
            )
            INSERT INTO Catalogos.Cursos (Nombre, Creditos)
            SELECT
                'NCurso_' + CAST(@RangeStartBigintCur + t.rn - 1 AS VARCHAR(20)) AS Nombre,
                ((ABS(CHECKSUM(@RangeStartBigintCur + t.rn - 1)) % 12) + 1) AS Creditos -- De  1 a 12 creditos.
            FROM ToGen t;
            DECLARE @RowsThisCur INT = @@ROWCOUNT;
            SET @InsertedCursos += @RowsThisCur;
            SET @RemainingCursos -= @RowsThisCur;


            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Cursos', @InsertedCursos, @RowsThisCur, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterCursos, ' Target=', @TargetCursos, ' Remaining=', @RemainingCursos));
            DECLARE @LogIDCur INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchCur DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsCur INT = DATEDIFF(MILLISECOND, @StartBatchCur, @EndBatchCur);
            UPDATE Control.LoadLog SET DurationMs = @DurationMsCur WHERE LoadLogID = @LogIDCur;

            PRINT 'Cursos insertados: ' + CAST(@RowsThisCur AS VARCHAR(10)) + ' | Total Cursos: ' + CAST(@InsertedCursos AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Cursos', @InsertedCursos, 0, 'ROLLBACK', SYSUTCDATETIME() ,CONCAT('Error generando Cursos: ', @err));
            RAISERROR('Error generando Cursos: %s',16,1,@err);
        END CATCH;
    END
    
    -- ==============================================================
    -- MATERIAS (IDENTITY) - asignación por Depto y balance por carga.
    -- ==============================================================

    DECLARE @AlreadyMaterias INT = (SELECT COUNT(*) FROM Operaciones.Materias);
    DECLARE @RemainingMaterias INT = CASE WHEN @TargetMaterias > @AlreadyMaterias THEN @TargetMaterias - @AlreadyMaterias ELSE 0 END;
    DECLARE @InsertedMaterias INT = 0, @IterMaterias INT = 0;

    -- Realizar un precalculo para conteo de departamentos disponibles.
    -- DECLARE @DeptCount INT = (SELECT COUNT(*) FROM #DeptList);
    IF @DeptCount = 0
    BEGIN
        RAISERROR('No hay departamentos definidos.', 16, 1);
        RETURN;
    END;

    WHILE @RemainingMaterias > 0 AND @IterMaterias < @MaxIters
    BEGIN
        SET @IterMaterias += 1;
        DECLARE @ThisBatchMat INT = CASE WHEN @RemainingMaterias < @BatchSize THEN @RemainingMaterias ELSE @BatchSize END;
        DECLARE @StartBatchMat DATETIME2 = SYSUTCDATETIME();

        -- Reservar rango para nombres de materias (garantizando reproducibilidad).
        DECLARE @RangeStartMat sql_variant, @RangeLastMat sql_variant;
        DECLARE @RangeStartBigintMat BIGINT;

        EXEC sp_sequence_get_range
            @sequence_name = N'dbo.MateriaSeq',
            @range_size = @ThisBatchMat,
            @range_first_value = @RangeStartMat OUTPUT,
            @range_last_value = @RangeLastMat OUTPUT;

        SET @RangeStartBigintMat = CONVERT(BIGINT, @RangeStartMat);

        -- Tabla temporal para capturar incrementos por profesor en este batch
        IF OBJECT_ID('tempdb..#InsertedProfCounts') IS NOT NULL DROP TABLE #InsertedProfCounts;
        CREATE TABLE #InsertedProfCounts (ProfesorID INT, Inc INT);

        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchMat) ROW_NUMBER() OVER (ORDER BY n) AS rn
                FROM dbo.Numbers
            ),
            MapDept AS (
                -- Se Asigna DeptRow en round-robin entre departamentos.
                SELECT t.rn,
                    ((t.rn - 1) % @DeptCount) + 1 AS DeptRowCalc
                FROM ToGen t
            ),
            DeptList AS (
                SELECT DeptoID, DeptRow FROM #DeptList
            ),
            ProfPick AS (
                -- Para cada rn, elegir un profesor del depto correspondiente usando round-robin sobre ProfCountPerDept.
                SELECT g.rn,
                    d.DeptoID,
                    -- elegir ProfRow target
                    (( (g.rn - 1) % pl.ProfCountPerDept) + 1) AS TargetProfRow,
                    pl.ProfesorID
                FROM MapDept g
                JOIN DeptList d ON d.DeptRow = g.DeptRowCalc
                CROSS APPLY (
                    -- seleccionar profesor cuyo ProfRow coincide con el índice calculado
                    SELECT TOP (1) p.ProfesorID, p.ProfRow, p.ProfCountPerDept
                    FROM #ProfList p
                    WHERE p.DeptoID = d.DeptoID
                        AND p.ProfRow = (( (g.rn - 1) % p.ProfCountPerDept) + 1)
                ) pl
            )
            -- Insertar materias y capturar ProfesorID insertado para conteo.
            INSERT INTO Operaciones.Materias (Nombre, Creditos, ProfesorID)
            OUTPUT inserted.ProfesorID, 1 INTO #InsertedProfCounts(ProfesorID, Inc)
            SELECT
                'Materia_' + CAST(@RangeStartBigintMat + pp.rn - 1 AS VARCHAR(20)) AS Nombre,
                ((ABS(CHECKSUM(@RangeStartBigintMat + pp.rn - 1)) % 6) + 1) AS Creditos,  -- Creditos de  1 a 6.
                pp.ProfesorID
            FROM ProfPick pp;

            DECLARE @RowsThisMat INT = @@ROWCOUNT;
            SET @InsertedMaterias += @RowsThisMat;
            SET @RemainingMaterias -= @RowsThisMat;

            -- Sumar incrementos por profesor y actualizar #ProfList ordenando por nueva carga.
            ;WITH Incs AS (
                SELECT ProfesorID, SUM(Inc) AS IncCount
                FROM #InsertedProfCounts
                GROUP BY ProfesorID
            ),
            UpdatedLoads AS (
                SELECT pl.ProfesorID,
                    pl.DeptoID,
                    pl.CurrentMatCount + ISNULL(i.IncCount, 0) AS NewLoad
                FROM #ProfList pl
                LEFT JOIN Incs i ON i.ProfesorID = pl.ProfesorID
            )
            -- Reconstruir #ProfList con nuevo orden por carga (menor carga primero).
            INSERT INTO #ProfList (ProfesorID, DeptoID, ProfRow, ProfCountPerDept, CurrentMatCount)
            SELECT ProfesorID, DeptoID,
                ROW_NUMBER() OVER (PARTITION BY DeptoID ORDER BY NewLoad, ProfesorID) AS ProfRow,
                COUNT(*) OVER (PARTITION BY DeptoID) AS ProfCountPerDept,
                NewLoad AS CurrentMatCount
            FROM UpdatedLoads;
            
            DELETE FROM #ProfList WHERE ProfesorID NOT IN (
                SELECT ProfesorID FROM #ProfList 
                WHERE ROWID IN (SELECT MIN(ROWID) OVER (PARTITION BY ProfesorID) FROM #ProfList)
            );

            -- Logging del batch.
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Materias', @InsertedMaterias, @RowsThisMat, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterMaterias, ' Target=', @TargetMaterias, ' Remaining=', @RemainingMaterias));
            DECLARE @LogIDMat INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchMat DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsMat INT = DATEDIFF(MILLISECOND, @StartBatchMat, @EndBatchMat);
            UPDATE Control.LoadLog SET DurationMs = @DurationMsMat WHERE LoadLogID = @LogIDMat;

            PRINT 'Materias insertadas: ' + CAST(@RowsThisMat AS VARCHAR(10)) + ' | Total Materias: ' + CAST(@InsertedMaterias AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            DECLARE @err2 NVARCHAR(4000) = ERROR_MESSAGE();
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Materias', @InsertedMaterias, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error generando materias: ', @err2));
            RAISERROR('Error generando Materias: %s',16,1,@err2);
        END CATCH;
    END

    PRINT 'Diversificación finalizada. Cursos insertados: ' + FORMAT(@InsertedCursos, 'N0') +
        ' | Materias insertadas: ' + FORMAT(@InsertedMaterias, 'N0');

    -- Limpieza de temporales
    IF OBJECT_ID('tempdb..#DeptList') IS NOT NULL DROP TABLE #DeptList;
    IF OBJECT_ID('tempdb..#ProfList') IS NOT NULL DROP TABLE #ProfList;
    IF OBJECT_ID('tempdb..#InsertedProfCounts') IS NOT NULL DROP TABLE #InsertedProfCounts;


--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 9. CARGA MASIVA DE ALUMNOS ( Usando sp_sequence_get_range (con conversión sql_variant -> bigint).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '----------------------------------------------------------';
    PRINT '??       Generando alumnos ...';
    PRINT '----------------------------------------------------------';
    -- Asume que: dbo.Numbers, dbo.AlumnoSeq, #CarrList y Control.LoadLog existen y parámetros globales están definidos.
    -- Cuenta cuántos alumnos ya existen con el prefijo de stress (Para ajusta el filtro).
    DECLARE @NombreBase NVARCHAR(50) = 'UNI_';
    DECLARE @EmailDomain NVARCHAR(100) = '@escolar.edu';
    DECLARE @SeqNameAlu NVARCHAR(128) = N'dbo.AlumnoSeq';

    IF OBJECT_ID('dbo.Numbers','U') IS NULL
    BEGIN
        RAISERROR('dbo.Numbers no existe. Crea y pobla dbo.Numbers antes de ejecutar este script.',16,1);
        RETURN;
    END;

    DECLARE @AlreadyAlu INT = (SELECT COUNT(*) FROM Catalogos.Alumnos WHERE Email LIKE '%' + @NombreBase + '%' + @EmailDomain);
    DECLARE @RemainingAlu INT = CASE WHEN @TargetNewAlu > @AlreadyAlu THEN @TargetNewAlu - @AlreadyAlu ELSE 0 END;

    PRINT 'Inicio carga Alumnos. Objetivo: ' + CAST(@TargetNewAlu AS VARCHAR(20)) + ' | Ya existen: ' + CAST(@AlreadyAlu AS VARCHAR(20));

    -- Loop controlado por objetivo y tope de iteraciones.
    WHILE @RemainingAlu > 0 AND @CurrentIterAlu < @MaxIters
    BEGIN
        SET @CurrentIterAlu += 1;
        DECLARE @ThisBatchAlu INT = CASE WHEN @RemainingAlu < @BatchSize THEN @RemainingAlu ELSE @BatchSize END;
        DECLARE @StartBatchAlu DATETIME2 = SYSUTCDATETIME();

        -- Reservamnos un rango de la sequencia en una sola llamada (outputs sql_variant).
        DECLARE @RangeStartAlu sql_variant, @RangeLastAlu sql_variant;
        DECLARE @RangeStartBigintAlu BIGINT, @RangeLastBigintAlu BIGINT;

        EXEC sp_sequence_get_range 
            @sequence_name = @SeqNameAlu,
            @range_size = @ThisBatchAlu ,
            @range_first_value = @RangeStartAlu OUTPUT,
            @range_last_value = @RangeLastAlu OUTPUT;

        -- Conversión explícita a BIGINT y uso exclusivo de las variables BIGINT.
        SET @RangeStartBigintAlu = CONVERT(BIGINT, @RangeStartAlu);
        SET @RangeLastBigintAlu  = CONVERT(BIGINT, @RangeLastAlu);

        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchAlu ) ROW_NUMBER() OVER (ORDER BY n) AS rn
                FROM dbo.Numbers
            )
            INSERT INTO Catalogos.Alumnos (Nombre, CarreraID, DeptoID, Email, FechaNacimiento, Sexo, MetaData_ETL)
            SELECT
                @NombreBase + CAST(@RangeStartBigintAlu + t.rn - 1 AS VARCHAR(20)) AS Nombre,
                C.CarreraID,
                C.DeptoID,
                LOWER(@NombreBase) + CAST(@RangeStartBigintAlu + t.rn - 1 AS VARCHAR(20)) + @EmailDomain AS Email,
                CAST(DATEADD(DAY, -((ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1)) % 36500)), GETDATE()) AS DATE) AS FechaNacimiento,
                CASE (ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1 + 999)) % 2) WHEN 0 THEN 'M' ELSE 'F' END AS Sexo,
                -- MetaData_ETL consolida FechaIngreso | Estatus | Promedio para normalizar en Fase 4
                CONCAT(
                    CONVERT(VARCHAR(10), CAST(DATEADD(DAY, -((ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1 + 12345)) % 3650)), GETDATE()) AS DATE), 23),
                    ' | ',
                    CASE (ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1)) % 6)
                        WHEN 0 THEN 'ACTIVO' WHEN 1 THEN 'IRREGULAR' WHEN 2 THEN 'CONDICIONAL'
                        WHEN 3 THEN 'BAJA_TEMP' WHEN 4 THEN 'BAJA_DEFI' WHEN 5 THEN 'EGRESADO' END,
                    ' | ',
                    CAST( ( (ABS(CHECKSUM(@RangeStartBigintAlu + t.rn - 1 + 54321)) % 401) / 100.0 ) + 6.00 AS VARCHAR(5))
                ) AS MetaData_ETL
            FROM ToGen t
            CROSS APPLY (SELECT ((t.rn - 1) % (SELECT COUNT(*) FROM #CarrList)) + 1 AS CarrRowCalc) rc
            JOIN #CarrList C ON C.CarrRow = rc.CarrRowCalc
            WHERE NOT EXISTS (
                SELECT 1 FROM Catalogos.Alumnos A
                WHERE A.Email = LOWER(@NombreBase) + CAST(@RangeStartBigintAlu + t.rn - 1 AS VARCHAR(20)) + @EmailDomain
            );

            DECLARE @RowsThisAlu INT = @@ROWCOUNT;
            SET @InsertedTotalAlu += @RowsThisAlu;
            SET @RemainingAlu -= @RowsThisAlu;
            -- Log con duración del batch (inserta y luego actualiza DurationMs).
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Alumnos', @InsertedTotalAlu, @RowsThisAlu, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @CurrentIterAlu, ' Target=', @TargetNewAlu, ' Remaining=', @RemainingAlu));
            DECLARE @LogIDAlu INT = SCOPE_IDENTITY();

            COMMIT;

            DECLARE @EndBatchAlu DATETIME2 = SYSUTCDATETIME();
            DECLARE @DurationMsAlu INT = DATEDIFF(MILLISECOND, @StartBatchAlu, @EndBatchAlu);

            -- Actualizar el registro de log con duración.
            UPDATE Control.LoadLog SET DurationMs = @DurationMsAlu WHERE LoadLogID = @LogIDAlu;

            PRINT 'Alumnos insertados en batch: ' + CAST(@RowsThisAlu AS VARCHAR(10)) +
                ' | Total insertados: ' + CAST(@InsertedTotalAlu AS VARCHAR(20)) +
                ' | Iter ' + CAST(@CurrentIterAlu AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Alumnos', @InsertedTotalAlu, 0, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            THROW;
        END CATCH;
    END
    -- Se deben Reconstruir índices si fueron deshabilitados.
    -- ALTER INDEX ALL ON Catalogos.Alumnos REBUILD;
    -- Aplicamos una seguridad adicional: si alcanzamos tope de iteraciones sin completar objetivo, loguear y alertar.
    IF @RemainingAlu > 0 AND @CurrentIterAlu >= @MaxIters
    BEGIN
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Alumnos', @InsertedTotalAlu, @InsertedTotalAlu, 'PARTIAL', SYSUTCDATETIME(),
                CONCAT('Max iterations reached=', @MaxIters, ' Remaining=', @RemainingAlu));
        RAISERROR('Máximo de iteraciones alcanzado en carga de alumnos. Remaining=%d', 16, 1, @RemainingAlu);
    END
    PRINT 'Carga Alumnos finalizada. Total insertados en este run: ' + FORMAT(@InsertedTotalAlu,'N0') + ' | Remaining=' + FORMAT(@RemainingAlu,'N0');

    IF OBJECT_ID('tempdb..#CarrList') IS NOT NULL DROP TABLE #CarrList;

--- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 10. GENERAR INSCRIPCIONES MASIVAS POR LOTES (OUTPUT -> #NewIns).
--- -- Usasando Estatus desde CursosCount según MetaData_ETL para decidir cantidad de inscripciones por alumno. ACTIVO=6, IRREGULAR=4 a 5, CONDICIONAL=3 a 4 , EGRESADO/BAJA_TEMP/BAJA_DEFI -> 0
--- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Se distribuye inscripciones entre varios CiclosEscolares (lista parametrizable).
    -- Buscando evitar duplicados (AlumnoID, MateriaID, CursoID, CicloEscolar).
    PRINT '--------------------------------------------------------------------------------------------------';
    PRINT '  Iniciando Inscripciones ...';
    PRINT '--------------------------------------------------------------------------------------------------';
    DECLARE @CurrentRunInsPar INT = 1;

    -- Lista de ciclos a inyectar.
    IF OBJECT_ID('tempdb..#Ciclos') IS NOT NULL DROP TABLE #Ciclos;
    CREATE TABLE #Ciclos (Ciclo NVARCHAR(20), CicloRow INT);
    ;WITH Split AS (
        SELECT LTRIM(RTRIM(value)) AS Ciclo, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
        FROM STRING_SPLIT(@CiclosCSV, ',')
    )
    INSERT INTO #Ciclos (Ciclo, CicloRow) SELECT Ciclo, rn FROM Split;
    DECLARE @CiclosCount INT = (SELECT COUNT(*) FROM #Ciclos);
    DECLARE @AluCount INT = (SELECT COUNT(*) FROM #AluList);
    DECLARE @MatCount INT = (SELECT COUNT(*) FROM #MatList);

    -- Control
    DECLARE @AlreadyIns INT = (SELECT COUNT(*) FROM Operaciones.Inscripciones);
    DECLARE @RemainingIns INT = CASE WHEN @TargetInsTotal > @AlreadyIns THEN @TargetInsTotal - @AlreadyIns ELSE 0 END;
    DECLARE @Iter INT = 0;

-- Ayuda: análisis en de acuerdo a función del Estatus desde MetaData_ETL (simple, busca token).
-- Nota : MetaData_ETL tiene formato "FechaIngreso | ESTATUS | Promedio"
    WHILE @RemainingIns > 0 AND @Iter < @MaxIters
    BEGIN
        SET @Iter += 1;
        DECLARE @ThisBatchInsPar INT = CASE WHEN @RemainingIns < @BatchSize THEN @RemainingIns ELSE @BatchSize END;
        DECLARE @StartBatchInsPar DATETIME2 = SYSUTCDATETIME();

        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToGen AS (
                SELECT TOP (@ThisBatchInsPar) ROW_NUMBER() OVER (ORDER BY n) AS rn
                FROM dbo.Numbers
            ),
            -- Mapeo de generacion linea a alumno determinista.
            MapAlu AS (
                SELECT t.rn,
                    ((t.rn - 1) % @AluCount) + 1 AS AluRowCalc,
                    ((t.rn - 1) % @CiclosCount) + 1 AS CicloRowCalc
                FROM ToGen t
            ),
            AluPick AS (
                SELECT m.rn, a.AlumnoID, a.MetaData_ETL, c.Ciclo
                FROM MapAlu m
                JOIN #AluList a ON a.AluRow = m.AluRowCalc
                JOIN #Ciclos c ON c.CicloRow = m.CicloRowCalc
            ),
            -- Derivar el Estatus y número de materias por alumno (determinista).
            AluPlan AS (
                SELECT ap.rn, ap.AlumnoID, ap.MetaData_ETL, ap.Ciclo,
                    -- Extraer token de ESTATUS: tomar la segunda parte tras '|' (simple split).
                    LTRIM(RTRIM(
                        CASE 
                            WHEN CHARINDEX('|', ap.MetaData_ETL) > 0 
                            THEN
                                -- Obtener substring entre primer '|' y segundo '|'.
                                SUBSTRING(
                                    ap.MetaData_ETL,
                                    CHARINDEX('|', ap.MetaData_ETL) + 1,
                                    CASE WHEN CHARINDEX('|', ap.MetaData_ETL, CHARINDEX('|', ap.MetaData_ETL)+1) > 0 
                                            THEN CHARINDEX('|', ap.MetaData_ETL, CHARINDEX('|', ap.MetaData_ETL)+1) - CHARINDEX('|', ap.MetaData_ETL) - 1
                                            ELSE LEN(ap.MetaData_ETL)
                                    END
                                )
                            ELSE ''
                        END
                    )) AS EstatusRaw
                FROM AluPick ap
            ),
            -- Normalizar Estatus y calcular NumMaterias (determinista con CHECKSUM para rangos).
            AluPlanNorm AS (
                SELECT rn, AlumnoID, Ciclo, 
                    UPPER(REPLACE(EstatusRaw,' ','') ) AS EstatusNorm,
                    CASE 
                        WHEN UPPER(REPLACE(EstatusRaw,' ','') ) = 'ACTIVO' THEN 6
                        WHEN UPPER(REPLACE(EstatusRaw,' ','') ) = 'IRREGULAR' THEN ((ABS(CHECKSUM(AlumnoID)) % 2) + 4)  -- 4..5
                        WHEN UPPER(REPLACE(EstatusRaw,' ','') ) = 'CONDICIONAL' THEN ((ABS(CHECKSUM(AlumnoID+7)) % 2) + 3) -- 3..4
                        ELSE 0
                    END AS NumMaterias
                FROM AluPlan
            ),
            -- Cada alumno dentro N  = NumMaterias y el mapa de Materia/Course usando listado round-robin.
            Expand AS (
                SELECT apn.AlumnoID, apn.Ciclo, v.Seq
                FROM AluPlanNorm apn
                CROSS APPLY (
                    SELECT TOP (apn.NumMaterias) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Seq
                    FROM dbo.Numbers
                ) v
            ),
            -- Asigna cada fila expandida a una Materia y Curso determinista.
            MapToMat AS (
                SELECT e.AlumnoID, e.Ciclo, e.Seq,
                    (( (ABS(CHECKSUM(e.AlumnoID + e.Seq)) ) % @MatCount) + 1) AS MatRowCalc,
                    (( (ABS(CHECKSUM(e.AlumnoID + e.Seq + 123)) ) % @CursoCount) + 1) AS CursoRowCalc
                FROM Expand e
            )
            -- Insertar inscripciones y capturar IDs en #NewIns.
            INSERT INTO Operaciones.Inscripciones (AlumnoID, MateriaID, CicloEscolar, NotaFinal, CursoID)
            OUTPUT inserted.InscripcionID, inserted.AlumnoID, inserted.MateriaID, inserted.CursoID, inserted.CicloEscolar INTO #NewIns
            SELECT
                A.AlumnoID,
                M.MateriaID,
                mt.Ciclo,
                NULL, -- NotaFinal se calculará después.
                C.CursoID
            FROM MapToMat mt
            JOIN #AluList A ON A.AlumnoID = mt.AlumnoID
            JOIN #MatList M ON M.MatRow = mt.MatRowCalc
            JOIN #CursoList C ON C.CursoRow = mt.CursoRowCalc
            WHERE NOT EXISTS (
                SELECT 1 FROM Operaciones.Inscripciones i
                WHERE i.AlumnoID = A.AlumnoID AND i.MateriaID = M.MateriaID AND i.CursoID = C.CursoID AND i.CicloEscolar = mt.Ciclo
            );

            DECLARE @RowsThisInsPar INT = @@ROWCOUNT;
            SET @InsertedTotalInsPar += @RowsThisInsPar;
            SET @RemainingIns -= @RowsThisInsPar;
            -- Log y checkpoint.
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunInsPar, 'Inscripciones', @InsertedTotalInsPar, @RowsThisInsPar, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @Iter, ' TargetApprox=', @TargetInsTotal, ' Remaining=', @RemainingIns));
            COMMIT;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunInsPar, 'Inscripciones', @InsertedTotalInsPar, 0, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            THROW;
        END CATCH;

        WAITFOR DELAY @PauseBetweenBatches;
    END
    PRINT 'Inscripciones generadas totales (aprox): ' + CAST(@InsertedTotalInsPar AS VARCHAR(20));

--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 11. INSERCION DE CALIFICACIÓNES PARCIALES POR INSCRIPCIONID (1-3 parciales por inscripción, evitando duplicados).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Se calcula NotaFinal promedio ponderado simple y actualiza Operaciones.Inscripciones.NotaFinal
    DECLARE @BatchSizeCal INT = 5000;
    DECLARE @PauseBetweenBatchesCal TIME = '00:00:01';
    DECLARE @MaxItersCal INT = 200000;
    DECLARE @CurrentRunCal INT = 1;
    
    -- Asegurar #NewInsCal existe (si no, tomar inscripciones recientes)
    IF OBJECT_ID('tempdb..#NewInsCal') IS NULL
    BEGIN
        SELECT TOP (100000) InscripcionID, AlumnoID, MateriaID, CursoID, CicloEscolar INTO #NewInsCal
        FROM Operaciones.Inscripciones
        ORDER BY InscripcionID DESC;
    END;

    INSERT INTO #ToProcessIns (InscripcionID)
    SELECT InscripcionID FROM #NewInsCal
    WHERE InscripcionID NOT IN (SELECT DISTINCT InscripcionID FROM Operaciones.Calificaciones);

    
    DECLARE @TotalToProc INT = (SELECT COUNT(*) FROM #ToProcessIns);
    DECLARE @Processed INT = 0, @IterCal INT = 0;

    WHILE @Processed < @TotalToProc AND @IterCal < @MaxItersCal
    BEGIN
        SET @IterCal += 1;
        DECLARE @ThisBatchCal INT = CASE WHEN (@TotalToProc - @Processed) < @BatchSizeCal THEN (@TotalToProc - @Processed) ELSE @BatchSizeCal END;
        BEGIN TRAN;
        BEGIN TRY
            ;WITH Pick AS (
                SELECT TOP (@ThisBatchCal) InscripcionID FROM #ToProcessIns ORDER BY InscripcionID
            ),
            GenPar AS (
                SELECT p.InscripcionID,
                    ((ABS(CHECKSUM(p.InscripcionID)) % 3) + 1) AS ParcalesToCreate
                FROM Pick p
            ),
            Expand AS (
                SELECT g.InscripcionID, v.ParcialNum
                FROM GenPar g
                CROSS APPLY (VALUES (1),(2),(3)) v(ParcialNum)
                WHERE v.ParcialNum <= g.ParcalesToCreate
            )
        -- Insertar parciales evitando duplicados.
            INSERT INTO Operaciones.Calificaciones (InscripcionID, ParcialNumero, Nota, MetaData_ETL)
            SELECT e.InscripcionID, e.ParcialNumero,
                CAST(((ABS(CHECKSUM(e.InscripcionID + e.ParcialNumero)) % 401) / 100.0) + 6.00 AS DECIMAL(5,2)) AS Nota,
                CONCAT('GEN_CAL|P', e.ParcialNumero, '|I', CAST(e.InscripcionID AS VARCHAR(20))) AS MetaData_ETL
            FROM Expand e
            WHERE NOT EXISTS (
                SELECT 1 FROM Operaciones.Calificaciones c
                WHERE c.InscripcionID = e.InscripcionID AND c.ParcialNumero = e.ParcialNumero
            );

            -- Calcular NotaFinal por Inscripcion (promedio simple de parciales insertados)
            ;WITH NewAvg AS (
                SELECT c.InscripcionID, AVG(CAST(c.Nota AS FLOAT)) AS AvgCal
                FROM Operaciones.Calificaciones c
                WHERE c.InscripcionID IN (SELECT InscripcionID FROM Pick)
                GROUP BY c.InscripcionID
            )
            UPDATE i
            SET i.NotaFinal = CAST(na.AvgCal AS DECIMAL(5,2))
            FROM Operaciones.Inscripciones i
            JOIN NewAvg na ON na.InscripcionID = i.InscripcionID;

            DECLARE @RowsCal INT = @@ROWCOUNT;
            SET @Processed += @ThisBatchCal;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunCal, 'Calificaciones', @Processed, @RowsCal, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterCal, ' BatchIns=', @ThisBatchCal, ' RowsCal=', @RowsCal));
            COMMIT;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunCal, 'Calificaciones', @Processed, 0, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            THROW;
        END CATCH;

        WAITFOR DELAY @PauseBetweenBatchesCal;
    END

    PRINT 'Parciales procesados (aprox): ' + CAST(@Processed AS VARCHAR(20));

--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 12. GENERAR ASISTENCIAS DETERMINISTAS POR LOTES (USANDO #NewIns PARA CONTROL DE FK).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Generar asistencias por InscripcionID usando CicloEscolar 'YYYY-1' o 'YYYY-2'
    -- Expandir en batches para no saturar log y evitar timeouts, generando fechas de asistencia dentro del semestre correspondiente.
    DECLARE @SessionsPerIns INT = 12;  -- Sesiones por inscripción
    DECLARE @BatchSizeAsis INT = @BatchSize;
    DECLARE @PauseBetweenBatchesAsis TIME = '00:00:01';
    DECLARE @CurrentRunAsis INT = 1;

    DECLARE @TotalIns INT = (SELECT COUNT(*) FROM #NewIns);
    DECLARE @ProcessedIns INT = 0, @IterAsis INT = 0;

    WHILE @ProcessedIns < @TotalIns AND @IterAsis < @MaxIters
    BEGIN
        SET @IterAsis += 1;
        DECLARE @ThisBatchAsis INT = CASE WHEN (@TotalIns - @ProcessedIns) < @BatchSizeAsis THEN (@TotalIns - @ProcessedIns) ELSE @BatchSizeAsis END;
        DECLARE @RowsAsis INT = 0;
        BEGIN TRAN;
        BEGIN TRY
            ;WITH Pick AS (
                SELECT TOP (@ThisBatchAsis) NI.InscripcionID
                FROM #NewIns NI
                WHERE NI.InscripcionID NOT IN (SELECT DISTINCT InscripcionID FROM Operaciones.Asistencias)
                ORDER BY NI.InscripcionID
            ),
            Sessions AS (
                SELECT p.InscripcionID,
                    DATEADD(DAY, s.SessionOffset, CAST(GETDATE() AS DATE)) AS Fecha,
                    CASE WHEN (ABS(CHECKSUM(p.InscripcionID + s.SessionOffset)) % 100) < 85 THEN 1 ELSE 0 END AS Presente,
                    s.SessionOffset
                FROM Pick p
                CROSS APPLY (
                    SELECT TOP (@SessionsPerIns) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS SessionOffset
                    FROM dbo.Numbers
                ) s
            )
            INSERT INTO Operaciones.Asistencias (InscripcionID, AlumnoID, CursoID, FechaAsistencia, Presente)
            SELECT s.InscripcionID, i.AlumnoID, i.CursoID, s.Fecha, s.Presente
            FROM Sessions s
            JOIN Operaciones.Inscripciones i ON i.InscripcionID = s.InscripcionID
            WHERE NOT EXISTS (
                SELECT 1 FROM Operaciones.Asistencias a
                WHERE a.InscripcionID = s.InscripcionID AND a.FechaAsistencia = s.Fecha
            );

            SET @RowsAsis = @@ROWCOUNT;
            SET @ProcessedIns += @ThisBatchAsis;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunAsis, 'Asistencias', @ProcessedIns, @RowsAsis, 'COMMIT', SYSUTCDATETIME(),
                    CONCAT('Iter=', @IterAsis, ' BatchIns=', @ThisBatchAsis, ' RowsAsis=', @RowsAsis));

            WAITFOR DELAY @PauseBetweenBatchesAsis;

            COMMIT;

            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRunAsis, 'Asistencias', @ProcessedIns, @RowsAsis, 'ROLLBACK', SYSUTCDATETIME(), ERROR_MESSAGE());
            PRINT 'ERROR en batch Asistencias: ' + ERROR_MESSAGE();
            THROW;
        END CATCH;
    END
    PRINT 'Asistencias generadas (aprox): ' + CAST(@ProcessedIns * @SessionsPerIns AS VARCHAR(20));

/*
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 13. AJUSTE: Actualizamos la NotaFinal por lotes (promedio; clamp mínimo 60).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    DECLARE @RowsUpd INT = 1;
    WHILE @RowsUpd > 0
    BEGIN
        BEGIN TRAN;
        BEGIN TRY
            ;WITH CTE_Prom AS (
                SELECT TOP (@BatchSize) I.InscripcionID,
                    COALESCE(ROUND(AVG(CAST(NULLIF(C.Nota,0) AS DECIMAL(7,4))),2), NULL) AS Prom
                FROM Operaciones.Inscripciones I
                LEFT JOIN Operaciones.Calificaciones C ON C.InscripcionID = I.InscripcionID
                WHERE I.NotaFinal IS NULL
                GROUP BY I.InscripcionID
                ORDER BY I.InscripcionID
            )
            UPDATE I
            SET NotaFinal = CASE WHEN P.Prom IS NULL THEN 0 -- o NULL ajustado a la política.
                            WHEN P.Prom < 60 THEN 60
                            ELSE P.Prom END
            FROM Operaciones.Inscripciones I
            JOIN CTE_Prom P ON I.InscripcionID = P.InscripcionID;

            SET @RowsUpd = @@ROWCOUNT;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
            VALUES (@CurrentRun, 'NotaFinal', 0, @RowsUpd, 'COMMIT', CONCAT('NotaFinal batch rows=', @RowsUpd));

            COMMIT;
            PRINT 'NotaFinal actualizada: ' + CAST(@RowsUpd AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog  (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
            VALUES (@CurrentRun, 'NotaFinal', 0, 0, 'ROLLBACK', ERROR_MESSAGE());
            PRINT 'ERROR en batch NotaFinal: ' + ERROR_MESSAGE();
            THROW;
        END CATCH;
    END
*/
--- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- > 14.  ACTUALIZACION: Para checkpoints de Inscripcion, Calificaciones y Asistencias (para control de FK en procesos posteriores).
--- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Insertar checkpoints
    INSERT INTO Control.Checkpoints (Entidad, LastRun, LastTimestamp, RowsTotal, Estado, Mensaje)
    VALUES ('Inscripciones', @CurrentRun, SYSUTCDATETIME(), (SELECT COUNT(*) FROM Operaciones.Inscripciones), 'OK', 'Carga inscripciones por lote con Estatus-based load');

    INSERT INTO Control.Checkpoints (Entidad, LastRun, LastTimestamp, RowsTotal, Estado, Mensaje)
    VALUES ('Calificaciones', @CurrentRunCal, SYSUTCDATETIME(), (SELECT COUNT(*) FROM Operaciones.Calificaciones), 'OK', 'Parciales insertados');

    INSERT INTO Control.Checkpoints (Entidad, LastRun, LastTimestamp, RowsTotal, Estado, Mensaje)
    VALUES ('Asistencias', @CurrentRunAsis, SYSUTCDATETIME(), (SELECT COUNT(*) FROM Operaciones.Asistencias), 'OK', 'Asistencias generadas');
=======
--- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- > 13.  ACTUALIZACION: Para checkpoints (para control de FK en procesos posteriores).
--- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Insertar checkpoints
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
    USING (SELECT 'Inscripciones' AS Entidad, ISNULL(MAX(InscripcionID),0) AS UltimoID
    FROM Operaciones.Inscripciones) AS SI
    ON CkpI.Entidad = SI.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = SI.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (SI.Entidad, SI.UltimoID, SYSUTCDATETIME());

    MERGE Control.Checkpoints AS CkpC
    USING (SELECT 'Calificaciones' AS Entidad, ISNULL(MAX(CalificacionID),0) AS UltimoID
    FROM Operaciones.Calificaciones) AS SCal
    ON CkpC.Entidad = SCal.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = SCal.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (SCal.Entidad, SCal.UltimoID, SYSUTCDATETIME());

    MERGE Control.Checkpoints AS CkpA
    USING (SELECT 'Asistencias' AS Entidad, ISNULL(MAX(AsistenciaID),0) AS UltimoID
    FROM Operaciones.Asistencias) AS SEn
    ON CkpA.Entidad = SEn.Entidad
    WHEN MATCHED THEN UPDATE SET UltimoID = SEn.UltimoID, FechaActualizacion = SYSUTCDATETIME()
    WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (SEn.Entidad, SEn.UltimoID, SYSUTCDATETIME());
>>>>>>> feature/P2-Executive-Diorama

    -- Métricas resumidas
    INSERT INTO Control.Metrics (MetricDate, MetricName, MetricValue, Notes)
    VALUES (SYSUTCDATETIME(), 'TotalAlumnos', (SELECT COUNT(*) FROM Catalogos.Alumnos), 'Total alumnos en catálogo');

    INSERT INTO Control.Metrics (MetricDate, MetricName, MetricValue, Notes)
    VALUES (SYSUTCDATETIME(), 'TotalInscripciones', (SELECT COUNT(*) FROM Operaciones.Inscripciones), 'Total inscripciones');

    INSERT INTO Control.Metrics (MetricDate, MetricName, MetricValue, Notes)
    VALUES (SYSUTCDATETIME(), 'PromedioParcialesPorInscripcion', (SELECT AVG(Num) FROM (SELECT COUNT(*) AS Num FROM Operaciones.Calificaciones GROUP BY InscripcionID) t), 'Promedio de parciales por inscripción');

    INSERT INTO Control.Metrics (MetricDate, MetricName, MetricValue, Notes)
    VALUES (SYSUTCDATETIME(), 'PorcAsistenciaPromedio', (SELECT AVG(CAST(Presente AS FLOAT))*100.0 FROM Operaciones.Asistencias), 'Porcentaje promedio de asistencia');

    PRINT 'Checkpoints y métricas registradas en Control.Checkpoints y Control.Metrics';

---- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- -- 15. MÉTRICAS FINALES.
---- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- POR RUN.
    DECLARE @EndTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @CntProf INT = (SELECT COUNT(*) FROM Catalogos.Profesores);
    DECLARE @CntDept INT = (SELECT COUNT(*) FROM Catalogos.Departamentos);
    DECLARE @CntAlu INT = (SELECT COUNT(*) FROM Catalogos.Alumnos);
    DECLARE @CntIns INT = (SELECT COUNT(*) FROM Operaciones.Inscripciones);
    DECLARE @CntCal INT = (SELECT COUNT(*) FROM Operaciones.Calificaciones);
    DECLARE @CntAsi INT = (SELECT COUNT(*) FROM Operaciones.Asistencias);

    PRINT 'Métricas Run: ' + CAST(@CurrentRun AS VARCHAR(3)) + ' Alumnos='+CAST(@CntAlu AS VARCHAR(12)) + ' Inscripciones=' + CAST(@CntIns AS VARCHAR(12)) + ' Calificaciones=' + CAST(@CntCal AS VARCHAR(12)) + ' Asistencias=' + CAST(@CntAsi AS VARCHAR(12));

-- Preparar siguiente run
<<<<<<< HEAD
    SET @CurrentRun = @CurrentRun + 1;
=======
    SET @CurrentRun += 1;
>>>>>>> feature/P2-Executive-Diorama
    -- Limpiar #NewIns para la siguiente iteración si se desea regenerar nuevas inscripciones en cada run.
    -- NOTA: durante pruebas deja las temp tables para inspección
    IF OBJECT_ID('tempdb..#Ciclos') IS NOT NULL DROP TABLE #Ciclos;
    IF OBJECT_ID('tempdb..#AluList') IS NOT NULL DROP TABLE #AluList;
    IF OBJECT_ID('tempdb..#NewIns') IS NOT NULL DROP TABLE #NewIns;
<<<<<<< HEAD
=======
    IF OBJECT_ID('tempdb..#NewInsCal') IS NOT NULL DROP TABLE #NewInsCal;
    IF OBJECT_ID('tempdb..#ToProcessIns') IS NOT NULL DROP TABLE #ToProcessIns;
>>>>>>> feature/P2-Executive-Diorama
    IF OBJECT_ID('tempdb..#Cursos') IS NOT NULL DROP TABLE #Cursos;
    IF OBJECT_ID('tempdb..#Materias') IS NOT NULL DROP TABLE #Materias;
    IF OBJECT_ID('tempdb..#CarrList') IS NOT NULL DROP TABLE #CarrList;
    IF OBJECT_ID('tempdb..#ParcToInsert') IS NOT NULL DROP TABLE #ParcToInsert;
<<<<<<< HEAD
=======
    
>>>>>>> feature/P2-Executive-Diorama

    INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje, DurationMs)
    VALUES (@CurrentRun, 'Metrics', 0, @CntIns, 'COMMIT', CONCAT('Ins=',@CntIns,' Cal=',@CntCal,' Asi=',@CntAsi), NULL);
    PRINT '';
    PRINT '============================================================================';
    PRINT '         ✅ RESUMEN DE EJECUCIÓN EXITOSA RUN ' + CAST(@CurrentRun AS VARCHAR(3)) + ' completada.';
    PRINT '============================================================================';
    PRINT '✅ Alumnos Procesados:   ' + FORMAT(@CntAlu, 'N0');
    PRINT '📝 Departamentos Inyectados: ' + FORMAT(@CntDept, 'N0');
    PRINT '📝 Profesores Inyectados: ' + FORMAT(@CntProf, 'N0');
    PRINT '📝 Inscripciones Inyectadas: ' + FORMAT(@CntIns, 'N0');
    PRINT '📝 Calificaciones Inyectadas: ' + FORMAT(@CntCal, 'N0');
    PRINT '📝 Asistencias Inyectadas: ' + FORMAT(@CntAsi, 'N0');
    PRINT '📝 Materias Inyectadas:     ' + FORMAT(@InsertedMaterias, 'N0');
    PRINT '📝 Cursos Inyectados:    ' + FORMAT(@InsertedCursos, 'N0');
    PRINT '⏱️ Tiempo de Respuesta:  ' + FORMAT(DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME()), 'N0') + ' ms';
    PRINT '⏱️ Tiempo de Ejecución: ' + FORMAT(DATEDIFF(MILLISECOND, @StartTime, @EndTime), 'N0') + ' ms';
    PRINT '📅 Finalizado el:        ' + CAST(SYSDATETIME() AS VARCHAR);
    PRINT '============================================================================';
    PRINT '';
    WAITFOR DELAY @PauseBetweenBatches;
    PRINT '--------------------Stress Test integrado finalizado-----------------------------------';

END




