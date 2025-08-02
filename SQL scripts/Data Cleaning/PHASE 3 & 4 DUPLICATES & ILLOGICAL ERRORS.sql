-- PHASE 3 – REMOVING DUPLICATES

-- View duplicates
SELECT ProductionEventSK,BottleID_Natural,Timestamp, COUNT(*)
FROM FactProductionEvent
GROUP BY ProductionEventSK,BottleID_Natural,Timestamp
HAVING COUNT(*) > 1

-- Use ROW_NUMBER to identify redundant rows
WITH CTE AS (
    SELECT ProductionEventSK,BottleID_Natural,Timestamp, 
           ROW_NUMBER() OVER(PARTITION BY ProductionEventSK,BottleID_Natural,Timestamp 
           ORDER BY ProductionEventSK) AS rn
    FROM FactProductionEvent
)
DELETE FROM FactProductionEvent
WHERE ProductionEventSK IN (
    SELECT ProductionEventSK FROM CTE WHERE rn > 1
)

----------------------------------------------------------
-- PHASE 4 – LOGICAL INCONSISTENCIES

-- Investigate inconsistencies in test results vs defects
SELECT LeakTestResult, Defect_Type
FROM FactProductionEvent
WHERE LeakTestResult = 'Pass' AND Defect_Type IN ('Leaky_Cap', 'Both')

SELECT LeakTestResult, Defect_Type
FROM FactProductionEvent
WHERE LeakTestResult = 'Fail' AND Defect_Type = 'None'

-- Spot unusually high underfills tagged as 'underfilled'
SELECT UnderfillAmount_ml,Defect_Type 
FROM FactProductionEvent 
WHERE UnderfillAmount_ml > (
    SELECT MAX(UnderfillAmount_ml) FROM 
    (
        SELECT UnderfillAmount_ml,Defect_Type, ActualFillVolume_ml, calculated_ActualFillVolume_ml
        FROM FactProductionEvent
        WHERE Defect_Type = 'underfilled'
    ) t
)
AND Defect_Type IN('underfilled', 'Both')

-- Minimum underfill for reference
SELECT MIN(underfillAmount_ml)
FROM FactProductionEvent
WHERE Defect_Type = 'underfilled'

-- Join with supplier data for traceability
SELECT c.SupplierSK, s.SupplierName, s.SupplierID_Natural 
FROM FactProductionEvent f 
JOIN DimCapBatch c ON c.CapBatchSK = f.CapBatchSK 
JOIN DimSupplier s ON c.SupplierSK = s.SupplierSK

-- Final output for review
SELECT * FROM FactProductionEvent


SELECT TRY_CAST(ActualFillVolume_ml AS FLOAT), ActualFillVolume_ml FROM FactProductionEvent