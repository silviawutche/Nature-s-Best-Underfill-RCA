-----------------------------------------------------------
-- DATA EXPLORATION PHASE
-- Goal: Understand data structure, identify NULLs, and explore patterns



--  Exploring dimension tables to understand metadata
SELECT * FROM DimBottleBatch        -- Bottle batch metadata
SELECT * FROM DimCapBatch           -- Cap batch metadata
SELECT * FROM DimDate               -- Date dimension for time-based grouping
SELECT * FROM DimJuiceBatch         -- Juice batch details
SELECT DISTINCT juiceType FROM DimJuiceBatch -- Unique juice types

--  Exploring operator and machine metadata
SELECT * FROM DimMachine            -- Machines like filler, capper, etc.
SELECT * FROM DimNozzle             -- Nozzle info
SELECT * FROM DimOperator           -- Operator details

--  Checking operator role distribution
SELECT [Role], COUNT(*) 
FROM DimOperator
GROUP BY [Role]

--  Checking supplier data
SELECT * FROM DimSupplier
 


-----------------------------------------------------------
-- NULL CHECK: Checking percentage of NULLs in KEY columns
-----------------------------------------------------------
SELECT 
  COUNT(*) AS total_rows,
  (COUNT(*) - COUNT(FillerNozzleSK)) * 100.0 / COUNT(*) AS FillerNozzleSK_null_pct,
  (COUNT(*) - COUNT(ProductionEventSK)) * 100.0 / COUNT(*) AS ProductionEventSK_null_pct,
  (COUNT(*) - COUNT(BottleID_Natural)) * 100.0 / COUNT(*) AS BottleID_Natural_null_pct,
  (COUNT(*) - COUNT(Timestamp)) * 100.0 / COUNT(*) AS Timestamp_null_pct,
  (COUNT(*) - COUNT(operatorSK)) * 100.0 / COUNT(*) AS operatorSK_null_pct,
  (COUNT(*) - COUNT(LineID)) * 100.0 / COUNT(*) AS LineID_null_pct,
  (COUNT(*) - COUNT([product])) * 100.0 / COUNT(*) AS product_null_pct,
  (COUNT(*) - COUNT(shift)) * 100.0 / COUNT(*) AS shift_null_pct,
  (COUNT(*) - COUNT(OperatorID_Natural)) * 100.0 / COUNT(*) AS OperatorID_Natural_null_pct,
  (COUNT(*) - COUNT(OperatorRole)) * 100.0 / COUNT(*) AS OperatorRole_null_pct,
  (COUNT(*) - COUNT(FillerMachineSK)) * 100.0 / COUNT(*) AS FillerMachineSK_null_pct,
  (COUNT(*) - COUNT(FillerMachineID_Natural)) * 100.0 / COUNT(*) AS FillerMachineID_Natural_null_pct,
  (COUNT(*) - COUNT(JuiceBatchSK)) * 100.0 / COUNT(*) AS JuiceBatchSK_null_pct,
  (COUNT(*) - COUNT(BottleBatchSK)) * 100.0 / COUNT(*) AS BottleBatchSK_null_pct,
  (COUNT(*) - COUNT(TargetFillVolume_ml)) * 100.0 / COUNT(*) AS TargetFillVolume_ml_null_pct,
  (COUNT(*) - COUNT(ActualFillVolume_ml)) * 100.0 / COUNT(*) AS ActualFillVolume_ml_null_pct,
  (COUNT(*) - COUNT(FillSpeedBottlesPerMin_Set)) * 100.0 / COUNT(*) AS FillSpeedBottlesPerMin_Set_null_pct,
  (COUNT(*) - COUNT(FillSpeedBottlesPerMin_Actual)) * 100.0 / COUNT(*) AS FillSpeedBottlesPerMin_Actual_null_pct,
  (COUNT(*) - COUNT(JuiceTemperatureC_In)) * 100.0 / COUNT(*) AS JuiceTemperatureC_In_null_pct,
  (COUNT(*) - COUNT(JuiceViscosity_cPs_Actual)) * 100.0 / COUNT(*) AS JuiceViscosity_cPs_Actual_null_pct,
  (COUNT(*) - COUNT(AmbientHumidityPercent_Line)) * 100.0 / COUNT(*) AS AmbientHumidityPercent_Line_null_pct,
  (COUNT(*) - COUNT(AmbientTemperatureC_Line)) * 100.0 / COUNT(*) AS AmbientTemperatureC_Line_null_pct,
  (COUNT(*) - COUNT(Defect_Type)) * 100.0 / COUNT(*) AS Defect_Type_null_pct,
  (COUNT(*) - COUNT(LeakTestResult)) * 100.0 / COUNT(*) AS LeakTestResult_null_pct,
  (COUNT(*) - COUNT(UnderfillAmount_ml)) * 100.0 / COUNT(*) AS UnderfillAmount_ml_null_pct,
  (COUNT(*) - COUNT(FillerMaintenanceLast_Days_Snapshot)) * 100.0 / COUNT(*) AS FillerMaintenanceLast_Days_Snapshot_null_pct
