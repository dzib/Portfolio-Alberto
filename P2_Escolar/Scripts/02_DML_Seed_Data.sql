/* 
===========================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE 2.1: Datos de Control - Seed Data DML
AUTOR: Alberto Dzib
VERSIÓN: 2.3.1 (Enterprise Load Simulation)
DESCRIPCIÓN: 
    - Carga con datos compuestos en 'MetaData_ETL'.
    - Datos iniciales y la lógica de diversificación.
    - Registro de transacciones iniciales para validación de PK/FK.
    - Uso de métricas de performance estandarizadas.
    - Poblado completo de Catalogos.Departamentos y Catalogos.DeptoMeta.
    - Poblado de Catalogos.Profesores, Catalogos.Carreras, Support.TemasVariantes.
    - Generación controlada de Catalogos.Cursos (DeptoID 1..4).
    - Poblado estático de Catalogos.Alumnos.
    - Carga controlada en Operaciones: Materias, Inscripciones, Asistencias, Calificaciones.
    - Checkpoints y trazabilidad en Control.LoadLog.
INSTRUCCIONES | ARCHIVO: 02_DML_Seed_P2_Escolar.
    - Ejecutar después de 01_Setup (creación de esquemas, tablas Support.* y dbo.Numbers).
    - Revisar Control.LoadLog tras la ejecución.
============================================================================================================
*/

USE P2_EscolarDB;
GO

SET NOCOUNT ON; -- Suprime el mensaje: "(1 filas afectadas)".
-- Numeros de run para Control.LoadLog.
DECLARE @CurrentRun INT = ISNULL((SELECT MAX(RunNumber) FROM Control.LoadLog), 0) + 1;
DECLARE @StartTimeGlobal DATETIME2 = SYSUTCDATETIME();
DECLARE @blkStart DATETIME2;
DECLARE @blkEnd DATETIME2;
DECLARE @start_cpu BIGINT;
DECLARE @end_cpu BIGINT;
DECLARE @start_reads BIGINT;
DECLARE @end_reads BIGINT;
DECLARE @start_writes BIGINT;
DECLARE @end_writes BIGINT;
DECLARE @rowsAffected INT;
DECLARE @logId INT;

