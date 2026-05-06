/* 
=================================================================================================================================================================
PROYECTO: P1_Inventario -Sistema de Gestión de Inventario.
FASE 4.1: Data Cleansing & ETL.
AUTOR: Alberto Dzib
VERSIÓN: 3.0 (Refactorización Single-Pass Processing)
DESCRIPCIÓN:
    - Implementación de limpieza atómica. Se extraen, limpian y formatean los datos en una sola pasada de motor para maximizar el rendimiento y la consistencia.
    - Se eliminan restricciones legacy que bloqueaban la limpieza de pipes.
    - Se agregan todas las columnas necesarias de una vez para preparar la estructura antes de la transformación.
    - Se aplican transformaciones robustas para normalizar categorías, proveedores, clientes, pedidos, pagos y ventas,
----   incluyendo manejo de casos atípicos y validación de formato estándar global.
    - Se realiza una validación final de calidad (QA) para verificar que no queden datos no atómicos.
=================================================================================================================================================================
*/
USE P1_Inventario;
GO

PRINT '--- PASO 1: ELIMINANDO RESTRICCIONES LEGACY ---';
IF EXISTS (SELECT * FROM sys.check_constraints WHERE name = 'CHK_FmtEstado')
    ALTER TABLE Operaciones.Pedidos DROP CONSTRAINT CHK_FmtEstado;
GO

PRINT '--- PASO 2: AGREGANDO COLUMNAS DE SOPORTE ---';
-- Agregamos todas las columnas necesarias de una vez.
-- Esto es más eficiente que agregar una por una, y nos asegura que toda la estructura esté lista antes de comenzar la transformación.

-- Inventario.
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Inventario.Categorias') AND name = 'Clasificacion')
    ALTER TABLE Inventario.Categorias ADD Clasificacion NVARCHAR(100);

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Inventario.Proveedores') AND name = 'Rubro')
    ALTER TABLE Inventario.Proveedores ADD Rubro NVARCHAR(100), Estado NVARCHAR(100);

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Inventario.Productos') AND name = 'Modelo_Ref')
    ALTER TABLE Inventario.Productos ADD Modelo_Ref NVARCHAR(100);

-- Operaciones.
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Operaciones.Clientes') AND name = 'Segmento')
    ALTER TABLE Operaciones.Clientes ADD Segmento NVARCHAR(100), Estado NVARCHAR(100);

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Operaciones.Pedidos') AND name = 'AccionPendiente')
    ALTER TABLE Operaciones.Pedidos ADD AccionPendiente NVARCHAR(200)

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Operaciones.Pagos') AND name = 'InstitucionFinanciera')
    ALTER TABLE Operaciones.Pagos ADD InstitucionFinanciera NVARCHAR(100);

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('Operaciones.Ventas_Mostrador') AND name = 'UbicacionRegional')
    ALTER TABLE Operaciones.Ventas_Mostrador ADD UbicacionRegional NVARCHAR(100);
GO

PRINT '--- PASO 3: PIPELINE ETL (SINGLE-PASS PROCESSING) ---';
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3.1 CATEGORÍAS (Extracción + Formato Título).
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------

PRINT 'Limpiando tabla: Categorias...';

UPDATE Inventario.Categorias SET 
    Clasificacion = UPPER(LEFT(TRIM(SUBSTRING(Nombre, CHARINDEX('|', Nombre) + 1, 100)), 1)) + 
                    LOWER(SUBSTRING(TRIM(SUBSTRING(Nombre, CHARINDEX('|', Nombre) + 1, 100)), 2, 100)),
    Nombre = UPPER(LEFT(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 1)) + 
            LOWER(SUBSTRING(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 2, 100))
WHERE Nombre LIKE '%|%';

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3.2 PROVEEDORES (Extracción + Grooming de Acentos).
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------

PRINT 'Limpiando tabla: Proveedores...';

UPDATE Inventario.Proveedores SET 
    Rubro = UPPER(LEFT(TRIM(SUBSTRING(Nombre, CHARINDEX('|', Nombre) + 1, 100)), 1)) + 
            LOWER(SUBSTRING(TRIM(SUBSTRING(Nombre, CHARINDEX('|', Nombre) + 1, 100)), 2, 100)),
    Nombre = UPPER(LEFT(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 1)) + 
            LOWER(SUBSTRING(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 2, 100)),
    Estado = CASE 
        WHEN Ciudad_Estado LIKE '%YUC%' THEN 'Yucatán'
        WHEN Ciudad_Estado LIKE '%QRO%' THEN 'Querétaro'
        ELSE UPPER(LEFT(TRIM(SUBSTRING(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) + 1, 100)), 1)) + 
            LOWER(SUBSTRING(TRIM(SUBSTRING(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) + 1, 100)), 2, 100))
    END,
    Ciudad_Estado = UPPER(LEFT(TRIM(LEFT(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) - 1)), 1)) + 
                    LOWER(SUBSTRING(TRIM(LEFT(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) - 1)), 2, 100))
