/* 
===========================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 1.1 (SQL) - Arquitectura de Datos e Integridad Referencial
AUTOR: Alberto Dzib
VERSIÓN: 2.1 (Retrofitting)
DESCRIPCIÓN: 
    - Implementación de esquemas segmentados (Catalogos, Operaciones).
    - Preparación de columnas para normalización 1NF (Metadata_ETL).
    - Aplicación de Constraints Nominados para garantizar la calidad de los datos.
    - Aplicación de estándares PascalCase y Constraints nominados.
    - Implementación de DATETIME2 para auditar registros y facilitar procesos de limpieza (Data Cleansing). 
===========================================================================================================
*/

-- ---------------------------------------------------------------------------------------------------------
-- 1. GESTIÓN DE BASE DE DATOS (IDEMPOTENCIA).
-- ---------------------------------------------------------------------------------------------------------
USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'P2_EscolarDB')
BEGIN
    ALTER DATABASE P2_EscolarDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE P2_EscolarDB;
END;
GO

CREATE DATABASE P2_EscolarDB;
GO

USE P2_EscolarDB;
GO

-- ---------------------------------------------------------------------------------------------------------
-- 2. CREACIÓN DE ESQUEMAS.
-- ---------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Catalogos')
BEGIN
    EXEC('CREATE SCHEMA Catalogos');
    PRINT '✅ Esquema [Catalogos] creado.';
END;

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Operaciones')
BEGIN 
    EXEC('CREATE SCHEMA Operaciones');
    PRINT '✅ Esquema [Operaciones] creado.';
END;
GO

-- ---------------------------------------------------------------------------------------------------------
-- 3. TABLAS MAESTRAS (ESQUEMA CATALOGOS).
-- ---------------------------------------------------------------------------------------------------------
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME(); -- Para métricas de tiempo de ejecución.

BEGIN TRY
    CREATE TABLE Catalogos.Departamentos (
        DeptoID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(100) NOT NULL,
        PresupuestoAnual DECIMAL(15,2) CONSTRAINT CHK_PresupuestoPos CHECK (PresupuestoAnual >= 0),
        CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
    );

    CREATE TABLE Catalogos.Profesores (
        ProfesorID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(150) NOT NULL,
        Email NVARCHAR(100) CONSTRAINT UQ_Prof_Email UNIQUE,
        DeptoID INT CONSTRAINT FK_Prof_Depto FOREIGN KEY REFERENCES Catalogos.Departamentos(DeptoID),
        IsActive BIT DEFAULT 1
    );

    CREATE TABLE Catalogos.Carreras (
        CarreraID INT IDENTITY(1,1) PRIMARY KEY,
        NombreCarrera VARCHAR(100) NOT NULL,
        DeptoID INT CONSTRAINT FK_Carreras_Deptos FOREIGN KEY REFERENCES Catalogos.Departamentos(DeptoID)
    ); -- Vinculamos la Carrera al Departamento (Facultad).

    CREATE TABLE Catalogos.Alumnos (
        AlumnoID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(150) NOT NULL,
        CarreraID INT CONSTRAINT FK_Alumnos_Carreras FOREIGN KEY REFERENCES Catalogos.Carreras(CarreraID),
        DeptoID INT CONSTRAINT FK_Alumnos_Deptos FOREIGN KEY REFERENCES Catalogos.Departamentos(DeptoID),
        Email NVARCHAR(100) CONSTRAINT UQ_Alu_Email UNIQUE,
        FechaNacimiento DATE,
        -- Columna Legacy para la Fase 4: FechaIngreso | Estatus | Promedio".
        MetaData_ETL NVARCHAR(MAX),
        -- Columna Destino (single-Pass ETL Ready).
        FechaIngreso Date,
        EstatusAcademico NVARCHAR(50),
        PromedioHistorico DECIMAL(4,2),
        CreateAt DATETIME2 DEFAULT SYSUTCDATETIME()
    );

    CREATE TABLE Catalogos.Cursos (
        CursoID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(100) NOT NULL,
        Creditos INT CONSTRAINT CK_Creditos CHECK (Creditos BETWEEN 1 AND 12),
    );

    -- Estructura para logica de Llave compuesta para tabla intermedia.
    CREATE TABLE Catalogos.CursosProfesores (
        CursoID INT NOT NULL,
        ProfesorID INT NOT NULL,
        CicloLectivo VARCHAR(10) DEFAULT '2025-1',
        CONSTRAINT PK_CursosProfesores PRIMARY KEY (CursoID, ProfesorID),
        CONSTRAINT FK_CP_Cursos FOREIGN KEY (CursoID) REFERENCES Catalogos.Cursos(CursoID),
        CONSTRAINT FK_CP_Profesores FOREIGN KEY (ProfesorID) REFERENCES Catalogos.Profesores(ProfesorID)
    );