BEGIN TRY
--- -- --------------------------------------------------------------------------------------------------------
--- -- 00. Inicio
--- -- --------------------------------------------------------------------------------------------------------
    PRINT '================================================================================';
    PRINT '02_DML: Inicio poblado controlado (prueba Deptos 1 al 4)';
    PRINT 'RunNumber: ' + CAST(@CurrentRun AS VARCHAR(10));
    PRINT '================================================================================';

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 1. POBLAR DEPARTAMENTOS Y TABLA AUXILIAR METADATA.
--- -- ---------------------------------------------------------------------------------------------------------
    -- Catalogos.Departamentos (8) y Catalogos.DeptoMeta (mapeo).
    BEGIN TRAN;
    BEGIN TRY
    -- Aplicamos la función inline para capturar métricas de la sesión actual.
    -- (sys.dm_exec_requests nos ayuda para obtener contadores del request actual).
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Catalogos.Departamentos)
        BEGIN
            INSERT INTO Catalogos.Departamentos (Nombre, PresupuestoAnual)
            VALUES
                ('Departamento de Ciencias Sociales', 5000000.00),
                ('Departamento de Ingenierías', 3000000.00),
                ('Departamento de Humanidades y Comunicación', 450000.00),
                ('Departamento de Ciencias Biomédicas', 2500000.00),
                ('Departamento de Ciencias Exactas y Naturales', 1800000),
                ('Departamento de Ciencias Económico-Administrativas', 1200000),
                ('Departamento de Artes y Diseño', 450000),
                ('Departamento de Ciencias de la Salud Pública', 1500000);
        END

        ELSE
        BEGIN
            PRINT 'Catalogos.Departamentos ya contiene datos; se omite inserción.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Catalogos.Departamentos', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Departamentos ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;
        -- Insertar checkpoint y capturar id.
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Departamentos', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'Departamentos insertados');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;
        -- métricas finales y actualizar el registro.
        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);


        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;
        PRINT '✅ Catálogo: Departamentos insertado: '+ CAST(@rowsAffected AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @err_dep NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Departamentos', 0, @rowsAffected, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error Departamentos: ', @err_dep));
        RAISERROR('Error en bloque Departamentos: %s',16,1,@err_dep);
    END CATCH;

    BEGIN TRAN;
    BEGIN TRY
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        -- Tabla de mapeo para prefijos y descripciones por departamento.
        IF OBJECT_ID('Catalogos.DeptoMeta','U') IS NULL
        BEGIN
            CREATE TABLE Catalogos.DeptoMeta (
                DeptoID INT PRIMARY KEY IDENTITY(1,1),
                PrefijoNombre NVARCHAR(100) NOT NULL,
                DescripcionCurso NVARCHAR(400) NOT NULL
            );
            INSERT INTO Catalogos.DeptoMeta ( PrefijoNombre, DescripcionCurso)
            VALUES
                ( 'Desarrollo Humano - ', 'Curso introductorio sobre desarrollo humano y sociedad.'),
                ( 'Programación - ', 'Curso práctico de programación y sistemas.'),
                ( 'Ética Profesional - ', 'Curso de humanidades y desarrollo profesional.'),
                ( 'Biología - ', 'Curso de ciencias biomédicas y salud.'),
                ( 'Métodos Numericos - ', 'Curso de ciencias exactas y experimentales.'),
                ( 'Contabilidad - ', 'Curso de administración y gestión.'),
                ( 'Dibujo - ', 'Curso de artes y diseño.'),
                ( 'Salud Pública  - ', 'Curso de salud pública y políticas sanitarias.');
            END

            ELSE
            BEGIN
                INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
                VALUES (@CurrentRun, 'Catalogos.DeptoMeta', 0, 0, 'SKIP', SYSUTCDATETIME(), 'DeptoMeta ya existentes - omitido');
        END
        SET @rowsAffected = @@ROWCOUNT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.DeptoMeta', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'DeptoMeta creado y poblado');
        SET @logId = SCOPE_IDENTITY();
    
        COMMIT;
        -- métricas finales y actualizar el registro.
        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;
        PRINT '✅--Tabla DeptoMeta de mapeo para prefijos y descripciones por departamento creada--.';

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @err_depmet NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.DeptoMeta', 0, @rowsAffected, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error DeptoMeta: ', @err_depmet));
        RAISERROR('Error en bloque DeptoMeta: %s',16,1,@err_dep);
    END CATCH;
--- -- ---------------------------------------------------------------------------------------------------------
--- -- 2. POBLAR PROFESORES (Relacionados con Deptos estático).
--- -- ---------------------------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Catalogos.Profesores)
        BEGIN
            INSERT INTO Catalogos.Profesores ( Nombre, Email, DeptoID, MetaData_ETL, IsActive, Sexo)
            VALUES
                ('Doctor Julián Pérez', 'julian.perez@escolar.edu', 1, 'GEN_001|TIEMPO_COMPLETO', 1, 'M'),
                ('Maestra Elena Gómez', 'elena.gomez@escolar.edu', 2, 'GEN_002|MEDIO_TIEMPO', 1, 'F'),
                ('Doctor Roberto Isaac', 'roberto.isaac@escolar.edu', 3, 'GEN_003|INVITADO', 0, 'M'),
                ('Profesora Ana Martínez', 'ana.martinez@escolar.edu', 4, 'GEN_004|TIEMPO_COMPLETO', 1, 'F');
        END
        
        ELSE
        BEGIN
            PRINT 'Catalogos.Profesores ya contiene datos; se omite inserción.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Catalogos.Profesores', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Profesores ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Profesores', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'Profesores iniciales insertados');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;
    
        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Catalogos.Profesores insertados: ' + CAST( @rowsAffected AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @err_prof NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Profesores', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error Profesores: ', @err_prof));
        RAISERROR('Error en bloque Profesores: %s',16,1,@err_prof);
    END CATCH
