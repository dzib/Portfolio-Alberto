/* 
==============================================================================================================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 3 -  Stress Test & Data Quality Shield
AUTOR: Alberto Dzib
VERSIÓN: 2.3 (Enterprise Load Simulation por lotes, determinista)
DESCRIPCIÓN: 
    - Script de stress test adaptado para cargas grandes. Procesa inscripciones, asistencias y actualización de NotaFinal en lotes para reducir uso de log y evitar timeouts. 
    - Con generación determinista para asistencias y evita NEWID() en comprobaciones críticas.
    - Generación de datos no atómicos en columna Metadata_ETL para futuro proceso de limpieza.
===============================================================================================================================================================================================
*/

USE P2_EscolarDB;
GO
--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- VARIABLES DE BUCLE Y MÉTRICAS PARA CONTROL.
--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET NOCOUNT ON;                                             -- Para reducir tiempo se suprime el mensaje de "(1 filas afectadas)".
SET XACT_ABORT ON;                                          -- Para asegura que errores aborten la transacción.
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
-- ===================================
-- Parámetros (ajusta según entorno)
-- ===================================
DECLARE @MaxRuns INT = 11;                                  -- Número de ejecuciones completas (runs).
DECLARE @CurrentRun INT = 1;
DECLARE @BatchSize INT = 500;                               -- Parámetros de stress inserción masiva Tamaño de lote para operaciones pesadas.
DECLARE @PauseBetweenBatches VARCHAR(8) = '00:00:01';       -- Pausa entre lotes para reducir presión en el log y evitar timeouts Formato hh:mm:ss.
-- Pausa de 1 segundo entre lotes para reducir presión en el log y evitar timeouts.
DECLARE @MinAsis INT = 2, @MaxAsis INT = 4;                 -- Rango de asistencias por inscripción.
DECLARE @MinParciales INT = 2, @MaxParciales INT = 3;       -- Rango de parciales por inscripción.
DECLARE @NProf INT = 1000;                                  -- Volumen de profesores a generar.
DECLARE @NAlu INT = 10000;                                  -- Ajustar volumen de alumnos para simular carga.
DECLARE @NAluRun INT = 10000;                               -- Volumen de alumnos muestreados para Inscripciones por batch.


--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- > PRIMERA LECTURA: De checkpoints actuales para control de FK (defensivo: 0).
--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DECLARE @UltProf INT = ISNULL((SELECT UltimoID FROM Control.Checkpoints WHERE Entidad = 'Profesores'),0);
DECLARE @UltAlu INT = ISNULL((SELECT UltimoID FROM Control.Checkpoints WHERE Entidad = 'Alumnos'),0);
DECLARE @NombreBase NVARCHAR(50) = ISNULL(CHOOSE(FLOOR(RAND()*2)+1,'Alumno', 'Candidato'),'User');
DECLARE @UltCurso INT = ISNULL((SELECT UltimoID FROM Control.Checkpoints WHERE Entidad = 'Cursos'),0);
DECLARE @UltMat INT = ISNULL((SELECT UltimoID FROM Control.Checkpoints WHERE Entidad = 'Materias'),0);

PRINT '--------------------------------------------------------------------------------------------------';
PRINT '🚀 Iniciando Stress Test en P2_EscolarDB...' + CAST(SYSUTCDATETIME() AS VARCHAR);
PRINT '--------------------------------------------------------------------------------------------------';
--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- 1. TABLAS DE CONTROL / LOGGING
--- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('Control.LoadLog','U') IS NULL
BEGIN
CREATE TABLE Control.LoadLog (
    LoadLogID INT IDENTITY(1,1) PRIMARY KEY,
    RunNumber INT,
    Entidad NVARCHAR(100),
    BatchOffset INT,
    RowsAffected INT,
    Estado NVARCHAR(20),
    Fecha DATETIME2 DEFAULT SYSUTCDATETIME(),
    Mensaje NVARCHAR(4000) NULL
);
END