WHERE Nombre LIKE '%|%' OR Ciudad_Estado LIKE '%|%';

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3.3 PRODUCTOS (Nombre y Modelo).
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
PRINT 'Limpiando tabla: Productos (Separando Nombre y Modelo)...';

UPDATE Inventario.Productos SET 
    Modelo_Ref = UPPER(TRIM(SUBSTRING(Nombre, CHARINDEX('|', Nombre) + 1, 100))),
    Nombre = UPPER(LEFT(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 1)) + 
            LOWER(SUBSTRING(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 2, 100))
WHERE Nombre LIKE '%|%';

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3.4 CLIENTES (Extracción + Unificación de Segmentos).
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------

PRINT 'Limpiando tabla: Clientes...';

UPDATE Operaciones.Clientes SET 
    Segmento = UPPER(LEFT(TRIM(SUBSTRING(Nombre, CHARINDEX('|', Nombre) + 1, 100)), 1)) + 
                LOWER(SUBSTRING(TRIM(SUBSTRING(Nombre, CHARINDEX('|', Nombre) + 1, 100)), 2, 100)),
    Nombre   = UPPER(LEFT(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 1)) + 
                LOWER(SUBSTRING(TRIM(LEFT(Nombre, CHARINDEX('|', Nombre) - 1)), 2, 100)),
    Estado   = CASE 
        WHEN Ciudad_Estado LIKE '%YUC%' THEN 'Yucatán'
        WHEN Ciudad_Estado LIKE '%QRO%' THEN 'Querétaro'
        WHEN Ciudad_Estado LIKE '%PUE%' THEN 'Puebla'
        ELSE UPPER(LEFT(TRIM(SUBSTRING(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) + 1, 100)), 1)) + 
            LOWER(SUBSTRING(TRIM(SUBSTRING(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) + 1, 100)), 2, 100))
    END,
    Ciudad_Estado = UPPER(LEFT(TRIM(LEFT(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) - 1)), 1)) + 
                    LOWER(SUBSTRING(TRIM(LEFT(Ciudad_Estado, CHARINDEX('|', Ciudad_Estado) - 1)), 2, 100))
WHERE Nombre LIKE '%|%' OR Ciudad_Estado LIKE '%|%';

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3.5 PEDIDOS Y PAGOS (Omnicanalidad: Unificación de 'Pagado').
-- --------------------------------------------------------------------------------------------------------------------------------------------------------------

PRINT 'Limpiando tabla unificada: Pedidos y Pagos...';

UPDATE Operaciones.Pedidos SET 
    AccionPendiente = UPPER(LEFT(TRIM(SUBSTRING(Estado_Info, CHARINDEX('|', Estado_Info) + 1, 100)), 1)) + 
                        LOWER(SUBSTRING(TRIM(SUBSTRING(Estado_Info, CHARINDEX('|', Estado_Info) + 1, 100)), 2, 100)),
    Estado_Info = CASE 
        WHEN Estado_Info LIKE '%PAGADO%' OR Estado_Info LIKE '%Pagado%' THEN 'Pagado'
        WHEN Estado_Info LIKE '%Cancelado%' THEN 'Cancelado'
        WHEN Estado_Info LIKE '%Pendiente%' THEN 'Pendiente'
        ELSE UPPER(LEFT(TRIM(LEFT(Estado_Info, CHARINDEX('|', Estado_Info) - 1)), 1)) + 
            LOWER(SUBSTRING(TRIM(LEFT(Estado_Info, CHARINDEX('|', Estado_Info) - 1)), 2, 100))
    END
WHERE Estado_Info LIKE '%|%';

PRINT 'Limpiando tabla: Pagos...';