--- -- ---------------------------------------------------------------------------------------------------------
--- -- 3. RELACIÓN CATALOGOS.CARRERA-DEPARTAMENTOS (estático, completo).
--- -- ---------------------------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Catalogos.Carreras)
        BEGIN
            INSERT INTO Catalogos.Carreras (NombreCarrera, DeptoID)
            VALUES
                -- 1 = Departamento de Ciencias Sociales.
                ('Psicología', 1),                                                   -- CarreraID = 1
                ('Antropología Social', 1),                                          -- CarreraID = 2
                ('Ciencia Política', 1),                                             -- CarreraID = 3
                -- 2 = Departamento de Ingenierías.
                ('Ingeniería en Sistemas', 2),                                       -- CarreraID = 4
                ('Ingeniería Industrial', 2),                                        -- CarreraID = 5
                ('Ingeniería Electrónica', 2),                                       -- CarreraID = 6
                -- 3 = Departamento de Humanidades y Comunicación.
                ('Comunicación Social', 3),                                          -- CarreraID = 7
                ('Literatura y Estudios Culturales', 3),                             -- CarreraID = 8
                ('Trabajo Social', 3),                                               -- CarreraID = 9
                -- 4 = Departamento de Ciencias Biomédica.
                ('Odontología', 4),                         -- CarreraID = 10
                ('Medicina', 4),                            -- CarreraID = 11
                ('Nutrición', 4),                           -- CarreraID = 12
                -- Departamento 5: Ciencias Exactas y Naturales
                ('Matemáticas Aplicadas', 5),
                ('Física Experimental', 5),
                ('Química Analítica', 5),
                -- Departamento 6: Ciencias Económico-Administrativas
                ('Administración de Empresas', 6),
                ('Contaduría Pública', 6),
                ('Economía', 6),
                -- Departamento 7: Artes y Diseño
                ('Diseño Gráfico', 7),
                ('Artes Visuales', 7),
                ('Diseño Industrial', 7),
                -- Departamento 8: Ciencias de la Salud Pública
                ('Epidemiología', 8),
                ('Gestión en Salud Pública', 8),
                ('Políticas Sanitarias', 8);
        END
        
        ELSE
        BEGIN
            PRINT 'Catalogos.Carreras ya contiene datos; se omite inserción.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Catalogos.Carreras', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Univeraso de Carreras ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;

        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Carreras', 0,  @rowsAffected , 'COMMIT', SYSUTCDATETIME(), 'Universo de Carreras insertadas (completo)');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;

        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Catalogos.Carreras insertadas: ' + CAST( @rowsAffected  AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @err_car NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Carreras', 0,  @rowsAffected , 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error Carreras: ', @err_car));
        RAISERROR('Error en bloque Carreras: %s',16,1,@err_car);
    END CATCH;

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 4. DICERSIFICACIÓN POBLADO DE BLOQUE: Support.TemasVariantes.
--- -- ---------------------------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY
        PRINT '--- 02_DML: Poblando Support.TemasVariantes (2 variantes por tipo por semestre) ---';