IF OBJECT_ID('Control.Checkpoints','U') IS NULL
BEGIN
CREATE TABLE Control.Checkpoints (
    Entidad NVARCHAR(100) PRIMARY KEY,
    UltimoID BIGINT,
    FechaActualizacion DATETIME2
);
END

--- ----------------------------
---  1.1 VALIDACIONES INICIALES.
--- ----------------------------
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Inscripciones' AND schema_id = SCHEMA_ID('Operaciones'))
BEGIN
RAISERROR('No se encuentra Operaciones.Inscripciones. Verifica esquema.',16,1);
RETURN;
END

--- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 2. PREPARACIÓN: MATERIALIZAR CATÁLOGOS EN TABLAS TEMPORALES (para determinismo y velocidad).
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

DECLARE @CarrCount INT = (SELECT COUNT(*) FROM #CarrList);
DECLARE @CursoCount INT = (SELECT COUNT(*) FROM #Cursos);
DECLARE @MateriaCount INT = (SELECT COUNT(*) FROM #Materias);

IF @CarrCount = 0 OR @CursoCount = 0 OR @MateriaCount = 0
BEGIN
    RAISERROR('Faltan catálogos (Carreras/Cursos/Materias). Abortando.',16,1);
    RETURN;
END
PRINT 'Catalogos materializados: Cursos=' + FORMAT(@CursoCount, 'N0') + ' | Materias=' + FORMAT(@MateriaCount, 'N0');

-- Tabla Temp para capturar inscripciones creadas en cada run.
IF OBJECT_ID('tempdb..#NewIns') IS NOT NULL DROP TABLE #NewIns;
CREATE TABLE #NewIns (
    InscripcionID INT,
    AlumnoID INT,
    MateriaID INT,
    CursoID INT,
    CicloEscolar NVARCHAR(20),
    NotaFinal DECIMAL(5,2)
);

--- -------------------------------------------
--- -- 2.1 Outer loop: runs (1..@MaxRuns).
--- -------------------------------------------
WHILE @CurrentRun <= @MaxRuns
BEGIN
    PRINT '------------------------------------------------------------';
    PRINT 'Iniciando Run ' + CAST(@CurrentRun AS VARCHAR(3)) + ' de ' + CAST(@MaxRuns AS VARCHAR(3)) + ' - ' + CONVERT(VARCHAR(30), SYSUTCDATETIME());
    PRINT '------------------------------------------------------------';

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 3. POBLADO: Departamentos. (Idempotente: solo inserta si no existe).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY
        PRINT '----------------------------------------------------------------';
        PRINT '🏢   Diversificando de Departamentos..'
        PRINT '----------------------------------------------------------------';

        IF NOT EXISTS (SELECT 1 FROM Catalogos.Departamentos WHERE Nombre IN (
            'Departamento de Ciencias Exactas y Naturales',
            'Departamento de Ciencias Económico-Administrativas',
            'Departamento de Artes y Diseño',
            'Departamento de Ciencias de la Salud Pública'
        ))
        BEGIN
            INSERT INTO Catalogos.Departamentos (Nombre, PresupuestoAnual) VALUES
            ('Departamento de Ciencias Exactas y Naturales', 800000),
            ('Departamento de Ciencias Económico-Administrativas', 200000),
            ('Departamento de Artes y Diseño', 450000),
            ('Departamento de Ciencias de la Salud Pública', 150000);
        END

        DECLARE @InsertedDeptos INT = (SELECT COUNT(*) FROM Catalogos.Departamentos);
            IF @InsertedDeptos = 0
            BEGIN
                RAISERROR('No se insertaron departamentos en Catalogos.Departamentos. Abortar Insersion',16,1);
            RETURN;
        END
        PRINT 'Departamentos insertados: ' + FORMAT(@InsertedDeptos, 'N0');

--- -------------------------------------------------------------------------
--- -- 4. GENERACIÓN DE PROFESORES (idempotente).
--- -------------------------------------------------------------------------
        ;WITH nums AS (
            SELECT TOP (@NProf) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
            FROM sys.all_columns
        ), NewProfs AS (
            SELECT
                'NProf_' + CAST(rn AS VARCHAR(12)) AS Nombre,
                'Nprof' + CAST(rn AS VARCHAR(12)) + '@escolar.edu' AS Email,
                ((rn - 1) % (SELECT COUNT(*) FROM Catalogos.Departamentos)) + 1 AS DeptoID
            FROM nums
            )
        INSERT INTO Catalogos.Profesores (Nombre, Email, DeptoID)
        SELECT N.Nombre, N.Email, N.DeptoID
        FROM NewProfs N
        WHERE NOT EXISTS (SELECT 1 FROM Catalogos.Profesores P WHERE P.Email = N.Email);

        -- Se actualizar checkpoint Profesores.
        MERGE Control.Checkpoints AS C
        USING (SELECT 'Profesores' AS Entidad, ISNULL(MAX(ProfesorID),0) AS UltimoID FROM Catalogos.Profesores) AS S
        ON C.Entidad = S.Entidad
        WHEN MATCHED THEN UPDATE SET UltimoID = S.UltimoID, FechaActualizacion = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (S.Entidad, S.UltimoID, SYSUTCDATETIME());

        DECLARE @InsertedProf INT=(SELECT COUNT(*)
        FROM Catalogos.Profesores
        WHERE ProfesorID > @UltProf);
            IF @InsertedProf = 0
            BEGIN
                RAISERROR('No se insertaron profesores en Catalogos.Profesores. Abortar Insersion',16,1);
            RETURN;
        END
        PRINT 'Profesores generados/actualizados: ' + FORMAT(@InsertedProf, 'N0');

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 5. DIVERSIFICACIÓN DE CURSOS Y MATERIAS.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Catalogos.Cursos WHERE Nombre LIKE 'StressCurso_%')
        BEGIN
        INSERT INTO Catalogos.Cursos (Nombre) 
        SELECT 'NCurso_' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(15))
        FROM (SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1) a(n)
        CROSS JOIN (SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1) b(n); -- 50 ejemplo
        END
    
        DECLARE @InsertedCurs INT = (SELECT COUNT(*) FROM Catalogos.Cursos);
            IF @InsertedCurs = 0
            BEGIN
                RAISERROR('No se insertaron Cursos en Catalogos.Cursos. Abortar Insersion',16,1);
            RETURN;
        END
        PRINT 'Cursos insertados: ' + FORMAT(@InsertedCurs, 'N0');

        IF NOT EXISTS (SELECT 1 FROM Operaciones.Materias WHERE Nombre LIKE 'StressMateria_%')
        BEGIN
        INSERT INTO Operaciones.Materias (Nombre)
        SELECT 'NMateria_' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(15))
        FROM (SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1) a(n)
        CROSS JOIN (SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1) b(n); -- 15 ejemplo
        END

        DECLARE @InsertedMat INT = (SELECT COUNT(*) FROM Operaciones.Materias);
            IF @InsertedMat = 0
            BEGIN
                RAISERROR('No se insertaron Materias en Operaciones.Materias. Abortar Insersion',16,1);
            RETURN;
        END
        PRINT 'Materias insertadas: ' + FORMAT(@InsertedMat, 'N0');

    -- Actualizar checkpoints de Cursos y Materias.
        MERGE Control.Checkpoints AS CKc
        USING (SELECT 'Cursos' AS Entidad, ISNULL(MAX(CursoID),0) AS UltimoID FROM Catalogos.Cursos) AS Sc
        ON CKc.Entidad = Sc.Entidad
        WHEN MATCHED THEN UPDATE SET UltimoID = Sc.UltimoID, FechaActualizacion = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (Sc.Entidad, Sc.UltimoID, SYSUTCDATETIME());

        MERGE Control.Checkpoints AS CKm
        USING (SELECT 'Materias' AS Entidad, ISNULL(MAX(MateriaID),0) AS UltimoID FROM Operaciones.Materias) AS Sm
        ON CKm.Entidad = Sm.Entidad
        WHEN MATCHED THEN UPDATE SET UltimoID = Sm.UltimoID, FechaActualizacion = SYSUTCDATETIME()
        WHEN NOT MATCHED THEN INSERT (Entidad, UltimoID, FechaActualizacion) VALUES (Sm.Entidad, Sm.UltimoID, SYSUTCDATETIME());

        COMMIT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
        VALUES (@CurrentRun, 'PobladoInicial', 0, 1, 'COMMIT', 'Departamentos/Profesores/Cursos/Materias');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
        VALUES (@CurrentRun, 'PobladoInicial', 0, 0, 'ROLLBACK', ERROR_MESSAGE());
        PRINT 'ERROR en PobladoInicial: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 6. CARGA MASIVA DE ALUMNOS (Se asigna CarreraID, DeptoID coherente, idempotente).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '----------------------------------------------------------';
    PRINT '??       Generando alumnos ...';
    PRINT '----------------------------------------------------------';

    DECLARE @RowsAlu INT = 1;
    DECLARE @OffsetAlu INT = 0;
    WHILE @RowsAlu > 0
    BEGIN
        BEGIN TRAN;
        BEGIN TRY
            ;WITH RandRows AS (
                SELECT TOP (@BatchSize) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
                FROM sys.all_columns
            ), NewAlu AS (
                SELECT
                @NombreBase + '_ID_' + CAST((SELECT ISNULL(MAX(AlumnoID),0) FROM Catalogos.Alumnos) + rn + @OffsetAlu AS VARCHAR(20)) AS Nombre,
                LOWER(@NombreBase) + CAST((SELECT ISNULL(MAX(AlumnoID),0) FROM Catalogos.Alumnos) + rn + @OffsetAlu AS VARCHAR(20)) + '@escolar.edu' AS Email,
                DATEADD(DAY, -((rn + @OffsetAlu) % 36500), GETDATE()) AS FechaNacimiento,
                -- MetaData_ETL: fecha | estatus | nota (ejemplo).
                FORMAT(DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1825, GETDATE()), 'yyyy-MM-dd') + ' | ' +
                    CASE (ABS(CHECKSUM(NEWID())) % 7)
                        WHEN 0 THEN 'REGULAR' WHEN 1 THEN 'IRREGULAR' WHEN 2 THEN 'CONDICIONAL'
                        WHEN 3 THEN 'BAJA_TEMP' WHEN 4 THEN 'BAJA_DEFI' WHEN 5 THEN 'EGRESADO' ELSE 'TITULADO'
                END + ' | ' + CAST((ABS(CHECKSUM(NEWID())) % 41) + 60 AS VARCHAR(5)) AS MetaData_ETL,
                ((rn + @OffsetAlu - 1) % @CarrCount) + 1 AS CarreraID,
                (SELECT DeptoID FROM #CarrList WHERE CarrRow = ((rn + @OffsetAlu - 1) % @CarrCount) + 1) AS DeptoID
                FROM RandRows
            )
            INSERT INTO Catalogos.Alumnos (Nombre, Email, FechaNacimiento, MetaData_ETL, CarreraID, DeptoID)
            SELECT N.Nombre, N.Email, N.FechaNacimiento, N.MetaData_ETL, N.CarreraID, N.DeptoID
            FROM NewAlu N
            WHERE NOT EXISTS (SELECT 1 FROM Catalogos.Alumnos A WHERE A.Email = N.Email);

            SET @RowsAlu = @@ROWCOUNT;
            COMMIT;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado)
            VALUES (@CurrentRun, 'Alumnos', @OffsetAlu, @RowsAlu, 'COMMIT');

            PRINT 'Batch Alumnos insertados: ' + CAST(@RowsAlu AS VARCHAR(10)) + ' (offset ' + CAST(@OffsetAlu AS VARCHAR(10)) + ')';
            SET @OffsetAlu = @OffsetAlu + @RowsAlu;
            IF @RowsAlu = 0 BREAK;
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
        VALUES (@CurrentRun, 'Alumnos', @OffsetAlu, 0, 'ROLLBACK', ERROR_MESSAGE());
        PRINT 'ERROR en batch Alumnos: ' + ERROR_MESSAGE();
        THROW;
        END CATCH;
    END

--- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 7. GENERAR INSCRIPCIONES MASIVAS POR LOTES (OUTPUT -> #NewIns), Parciales y Asistencias).
--- -- --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '--------------------------------------------------------------------------------------------------';
    PRINT '  Iniciando Inscripciones, Parciales...';
    PRINT '--------------------------------------------------------------------------------------------------';
    DECLARE @RowsIns INT = 1;
    DECLARE @OffsetIns INT = 0;

    WHILE @RowsIns > 0
    BEGIN
        BEGIN TRAN;
        BEGIN TRY
            ;WITH ToProcess AS (    -- Realizamos la extracción del token EstatusAcademico para decidir cantidad, pero sin usar funciones de texto complejas en la consulta principal.
                SELECT TOP (@BatchSize) A.AlumnoID,
                        -- extraer EstatusAcademico token para decidir cantidad
                        CASE
                            WHEN CHARINDEX('|',A.MetaData_ETL) = 0 THEN NULL
                            ELSE UPPER(LTRIM(RTRIM(
                                SUBSTRING(
                                    A.MetaData_ETL,
                                    CHARINDEX('|',A.MetaData_ETL) + 1,
                                    CASE WHEN CHARINDEX('|',A.MetaData_ETL, CHARINDEX('|',A.MetaData_ETL)+1) = 0
                                        THEN LEN(A.MetaData_ETL)
                                        ELSE CHARINDEX('|',A.MetaData_ETL, CHARINDEX('|',A.MetaData_ETL)+1) - CHARINDEX('|',A.MetaData_ETL) - 1 END
                                )
                            )))
                        END AS RawEstatus
                FROM Catalogos.Alumnos A
                LEFT JOIN Operaciones.Inscripciones I ON I.AlumnoID = A.AlumnoID AND I.CicloEscolar = CAST(YEAR(GETDATE()) AS VARCHAR(4)) + '-1'
                WHERE I.InscripcionID IS NULL
                ORDER BY A.AlumnoID
            )
            INSERT INTO Operaciones.Inscripciones (AlumnoID, MateriaID, CursoID, CicloEscolar, NotaFinal)
            OUTPUT inserted.InscripcionID, inserted.AlumnoID, inserted.MateriaID, inserted.CursoID, inserted.CicloEscolar, inserted.NotaFinal
            INTO #NewIns (InscripcionID, AlumnoID, MateriaID, CursoID, CicloEscolar, NotaFinal)
            SELECT tp.AlumnoID,
                    M.MateriaID,
                    C.CursoID,
                    CAST(YEAR(GETDATE()) AS VARCHAR(4)) + '-1',
                    NULL
            FROM ToProcess tp
            CROSS APPLY (
                SELECT CASE
                WHEN tp.RawEstatus LIKE '%REGUL%' THEN 6
                WHEN tp.RawEstatus LIKE '%IRREG%' THEN 4
                WHEN tp.RawEstatus LIKE '%CONDIC%' THEN 5
                ELSE 0
            END AS Cantidad
            ) Cnt
            CROSS APPLY (
                SELECT n FROM (
                    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
                    FROM (VALUES(0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) a(n)
                    CROSS JOIN (VALUES(0),(0),(0),(0),(0),(0),(0),(0),(0),(0)) b(n)
                ) Tally WHERE n <= Cnt.Cantidad
            ) t
            CROSS APPLY (
                SELECT TOP (1) MateriaID FROM #Materias
                WHERE MateriaRow = ((ABS(CHECKSUM(CONCAT(tp.AlumnoID, t.n))) % @MateriaCount) + 1)
                ORDER BY MateriaID
            ) M
            CROSS APPLY (
                SELECT TOP (1) CursoID FROM #Cursos
                WHERE CursoRow = ((ABS(CHECKSUM(CONCAT(tp.AlumnoID, t.n))) % @CursoCount) + 1)
                ORDER BY CursoID
            ) C
            WHERE Cnt.Cantidad > 0
                AND NOT EXISTS (
                    SELECT 1 FROM Operaciones.Inscripciones I2
                    WHERE I2.AlumnoID = tp.AlumnoID
                        AND I2.MateriaID = M.MateriaID
                        AND I2.CursoID = C.CursoID
                        AND I2.CicloEscolar = CAST(YEAR(GETDATE()) AS VARCHAR(4)) + '-1'
            );
            SET @RowsIns = @@ROWCOUNT;
            -- Log y checkpoint.
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado)
            VALUES (@CurrentRun, 'Inscripciones', @OffsetIns, @RowsIns, 'COMMIT');

            COMMIT;
            PRINT 'Batch Inscripciones insertadas: ' + CAST(@RowsIns AS VARCHAR(10)) + ' (offset ' + CAST(@OffsetIns AS VARCHAR(10)) + ')';
            SET @OffsetIns = @OffsetIns + @RowsIns;
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
            VALUES (@CurrentRun, 'Inscripciones', @OffsetIns, 0, 'ROLLBACK', ERROR_MESSAGE());
            PRINT 'ERROR en batch Inscripciones: ' + ERROR_MESSAGE();
            THROW;
        END CATCH;
    END
        
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 8. INSERCION DE PARCIALES POR LOTES USANDO INSCRIPCIONID (1-3 parciales por inscripción, evitando duplicados).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- Asegurarse de que #NewIns existe y contiene filas; si no, crear temporal vacía.
    DECLARE @RowsPar INT = 0;
    BEGIN TRAN;
    BEGIN TRY
        INSERT INTO Operaciones.Calificaciones (InscripcionID, ParcialNumero, AlumnoID, CursoID, Nota, FechaAplicacion)
        SELECT N.InscripcionID,
            P.ParcialNum,
            N.AlumnoID,
            N.CursoID,
            CAST((ABS(CHECKSUM(CONCAT(N.InscripcionID,'-',P.ParcialNum))) % 101) AS DECIMAL(5,2)),
            SYSUTCDATETIME()
        FROM #NewIns N
        CROSS JOIN (VALUES (1),(2),(3)) AS P(ParcialNum)
        LEFT JOIN Operaciones.Calificaciones C ON C.InscripcionID = N.InscripcionID AND C.ParcialNumero = P.ParcialNum
        WHERE C.CalificacionID IS NULL;

        SET @RowsPar = @@ROWCOUNT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado)
        VALUES (@CurrentRun, 'Calificaciones', 0, @RowsPar, 'COMMIT');

        COMMIT;
        PRINT 'Parciales insertados para nuevas inscripciones: ' + CAST(@RowsPar AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
        VALUES (@CurrentRun, 'Calificaciones', 0, 0, 'ROLLBACK', ERROR_MESSAGE());
        PRINT 'ERROR en inserción de parciales: ' + ERROR_MESSAGE();
        THROW;
    END CATCH;

--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 9. GENERAR ASISTENCIAS DETERMINISTAS POR LOTES (USANDO #NewIns PARA CONTROL DE FK).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Generar asistencias por InscripcionID usando CicloEscolar 'YYYY-1' o 'YYYY-2'
-- Expandir en batches para no saturar log y evitar timeouts, generando fechas de asistencia dentro del semestre correspondiente.
    DECLARE @InsCount INT = (SELECT COUNT(*) FROM #NewIns);
    DECLARE @InsOffset INT = 0;
    DECLARE @RowsAsis INT = 1;

    WHILE @InsOffset < @InsCount
    BEGIN
        BEGIN TRAN;
        BEGIN TRY
            ;WITH BatchIns AS (
                SELECT InscripcionID, AlumnoID, CursoID, CicloEscolar
                FROM #NewIns
                ORDER BY InscripcionID
                OFFSET @InsOffset ROWS FETCH NEXT @BatchSize ROWS ONLY
            ),
            Sem AS (
                SELECT B.InscripcionID, B.AlumnoID, B.CursoID, B.CicloEscolar,
                    CASE WHEN RIGHT(B.CicloEscololar,1) = '1' THEN DATEFROMPARTS(CAST(LEFT(B.CicloEscololar,4) AS INT),1,1)
                            ELSE DATEFROMPARTS(CAST(LEFT(B.CicloEscololar,4) AS INT),7,1) END AS SemInicio,
                    CASE WHEN RIGHT(B.CicloEscololar,1) = '1' THEN DATEFROMPARTS(CAST(LEFT(B.CicloEscololar,4) AS INT),6,30)
                            ELSE DATEFROMPARTS(CAST(LEFT(B.CicloEscololar,4) AS INT),12,31) END AS SemFin
                FROM BatchIns B
            ),
            Expanded AS (
                SELECT S.*,
                    ROW_NUMBER() OVER (PARTITION BY S.InscripcionID ORDER BY (SELECT NULL)) AS Seq,
                    (ABS(CHECKSUM(CONCAT('C',S.InscripcionID,'-',S.AlumnoID))) % (@MaxAsis - @MinAsis + 1)) + @MinAsis AS Cantidad
                FROM Sem S
                CROSS JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) t
            )
            INSERT INTO Operaciones.Asistencias (InscripcionID, AlumnoID, CursoID, FechaAsistencia, Presente)
            SELECT E.InscripcionID, E.AlumnoID, E.CursoID, CA.FechaAsistencia, CA.Presente
            FROM Expanded E
            CROSS APPLY (
                SELECT
                CAST(
                    DATEADD(
                    DAY,
                    (ABS(CHECKSUM(CONCAT('D',E.InscripcionID,'-',E.Seq))) % (DATEDIFF(DAY, E.SemInicio, E.SemFin) + 1)),
                    E.SemInicio
                    ) AS DATE
                ) AS FechaAsistencia,
                CASE WHEN (ABS(CHECKSUM(CONCAT('P',E.InscripcionID,'-',E.Seq))) % 10) < 8 THEN 1 ELSE 0 END AS Presente
            ) CA
            WHERE E.Seq <= E.Cantidad
                AND E.SemInicio IS NOT NULL
                AND E.SemFin IS NOT NULL
                AND NOT EXISTS (
                    SELECT 1 FROM Operaciones.Asistencias A
                    WHERE A.InscripcionID = E.InscripcionID
                        AND A.FechaAsistencia = CA.FechaAsistencia
                );

            SET @RowsAsis = @@ROWCOUNT;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado)
            VALUES (@CurrentRun, 'Asistencias', @InsOffset, @RowsAsis, 'COMMIT');

            COMMIT;
            PRINT 'Batch Asistencias insertadas: ' + CAST(@RowsAsis AS VARCHAR(10)) + ' (offset ' + CAST(@InsOffset AS VARCHAR(10)) + ')';
            SET @InsOffset = @InsOffset + @BatchSize;
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
            VALUES (@CurrentRun, 'Asistencias', @InsOffset, 0, 'ROLLBACK', ERROR_MESSAGE());
            PRINT 'ERROR en batch Asistencias: ' + ERROR_MESSAGE();
            THROW;
        END CATCH;
    END

--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 9. AJUSTE: Actualizamos la NotaFinal por lotes (ignorando ceros para no afectar inscripciones sin parciales aún).
--- -- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    DECLARE @RowsUpd INT = 1;
    WHILE @RowsUpd > 0
    BEGIN
        BEGIN TRAN;
        BEGIN TRY
            ;WITH CTE_Prom AS (
                SELECT TOP (@BatchSize) I.InscripcionID,
                    COALESCE(ROUND(AVG(CAST(NULLIF(C.Nota,0) AS DECIMAL(7,4))),2), 0) AS Prom
                FROM Operaciones.Inscripciones I
                LEFT JOIN Operaciones.Calificaciones C ON C.InscripcionID = I.InscripcionID
                WHERE I.NotaFinal IS NULL
                GROUP BY I.InscripcionID
                ORDER BY I.InscripcionID
            )
            UPDATE I
            SET NotaFinal = P.Prom
            FROM Operaciones.Inscripciones I
            JOIN CTE_Prom P ON I.InscripcionID = P.InscripcionID;

            SET @RowsUpd = @@ROWCOUNT;

            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado)
            VALUES (@CurrentRun, 'NotaFinal', 0, @RowsUpd, 'COMMIT');

            COMMIT;
            PRINT 'Batch NotaFinal actualizado: ' + CAST(@RowsUpd AS VARCHAR(10));
            WAITFOR DELAY @PauseBetweenBatches;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK;
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
            VALUES (@CurrentRun, 'NotaFinal', 0, 0, 'ROLLBACK', ERROR_MESSAGE());
            PRINT 'ERROR en batch NotaFinal: ' + ERROR_MESSAGE();
            THROW;
        END CATCH;
    END

--- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- -- > 10.  ACTUALIZACION: Para checkpoints de Inscripcion, Calificaciones y Asistencias (para control de FK en procesos posteriores).
--- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY
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

    -- Aplicamos Limpieza temporal a nuesta tabla de Inscripciones.
    -- NOTA: durante pruebas deja las temp tables para inspección
    --IF OBJECT_ID('tempdb..#NewIns') IS NOT NULL DROP TABLE #NewIns;
    --IF OBJECT_ID('tempdb..#Cursos') IS NOT NULL DROP TABLE #Cursos;
    --IF OBJECT_ID('tempdb..#Materias') IS NOT NULL DROP TABLE #Materias;
    --IF OBJECT_ID('tempdb..#CarrList') IS NOT NULL DROP TABLE #CarrList;

------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
------- -- 12. MÉTRICAS FINALES.
------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Mensaje)
        VALUES (@CurrentRun, 'Checkpoints', 0, 0, 'ROLLBACK', ERROR_MESSAGE());
        DECLARE @ErrMsg NVARCHAR(4000)=ERROR_MESSAGE(), @ErrLine INT = ERROR_LINE();
        PRINT '';
        PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
        PRINT '==============================================================================';
        PRINT '         ❌ ERROR DETECTADO - TRANSACCIÓN REVERTIDA';
        PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
        PRINT '🔢 Código de Error:: ' + ISNULL(@ErrMsg,'(sin mensaje)') + ' en 📍 Línea del Error ' + CAST(@ErrLine AS VARCHAR(10));
        PRINT '⚙️ Procedimiento:     ' + ISNULL(ERROR_PROCEDURE(), 'Script Directo'); -- Procedimiento donde ocurrió el error.
        PRINT '';
        PRINT '    ERROR: ' + ISNULL(@ErrMsg,'(sin mensaje)') + ' en Linea: ' + CAST(@ErrLine AS VARCHAR(10));
        THROW;
    END CATCH;
    
    DECLARE @EndTime DATETIME2 = SYSUTCDATETIME();
    PRINT '';
    PRINT '============================================================================';
    PRINT '         ✅ RESUMEN DE EJECUCIÓN EXITOSA RUN ' + CAST(@CurrentRun AS VARCHAR(3)) + ' completada.';
    PRINT '============================================================================';
    SET @CurrentRun = @CurrentRun + 1;
    PRINT '✅ Alumnos Procesados:   ' + FORMAT(@RowsAlu, 'N0');
    PRINT '📝 Departamentos Inyectados: ' + FORMAT(@InsertedDeptos, 'N0');
    PRINT '📝 Profesores Inyectados: ' + FORMAT(@InsertedProf, 'N0');
    PRINT '📝 Inscripciones Inyectadas: ' + FORMAT(@RowsIns, 'N0');
    PRINT '📝 Materias Inyectadas:     ' + FORMAT(@InsertedMat, 'N0');
    PRINT '📝 Cursos Inyectados:    ' + FORMAT(@InsertedCurs, 'N0');
    PRINT '⏱️ Tiempo de Respuesta:  ' + FORMAT(DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME()), 'N0') + ' ms';
    PRINT '⏱️ Tiempo de Ejecución: ' + FORMAT(DATEDIFF(MILLISECOND, @StartTime, @EndTime), 'N0') + ' ms';
    PRINT '📅 Finalizado el:        ' + CAST(SYSDATETIME() AS VARCHAR);
    PRINT '============================================================================';
    PRINT '';
    WAITFOR DELAY @PauseBetweenBatches;
END


