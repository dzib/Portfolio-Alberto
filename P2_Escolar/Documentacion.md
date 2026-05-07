# 📑 Proyecto 2: Arquitectura de Datos Escolar - Resiliencia, Atomicidad y Stress Testing (V2.1)

## 📌 Descripción general

* Proyecto 2 del Portafolio de SQL, enfocado en la creación de un sistema de gestión académica para una institución educativa ficticia. El proyecto abarca desde la creación de tablas y carga masiva de datos, hasta la limpieza y transformación de datos para generar reportes analíticos.

---

## 🎯 Objetivo

* Diseñar e implementar un pipeline de datos completo para la gestión escolar, demostrando habilidades avanzadas en **Arquitectura de Datos, Procesos ETL y Business Intelligence**.

---

## 🏗️ Arquitectura del Pipeline (01-05)

* El ecosistema ha sido rediseñado para soportar fallos críticos de sistema y garantizar una recuperación del 100% en entornos de producción.

1. **01_Setup_DDL:** Arquitectura PascalCase con esquemas segmentados (`Catalogos`, `Operaciones`). Implementación de **Idempotencia Senior** con reseteo forzado de conexiones (`SINGLE_USER`).
2. **02_DML_Seed:** Poblado de catálogos maestros con jerarquía relacional:  **Departamentos (Facultades) ➡️ Carreras ➡️ Alumnos** **.**
3. **03_Stress_Test:** Inyección masiva de 5,000 registros con **Blindaje Proactivo de Nulos** y distribución aleatoria de alumnos por facultad para pruebas de carga realistas.
4. **04_ETL_Limpieza (Fase de Valor):**
   * **Single-Pass Processing:** Uso de **CTEs** para localizar delimitadores una sola vez, optimizando el uso de CPU.
   * **Triple Extracción Atómica:** Transformación de metadata sucia en columnas tipadas físicamente (`FechaIngreso`, `Estatus`, `Promedio`).
   * **Data Grooming:** Aplicación de Title Case a nombres y estatus.
5. **05_Executive_BI:** Dashboard visual en consola con barras de progreso y analítica de  **Eficiencia Presupuestaria** **.**

---

## 🛠️ Tecnologías y Estándares industriales

- **Entorno:** SQL Server 2025 | SSMS 22 | Git Flow.
- **Calidad:** Scripts Idempotentes (`DROP IF EXISTS`, `RESEED`).
- **Integridad:** Uso estricto de `DATETIME2`, `BEGIN TRY/CATCH` y `ROLLBACK`.
- **Métricas:** Logs detallados de tiempo de ejecución (ms) y filas afectadas.

---

## 📊 Evidencias de Ejecución

> Métricas finales obtenidas del Script 05.
> ![Resumen de Ejecución](./img/05-MetriEjecu-ReporteBI.png)

## 📊 Fase 5: Analytics & Business Intelligence (Executive View)

### 📈 Rendimiento por Facultad vs. Inversión (KPI Agregado) 🚀

>> Para demostrar la madurez del sistema, sustituiremos la tabla anterior por una que cruce el **Rendimiento Académico** con la  **Inversión (Presupuesto)** .
>>

| #           | Facultad                | Alumnos | Presupuesto Anual | Promedio | Visual Score   |
| ----------- | ----------------------- | ------- | ----------------- | -------- | -------------- |
| **1** | Administración         | 242     | $450,000.00       | 85.34    | `>>>>>>>>--` |
| **2** | Humanidades             | 286     | $250,000.00       | 85.21    | `>>>>>>>>--` |
| **3** | Facultad de Ingeniería | 230     | $500,000.00       | 84.69    | `>>>>>>>>--` |
| **4** | Ciencias Exactas        | 242     | $300,000.00       | 84.45    | `>>>>>>>>--` |

### 📈 Distribución de Estatus Académico (Segmentación)

| Estatus Académico      | Total | % Participación | Distribución Visual |
| ----------------------- | ----- | ---------------- | -------------------- |
| **Activo**        | 343   | 34.30%           | ¦¦¦¦¦¦         |
| **Pendiente**     | 282   | 28.20%           | ¦¦¦¦¦           |
| **Regular**       | 229   | 22.90%           | ¦¦¦¦             |
| **Baja Temporal** | 146   | 14.60%           | ¦¦                 |

> *Nota: Los datos reflejados corresponden al benchmark final tras la normalización atómica del ETL .*
>
> **"Legacy vs. Optimized"** :
>
> * *Legacy:* Gestión plana de alumnos por carrera.
> * *Optimized (V2.1.0):* Análisis relacional por Facultades con métricas de Score Visual y control presupuestario.

---

## 🚀 Cómo Ejecutar

1. Clonar el repositorio.
2. Ejecutar los scripts en orden secuencial (01 al 05) en SQL Server.
3. Consultar la vista `Operaciones.VW_Alumnos_Normalizados` para ver los datos limpios.

---

## 🧠 Retos Técnicos y Soluciones de Ingeniería

