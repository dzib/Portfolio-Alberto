/* 
===========================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 5 - Reportes de Business Intelligence (ConsolaBI)
AUTOR: Alberto Dzib
VERSIÓN: 2.0 (Visual Advanced)
DESCRIPCIÓN: 
    - Generación de KPIs de rendimiento académico.
    - Uso de Window Functions (RANK) para Cuadro de Honor.
    - Integración de la vista normalizada (ETL) con datos transaccionales.
============================================================================================================
*/

USE P2_EscolarDB;
GO

SET NOCOUNT ON; -- Suuprir el mensaje: "(1 filas afectadas)".
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME(); --Data Typing para métricas de tiempo.

PRINT '--------------------------------------------------------------------';
PRINT '📊 GENERANDO DASHBOARD EJECUTIVO - DZIB ANALYTICS';
PRINT '--------------------------------------------------------------------';

BEGIN TRY
--- -- ------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 1. KPI VISUAL: RENDIMIENTO POR CARRERA CON BARRAS DE PROGRESO.
--- -- ------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '==============================================================================';
    PRINT CHAR(13) + '>> [REPORTE 01] RENDIMIENTO COMPARATIVO POR FACULTAD';
    PRINT '==============================================================================';
    SELECT 
        LEFT(D.Nombre, 25) AS Facultad,
        COUNT(A.AlumnoID) AS [Población],
        FORMAT(D.PresupuestoAnual, 'C', 'en-US') AS [Presupuesto],
        CAST(AVG(A.PromedioHistorico) AS DECIMAL(4,2)) AS [Promedio],
        -- FIX: Convertimos a INT el promedio para evitar NULL y dividimos entre 10 para llevar la escala de 100 a 10.
        ISNULL(REPLICATE('>', CAST(AVG(A.PromedioHistorico)/10 AS INT)), '') + 
        ISNULL(REPLICATE('-', ABS(10 - CAST(AVG(A.PromedioHistorico)/10 AS INT))), '') AS [Score_Visual]
    FROM Operaciones.VW_Alumnos_Normalizados A
    JOIN Catalogos.Carreras C ON A.Carrera = C.NombreCarrera
    JOIN Catalogos.Departamentos D ON C.DeptoID = D.DeptoID
    GROUP BY D.Nombre, D.PresupuestoAnual
    ORDER BY [Promedio] DESC; -- Orden por éxito académico.

--- -- ------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 2. KPI VISUAL: SEMAFORIZACIÓN DE ESTATUS Y CUADRO DE HONOR.
--- -- ------------------------------------------------------------------------------------------------------------------------------------------------
    SELECT TOP 10
        DENSE_RANK() OVER (ORDER BY PromedioHistorico DESC) AS [Ranking],
        UPPER(Nombre) AS [Alumno],
        Carrera,
        PromedioHistorico AS [Nota],
        CASE 
            WHEN PromedioHistorico >= 9.5 THEN '!!! EXCELENCIA'
            WHEN PromedioHistorico >= 8.5 THEN '!! DESTACADO'
            ELSE 'REGULAR'
        END AS [Estatus_KPI]
    FROM Operaciones.VW_Alumnos_Normalizados
    ORDER BY PromedioHistorico DESC;

--- -- -----------------------------------------------------------------------------------------
--- -- 3. KPI DE SEGMENTACIÓN: SALUD ACADÉMICA GLOBAL.
--- -- -----------------------------------------------------------------------------------------
    PRINT CHAR(13) + '>> [REPORTE 03] DISTRIBUCIÓN DE ESTATUS Y PENETRACIÓN';
    PRINT '--------------------------------------------------------------------------------';
    SELECT 
        EstatusAcademico,
        COUNT(*) AS [Total],
        CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS [%_Participación],
        -- Gráfico de pay simple (representación visual)
        REPLICATE('■', CAST((COUNT(*) * 20.0 / SUM(COUNT(*)) OVER()) AS INT)) AS [Distribucion]
    FROM Operaciones.VW_Alumnos_Normalizados
    GROUP BY EstatusAcademico
    ORDER BY [%_Participación] DESC; -- De mayor a menor impacto.
--- -- ------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 5. MÉTRICAS DE CIERRE
--- -- ------------------------------------------------------------------------------------------------------------------------------------------------
        PRINT '';
    PRINT CHAR(13) +'=====================================================';
    PRINT '     ✅ Reportes BI Generados con Éxito';
    PRINT CHAR(13) +'=====================================================';
    PRINT '⏱️ Tiempo de procesamiento: ' + FORMAT(DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME()), 'N0') + ' ms';
    PRINT '📅 Reporte generado el:     ' + CAST(SYSDATETIME() AS VARCHAR);
    PRINT CHAR(13) +'=====================================================';

END TRY
BEGIN CATCH
--- -- -------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 6. MANEJO DE ERRORES
--- -- -------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '❌ Ocurrió un error durante la generación del los reportes.';
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '📍 Línea del Error:           ' + CAST(ERROR_LINE() AS VARCHAR);
    PRINT '❌ ERROR al generar reportes: ' + ERROR_MESSAGE();
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
END CATCH
