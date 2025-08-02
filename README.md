# Nature-s-Best-Underfill-RCA

### CONTEXT AND PROBLEM
Nature’s Best Juice Co. is currently dealing with a production issue on Line 1. Over the past several days, there's been a noticeable and rising number of underfilled bottles. QA has flagged it as a priority defect trend, but the cause is still unclear.

#### Problem Statement
There is a growing rate of underfilled bottles being produced on Line A. We don’t yet know the exact start date or what's driving the issue, but it appears to be gradually getting worse

#### Who are the stakeholders
* Quality Control Manager: Ensures product meets quality standards and flags any issues
* Maintenance Lead: Keeps machines running smoothly and handles repairs
* Production Line Manager: Manages daily output on Line A
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

Before                                             | After
![](https://github.com/silviawutche/Nature-s-Best-Underfill-RCA/blob/main/Resources/dirty%20event%20table.PNG)    | ![](https://github.com/silviawutche/Nature-s-Best-Underfill-RCA/blob/main/Resources/Clean_event%20table.PNG)

HYPOTHESES
-- WHAT DID YOU INITIALLY SUSPECTED

ANALYSIS
-- HOW WE TESTED EACH HYPOTHESES
-- WHAT METRICS WE CALCULATED
-- QUERIES AND LOGIC USED (VIEWS)

ROOT CAUSE
-- WHAT THE DATA PROVED
-- 5 WHYS

QUERY OPTIMIZATION
-- WHAT INDEXES 
-- HOW PERFORMANCE IMPROVED

VISUALIZATIONS
-- CHARTS USED AND WHY
-- THE STORY EACH CHART TOOL
TOOLS

RECOMMENDATIONS
-- LIST ACTIONS
-- ASSIGN ROLES