--- -- ---------------------------------------------------------------------------------------------------------
--- -- 4. TABLAS OPERATIVAS (ESQUEMA OPERACIONES).
--- -- ---------------------------------------------------------------------------------------------------------
    CREATE TABLE Operaciones.Materias (
        MateriaID INT PRIMARY KEY IDENTITY(1,1),
        Nombre NVARCHAR(100) NOT NULL,
        Creditos INT CONSTRAINT CHK_Creditos CHECK (Creditos > 0),
        ProfesorID INT CONSTRAINT FK_Mat_Prof FOREIGN KEY REFERENCES Catalogos.Profesores(ProfesorID)
    );

    CREATE TABLE Operaciones.Inscripciones (
        InscripcionID INT PRIMARY KEY IDENTITY(1,1),
        AlumnoID INT CONSTRAINT FK_Ins_Alu FOREIGN KEY REFERENCES Catalogos.Alumnos(AlumnoID),
        MateriaID INT CONSTRAINT FK_Ins_Mat FOREIGN KEY REFERENCES Operaciones.Materias(MateriaID),
        CicloEscolar NVARCHAR(20),
        NotaFinal DECIMAL(4,2) CONSTRAINT CHK_NotaRange CHECK (NotaFinal BETWEEN 0 AND 100)
    );

    CREATE TABLE Operaciones.Asistencias (
        AsistenciaID INT PRIMARY KEY IDENTITY(1,1),
        InscripcionID INT CONSTRAINT FK_Asis_Ins FOREIGN KEY REFERENCES Operaciones.Inscripciones(InscripcionID) ON DELETE CASCADE,
        FechaAsistencia DATE DEFAULT CAST(GETDATE() AS DATE),
        Presente BIT DEFAULT 1
    );


    CREATE TABLE Operaciones.Calificaciones (
        CalificacionID INT PRIMARY KEY IDENTITY(1,1),
        AlumnoID INT CONSTRAINT FK_Cal_Alumnos FOREIGN KEY REFERENCES Catalogos.Alumnos(AlumnoID),
        CursoID INT CONSTRAINT FK_Cal_Cursos FOREIGN KEY REFERENCES Catalogos.Cursos(CursoID),
        Nota DECIMAL(4,2) CONSTRAINT CK_Nota CHECK (Nota BETWEEN 0 AND 100),
        FechaEvaluacion DATETIME2 DEFAULT SYSUTCDATETIME()
    );


--- -- ---------------------------------------------------------------------------------------------------------
--- -- 5. LOG DE EJECUCIÓN Y CIERRE DE BLOQUE
--- -- ---------------------------------------------------------------------------------------------------------
    PRINT '=====================================================';
    PRINT '✅ FASE 1.1: 🚀 Arquitectura P2_Escolar Creada con Éxito';
    PRINT '⏱️ Tiempo de ejecución: ' + CAST(DATEDIFF(MS, @StartTime, SYSUTCDATETIME()) AS VARCHAR) + ' ms';
    PRINT '=====================================================';

END TRY
BEGIN CATCH
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '❌ Error en la ejecución: ' + ERROR_MESSAGE();
    PRINT '📍 Línea: ' + CAST(ERROR_LINE() AS VARCHAR);
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';

    IF @@TRANCOUNT > 0 ROLLBACK; -- Seguridad transaccional
END CATCH;
GO