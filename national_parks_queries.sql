-- ============================================
-- National Parks SQL Practice Queries
-- Database: national_parks.db
-- Tables: fact_visits, dim_parks, agg_annual
-- ============================================

-- TABLE OVERVIEW
-- fact_visits   : monthly visits per park (18,851 rows)
-- dim_parks     : one row per park - name, region, state (63 rows)
-- agg_annual    : annual totals per park pre-aggregated (1,575 rows)


-- ============================================
-- QUERY 1: Total recreation visits by year
-- Use case: Trend analysis (spot COVID dip in 2020)
-- ============================================
SELECT 
    Year,
    SUM(RecreationVisits) AS TotalVisits
FROM fact_visits
GROUP BY Year
ORDER BY Year;


-- ============================================
-- QUERY 2: Top 10 most visited parks all time
-- Use case: Bar chart in Tableau
-- ============================================
SELECT 
    ParkName,
    State,
    Region,
    SUM(RecreationVisits) AS TotalVisits
FROM fact_visits
GROUP BY ParkName, State, Region
ORDER BY TotalVisits DESC
LIMIT 10;


-- ============================================
-- QUERY 3: Total visits by region
-- Use case: Regional breakdown / pie chart
-- ============================================
SELECT 
    Region,
    SUM(RecreationVisits) AS TotalVisits,
    ROUND(SUM(RecreationVisits) * 100.0 / 
        (SELECT SUM(RecreationVisits) FROM fact_visits), 2) AS PctOfTotal
FROM fact_visits
GROUP BY Region
ORDER BY TotalVisits DESC;


-- ============================================
-- QUERY 4: Seasonal patterns (avg visits by month)
-- Use case: Seasonality line chart
-- ============================================
SELECT 
    Month,
    MonthName,
    ROUND(AVG(RecreationVisits), 0) AS AvgVisits,
    SUM(RecreationVisits) AS TotalVisits
FROM fact_visits
GROUP BY Month, MonthName
ORDER BY Month;


-- ============================================
-- QUERY 5: Year-over-year change in total visits
-- Use case: KPI card / trend analysis
-- ============================================
SELECT 
    Year,
    SUM(RecreationVisits) AS TotalVisits,
    SUM(RecreationVisits) - LAG(SUM(RecreationVisits)) 
        OVER (ORDER BY Year) AS YoYChange,
    ROUND((SUM(RecreationVisits) - LAG(SUM(RecreationVisits)) 
        OVER (ORDER BY Year)) * 100.0 / 
        LAG(SUM(RecreationVisits)) OVER (ORDER BY Year), 2) AS YoYPct
FROM fact_visits
GROUP BY Year
ORDER BY Year;


-- ============================================
-- QUERY 6: Visits by state (for map view)
-- Use case: Geographic choropleth map in Tableau
-- ============================================
SELECT 
    State,
    SUM(RecreationVisits) AS TotalVisits,
    COUNT(DISTINCT ParkName) AS NumParks
FROM fact_visits
GROUP BY State
ORDER BY TotalVisits DESC;


-- ============================================
-- QUERY 7: Overnight stays vs recreation visits
-- Use case: Dual-axis chart or scatter plot
-- ============================================
SELECT 
    ParkName,
    Region,
    SUM(RecreationVisits) AS TotalVisits,
    SUM(TotalOvernightStays) AS TotalOvernightStays,
    ROUND(SUM(TotalOvernightStays) * 1.0 / 
        NULLIF(SUM(RecreationVisits), 0), 4) AS OvernightRate
FROM fact_visits
GROUP BY ParkName, Region
ORDER BY TotalVisits DESC
LIMIT 20;


-- ============================================
-- QUERY 8: COVID impact analysis (2019 vs 2020)
-- Use case: Storytelling — great interview talking point
-- ============================================
SELECT 
    ParkName,
    SUM(CASE WHEN Year = 2019 THEN RecreationVisits ELSE 0 END) AS Visits_2019,
    SUM(CASE WHEN Year = 2020 THEN RecreationVisits ELSE 0 END) AS Visits_2020,
    SUM(CASE WHEN Year = 2020 THEN RecreationVisits ELSE 0 END) -
    SUM(CASE WHEN Year = 2019 THEN RecreationVisits ELSE 0 END) AS Drop,
    ROUND((SUM(CASE WHEN Year = 2020 THEN RecreationVisits ELSE 0 END) -
    SUM(CASE WHEN Year = 2019 THEN RecreationVisits ELSE 0 END)) * 100.0 /
    NULLIF(SUM(CASE WHEN Year = 2019 THEN RecreationVisits ELSE 0 END), 0), 1) AS PctChange
FROM fact_visits
WHERE Year IN (2019, 2020)
GROUP BY ParkName
ORDER BY PctChange ASC
LIMIT 15;


-- ============================================
-- QUERY 9: Backcountry vs frontcountry campers
-- Use case: Camping breakdown bar chart
-- ============================================
SELECT 
    Region,
    SUM(TentCampers) AS TentCampers,
    SUM(RVCampers) AS RVCampers,
    SUM(Backcountry) AS BackcountryCampers,
    SUM(ConcessionerCamping) AS ConcessionerCampers
FROM fact_visits
GROUP BY Region
ORDER BY TentCampers DESC;


-- ============================================
-- QUERY 10: Park recovery post-COVID (2021-2024)
-- Use case: Recovery trend — strong storytelling
-- ============================================
SELECT 
    Year,
    Region,
    SUM(RecreationVisits) AS TotalVisits
FROM fact_visits
WHERE Year BETWEEN 2019 AND 2024
GROUP BY Year, Region
ORDER BY Region, Year;
