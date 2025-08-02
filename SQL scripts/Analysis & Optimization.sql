--  BASELINE RANGE: Identify the range of production dates available
SELECT MIN(Datekey), MAX(Datekey) FROM FactProductionEvent

--  RAW DATA CHECK: Preview all production event records 
SELECT * FROM FactProductionEvent

--  BASELINE VS POST-ISSUE UNDERFILL RATE ANALYSIS
WITH CTE AS (
    SELECT Datekey AS production_date,
        COUNT(*) AS total_bottles,
        -- Count of underfilled or both defect types
        SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) AS underfilled_count,
        -- % of underfilled bottles for each production day
        SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) * 100.0 / COUNT(BottleID_Natural) AS underfill_percent
    FROM FactProductionEvent
    WHERE LineID = 'Line1'
    GROUP BY Datekey
),
-- Baseline average underfill before June 28
before_underfilled AS (
    SELECT 
        AVG(underfilled_count) AS before_Avg_underfilled_count,
        AVG(underfill_percent) AS before_Avg_underfill_percent
    FROM CTE
    WHERE production_date < '2025-06-28'
),
-- Post-issue average underfill on and after June 28
after_underfilled AS (
    SELECT 
        AVG(underfilled_count) AS after_Avg_underfilled_count,
        AVG(underfill_percent) AS after_Avg_underfill_percent
    FROM CTE
    WHERE production_date >= '2025-06-28'
)
-- Compare before and after average underfill percentages
SELECT before_Avg_underfill_percent, after_Avg_underfill_percent,
    (after_Avg_underfill_percent - before_Avg_underfill_percent) AS percentage_increase
FROM before_underfilled, after_underfilled;



-- OPTIMIZED BASELINE QUERY
-- Step 1: Daily aggregation of total bottles and underfilled counts
WITH CTE AS (
    SELECT 
        Datekey AS production_date,
        COUNT(*) AS total_bottles,
        SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) AS underfilled_count
    FROM FactProductionEvent
    WHERE LineID = 'Line1'
    GROUP BY Datekey
),

-- Step 2: Calculate underfill percentage per day
CTE2 AS (
    SELECT 
        production_date, 
        total_bottles,
        underfilled_count, 
        underfilled_count * 100.0 / total_bottles AS underfill_percent
    FROM CTE
),

-- Step 3: Compute average underfill stats before and after June 28
CTE3 AS (
    SELECT 
        AVG(CASE WHEN production_date < '2025-06-28' THEN underfill_percent END) AS before_Avg_underfill_percent,
        AVG(CASE WHEN production_date < '2025-06-28' THEN underfilled_count END) AS before_Avg_underfilled_count,
        AVG(CASE WHEN production_date >= '2025-06-28' THEN underfill_percent END) AS after_Avg_underfill_percent,
        AVG(CASE WHEN production_date >= '2025-06-28' THEN underfilled_count END) AS after_Avg_underfilled_count
    FROM CTE2
)

-- Final step: Compare underfill rates before and after June 28
SELECT 
    before_Avg_underfill_percent, 
    after_Avg_underfill_percent,
    (after_Avg_underfill_percent - before_Avg_underfill_percent) AS percentage_increase
FROM CTE3;


--  MACHINE + SHIFT INSPECTIONS
SELECT * FROM DimMachine
SELECT DISTINCT shift FROM FactProductionEvent

-- Check Saturday time range
SELECT MIN(Timestamp), MAX(Timestamp) FROM FactProductionEvent
WHERE shift = 'saturday'

-- Confirm affected Saturday production dates
SELECT DISTINCT Datekey FROM FactProductionEvent
WHERE shift = 'saturday'
ORDER BY DateKey

-- Extract time range for each shift on a given date
SELECT MIN(time), MAX(time) FROM (
    SELECT 
        MAX(CAST(Timestamp AS TIME)) AS time, 
        MIN(CAST(Timestamp AS TIME)) AS time,
        shift 
    FROM FactProductionEvent
    WHERE DateKey = '2025-07-14'
    GROUP BY shift
) t

--  SHIFT CONTRIBUTION TO UNDERFILL
SELECT shift,
    COUNT(BottleID_Natural) AS total_bottles,
    SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) AS underfilled_count,
    SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) * 100.0 / COUNT(BottleID_Natural) AS underfill_percent