### Durante el desarrollo del Proyecto 2 (Escolar), se enfrentaron desafíos técnicos de nivel avanzado que fueron resueltos mediante estándares de la industria:

##### **Version 2.1.0**

1. **Consistencia Semántica en Dashboard Visual**

* **Problema:** Los reportes de BI perdían coherencia al intentar visualizar promedios en escala 0-100 dentro de barras de progreso limitadas (Generación de `NULL`s).
* **Solución:** Implementación de **Ingeniería de Defensa** mediante `CAST`, `FLOOR` y `ABS` para normalizar escalas (1-10) y asegurar que el `Score_Visual` nunca falle, incluso ante datos atípicos.

2. **Jerarquía de Facultades y Eficiencia de Inversión**

* **Problema:** El sistema original carecía de visión de negocio al no relacionar el éxito académico con la inversión financiera.
* **Solución:** Se vinculó la tabla `Departamentos` (Presupuesto) con `Carreras` y `Alumnos`. Esto permitió crear el KPI  **"Eficiencia de Inversión"** **, comparando el promedio académico por facultad contra su presupuesto anual.**

---

##### **Version 1.0.0**

1. **Gestión de Identidades en Pruebas de Estrés**

- **Problema:** Al ejecutar cargas masivas repetidas, los contadores `IDENTITY` no se reiniciaban con el comando `DELETE`, causando inconsistencias en las llaves foráneas y fallos en la lógica de filtrado.
- **Solución:** Se implementó `DBCC CHECKIDENT ('Tabla', RESEED, 0)` para garantizar que cada ejecución del pipeline inicie con una base de datos limpia y predecible desde el ID 1.
- **Impacto:** La gestión correcta de identidades en pruebas de estrés permitió mantener la **consistencia referencial** en todas las ejecuciones, evitando errores críticos en llaves foráneas y asegurando resultados confiables. Este ajuste incrementa la **robustez del pipeline**, facilita la **repetibilidad de escenarios de prueba** y aporta mayor **credibilidad a los benchmarks de rendimiento**.
  Esto garantiza **consistencia en las llaves foráneas**, elimina fallos en la lógica de filtrado y permite **pipelines confiables y repetibles** en entornos de carga masiva.

2. **Manejo de Desbordamiento Aritmético (Overflow)**

- **Problema:** Durante la generación de datos aleatorios, el cálculo de notas generaba valores de `100.00`, excediendo la precisión definida de `DECIMAL(4,2)` (máximo 99.99).
- **Solución:** Se ajustó la lógica de generación aleatoria mediante operadores de módulo (`%`) y se envolvió el proceso en bloques `BEGIN TRY/CATCH` para asegurar que el sistema nunca quede en un estado inconsistente (Rollback automático).
- **Impacto:** Se garantizó el 100% de la integridad de los datos financieros/académicos evitando detenciones en el pipeline.

3. **Procesamiento de Datos No Atómicos (ETL)**

- **Problema:** Ingesta de datos "sucios" en una sola columna con formato `Fecha|Estatus|Promedio`, lo cual impedía el análisis numérico y temporal.
- **Solución:** Se diseñó una capa de transformación mediante Common Table Expressions (CTEs) anidadas y funciones de cadena (`CHARINDEX`, `SUBSTRING`). Esto permitió separar y convertir los datos a tipos `DATETIME2` y `DECIMAL`, creando una Vista Operativa lista para Business Intelligence.
- **Impacto:** La normalización de datos no atómicos permitió transformar información cruda en **insumos analíticos confiables**. Este proceso habilitó la **trazabilidad temporal**, el cálculo preciso de métricas y la creación de una **vista operativa lista para BI**, elevando la calidad de los reportes y la capacidad de tomar decisiones estratégicas.

4. **Automatización y Métricas**

- **Problema:** Dificultad para medir el impacto de rendimiento en procesos masivos.
- **Solución:** Se estandarizó el uso de `SYSUTCDATETIME()` y `DATEDIFF` en todos los scripts, proporcionando logs de ejecución profesionales que informan el tiempo de proceso en milisegundos y el volumen de filas afectadas.
- **Impacto:** La estandarización de métricas permitió convertir cada proceso masivo en una **fuente confiable de evidencia de rendimiento**. Con registros uniformes de tiempo y volumen de filas, se logró una **medición objetiva del impacto**, facilitando la **comparación entre pipelines**, la **detección temprana de cuellos de botella** y la **comunicación clara de resultados a nivel ejecutivo**.

---

## 🛠️ Estándares de Código (Lógica)

* **Single Source of Truth:** La limpieza ocurre en la capa de persistencia; la vista analítica consume datos 100% atómicos.
* **SARGability:** Filtros eficientes (`LIKE '%|%|%'`) que evitan el procesamiento innecesario de filas ya limpias.
* **Resiliencia Atómica:** Uso mandatorio de `TRY...CATCH` con `ROLLBACK` automático para prevenir corrupción de datos en cargas masivas.

---

**Autor:** Alberto Dzib
**Versión:** 2.1.0
