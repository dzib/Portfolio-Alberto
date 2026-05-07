/* 
==========================================================================================================================================================
PROYECTO: P2_Escolar - Sistema de Gestión Académica
FASE: 3 -  Stress Test & Data Quality Shield
AUTOR: Alberto Dzib
VERSIÓN: 2.2 (Enterprise Load Simulation)
DESCRIPCIÓN: 
    - Inserción masiva de 1,000 alumnos usando bucle WHILE.
    - Implementación de transacciones para asegurar la integridad.
    - Generación de datos no atómicos en columna Metadata_ETL para futuro proceso de limpieza.
==========================================================================================================================================================
*/

USE P2_EscolarDB;
GO

-- ------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables para control de bucle y métricas.
-- ------------------------------------------------------------------------------------------------------------------------------------------------------
SET NOCOUNT ON; -- Para reducir tiempo se suprime el mensaje de "(1 filas afectadas)".
DECLARE @Contador INT = 1;
DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
DECLARE @MaxAlumnos INT = 1000; -- Volumen de maestros.
DECLARE @MaxNotas INT = 5000;   -- Volumen transaccional (Stress).

----- ---------------------------------------------------------------------------------------------------------------------------------------------------
PRINT '--------------------------------------------------------------------------------------------------';
PRINT '🚀 Iniciando Stress Test en P2_EscolarDB...' + CAST(SYSUTCDATETIME() AS VARCHAR);
PRINT '--------------------------------------------------------------------------------------------------';
----- ---------------------------------------------------------------------------------------------------------------------------------------------------
BEGIN TRY
    BEGIN TRANSACTION;

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 1. LIMPIEZA Y RESET DE IDENTIDADES (Idempotencia).
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
    DELETE FROM Operaciones.Asistencias;
    DELETE FROM Operaciones.Inscripciones;
    DELETE FROM Operaciones.Calificaciones; -- Borrar detalle primero por FK
    DELETE FROM Catalogos.Alumnos;
    DBCC CHECKIDENT ('Catalogos.Alumnos', RESEED, 0) WITH NO_INFOMSGS; -- Para que en la consola se vea limpia.

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 2. POBLADO DE DEPARTAMENTOS Y PROFESORES.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '--------------------------------------------------------------------------------------------------';
    PRINT '🏢 Diversificando Departamentos y Profesores...';
    PRINT '--------------------------------------------------------------------------------------------------';
    INSERT INTO Catalogos.Departamentos (Nombre, PresupuestoAnual)
    VALUES
        ('Facultad de Medicina', 800000),
        ('Ciencias Sociales', 200000), 
        ('Diseño y Arquitectura', 450000),
        ('Idiomas', 150000);

    INSERT INTO Catalogos.Profesores (Nombre, Email, DeptoID)
    SELECT TOP 5
        'Prof_N' + CAST(ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS VARCHAR),
        'staff' + CAST(ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS VARCHAR) + '@escolar.edu',
        (SELECT TOP 1 DeptoID FROM Catalogos.Departamentos ORDER BY NEWID())
    FROM sys.all_columns; -- Generador de filas rápido.

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 3. DIVERSIFICACIÓN DE CURSOS.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '📚 Generando catálogo de cursos extendido...';
    INSERT INTO Catalogos.Cursos (Nombre, Creditos)
    VALUES 
        ('IA Generativa', 10),
        ('Estructuras de Datos', 8),
        ('Historia del Arte', 5),
        ('Derecho Mercantil', 7);

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 4. CARGA MASIVA DE ALUMNOS CON SHIELD DE NULOS.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
    PRINT '--------------------------------------------------------------------------------------------------';
    PRINT '👥 Generando ' + CAST(@MaxAlumnos AS VARCHAR) + ' alumnos con blindaje de nulos...';
    PRINT '--------------------------------------------------------------------------------------------------';
    
    WHILE @Contador <= @MaxAlumnos
    BEGIN
        -- Generación de variables con ISNULL para evitar fallos en concatenación.
        DECLARE @NombreBase NVARCHAR(50) = ISNULL(CHOOSE(FLOOR(RAND()*3)+1,'Estudiante', 'Alumno', 'Candidato'),'User');
        DECLARE @EstatusBase NVARCHAR(20) = ISNULL(CHOOSE(FLOOR(RAND()*3)+1,'ACTIVO', 'REGULAR', 'BAJA_TEMP'), 'PENDIENTE');
        DECLARE @NotaRandom DECIMAL(4,2) = ISNULL(CAST(RAND()*29.99 + 70 AS DECIMAL(4,2)), 70.00); -- Forzado para no exeda 99.99
        DECLARE @CarreraRandom  INT = FLOOR(RAND()* 4) + 1; -- Asignación aleatoria de Departamento (1-4) para evitar ruptura de FK.

        INSERT INTO Catalogos.Alumnos (Nombre, Email, FechaNacimiento, MetaData_ETL, CarreraID)
        VALUES (
            @NombreBase + '_ID_' + CAST(@Contador AS VARCHAR(10)),
            LOWER(@NombreBase) + CAST(@Contador AS VARCHAR(10)) + '@escolar.edu',
            DATEADD(DAY, -FLOOR(RAND()*365*20), GETDATE()), -- Para optener un rango de edades amplio.
            -- Metadata Legacy con variaciónes de espacio correción con el ETL.
            CAST(CAST(DATEADD(DAY, -FLOOR(RAND()*500), GETDATE()) AS DATE) AS VARCHAR(10)) + ' | ' + @EstatusBase + ' | ' + CAST(@NotaRandom AS VARCHAR(5)),
            @CarreraRandom
        );
        SET @Contador += 1;
    END

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
--- -- 5. INSCRIPCIONES MASIVAS.
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
    INSERT INTO Operaciones.Inscripciones (AlumnoID, MateriaID, CicloEscolar, NotaFinal)
    SELECT TOP (@MaxAlumnos * 3) -- Para que cada alumno tenga 3 materias promedio.
        A.AlumnoID,
        M.MateriaID,
        '2025-1',
        NULL -- La nota final se calcula después en el ETL
    FROM Catalogos.Alumnos A
    CROSS JOIN Operaciones.Materias M
    ORDER BY NEWID();