FROM FactProductionEvent
WHERE LineID = 'Line1' AND Datekey >= '2025-06-28'
GROUP BY shift

--  JUICE TYPE + VISCOSITY ANALYSIS AROUND JUNE 28
WITH CTE AS (
    SELECT DateKey, j.JuiceBatchSK, Product, JuiceViscosity_cPs_Actual, TargetViscosity_cPs
    FROM FactProductionEvent f 
    JOIN DimJuiceBatch j ON f.JuiceBatchSK = j.JuiceBatchSK
    WHERE datekey BETWEEN DATEADD(WEEK, -1, '2025-06-28') AND '2025-07-15'
      AND LineID = 'Line1' AND FillerMachineID_Natural = 'Filler_11'
)

-- Compare average viscosity before and after the issue started
SELECT 
    AVG(CASE WHEN DateKey BETWEEN DATEADD(WEEK, -1, '2025-06-28') AND '2025-06-28' THEN JuiceViscosity_cPs_Actual END) AS before_avg_Viscosity,
    AVG(CASE WHEN DateKey >= '2025-06-28' THEN JuiceViscosity_cPs_Actual END) AS after_avg_Viscosity
FROM CTE

--  FILTER TO SPECIFIC NOZZLES ON FILLER_11
SELECT * FROM DimNozzle
WHERE NozzleID_Natural LIKE '%Filler_11%'

--  NOZZLE PERFORMANCE COMPARISON: BEFORE vs AFTER (ORIGINAL QUERY)
WITH before AS (
    SELECT NozzleID_Natural, lastreplacementdate,
        COUNT(BottleID_Natural) AS total_bottles,
        SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) AS before_underfilled_count,
        SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) * 100.0 / COUNT(BottleID_Natural) AS before_underfill_percent
    FROM FactProductionEvent f 
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND Datekey < '2025-06-28'
    GROUP BY NozzleID_Natural, lastreplacementdate
),
after AS (
    SELECT NozzleID_Natural, lastreplacementdate,
        COUNT(BottleID_Natural) AS total_bottles,
        SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) AS after_underfilled_count,
        SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) * 100.0 / COUNT(BottleID_Natural) AS after_underfill_percent
    FROM FactProductionEvent f 
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND Datekey >= '2025-06-28'
    GROUP BY NozzleID_Natural, lastreplacementdate
)

SELECT after.NozzleID_Natural,AVG(before_underfill_percent) before_underfill, 
AVG(after_underfill_percent) AS after_underfill, after.LastReplacementDate
FROM after JOIN before ON after.NozzleID_Natural = before.NozzleID_Natural
GROUP BY after.NozzleID_Natural, after.LastReplacementDate;

-- NOZZLE PERFORMANCE COMPARISON: BEFORE vs AFTER (OPTIMIZED QUERY)
SELECT 
    NozzleID_Natural,
    lastreplacementdate,
    COUNT(BottleID_Natural) AS total_bottles,

    -- Calculate underfill % before June 28 for each nozzle
    SUM(CASE 
        WHEN Datekey < '2025-06-28' AND Defect_type IN ('Underfilled', 'both') 
        THEN 1 ELSE 0 
    END) * 100.0 / 
    COUNT(CASE WHEN Datekey < '2025-06-28' THEN BottleID_Natural END) AS before_underfill_percent,

    -- Calculate underfill % after June 28 for each nozzle
    SUM(CASE 
        WHEN Datekey >= '2025-06-28' AND Defect_type IN ('Underfilled', 'both') 
        THEN 1 ELSE 0 
    END) * 100.0 / 
    COUNT(CASE WHEN Datekey >= '2025-06-28' THEN BottleID_Natural END) AS after_underfill_percent

FROM FactProductionEvent f 
JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
WHERE LineID = 'Line1'
GROUP BY NozzleID_Natural, lastreplacementdate;


-- Compare nozzle performance and detect long-unreplaced nozzles
SELECT after.NozzleID_Natural,
    AVG(before_underfill_percent) AS before_underfill, 
    AVG(after_underfill_percent) AS after_underfill,
    after.LastReplacementDate
FROM after 
JOIN before ON after.NozzleID_Natural = before.NozzleID_Natural
GROUP BY after.NozzleID_Natural, after.LastReplacementDate

