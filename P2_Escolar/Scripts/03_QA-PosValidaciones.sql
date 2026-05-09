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

-- Materias con profesor inexistente
SELECT COUNT(*) MateriasSinProfesor
FROM Operaciones.Materias m
    LEFT JOIN Catalogos.Profesores p ON m.ProfesorID = p.ProfesorID
WHERE p.ProfesorID IS NULL;

-- Inscripciones sin CursoID
SELECT COUNT(*) Ins_Sin_CursoID
FROM Operaciones.Inscripciones
WHERE CursoID IS NULL;

-- Inscripciones sin parciales
SELECT COUNT(*) Ins_Sin_Parciales
FROM Operaciones.Inscripciones i
    LEFT JOIN Operaciones.Calificaciones c ON i.InscripcionID = c.InscripcionID
WHERE c.InscripcionID IS NULL;