--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
---- -- 6. CARGA DE CALIFICACIONES (CROSS-JOIN DE ALTO RENDIMIENTO).
    PRINT '📊 Inyectando ' + CAST(@MaxNotas AS VARCHAR) + ' calificaciones de forma atómica...';
--- -- ---------------------------------------------------------------------------------------------------------------------------------------------------
    INSERT INTO Operaciones.Calificaciones (AlumnoID, CursoID, Nota)
    SELECT TOP (@MaxNotas)
        A.AlumnoID,
        C.CursoID, 
        ISNULL(ROUND(RAND(CHECKSUM(NEWID()))*39.99 +60, 2), 0) -- Blindaje contra nulos en el cálculo.
    FROM Catalogos.Alumnos A
    CROSS JOIN Catalogos.Cursos C -- Con esto se creará combinaciones para todos.
    ORDER BY NEWID();

    COMMIT TRANSACTION;

--- -- --------------------------------------------------------------------------------------------------------------------------------------------
--- -- 5. MÉTRICAS FINALES
--- -- --------------------------------------------------------------------------------------------------------------------------------------------
    DECLARE @EndTime DATETIME2 = SYSUTCDATETIME();
    PRINT '';
    PRINT '=====================================================';
    PRINT '       ✅ RESUMEN DE EJECUCIÓN EXITOSA';
    PRINT '=====================================================';
    PRINT '✅ Alumnos Procesados:   ' + FORMAT(@MaxAlumnos, 'N0');
    PRINT '✅ Inscripciones Totales:  ' + FORMAT(@MaxAlumnos * 3, 'N0'); -- Reflejando el TOP (@MaxAlumnos * 3)
    PRINT '📝 Notas Inyectadas:     ' + FORMAT(@MaxNotas, 'N0');
    PRINT '⏱️ Tiempo de Respuesta:  ' + FORMAT(DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME()), 'N0') + ' ms';
    PRINT '📅 Finalizado el:        ' + CAST(SYSDATETIME() AS VARCHAR);
    PRINT '=====================================================';
    PRINT '';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; -- Asegura que cualquier error revierta los cambios para mantener la integridad de la base de datos.

    PRINT '';
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '=====================================================';
    PRINT '          ❌ ERROR DETECTADO - TRANSACCIÓN REVERTIDA';
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
    PRINT '📍 Línea del Error: ' + CAST(ERROR_LINE() AS VARCHAR); -- Línea donde ocurrió el error.
    PRINT '🔢 Código de Error:   ' + CAST(ERROR_NUMBER() AS VARCHAR); -- Código de error específico.
    PRINT '📄 ERROR CRÍTICO EN PIPELINE: ' + ERROR_MESSAGE();
    PRINT '⚙️  Procedimiento:     ' + ISNULL(ERROR_PROCEDURE(), 'Script Directo');
    PRINT '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!';
END CATCH
GO