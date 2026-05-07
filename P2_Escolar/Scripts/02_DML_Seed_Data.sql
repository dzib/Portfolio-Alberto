/* 
===========================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE 2.1: Datos de Control - Seed Data (Data Cleansing Simulation)
AUTOR: Alberto Dzib
VERSIÓN: 2.1
DESCRIPCIÓN: 
    - Inserción de catálogos base (Departamentos, Profesores, Cursos).
    - Carga de Alumnos con datos compuestos en 'MetaData_ETL' (Fecha | Estatus | Promedio).
    - Registro de transacciones iniciales para validación de PK/FK.
    - Uso de métricas de performance estandarizadas.
============================================================================================================
*/

USE P2_EscolarDB;
GO

DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();

BEGIN TRY
--- -- ---------------------------------------------------------------------------------------------------------
--- -- 1. POBLAR DEPARTAMENTOS.
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Departamentos)
    BEGIN
        INSERT INTO Catalogos.Departamentos (Nombre, PresupuestoAnual)
        VALUES
            ('Facultad de Ingeniería', 500000.00),
            ('Ciencias Exactas', 300000.00),
            ('Administración', 450000.00),
            ('Humanidades', 250000.00);
        PRINT '✅ Catálogo: Departamentos insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 2. POBLAR PROFESORES (Relacionados con Deptos).
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Profesores)
    BEGIN
        INSERT INTO Catalogos.Profesores ( Nombre, Email, DeptoID)
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
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Cursos)
    BEGIN
        INSERT INTO Catalogos.Cursos (Nombre, Creditos)
        VALUES 
            ('Base de Datos I', 8),
            ('Programación SQL Server', 6),
            ('Análisis de Algoritmos', 7),
            ('Ética Profesional', 4);
        PRINT '✅ Catálogo: Cursos insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 4. RELACIÓN CARRERA-ALUMNOS.
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Carreras)
    BEGIN
        INSERT INTO Catalogos.Carreras (NombreCarrera, DeptoID)
        VALUES
            ('Ingeniería en Sistemas', 1), -- 1 = Facultad de Ingeniería
            ('Cálculo Avanzado', 2),        -- 2 = Ciencias Exactas
            ('Contaduría Pública', 3),     -- 3 = Administración
            ('Derecho Penal', 4);          -- 4 = Humanidades
        PRINT '✅ Catálogo: Carreras insertado.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 5. POBLAR ALUMNOS (Dato Maestro con Metadata ETL).
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.Alumnos)
    BEGIN
        INSERT INTO Catalogos.Alumnos (Nombre, CarreraID, Email, FechaNacimiento, MetaData_ETL)
        VALUES
            ('Juan Carlos Luna | VIP', 1, 'juan.luna@test.com', '2002-05-15', '2023-01-10 | Activo | 8.5'),
            ('Sofia Reyes | Beca', 2, 'sofia.reyes@test.com', '2001-11-20', '2022-08-15 | Regular | 9.2'),
            ('Miguel Angel Sosa | Deporte', 3, 'migue.sosa@test.com', '2003-02-10', '2023-01-10 | Condicional | 7.4');
        PRINT '✅ Catálogo: Alumnos (Legacy Style) insertado.';
    END


--- -- ---------------------------------------------------------------------------------------------------------
--- -- 6. RELACIÓN CURSOS-PROFESORES (Asignación Académica)..
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Catalogos.CursosProfesores )  -- (Tabla Muchos a Muchos).
    BEGIN
        INSERT INTO Catalogos.CursosProfesores (CursoID, ProfesorID, CicloLectivo)
        VALUES
            (1, 1, '2025-1'), -- Julián en Bases de Datos I
            (2, 2, '2025-1'), -- Elena en Programación SQL
            (4, 4, '2025-1'); -- Ana en Ética
        PRINT '✅ Relación: Cursos-Profesores establecida.';
    END

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 7. OPERACIONES (Materias , Inscripciones y Calificaciones).
--- -- ---------------------------------------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Operaciones.Materias) -- (Uniendo Alumnos con sus Materias/Cursos).
    BEGIN
        INSERT INTO Operaciones.Materias (Nombre, Creditos , ProfesorID)
        VALUES
            ('Inducción 1', 10, 1 ),
            ('Inducción 2', 20, 2);
        PRINT '✅ Operaciones: Materias iniciales registradas.';
    END

    IF NOT EXISTS (SELECT 1 FROM Operaciones.Inscripciones) -- (Uniendo Alumnos con sus Materias/Cursos).
    BEGIN
        INSERT INTO Operaciones.Inscripciones (AlumnoID, MateriaID, CicloEscolar, NotaFinal)
        VALUES
            (1, 1, '2025-1', NULL), -- Juan Carlos inscrito en Materia 1
            (2, 2, '2025-1', NULL);
        PRINT '✅ Operaciones: Inscripciones iniciales registradas.';
    END

    IF NOT EXISTS (SELECT 1 FROM Operaciones.Calificaciones)  -- Calificaciones Parciales
    BEGIN
        INSERT INTO Operaciones.Calificaciones (AlumnoID, CursoID, Nota)
        VALUES
            (1, 1, 85.00),
            (2, 2, 95.0);
        PRINT '✅ Operaciones: Calificaciones parciales registradas.';
    END

---- -- ---------------------------------------------------------------------------------------------------------
--- -- 8. MÉTRICAS DE EJECUCIÓN.
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