-- Regla: 3 tipos × 2 variantes por semestre = 6 materias base por semestre.
-- Diversificación: la VarianteIndex rota por semestre para que la oferta cambie progresivamente.
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Support.TemasVariantes)
        BEGIN
            DECLARE @s INT = 1;
            DECLARE @maxSem INT = (SELECT COUNT(*) FROM Support.Semestres);

            WHILE @s <= @maxSem
            BEGIN
                DECLARE @tipoID INT = 1;
                WHILE @tipoID <= (SELECT COUNT(*) FROM Support.TemaTipos)
                BEGIN
                    DECLARE @offset INT = 0;
                    WHILE @offset <= 1
                    BEGIN
                        DECLARE @varIndex INT = ((@s - 1) + @offset) % 6 + 1;
                        DECLARE @tipoNombre NVARCHAR(100) = (SELECT TipoNombre FROM Support.TemaTipos WHERE TemaTipoID = @tipoID);
                        DECLARE @ciclo NVARCHAR(20) = (SELECT c.Ciclo FROM Support.Ciclos c
                                                    JOIN Support.Semestres ss ON ss.CicloID = c.CicloID
                                                    WHERE ss.SemestreNumero = @s);

                        DECLARE @nombre NVARCHAR(200) = CONCAT(@tipoNombre, ' ', @varIndex, ' (', @ciclo, ')');

                        IF NOT EXISTS (
                            SELECT 1 FROM Support.TemasVariantes tv
                            WHERE tv.SemestreID = @s AND tv.TemaTipoID = @tipoID AND tv.VarianteIndex = @varIndex
                        )
                        BEGIN
                            INSERT INTO Support.TemasVariantes (SemestreID, TemaTipoID, VarianteIndex, Nombre)
                            VALUES (@s, @tipoID, @varIndex, @nombre);
                        END

                        SET @offset += 1;
                    END
                    SET @tipoID += 1;
                END
                SET @s += 1;
            END
        END

        ELSE
        BEGIN
            PRINT 'Support.TemasVariantes ya contiene datos; se omite poblado.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Support.TemasVariantes', 0, 0, 'SKIP', SYSUTCDATETIME(), 'TemasVariantes ya poblado - omitido');
        END

        DECLARE @rowsTV INT = (SELECT COUNT(*) FROM Support.TemasVariantes);
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Support.TemasVariantes', 0, @rowsTV, 'COMMIT', SYSUTCDATETIME(), 'Poblado inicial de TemasVariantes (2 variantes por tipo por semestre)');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;

        -- Para medir fin y actualizar métricas,
        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ --- Support.TemasVariantes poblado. ---';

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @err_tv NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Support.TemasVariantes', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error poblando TemasVariantes: ', @err_tv));
        RAISERROR('Error poblando Support.TemasVariantes: %s',16,1,@err_tv);
    END CATCH;

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 5. POBLAR CATALOGOS.CURSOS. (6 módulos por carrera). usando Catalogos.DeptoMeta.
--- -- ---------------------------------------------------------------------------------------------------------
-- Solo se va a procesar los DeptoID 1 al 4 en esta ejecución.
    BEGIN TRAN;
    BEGIN TRY
        PRINT '--- 02_DML: Generando Catalogos.Cursos (6 módulos por carrera) para Deptos 1 al 4. ---';
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Catalogos.Cursos WHERE DeptoID BETWEEN 1 AND 4)
        BEGIN
            ;WITH CursosBase AS (
                SELECT c.CarreraID, c.NombreCarrera, c.DeptoID, dm.PrefijoNombre, dm.DescripcionCurso
                FROM Catalogos.Carreras c
                JOIN Catalogos.DeptoMeta dm ON dm.DeptoID = c.DeptoID
                WHERE c.DeptoID BETWEEN 1 AND 4
            ),
            Modulos AS (
                SELECT cb.CarreraID, cb.NombreCarrera, cb.DeptoID, cb.PrefijoNombre, cb.DescripcionCurso, n.rn
                FROM CursosBase cb
                CROSS APPLY (SELECT TOP (6) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn FROM dbo.Numbers) n
            ),
            NivelMap AS (
                SELECT 1 AS NivelOrden, 'Introductorio' AS Nivel UNION ALL
                SELECT 2, 'Intermedio' UNION ALL
                SELECT 3, 'Avanzado'
            )
            INSERT INTO Catalogos.Cursos (Nombre, Descripcion, Creditos, Nivel, DeptoID)
            SELECT
                CONCAT(m.PrefijoNombre, m.NombreCarrera, ' - Módulo ', m.rn) AS Nombre,
                m.DescripcionCurso AS Descripcion,
                ((ABS(CHECKSUM(m.CarreraID + m.rn)) % 7) + 6) AS Creditos,
                nm.Nivel AS Nivel,
                m.DeptoID
            FROM Modulos m
            JOIN NivelMap nm ON nm.NivelOrden = ((m.rn - 1) % 3) + 1;
        END

        ELSE
        BEGIN
            PRINT 'Catalogos.Cursos ya contiene datos; se omite generación.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Catalogos.Cursos', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Catalogos.Cursos ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;

        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Cursos', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'Cursos generados (6 módulos por carrera)');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;

        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Catalogos.Cursos generados (Deptos 1 al 4): ' + CAST(@rowsAffected AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @err_cursos NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Cursos', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error generando Cursos: ', @err_cursos));
        RAISERROR('Error generando Catalogos.Cursos: %s',16,1,@err_cursos);
    END CATCH;

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 5. POBLAR ALUMNOS (Dato Maestro estático con Metadata ETL).
--- -- ---------------------------------------------------------------------------------------------------------
    BEGIN TRAN;
    BEGIN TRY
        PRINT '--- 02_DML: Insertando Catalogos.Alumnos (datos estáticos) ---';
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        
        IF NOT EXISTS (SELECT 1 FROM Catalogos.Alumnos)
        BEGIN
            INSERT INTO Catalogos.Alumnos (Nombre, CarreraID, DeptoID, Email, FechaNacimiento, Sexo, MetaData_ETL)
            VALUES
                ('Juan Carlos Luna', 1, 1, 'juan.lunaUNI_@escolar.edu', '2002-05-15', 'M', '2024-02-10|REGULAR|85.52'),
                ('Sofia Reyes', 4, 2, 'sofia.reyesUNI_@escolar.edu', '2001-11-20', 'F', '2025-02-15|REGULAR|90.24'),
                ('Andrea Diaz', 7, 3, 'andrea.diazUNI_@escolar.edu', '2000-01-20', 'F', '2024-07-10|IRREGULAR|78.83'),
                ('Miguel Angel Sosa', 10, 4, 'migue.sosaUNI_@escolar.edu', '1999-02-10', 'M', '2025-07-10|CONDICIONAL|70.44');
        END

        ELSE
        BEGIN
            PRINT 'Catalogos.Alumnos ya contiene los 4 datos estaticos; se omite generación.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Catalogos.Alumnos', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Catalogos.Alumnos ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;

        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Alumnos', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'Alumnos estáticos insertados (legacy style)');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;
