/* 
=========================================================================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 4 - Proceso ETL y Limpieza de Datos
AUTOR: Alberto Dzib
VERSIÓN: 2.0
DESCRIPCIÓN: 
    - Persistencia física de datos mediante Triple Extracción Atómica.
    - Data Grooming (Title Case) aplicado a Nombres y Estatus Académico.
    - Creación de Capa de Abstracción (Vista) para optimización de reportes.
    - Implementación de manejo de errores con TRY...CATCH para asegurar la robustez del proceso ETL.
=========================================================================================================================================================
*/

USE P2_EscolarDB;
GO

-- Preparacion de entorno para proceso ETL.
SET NOCOUNT ON; -- Suuprir el mensaje: "(1 filas afectadas)".
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME(); --Data Typing para métricas de tiempo.

BEGIN TRY
    BEGIN TRANSACTION;

    PRINT '--------------------------------------------------------------------';
    PRINT '🧹 Iniciando proceso ETL de Normalización y Persistencia...';
    PRINT '--------------------------------------------------------------------';
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 1. TRANSFORMACIÓN Y PERSISTENCIA FÍSICA (UPDATE ATÓMICO).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
;WITH Posiciones AS (
        -- Localizamos los delimitadores una sola vez para eficiencia de CPU.
        SELECT 
            AlumnoID, MetaData_ETL, Nombre,
            CHARINDEX('|', MetaData_ETL) as P1,
            CHARINDEX('|', MetaData_ETL, CHARINDEX('|', MetaData_ETL) + 1) as P2
        FROM Catalogos.Alumnos
        WHERE MetaData_ETL LIKE '%|%|%' -- SARGability: Solo procesamos datos sucios.
    )
    UPDATE A
    SET 
        -- Extracción y conversión de tipos en una sola pasada.
        A.FechaIngreso      = CAST(TRIM(LEFT(P.MetaData_ETL, P.P1 - 1)) AS DATE),
        
        A.EstatusAcademico  = UPPER(LEFT(TRIM(SUBSTRING(P.MetaData_ETL, P.P1 + 1, P.P2 - P.P1 - 1)), 1)) + 
                                LOWER(SUBSTRING(TRIM(SUBSTRING(P.MetaData_ETL, P.P1 + 1, P.P2 - P.P1 - 1)), 2, 50)),
        
        A.PromedioHistorico = CAST(TRIM(SUBSTRING(P.MetaData_ETL, P.P2 + 1, 10)) AS DECIMAL(4,2)),
        
        -- Data Grooming: Limpieza de Nombre y Formato Título (Solo si existe el delimitador).
        A.Nombre = CASE 
                    WHEN A.Nombre LIKE '%|%' THEN 
                        UPPER(LEFT(TRIM(LEFT(A.Nombre, CHARINDEX('|', A.Nombre) - 1)), 1)) + 
                        LOWER(SUBSTRING(TRIM(LEFT(A.Nombre, CHARINDEX('|', A.Nombre) - 1)), 2, 150))
                    ELSE 
                        UPPER(LEFT(TRIM(A.Nombre), 1)) + LOWER(SUBSTRING(TRIM(A.Nombre), 2, 150))
                END
    FROM Catalogos.Alumnos A
    JOIN Posiciones P ON A.AlumnoID = P.AlumnoID;

    DECLARE @Normalizados INT = @@ROWCOUNT; -- Capturamos el impacto real del ETL.
    PRINT '✅ Persistencia en tabla Catalogos.Alumnos finalizada.';

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
--- --  2. CREACIÓN DE CAPA DE SERVICIO (VISTA ANALÍTICA).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
    IF OBJECT_ID('Operaciones.VW_Alumnos_Normalizados', 'V') IS NOT NULL
        DROP VIEW Operaciones.VW_Alumnos_Normalizados;
    
    EXEC('
        CREATE VIEW Operaciones.VW_Alumnos_Normalizados AS
        SELECT 
            AlumnoID, 
            Nombre, 
            FechaIngreso, 
            EstatusAcademico, 
            PromedioHistorico
        FROM Catalogos.Alumnos
    ');

    COMMIT TRANSACTION;
--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 3. MÉTRICAS DE ÉXITO.
--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '=====================================================';
    PRINT '     ✅ PROCESO ETL P2 COMPLETADO CON ÉXITO';
    PRINT '=====================================================';
    PRINT '📋 Registros Normalizados: ' + FORMAT(@Normalizados, 'N0');
    PRINT '⏱️  Tiempo de ejecución:    ' + FORMAT(DATEDIFF(MS, @StartTime, SYSUTCDATETIME()), 'N0') + ' ms';
    PRINT '📅 Finalizado el:          ' + CAST(SYSDATETIME() AS VARCHAR);
    PRINT '=====================================================';

END TRY
BEGIN CATCH

--- -- -----------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 4. MANEJO DE ERRORES.
--- -----------------------------------------------------------------------------------------------------------------------------------------------------
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '          ❌ ERROR EN PROCESO ETL';
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '📍 Línea del Error:   ' + CAST(ERROR_LINE() AS VARCHAR);
    PRINT '📄 Mensaje:           ' + ERROR_MESSAGE();
    PRINT '⚙️  Estado:            Transacción Revertida (Rollback)';
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
END CATCH
GO