FROM FactProductionEvent


-----------------------------------------------------------
-- DUPLICATE CHECKS
-- Helps confirm uniqueness of bottle IDs and event keys
-----------------------------------------------------------
SELECT BottleID_Natural, COUNT(*) 
FROM FactProductionEvent
GROUP BY BottleID_Natural
HAVING COUNT(*) > 1

SELECT ProductionEventSK, COUNT(*) 
FROM FactProductionEvent
GROUP BY ProductionEventSK
HAVING COUNT(*) > 1


-----------------------------------------------------------
-- RECORD DRILL-DOWNS
-- Investigate specific bottle or batch
-----------------------------------------------------------
SELECT * FROM FactProductionEvent
WHERE BottleID_Natural = 'BTL2500237183'

SELECT BottleID_Natural 
FROM FactProductionEvent
WHERE BottleBatchSK = '188'


-----------------------------------------------------------
-- DATA TYPE STANDARDIZATION (Nozzle columns)
-----------------------------------------------------------
-- Check current data types
SELECT COLUMN_NAME, DATA_TYPE 
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('DimNozzle', 'FactProductionEvent')
  AND COLUMN_NAME IN ('FillerNozzleSK', 'NozzleSK')

-- Change data types for consistency
ALTER TABLE DimNozzle 
ALTER COLUMN NozzleSK INT

ALTER TABLE FactProductionEvent
ALTER COLUMN FillerNozzleSK INT

-- Convert back to string 
ALTER TABLE FactProductionEvent
ALTER COLUMN FillerNozzleSK NVARCHAR(10)


-----------------------------------------------------------
-- CLEANING TEXT VALUES: Removing .0 from 'FillerNozzleSK'
-----------------------------------------------------------
-- Preview substring logic to isolate value before '.'
SELECT FillerNozzleSK, CHARINDEX('.',FillerNozzleSK) AS location_of_dot,
SUBSTRING(FillerNozzleSK, 1, CHARINDEX('.',FillerNozzleSK)-1)
FROM FactProductionEvent

-- Clean the values and update
UPDATE FactProductionEvent
SET FillerNozzleSK = TRIM(SUBSTRING(FillerNozzleSK, 1, CHARINDEX('.',FillerNozzleSK)-1))

-- Check if unwanted characters like '0' are still present
SELECT FillerNozzleSK, CHARINDEX('0',FillerNozzleSK) AS location_of_zero
FROM FactProductionEvent

-- Final unique check
SELECT DISTINCT FillerNozzleSK 
FROM FactProductionEvent


-----------------------------------------------------------
-- VALUE DISTRIBUTIONS
-- spot skewed categories or rare values
-----------------------------------------------------------
SELECT OperatorRole, COUNT(*) 
FROM FactProductionEvent
GROUP BY OperatorRole

SELECT Defect_Type, COUNT(*) 
FROM FactProductionEvent
GROUP BY Defect_Type

-- Time range of the data
SELECT MIN(DateKey) AS StartDate, MAX(DateKey) AS EndDate
FROM FactProductionEvent

SELECT DateKey FROM FactProductionEvent
WHERE datekey IS NULL

SELECT * FROM DimDate

-- CHECKING FOR MISSING DAYS OR GAPS
SELECT FullDate AS date_column, DayName, p.DateKey AS production_date
FROM DimDate d LEFT JOIN FactProductionEvent p
ON d.DateKey = p.DateKey
WHERE  p.DateKey IS NULL
ORDER BY d.DateKey