git
        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Catálogo: 4 Alumnos estáticos (Legacy Style) insertado.';

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @err_alus NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Catalogos.Alumnos', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error generando Alumnos: ', @err_alus));
        RAISERROR('Error generando Catalogos.Alumnos: %s',16,1,@err_alus);
    END CATCH;

-- -- -----------------------------------------------------------------------------------------------------------------
--- -- 6. CARGA CONTROLADA EN OPERACIONES (Materias , Inscripciones, Asistencias y Calificaciones)|(uso de Support.*).
--- -- -----------------------------------------------------------------------------------------------------------------
--- ---------------------------------------
--- -- Parámetros y validaciones previas.
--- ---------------------------------------
    DECLARE @DeptFilterLow INT = 1;
    DECLARE @DeptFilterHigh INT = 4;

    IF (SELECT COUNT(*) FROM Support.Ciclos) = 0
        RAISERROR('Support.Ciclos vacío. Ejecuta 01Setup primero.',16,1);

    IF (SELECT COUNT(*) FROM Catalogos.Cursos WHERE DeptoID BETWEEN @DeptFilterLow AND @DeptFilterHigh) = 0
        RAISERROR('No hay cursos para Deptos 1..4. Ejecuta la parte de Catalogos.Cursos en 02_DML.',16,1);

--- -- 1) GENERAR Operaciones.Materias (por Ciclo y Grupos A-C).
    BEGIN TRAN;
    BEGIN TRY
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Operaciones.Materias)
        BEGIN
            -- Grupos A-C
            DECLARE @Grupos TABLE (Grupo NVARCHAR(5));
            INSERT INTO @Grupos (Grupo) VALUES ('A'),('B'),('C');

            -- Profesor por depto: primer profesor activo por depto (determinista).
            ;WITH ProfPick AS (
                SELECT p.ProfesorID, p.DeptoID,
                        ROW_NUMBER() OVER (PARTITION BY p.DeptoID ORDER BY p.ProfesorID) AS RN
                FROM Catalogos.Profesores p
                WHERE ISNULL(p.IsActive,1)=1
            ),
            FirstProf AS (
                SELECT ProfesorID, DeptoID FROM ProfPick WHERE RN = 1
            )
            INSERT INTO Operaciones.Materias (Nombre, Creditos, ProfesorID, CursoID, CicloEscolar, Grupo)
            SELECT
                CONCAT(dm.PrefijoNombre, c.Nombre, ' - ', cyc.Ciclo, ' - Sem', ss.SemestreNumero, ' - Grupo ', g.Grupo, ' - ', fp.ProfesorID) AS Nombre,
                c.Creditos,
                fp.ProfesorID,
                c.CursoID,
                cyc.Ciclo,
                g.Grupo
            FROM Catalogos.Cursos c
            JOIN Catalogos.DeptoMeta dm ON dm.DeptoID = c.DeptoID
            JOIN FirstProf fp ON fp.DeptoID = c.DeptoID
            JOIN Support.Semestres ss ON 1=1
            JOIN Support.Ciclos cyc ON cyc.CicloID = ss.CicloID
            JOIN Support.TemasVariantes tv ON tv.SemestreID = ss.SemestreID
            CROSS JOIN @Grupos g
            WHERE c.DeptoID BETWEEN @DeptFilterLow AND @DeptFilterHigh
                AND NOT EXISTS (
                    SELECT 1 FROM Operaciones.Materias m
                    WHERE m.CursoID = c.CursoID
                        AND m.CicloEscolar = cyc.Ciclo
                        AND m.Grupo = g.Grupo
                        AND m.Nombre LIKE '%' + dm.PrefijoNombre + '%'
                );
        END

        ELSE
        BEGIN
            PRINT 'Operaciones.Materias ya contiene datos; se omite generación.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Operaciones.Materias', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Operaciones.Materias ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Materias', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), CONCAT('Materias masivas insertadas Deptos ', @DeptFilterLow, '-', @DeptFilterHigh));
        SET @logId = SCOPE_IDENTITY();

        COMMIT;

        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Operaciones.Materias insertadas: ' + FORMAT(@rowsAffected, 'N0');

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @errMat NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Materias', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error Materias: ', @errMat));
        RAISERROR('Error en bloque Materias: %s',16,1,@errMat);
    END CATCH;
