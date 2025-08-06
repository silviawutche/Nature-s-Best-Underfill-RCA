# Nature-s-Best-Underfill-RCA

### CONTEXT AND PROBLEM
Nature’s Best Juice Co. is currently dealing with a production issue on Line 1. Over the past several days, there's been a noticeable and rising number of underfilled bottles. QA has flagged it as a priority defect trend, but the cause is still unclear.

#### Problem Statement
There is a growing rate of underfilled bottles being produced on Line A. We don’t yet know the exact start date or what's driving the issue, but it appears to be gradually getting worse

#### Who are the stakeholders
* Quality Control Manager: Ensures product meets quality standards and flags any issues
* Maintenance Lead: Keeps machines running smoothly and handles repairs
* Production Line Manager: Manages daily output on Line 1
* Plant Director: Leads the full plant operation

### BUSINESS IMPACT
We calculated the fallout from the 18 days of the underfill issues:
* **21544 underfilled bottles**
* At ₦85 and ₦73 per bottle, that's **#485,189** in lost product
* **38 Litres** of Juice was wasted


### Data Exploration and Schema Design
We worked on a structured production dataset built around a star schema with a central fact table called "FactProductionEvent"
* DimDate -- This is the calendar table
* DimMachine -- This table lists all the production machines in our factory.
* DimNozzle -- This table provides details about the small parts (nozzles) on our juice filling machines.
* DimJuiceBatch -- This table details each large quantity (batch) of juice we use
* DimBottleBatch -- This table provides information about each delivery (batch) of empty bottles we receive
* DimSupplier -- This table contains information about the companies that supply us with empty bottles

There's one snowflake element: 
  
### ER DIAGRAM 
We designed an ER diagram to visualize table relationships and track foreign keys used during analysis.
<img width="751" height="793" alt="ER Diagram" src="https://github.com/user-attachments/assets/c1a111ce-f692-4c7e-922f-0dd3c68f954b" />


## DATA CLEANING - 4- Phase Process
The cleaning was done in four phases
1. Phase 1: Timestamp
   * Timestamps are critical for trend analysis, cleaning them first ensured that sorting, filtering and comparisons worked properly. We fixed malformed and inconsistent formats, recast from text to datetime.

2. Phase 2: Numeric Corrections
   * We converted fill volume, temperature colums to numeric formats. Replaced text strings like 'Sensor broken' with nulls. This ensured that metrics are reliable.
   
-- STANDARDIZATION OF TEXT VALUES
-- LOGICAL INCONSISTENCIES