-- Check nozzle maintenance history
SELECT FillerMaintenanceLast_Days_Snapshot FROM FactProductionEvent

-- Volume metrics for analysis of actual vs target fill
SELECT calculated_ActualFillVolume_ml, TargetFillVolume_ml 
FROM FactProductionEvent

-- Hypothesis chain 
-- 1. Bottles on Line 1 are underfilled
-- 2. Caused by two faulty nozzles
-- 3. They haven't been replaced in 3 years
-- 4. Maintenance procedures weren’t followed

-- Link nozzle to their maintenance age post-issue
SELECT FillerMaintenanceLast_Days_Snapshot, NozzleID_Natural 
FROM FactProductionEvent f
JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
WHERE LineID = 'Line1' AND FillerMachineID_Natural = 'Filler_11'
AND DateKey >= '2025-06-28'

--  DAILY UNDERFILL TREND OVER TIME
SELECT Datekey AS production_date,
    COUNT(BottleID_Natural) AS total_bottles,
    SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) AS underfilled_count,
    SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) * 100.0 / COUNT(BottleID_Natural) AS underfill_percent,
    SUM(CASE WHEN Defect_type IN ('Underfilled', 'both') THEN CostPerBottle_NGN ELSE 0 END)
FROM DimBottleBatch b 
JOIN FactProductionEvent f ON f.BottleBatchSK = b.BottleBatchSK
JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
WHERE LineID = 'Line1'
GROUP BY Datekey
ORDER BY Datekey

--  QUERY OPTIMIZATION - Clustered index for performance on date filtering
CREATE CLUSTERED INDEX idx_datekey ON FactProductionEvent (datekey)

--  IMPACT ANALYSIS: % contribution of specific nozzles to underfills
WITH Underfilled AS (
    SELECT COUNT(*) AS underfilled_bottles
    FROM FactProductionEvent f
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND DateKey >= '2025-06-28'
    AND FillerMachineID_Natural = 'Filler_11'
    AND Defect_type IN ('Underfilled', 'both')
    AND n.NozzleID_Natural IN ('Filler_11_N4','Filler_11_N2')
),
total_bottles AS (
    SELECT COUNT(*) AS total_bottles
    FROM FactProductionEvent f
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND DateKey >= '2025-06-28'
    AND FillerMachineID_Natural = 'Filler_11'
    AND n.NozzleID_Natural IN ('Filler_11_N4','Filler_11_N2')
)

-- % of defective output from bad nozzles
SELECT total_bottles, underfilled_bottles, 
    (underfilled_bottles * 100.0 / total_bottles) AS percentage
FROM underfilled, total_bottles

--  CALCULATE JUICE WASTE (LITERS)
WITH underfillAmount_ml AS (
    SELECT (SUM(UnderfillAmount_ml) * -1) / 1000 AS underfillAmount_ml 
    FROM FactProductionEvent f
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND DateKey >= '2025-06-28'
    AND FillerMachineID_Natural = 'Filler_11'
    AND n.NozzleID_Natural IN ('Filler_11_N4','Filler_11_N2')
    AND UnderfillAmount_ml <= -4
),
total_juice AS (
    SELECT (SUM(UnderfillAmount_ml) * -1) / 1000 AS total_juice 
    FROM FactProductionEvent f
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND DateKey >= '2025-06-28'
    AND FillerMachineID_Natural = 'Filler_11'
    AND n.NozzleID_Natural IN ('Filler_11_N4','Filler_11_N2')
)

SELECT total_juice, underfillAmount_ml AS total_waste, 
    underfillAmount_ml * 100.0 / total_juice AS percentage
FROM underfillAmount_ml, total_juice

--  AMOUNT LOST DUE TO DEFECT
WITH total_amount AS (
    SELECT SUM(CostPerBottle_NGN) total_amount 
    FROM DimBottleBatch b 
    JOIN FactProductionEvent f ON f.BottleBatchSK = b.BottleBatchSK
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND DateKey >= '2025-06-28'
    AND FillerMachineID_Natural = 'Filler_11'
    AND n.NozzleID_Natural IN ('Filler_11_N4','Filler_11_N2')
),
amount_lost AS (
    SELECT SUM(CostPerBottle_NGN) amount_lost 
    FROM DimBottleBatch b 
    JOIN FactProductionEvent f ON f.BottleBatchSK = b.BottleBatchSK
    JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
    WHERE LineID = 'Line1' AND DateKey = '2025-07-15'
    AND FillerMachineID_Natural = 'Filler_11'
    AND Defect_type IN ('Underfilled', 'both')
)