--- -- 2) INSERCIONES DE PRUEBA: Inscripciones iniciales (primeros alumnos y materias).
    BEGIN TRAN;
    BEGIN TRY
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Operaciones.Inscripciones)
        BEGIN
            DECLARE @A1 INT = (SELECT TOP (1) AlumnoID FROM Catalogos.Alumnos ORDER BY AlumnoID);
            DECLARE @A2 INT = (SELECT TOP (1) AlumnoID FROM Catalogos.Alumnos WHERE AlumnoID <> @A1 ORDER BY AlumnoID);
            DECLARE @M1 INT = (SELECT TOP (1) MateriaID FROM Operaciones.Materias ORDER BY MateriaID);
            DECLARE @M2 INT = (SELECT TOP (1) MateriaID FROM Operaciones.Materias WHERE MateriaID <> @M1 ORDER BY MateriaID);

            IF @A1 IS NULL OR @M1 IS NULL
                RAISERROR('No hay Alumnos o Materias suficientes para crear inscripciones de prueba.',16,1);

            INSERT INTO Operaciones.Inscripciones (AlumnoID, MateriaID, NotaFinal)
            VALUES
                (@A1, @M1, NULL),
                (ISNULL(@A2,@A1), ISNULL(@M2,@M1), NULL);
        END

        ELSE
        BEGIN
            PRINT 'Operaciones.Inscripciones ya contiene datos; se omite inserción inicial.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Operaciones.Inscripciones', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Inscripciones ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Inscripciones', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'Inscripciones iniciales insertadas');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;

        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Inscripciones iniciales insertadas: ' + CAST(@rowsAffected AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @errIns NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Inscripciones', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error Inscripciones: ', @errIns));
        RAISERROR('Error en bloque Inscripciones: %s',16,1,@errIns);
    END CATCH;
--- -- 3) ASISTENCIAS DE PRUEBA (vinculadas a inscripciones de muestra).
    BEGIN TRAN;
    BEGIN TRY
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Operaciones.Asistencias)
        BEGIN
            IF OBJECT_ID('tempdb..#InsSample') IS NOT NULL DROP TABLE #InsSample;
            SELECT TOP (2) InscripcionID, AlumnoID, MateriaID
            INTO #InsSample
            FROM Operaciones.Inscripciones
            ORDER BY InscripcionID;

            INSERT INTO Operaciones.Asistencias (InscripcionID, AlumnoID, CursoID, FechaAsistencia, Presente)
            SELECT i.InscripcionID, i.AlumnoID, m.CursoID,
                    CAST(SYSUTCDATETIME() AS DATE) AS FechaAsistencia,
                    1 AS Presente
            FROM #InsSample i
            JOIN Operaciones.Materias m ON m.MateriaID = i.MateriaID;
        END

        ELSE
        BEGIN
            PRINT 'Operaciones.Asistencias ya contiene datos; se omite inserción inicial.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Operaciones.Asistencias', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Asistencias ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Asistencias', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'Asistencias iniciales insertadas');
        SET @logId = SCOPE_IDENTITY();

        COMMIT;

        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Asistencias iniciales insertadas: ' + CAST(@rowsAffected AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @errAsis NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Asistencias', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error Asistencias: ', @errAsis));
        RAISERROR('Error en bloque Asistencias: %s',16,1,@errAsis);
    END CATCH;