|Before|  After|
|------|--------|
| ![](https://github.com/silviawutche/Nature-s-Best-Underfill-RCA/blob/main/Resources/dirty%20event%20table.PNG) | ![](https://github.com/silviawutche/Nature-s-Best-Underfill-RCA/blob/main/Resources/Clean_event%20table.PNG)|

### Hypothesis Exploration
Before we confirmed the root cause, we explore the following hypthesis:
* Machine Cause: Filler is the root cause
* Shift related
* Change in juice viscosity and type
* Bottle change from suppliers

We used a Fishbone Diagram to map these hypotheses
![Fishbone Diagram](https://github.com/silviawutche/Nature-s-Best-Underfill-RCA/blob/main/Resources/Fishbone%20diagram.png)


## ANALYSIS
#### WHAT METRICS WE CALCULATED
To guide our analysis and validate each hypotheses, we calculated key metrics
* Underfill Rate (Before and after Jume 28)
* Underfill Rate Trend
* Juice waste
* Underfill cost
#### HOW WE TESTED EACH HYPOTHESES
We designed our analysis to test each hypothesis
* Shift: We segmented production into Morning, Evening and Saturday. Underfill rates was consistent accross all shifts which made us to rule this assumption out.
* Juice viscosity: 

### QUERIES AND LOGIC USED (VIEWS)
We created a single unified view to simpplify analysis and reuse in PowerBi
###### Logic
```sql 
CREATE VIEW all_metrics AS
SELECT 
    f.DateKey,
    n.NozzleID_Natural,

    -- Define period before or after the cutoff
    CASE 
        WHEN f.DateKey < '2025-06-28' THEN 'Before' 
        ELSE 'After' 
    END AS period,

    -- Total number of bottles
    COUNT(b.BottleBatchID_Natural) AS total_bottles,

    -- Count of bottles with underfill issues
    SUM(CASE 
            WHEN f.defect_type IN ('Underfilled', 'both') THEN 1 
            ELSE 0 
        END) AS underfilled_bottles,

    -- Percentage of bottles underfilled
    SUM(CASE 
            WHEN f.defect_type IN ('Underfilled', 'both') THEN 1 
            ELSE 0 
        END) * 100.0 / NULLIF(COUNT(b.BottleBatchID_Natural), 0) AS underfill_bottle_percent,

    -- Total underfilled juice (ml to litres, positive)
    SUM(f.UnderfillAmount_ml * -1) / 1000.0 AS total_underfilled_juice_litres,

    -- Total juice lost due to underfill
    SUM(CASE 
            WHEN f.defect_type IN ('Underfilled', 'both') THEN f.UnderfillAmount_ml * -1 
            ELSE 0 
        END) / 1000.0 AS total_juice_lost_litres,

    -- % of underfilled juice out of total
    SUM(CASE 
            WHEN f.defect_type IN ('Underfilled', 'both') THEN f.UnderfillAmount_ml * -1 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(f.UnderfillAmount_ml * -1), 0) AS juice_waste_percent,

    -- Total bottle cost
    SUM(f.CostPerBottle_NGN) AS total_bottle_cost_ngn,

    -- Cost lost due to underfilled bottles
    SUM(CASE 
            WHEN f.defect_type IN ('Underfilled', 'both') THEN f.CostPerBottle_NGN 
            ELSE 0 
        END) AS cost_lost_due_to_underfill_ngn,

    -- % cost lost
    SUM(CASE 
            WHEN f.defect_type IN ('Underfilled', 'both') THEN f.CostPerBottle_NGN 
            ELSE 0 
        END) * 100.0 / NULLIF(SUM(f.CostPerBottle_NGN), 0) AS cost_lost_percent

FROM FactProductionEvent f
JOIN DimBottleBatch b 
    ON f.BottleBatchSK = b.BottleBatchSK
JOIN DimNozzle n 
    ON f.FillerNozzleSK = n.NozzleSK
WHERE 
    f.LineID = 'Line1' 
    AND f.FillerMachineID_Natural = 'Filler_11'

GROUP BY 
    f.DateKey, 
    n.NozzleID_Natural, 
    CASE 
        WHEN f.DateKey < '2025-06-28' THEN 'Before' 
        ELSE 'After' 
    END

ORDER BY 
    f.DateKey,
    n.NozzleID_Natural;

```


### Root Cause Summary
After analyzing underfill patterns by shift, juice batch and also the Line 1 filler, we found that over 95% of the underfilled bottles came from **Nozzles 2 and 4**, with the issue starting after June 28(spike start). These Nozzles have shown no failure or problems prior to the spike date.
Using the **5 Whys**, we traced the root cause to worn out nozzles that have not been replaced in over 40 months because there was no monitoring procedures.
![](https://github.com/silviawutche/Nature-s-Best-Underfill-RCA/blob/main/Resources/Root%20Cause%20Identification.png)
-- 5 WHYS

### QUERY OPTIMIZATION
We identified bottleneck when working on the production data and we tried to imprve performance by:
* Adding a clustered index on the Date column: This was because most of the queries were filtered and grouped by date..this helped speed performance
* Adding a filtered index on the defect_type column: This was because we frequently used the WHERE clause here
* Adding a non-clustered index on FillerNozzleSK (a foreign key heavily used in joins)
*Results*: CPU usage remained stable at 0.7; I/O reduced from 37.54 to 24.60.

### VISUALIZATIONS
-- CHARTS USED AND WHY
-- THE STORY EACH CHART TOOL


### RECOMMENDATIONS
-- LIST ACTIONS
* Because Nozzle 2 and 4 have not been replace in over 17 months and since it causes 95% of the underfilled issues, we recommend that they should be replaced ( by Maintenance) and immediately.
* Given that the maintenance was overdue by 17 months and this went unnoticed, it is recommended that a formal policy be implemented to ensure all maintenance schedules are strictly monitored and adhered to, to prevent future occurrences (by Production line Manager)
* Because defect trends were not monitored, we recommend building a dashboard to track maintenance schedules and fill rate in real time to enable timely detection of any anomalies. (Data Team)

WHY WE ARE CONFIDENT THE FIX WILL WORK
Together, these measures addressed both the symptom (underfill) and the cause (lack of tracking and delayed maintenance).


* Over 90% of underfilled bottles during the spike were traced to Nozzles 2 and 4
   ,these nozzles had no issues prior to June 23, confirming a recent issue

* The spike started immediately after June 20, with no changes in juice type, shift schedule, or bottle supplier

* Other hypotheses such as shift inconsistency, juice viscosity, and supplier change were ruled out using aggregated analysis and joins


* Replacing aging or damaged mechanical parts (like filler nozzles) is a well-accepted maintenance practice

Logically, eliminating the faulty nozzles would restore normal fill rates

This gave us confidence in recommending nozzle replacement as the primary corrective action





