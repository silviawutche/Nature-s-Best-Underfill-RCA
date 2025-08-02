-------------------------------------------------------------
-- PHASE 1 - TIMESTAMPS
-- Initial exploration of dimensional tables for context
SELECT * FROM DimBottleBatch        -- Bottle batch metadata
SELECT * FROM DimCapBatch           -- Cap batch metadata
SELECT * FROM DimDate               -- Date dimension for time-based grouping
SELECT * FROM DimJuiceBatch         -- Juice batch details
SELECT * FROM DimMachine            -- Machines like filler, capper, etc.
SELECT * FROM DimNozzle             -- Nozzle info
SELECT * FROM DimOperator           -- Operator details
SELECT * FROM FactProductionEvent   -- Raw production event data

-- Review structure of FactProductionEvent before making changes
EXEC sp_help 'FactProductionEvent'

-- Identify malformed timestamps that cannot be cast to datetime
SELECT Timestamp, TRY_CAST(Timestamp AS datetime2) FROM FactProductionEvent
WHERE TRY_CAST(Timestamp AS datetime2) IS NULL

-- Prep a new column for cleaned timestamps (datetime format)
ALTER TABLE FactProductionEvent
ADD clean_timestamp DATETIME2

-- Re-added as VARCHAR for transformation; should be removed after final cast
ALTER TABLE FactProductionEvent
ADD clean_timestamp VARCHAR(50)

-- Drop the unnecessary extra column
ALTER TABLE FactProductionEvent
DROP COLUMN clean_timestamp

-- Extract substring from malformed timestamps that contain 'TS'
-- Example format: 'TS2025-07-01 08:00:00'
SELECT Timestamp, 
SUBSTRING(Timestamp,5,19)
FROM FactProductionEvent
WHERE Timestamp LIKE '%TS%'

-- Replace unwanted characters in timestamps like '.' and ';' for valid parsing
SELECT Timestamp, REPLACE(REPLACE(timestamp, '.','-'),';',':')
FROM FactProductionEvent
WHERE TRY_CAST(Timestamp AS datetime2) IS NULL

-- Advanced substring logic for specific timestamp patterns
SELECT Timestamp, SUBSTRING(Timestamp,5,location_of_parenthesis - location_of_dot)
FROM (
    SELECT Timestamp, CHARINDEX('(',Timestamp) -2 AS location_of_parenthesis,
           CHARINDEX(' ',Timestamp) AS location_of_dot
    FROM FactProductionEvent
    WHERE Timestamp LIKE '%TS%'
) t

-- View distinct malformed timestamps
SELECT DISTINCT Timestamp
FROM FactProductionEvent 
WHERE TRY_CAST(Timestamp AS datetime2) IS NULL

-- Clean timestamps based on format patterns using CASE logic
-- Covers TS pattern, dot/semicolon issues, and known bad values
UPDATE FactProductionEvent 
SET clean_timestamp =
    CASE 
        WHEN timestamp LIKE '%TS%' THEN TRIM(SUBSTRING(Timestamp,5,19))
        WHEN timestamp LIKE '%.%' THEN TRIM(REPLACE(REPLACE(timestamp, '.','-'),';',':'))
        WHEN Timestamp = 'unknowntimestamp' OR Timestamp LIKE '%MM%' THEN NULL
        ELSE Timestamp 
    END 

-- Check if cleaned timestamps are all valid
SELECT timestamp, CAST(clean_timestamp AS DATETIME2(6)) 
FROM FactProductionEvent
WHERE TRY_CAST(clean_Timestamp AS datetime2) IS NULL

-- Verify trim step (extra safety check)
SELECT TRIM(clean_timestamp) FROM FactProductionEvent
WHERE TRY_CAST(Timestamp AS datetime2) IS NULL

-- Replace original timestamp column with cleaned version
ALTER TABLE FactProductionEvent
DROP COLUMN Timestamp

EXEC sp_rename 'FactProductionEvent.clean_timestamp', 'Timestamp', 'COLUMN'

-- Final validation for datetime conversion
SELECT Timestamp FROM FactProductionEvent
WHERE TRY_CAST(Timestamp AS datetime2) IS NULL

