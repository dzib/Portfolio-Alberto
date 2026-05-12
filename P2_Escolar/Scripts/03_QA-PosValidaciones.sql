/* 
=========================================================================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 4 - Validaciones post‑ejecución ETL (QA)
AUTOR: Alberto Dzib
VERSIÓN: 2.2
DESCRIPCIÓN: 
    - Queries de revision del proceso, para validacion o correción de posibles errores.
    - Por carga grande para evitar un crecimiento excesivo del log.
    - Para auditoría y reanudar cargas uso del: Control.Checkpoints.FechaActualizacion.
=========================================================================================================================================================
*/
USE P2_EscolarDB;
GO

SET NOCOUNT ON;
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();

-- Conteo de asistencias generadas
SELECT COUNT(*) AS TotalAsistencias
FROM Operaciones.Asistencias;

-- Ejemplo de fechas generadas
SELECT TOP(20)
    A.AsistenciaID, A.InscripcionID, I.CicloEscolar, A.FechaAsistencia
FROM Operaciones.Asistencias A
    JOIN Operaciones.Inscripciones I ON A.InscripcionID = I.InscripcionID
ORDER BY A.FechaAsistencia DESC;



-- 1) Asistencias fuera del semestre derivado desde CicloEscolar
SELECT A.AsistenciaID, A.InscripcionID, I.CicloEscolar, A.FechaAsistencia
FROM Operaciones.Asistencias A
    JOIN Operaciones.Inscripciones I ON A.InscripcionID = I.InscripcionID
WHERE (
      (RIGHT(I.CicloEscolar,1) = '1' AND (MONTH(A.FechaAsistencia) NOT BETWEEN 1 AND 6 OR YEAR(A.FechaAsistencia) <> CAST(LEFT(I.CicloEscolar,4) AS INT)))
    OR (RIGHT(I.CicloEscolar,1) = '2' AND (MONTH(A.FechaAsistencia) NOT BETWEEN 7 AND 12 OR YEAR(A.FechaAsistencia) <> CAST(LEFT(I.CicloEscolar,4) AS INT)))
);

-- 2) Duplicados exactos (misma InscripcionID + misma FechaAsistencia)
SELECT InscripcionID, FechaAsistencia, COUNT(*) AS Cnt
FROM Operaciones.Asistencias
GROUP BY InscripcionID, FechaAsistencia
HAVING COUNT(*) > 1;

-- 3) Estadísticas por Inscripcion (min/max/avg asistencias)
SELECT COUNT(*) AS TotalInscripciones,
    AVG(Cnt) AS PromedioAsisPorIns,
    MIN(Cnt) AS MinAsisPorIns,
    MAX(Cnt) AS MaxAsisPorIns
FROM (
  SELECT InscripcionID, COUNT(*) AS Cnt
    FROM Operaciones.Asistencias
    GROUP BY InscripcionID
) t;

-- 4) Comprobar que CicloEscolar tiene el formato esperado
SELECT TOP(50)
    CicloEscolar
FROM Operaciones.Inscripciones
WHERE CicloEscolar NOT LIKE '[0-9][0-9][0-9][0-9]-[12]';

SELECT InscripcionID, CAST(FechaAsistencia AS DATE) AS Dia, COUNT(*) AS Cnt
FROM Operaciones.Asistencias
GROUP BY InscripcionID, CAST(FechaAsistencia AS DATE)
HAVING COUNT(*) > 1;