-- % of cost lost from defects
SELECT amount_lost, total_amount, 
    (amount_lost * 100.0 / total_amount) AS percent_lost
FROM amount_lost, total_amount

--  QUERY OPTIMIZATION - --  INDEXES TO BOOST QUERY PERFORMANCE

-- Clustered index for performance on date filtering
CREATE CLUSTERED INDEX idx_datekey ON FactProductionEvent (datekey)

CREATE INDEX idx_defect ON FactProductionEvent (defect_type)
    WHERE Defect_type IN ('Underfilled', 'both')

CREATE INDEX idx_FillerNozzleSK ON FactProductionEvent (FillerNozzleSK)

--  CREATE A REUSABLE VIEW FOR DAILY PERFORMANCE METRICS
CREATE VIEW all_metrics AS
SELECT Datekey, NozzleID_Natural,
CASE WHEN DateKey < '2025-06-28' THEN 'Before' ELSE 'After' END AS period,
COUNT(BottleBatchID_Natural) AS total_bottles,
SUM(CASE WHEN defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) AS bottles_lost,
SUM(CASE WHEN defect_type IN ('Underfilled', 'both') THEN 1 ELSE 0 END) 
* 100.0/COUNT(BottleBatchID_Natural) AS underfill_bottle_percent,

(SUM(UnderfillAmount_ml) * -1)/1000 AS total_underfilled_juice,
SUM(CASE WHEN defect_type IN ('Underfilled', 'both') 
THEN UnderfillAmount_ml * -1 ELSE 0 END)/1000 AS total_juice_lost,

SUM(CASE WHEN defect_type IN ('Underfilled', 'both') 
THEN UnderfillAmount_ml * -1 ELSE 0 END) * 100.0/(SUM(UnderfillAmount_ml) * -1) AS juice_waste_percent,


SUM(CostPerBottle_NGN) total_cost, 
SUM(CASE WHEN defect_type IN ('Underfilled', 'both') THEN CostPerBottle_NGN ELSE 0 END) AS amount_lost,
SUM(CASE WHEN defect_type IN ('Underfilled', 'both') THEN CostPerBottle_NGN ELSE 0 END)*100.0/
SUM(CostPerBottle_NGN) AS amount_lost_percent

FROM FactProductionEvent f
JOIN DimBottleBatch b ON f.BottleBatchSK = b.BottleBatchSK
JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
WHERE LineID = 'Line1' AND FillerMachineID_Natural = 'Filler_11'

GROUP BY Datekey, NozzleID_Natural,
CASE WHEN DateKey < '2025-06-28' THEN 'Before' ELSE 'After' END

ORDER BY DateKey,NozzleID_Natural;

-- VALIDATION

SELECT COUNT(*) AS total_bottles
FROM FactProductionEvent f
JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
WHERE LineID = 'Line1' AND DateKey = '2025-07-15'
AND FillerMachineID_Natural = 'Filler_11'
AND n.NozzleID_Natural = 'Filler_11_N4'
--AND Defect_type IN ('Underfilled', 'both')


SELECT SUM(CostPerBottle_NGN) amount_lost 
FROM DimBottleBatch b JOIN FactProductionEvent f
ON f.BottleBatchSK = b.BottleBatchSK
JOIN DimNozzle n ON f.FillerNozzleSK = n.NozzleSK
WHERE LineID = 'Line1' AND DateKey = '2025-07-15'
AND FillerMachineID_Natural = 'Filler_11'
AND n.NozzleID_Natural = 'Filler_11_N4'
AND Defect_type IN ('Underfilled', 'both')



SELECT NozzleID_Natural, AVG(underfill_bottle_percent) FROM all_metrics
JOIN DimDate ON all_metrics.datekey = DimDate.DateKey
WHERE WeekOfYear BETWEEN 22 AND 29
GROUP BY NozzleID_Natural

SELECT AVG(underfill_bottle_percent) FROM all_metrics
WHERE period = 'before'
SELECT SUM(amount_lost) FROM all_metrics
WHERE period = 'after'