-- Convert column to correct datatype
ALTER TABLE FactProductionEvent
ALTER COLUMN Timestamp DATETIME2

--------------------------------------------------------------
-- Check and clean ProductionDate in juice batch table
SELECT ProductionDate, TRY_CAST(ProductionDate AS date) FROM DimJuiceBatch
WHERE TRY_CAST(ProductionDate AS date) IS NULL

----------------------------------------------------------------------
-- Validate TargetFillVolume_ml and clean ActualFillVolume_ml

SELECT TargetFillVolume_ml FROM FactProductionEvent
WHERE TRY_CAST(TargetFillVolume_ml AS FLOAT) IS NULL

-- Identify valid rows in ActualFillVolume_ml
SELECT ActualFillVolume_ml FROM FactProductionEvent
WHERE TRY_CAST(ActualFillVolume_ml AS FLOAT) IS NOT NULL

-- Add column for clean numeric values
ALTER TABLE FactProductionEvent
ADD clean_ActualFillVolume_ml FLOAT

-- Check data profile
SELECT AVG(ActualFillVolume_ml) FROM FactProductionEvent
SELECT MIN(ActualFillVolume_ml), MAX(ActualFillVolume_ml) FROM FactProductionEvent

-- Add column to store capped version
ALTER TABLE FactProductionEvent
ADD capped_ActualFillVolume_ml FLOAT

-- Copy original values to begin transformation
UPDATE FactProductionEvent
SET capped_ActualFillVolume_ml = ActualFillVolume_ml

-- Apply capping logic to restrict outliers (>500ml and <0ml)
SELECT AVG(capped) FROM 
(
    SELECT capped_ActualFillVolume_ml, 
           CASE 
               WHEN capped_ActualFillVolume_ml > 500 THEN 500.0
               WHEN capped_ActualFillVolume_ml < 0 THEN NULL
               ELSE capped_ActualFillVolume_ml 
           END AS capped
    FROM FactProductionEvent
) t

-- Investigate underfills by DateKey
SELECT Datekey, COUNT(*) 
FROM FactProductionEvent
WHERE ActualFillVolume_ml < TargetFillVolume_ml
GROUP BY Datekey ORDER BY DateKey

-- Check if NULLs in ActualFillVolume_ml correlate to specific defects
SELECT DISTINCT Defect_Type FROM FactProductionEvent
WHERE ActualFillVolume_ml IS NULL

-- Final cast of clean volume column
UPDATE FactProductionEvent
SET clean_ActualFillVolume_ml = TRY_CAST(ActualFillVolume_ml AS FLOAT)

-- Replace original column with clean version
ALTER TABLE FactProductionEvent
DROP COLUMN ActualFillVolume_ml

EXEC sp_rename 'FactProductionEvent.clean_ActualFillVolume_ml', 'ActualFillVolume_ml', 'COLUMN'

------------------------------------------------------------------------------------------
-- CLEAN FillSpeedBottlesPerMin_actual
SELECT FillSpeedBottlesPerMin_actual FROM FactProductionEvent
WHERE TRY_CAST(FillSpeedBottlesPerMin_actual AS FLOAT) IS NULL

-- Identify NULLs to assess data quality
SELECT FillSpeedBottlesPerMin_actual FROM FactProductionEvent
WHERE FillSpeedBottlesPerMin_actual IS NULL

-------------------------------------------------------------------
-- CLEAN JuiceTemperatureC_In with raw backup

-- View problematic non-numeric values
SELECT DISTINCT * FROM (
    SELECT JuiceTemperatureC_In 
    FROM FactProductionEvent
    WHERE TRY_CAST(JuiceTemperatureC_In AS FLOAT) IS NULL
) t

-- Backup raw values
ALTER TABLE FactProductionEvent 
ADD raw_JuiceTemperatureC_In VARCHAR(50)

-- Copy values before cleaning
UPDATE FactProductionEvent
SET raw_JuiceTemperatureC_In = JuiceTemperatureC_In