--- -- 4) CALIFICACIONES DE PRUEBA (vinculadas a las inscripciones de muestra).
    BEGIN TRAN;
    BEGIN TRY
        SET @blkStart = SYSUTCDATETIME();
        SET @start_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @start_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        IF NOT EXISTS (SELECT 1 FROM Operaciones.Calificaciones)
        BEGIN
            IF OBJECT_ID('tempdb..#InsSampleCal') IS NULL
            BEGIN
                SELECT TOP (2) InscripcionID INTO #InsSampleCal FROM Operaciones.Inscripciones ORDER BY InscripcionID;
            END

            INSERT INTO Operaciones.Calificaciones (InscripcionID, ParcialNumero, Nota, MetaData_ETL)
            SELECT InscripcionID, 1 AS ParcialNumero, 85.00 AS Nota, 'SEED|P1'
            FROM #InsSampleCal;

            -- Actualizar NotaFinal simple (igual a la nota del parcial en este seed).
            UPDATE i
            SET i.NotaFinal = c.Nota
            FROM Operaciones.Inscripciones i
            JOIN Operaciones.Calificaciones c ON c.InscripcionID = i.InscripcionID
            WHERE c.ParcialNumero = 1;
        END

        ELSE
        BEGIN
            PRINT 'Operaciones.Calificaciones ya contiene datos; se omite inserción inicial.';
            INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
            VALUES (@CurrentRun, 'Operaciones.Calificaciones', 0, 0, 'SKIP', SYSUTCDATETIME(), 'Calificaciones ya existentes - omitido');
        END

        SET @rowsAffected = @@ROWCOUNT;
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Calificaciones', 0, @rowsAffected, 'COMMIT', SYSUTCDATETIME(), 'Calificaciones iniciales insertadas');
        SET @logId = SCOPE_IDENTITY();


        COMMIT;

        SET @blkEnd = SYSUTCDATETIME();
        SET @end_cpu = ISNULL((SELECT cpu_time FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_reads = ISNULL((SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);
        SET @end_writes = ISNULL((SELECT writes FROM sys.dm_exec_requests WHERE session_id = @@SPID),0);

        UPDATE Control.LoadLog
        SET DurationMs = DATEDIFF(MILLISECOND, @blkStart, @blkEnd),
            CpuMs = CASE WHEN @end_cpu >= @start_cpu THEN @end_cpu - @start_cpu ELSE 0 END,
            RowsRead = CASE WHEN @end_reads >= @start_reads THEN @end_reads - @start_reads ELSE 0 END,
            RowsWritten = CASE WHEN @end_writes >= @start_writes THEN @end_writes - @start_writes ELSE 0 END
        WHERE LoadLogID = @logId;

        PRINT '✅ Calificaciones iniciales insertadas y NotaFinal actualizada: ' + CAST(@rowsAffected AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @errCal NVARCHAR(4000) = ERROR_MESSAGE();
        INSERT INTO Control.LoadLog (RunNumber, Entidad, BatchOffset, RowsAffected, Estado, Fecha, Mensaje)
        VALUES (@CurrentRun, 'Operaciones.Calificaciones', 0, 0, 'ROLLBACK', SYSUTCDATETIME(), CONCAT('Error Calificaciones: ', @errCal));
        RAISERROR('Error en bloque Calificaciones: %s',16,1,@errCal);
    END CATCH;

---- -- --------------------------------------------------------------------------------------------------------
--- -- 7. MÉTRICAS DE EJECUCIÓN (resumen del bloque).
--- -- ---------------------------------------------------------------------------------------------------------
    DECLARE @ElapsedMs BIGINT = DATEDIFF(MILLISECOND, @StartTimeGlobal, SYSUTCDATETIME());
    PRINT '=========================================================';
    PRINT '✅ Fase 2.2: Datos iniciales de P2 cargados con éxito.';
    PRINT '⏱️ Tiempo de ejecución: ' + CAST(@ElapsedMs AS VARCHAR(20)) + ' ms.';
    PRINT '=========================================================';

END TRY
BEGIN CATCH
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '❌ Error en Script 02 bloque de carga controlada:: ' + ERROR_MESSAGE();
    PRINT '📍 Línea: ' + CAST(ERROR_LINE() AS VARCHAR);
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    IF @@TRANCOUNT > 0 ROLLBACK; -- Seguridad transaccional
END CATCH;


---- -- --------------------------------------------------------------------------------------------------------
--- -- 8. CONSULTAS DE VERIFICACIÓN (manualmente posterior a ejecutar 02_DML).
--- -- ---------------------------------------------------------------------------------------------------------
-- 8.1 Temas por semestre (deben ser 6 por semestre).
SELECT ss.SemestreNumero, c.Ciclo, COUNT(tv.TemaVarID) AS TemasPorSemestre
FROM Support.TemasVariantes tv
JOIN Support.Semestres ss ON ss.SemestreID = tv.SemestreID
JOIN Support.Ciclos c ON c.CicloID = ss.CicloID
GROUP BY ss.SemestreNumero, c.Ciclo
ORDER BY ss.SemestreNumero;

-- 8.2 Cursos por carrera (debe mostrar 6 módulos por carrera para Deptos 1..4).
SELECT ca.NombreCarrera, ca.DeptoID, COUNT(cr.CursoID) AS CursosPorCarrera
FROM Catalogos.Carreras ca
LEFT JOIN Catalogos.Cursos cr ON cr.Nombre LIKE '%' + ca.NombreCarrera + '%'
GROUP BY ca.NombreCarrera, ca.DeptoID
ORDER BY ca.DeptoID, ca.NombreCarrera;

-- 8.3 Conteos generales de tablas Operaciones.
SELECT 
    (SELECT COUNT(*) FROM Operaciones.Materias) AS Total_Materias,
    (SELECT COUNT(*) FROM Operaciones.Inscripciones) AS Total_Inscripciones,
    (SELECT COUNT(*) FROM Operaciones.Calificaciones) AS Total_Calificaciones,
    (SELECT COUNT(*) FROM Operaciones.Asistencias) AS Total_Asistencias;

-- 8.4 Muestra de Materias generadas (primeras 50).
SELECT TOP (50) MateriaID, Nombre, Creditos, ProfesorID, CursoID, CicloEscolar, Grupo
FROM Operaciones.Materias
ORDER BY MateriaID;

-- 8.5 Muestra de Inscripciones (primeras 2).
SELECT TOP (2) i.InscripcionID, i.AlumnoID, a.Nombre AS AlumnoNombre, i.MateriaID, m.Nombre AS MateriaNombre, i.NotaFinal
FROM Operaciones.Inscripciones i
LEFT JOIN Catalogos.Alumnos a ON a.AlumnoID = i.AlumnoID
LEFT JOIN Operaciones.Materias m ON m.MateriaID = i.MateriaID
ORDER BY i.InscripcionID;

-- 8.6 Verificar integridad FK básica: inscripciones con materias inexistentes (debe devolver 0).
SELECT COUNT(*) AS Inscripciones_Sin_Materia
FROM Operaciones.Inscripciones i
LEFT JOIN Operaciones.Materias m ON m.MateriaID = i.MateriaID
WHERE m.MateriaID IS NULL;

-- 8.7 Verificar integridad FK básica: materias con cursos inexistentes (debe devolver 0).
SELECT COUNT(*) AS Materias_Sin_Curso
FROM Operaciones.Materias om
LEFT JOIN Catalogos.Cursos cr ON cr.CursoID = om.CursoID
WHERE cr.CursoID IS NULL;

-- 8.8 Revisar Control.LoadLog (últimos registros).
SELECT TOP (100) * FROM Control.LoadLog ORDER BY Fecha DESC, LoadLogID DESC

PRINT '================================================================================';
PRINT ' ---   02_DML (prueba) finalizado. Revisa Control.LoadLog.   --- ';
PRINT '================================================================================';
GO