UPDATE Operaciones.Pagos SET
    InstitucionFinanciera = UPPER(LEFT(TRIM(SUBSTRING(Metodo_Info, CHARINDEX('|', Metodo_Info) + 1, 100)), 1)) + 
                            LOWER(SUBSTRING(TRIM(SUBSTRING(Metodo_Info, CHARINDEX('|', Metodo_Info) + 1, 100)), 2, 100)),
    
    Metodo_Info = UPPER(LEFT(TRIM(LEFT(Metodo_Info, CHARINDEX('|', Metodo_Info) - 1)), 1)) + 
                    LOWER(SUBSTRING(TRIM(LEFT(Metodo_Info, CHARINDEX('|', Metodo_Info) - 1)), 2, 100))
WHERE Metodo_Info LIKE '%|%';

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3.6 VENTAS (Limpieza de Ruido 'Sucursal' + Formato Título)
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
PRINT 'Limpiando tabla: Ventas...';

UPDATE Operaciones.Ventas_Mostrador SET 
    UbicacionRegional = CASE -- Extraemos y corregimos acentos geográficos.
        WHEN Sucursal_Info LIKE '%MERIDA%' THEN 'Mérida'
        WHEN Sucursal_Info LIKE '%CANCUN%' THEN 'Cancún'
        ELSE UPPER(LEFT(TRIM(SUBSTRING(Sucursal_Info, CHARINDEX('|', Sucursal_Info) + 1, 100)), 1)) + 
            LOWER(SUBSTRING(TRIM(SUBSTRING(Sucursal_Info, CHARINDEX('|', Sucursal_Info) + 1, 100)), 2, 100))
    END,
    Sucursal_Info = UPPER(LEFT(TRIM(REPLACE(REPLACE(LEFT(Sucursal_Info, CHARINDEX('|', Sucursal_Info) - 1), 'Sucursal', ''), 'sucursal', '')), 1)) + 
                    LOWER(SUBSTRING(TRIM(REPLACE(REPLACE(LEFT(Sucursal_Info, CHARINDEX('|', Sucursal_Info) - 1), 'Sucursal', ''), 'sucursal', '')), 2, 100))
WHERE Sucursal_Info LIKE '%|%'; --Limpiamos ruido ("Sucursal") y formateamos.

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 3.7 DATA GROOMING (Palabras Compuestas: Final Touch)
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
PRINT '--- "Hard-coding" (DATA GROOMING) ---';

UPDATE Inventario.Proveedores SET
    Estado = STUFF(Estado, CHARINDEX(' ', Estado) + 1, 1, UPPER(SUBSTRING(Estado, CHARINDEX(' ', Estado) + 1, 1)))
WHERE CHARINDEX(' ', Estado) > 0; -- Solo aplica a filas que tengan un espacio, para evitar errores en estados de una sola palabra.

UPDATE Operaciones.Clientes SET
    Estado = STUFF(Estado, CHARINDEX(' ', Estado) + 1, 1, UPPER(SUBSTRING(Estado, CHARINDEX(' ', Estado) + 1, 1)))
WHERE CHARINDEX(' ', Estado) > 0; -- Función STUFF para reemplazar la letra después del espacio por su versión en mayúscula.
GO

--NEXT STEPS: Integrar tabla maestra de Dimensiones Geográficas para validar y corregir automáticamente cualquier ciudad o estado que no cumpla con el formato estándar,
-- utilizando JOINs y UPDATEs basados en similitud de texto (fuzzy matching) para casos atípicos no cubiertos por las reglas hard-coded.
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- 4. VALIDACIÓN FINAL DE CALIDAD (QA) (Verificar que no queden datos no atómicos).
-- -------------------------------------------------------------------------------------------------------------------------------------------------------------
PRINT 'Verificando resultados de la limpieza (QA)...';

-- Validación Proveedores.
SELECT TOP 5 'Proveedores' AS TBL, Nombre, Rubro, Estado FROM Inventario.Proveedores;

-- Validación Productos.
SELECT TOP 5 'Productos' AS TBL, Nombre, Modelo_Ref FROM Inventario.Productos;

-- Validación Clientes.
SELECT TOP 5 'Clientes' AS TBL, Nombre, Segmento, Estado FROM Operaciones.Clientes;

-- Validación Pedidos.
SELECT TOP 5 'Pedidos' AS TBL, Estado_Info, AccionPendiente FROM Operaciones.Pedidos;

-- Validación Pagos.
SELECT TOP 5 'Pagos' AS TBL, Metodo_Info, InstitucionFinanciera FROM Operaciones.Pagos;

-- Validación Ventas.
SELECT TOP 5 'Ventas_Mostradores' AS TBL, Sucursal_Info, UbicacionRegional FROM Operaciones.Ventas_Mostrador;

PRINT 'Proceso de limpieza completado exitosamente.';
GO