-- Convert text-based anomalies to NULL
UPDATE FactProductionEvent
SET JuiceTemperatureC_In = NULL
WHERE LOWER(TRIM(JuiceTemperatureC_In)) IN ('way too hot', 'sensor_broken','cold!','hot!')

-- Convert column to numeric
ALTER TABLE FactProductionEvent
ALTER COLUMN JuiceTemperatureC_In FLOAT

-- Similar steps for JuiceViscosity
SELECT JuiceViscosity_cPs_Actual FROM FactProductionEvent
WHERE TRY_CAST(JuiceViscosity_cPs_Actual AS FLOAT) IS NULL

SELECT AVG(JuiceViscosity_cPs_Actual) FROM FactProductionEvent 
SELECT MIN(JuiceViscosity_cPs_Actual), MAX(JuiceViscosity_cPs_Actual) FROM FactProductionEvent 

ALTER TABLE FactProductionEvent
ALTER COLUMN JuiceViscosity_cPs_Actual FLOAT

--- CLEAN AmbientTemperatureC_Line
SELECT DISTINCT * FROM
(
    SELECT AmbientTemperatureC_Line 
    FROM FactProductionEvent
    WHERE TRY_CAST(AmbientTemperatureC_Line AS FLOAT) IS NULL
) t

-- Backup raw
ALTER TABLE FactProductionEvent 
ADD raw_AmbientTemperatureC_Line VARCHAR(50)

UPDATE FactProductionEvent 
SET raw_AmbientTemperatureC_Line = AmbientTemperatureC_Line

-- Convert string value like '25 C' to 25.0
UPDATE FactProductionEvent
SET AmbientTemperatureC_Line = 25.0
WHERE AmbientTemperatureC_Line = '25 C'

-- Investigate distribution
SELECT * FROM FactProductionEvent WHERE AmbientTemperatureC_Line < 0

-- Remove text values
UPDATE FactProductionEvent
SET AmbientTemperatureC_Line = NULL
WHERE LOWER(TRIM(AmbientTemperatureC_Line)) IN ('sensor_err', 'fluctuating')

-- Final conversion
ALTER TABLE FactProductionEvent
ALTER COLUMN AmbientTemperatureC_Line FLOAT

-----------------------------------------------------------------------
-- CLEAN AmbientHumidityPercent_Line
SELECT AmbientHumidityPercent_Line FROM FactProductionEvent
WHERE TRY_CAST(AmbientHumidityPercent_Line AS FLOAT) IS NULL

ALTER TABLE FactProductionEvent
ALTER COLUMN AmbientHumidityPercent_Line FLOAT

SELECT AVG(AmbientHumidityPercent_Line), MIN(AmbientHumidityPercent_Line), MAX(AmbientHumidityPercent_Line)
FROM FactProductionEvent

-- CLEAN UnderfillAmount_ml
SELECT UnderfillAmount_ml FROM FactProductionEvent
WHERE TRY_CAST(UnderfillAmount_ml AS FLOAT) IS NULL

ALTER TABLE FactProductionEvent
ALTER COLUMN UnderfillAmount_ml FLOAT

-- Derived calculation for fill volume
ALTER TABLE FactProductionEvent
ADD calculated_ActualFillVolume_ml FLOAT

UPDATE FactProductionEvent
SET calculated_ActualFillVolume_ml = (UnderfillAmount_ml + TargetFillVolume_ml)

-- Review calculated results
SELECT TargetFillVolume_ml, ActualFillVolume_ml, UnderfillAmount_ml,
       (UnderfillAmount_ml + TargetFillVolume_ml)
FROM FactProductionEvent
WHERE ActualFillVolume_ml > 400

-- CLEAN FillerMaintenanceLast_Days_Snapshot
SELECT FillerMaintenanceLast_Days_Snapshot FROM FactProductionEvent
WHERE TRY_CAST(FillerMaintenanceLast_Days_Snapshot AS FLOAT) IS NULL

ALTER TABLE FactProductionEvent
ALTER COLUMN FillerMaintenanceLast_Days_Snapshot FLOAT

-- Final check
SELECT FillerMaintenanceLast_Days_Snapshot FROM FactProductionEvent