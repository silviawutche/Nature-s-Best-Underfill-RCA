-- PHASE 2 – STANDARDIZING TEXT COLUMNS

-- Standardizing Defect_Type categories
SELECT DISTINCT category FROM
(
    SELECT Defect_Type, CASE 
        WHEN TRIM(LOWER(defect_type)) IN ('cap leak','leaky_cap','leakycap','leaky cap','leak_cap') THEN 'Leaky_Cap'
        WHEN TRIM(LOWER(defect_type)) IN ('under fill', 'underfilled','low fill') THEN 'Underfilled'
        WHEN TRIM(LOWER(defect_type)) IN ('both defects', 'both','underfill&leak') THEN 'Both'
        WHEN TRIM(LOWER(defect_type)) IN ('none','n/a defect','nil', 'ok') THEN 'None' 
    END AS category
    FROM FactProductionEvent
) t

-- Apply cleaned values
UPDATE FactProductionEvent
SET Defect_Type = 
    CASE 
        WHEN TRIM(LOWER(defect_type)) IN ('cap leak','leaky_cap','leakycap','leaky cap','leak_cap') THEN 'Leaky_Cap'
        WHEN TRIM(LOWER(defect_type)) IN ('under fill', 'underfilled','low fill') THEN 'Underfilled'
        WHEN TRIM(LOWER(defect_type)) IN ('both defects', 'both','underfill&leak') THEN 'Both'
        WHEN TRIM(LOWER(defect_type)) IN ('none','n/a defect','nil', 'ok') THEN 'None' 
        ELSE Defect_Type
    END 
WHERE Defect_Type IS NOT NULL

-- Standardizing LeakTestResult values
SELECT DISTINCT LeakTestResult FROM FactProductionEvent

UPDATE FactProductionEvent
SET LeakTestResult = CASE 
    WHEN TRIM(LOWER(LeakTestResult)) IN ('ok', 'pass') THEN 'Pass'
    WHEN TRIM(LOWER(LeakTestResult)) IN ('not good', 'fail') THEN 'Fail'
    ELSE LeakTestResult 
END