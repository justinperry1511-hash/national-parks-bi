-- ============================================================
-- NATIONAL PARKS BI DATABASE
-- File: national_parks_master.sql
-- Author: Justin
-- Description: Complete build script -- schema, data load,
--              views, and validation all in one file.
--              Run each section one block at a time.
--
-- ORDER OF EXECUTION:
--   SECTION 1: Drop & rebuild schema
--   SECTION 2: Load dim_parks
--   SECTION 3: Load dim_date
--   SECTION 4: Load fact_visits
--   SECTION 5: Create views
--   SECTION 6: Final validation
-- ============================================================


-- ============================================================
-- SECTION 1: SCHEMA
-- Run this first. Drops everything and rebuilds clean tables.
-- ============================================================

DROP VIEW IF EXISTS vw_covid_impact;
DROP VIEW IF EXISTS vw_seasonal_patterns;
DROP VIEW IF EXISTS vw_regional_breakdown;
DROP VIEW IF EXISTS vw_top_parks;
DROP VIEW IF EXISTS vw_annual_trends;
DROP TABLE IF EXISTS fact_visits;
DROP TABLE IF EXISTS dim_parks;
DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_parks (
    UnitCode    TEXT PRIMARY KEY,
    ParkName    TEXT NOT NULL,
    ParkType    TEXT NOT NULL,
    Region      TEXT NOT NULL,
    State       TEXT NOT NULL
);

CREATE TABLE dim_date (
    DateKey     INTEGER PRIMARY KEY,
    Year        INTEGER NOT NULL,
    Month       INTEGER NOT NULL,
    MonthName   TEXT NOT NULL,
    Quarter     INTEGER NOT NULL,
    Season      TEXT NOT NULL
);

CREATE TABLE fact_visits (
    VisitID                 INTEGER PRIMARY KEY AUTOINCREMENT,
    UnitCode                TEXT NOT NULL,
    DateKey                 INTEGER NOT NULL,
    RecreationVisits        INTEGER NOT NULL DEFAULT 0,
    NonRecreationVisits     INTEGER NOT NULL DEFAULT 0,
    RecreationHours         INTEGER NOT NULL DEFAULT 0,
    ConcessionerLodging     INTEGER NOT NULL DEFAULT 0,
    ConcessionerCamping     INTEGER NOT NULL DEFAULT 0,
    TentCampers             INTEGER NOT NULL DEFAULT 0,
    RVCampers               INTEGER NOT NULL DEFAULT 0,
    Backcountry             INTEGER NOT NULL DEFAULT 0,
    MiscOvernightStays      INTEGER NOT NULL DEFAULT 0,
    TotalOvernightStays     INTEGER NOT NULL DEFAULT 0,
    CHECK (RecreationVisits >= 0),
    CHECK (TotalOvernightStays >= 0),
    FOREIGN KEY (UnitCode) REFERENCES dim_parks(UnitCode),
    FOREIGN KEY (DateKey)  REFERENCES dim_date(DateKey)
);

CREATE INDEX idx_fact_unitcode ON fact_visits(UnitCode);
CREATE INDEX idx_fact_datekey  ON fact_visits(DateKey);
CREATE INDEX idx_date_year     ON dim_date(Year);
CREATE INDEX idx_date_month    ON dim_date(Month);
CREATE INDEX idx_parks_region  ON dim_parks(Region);
CREATE INDEX idx_parks_state   ON dim_parks(State);

-- Verify schema built correctly
SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;


-- ============================================================
-- SECTION 2: LOAD dim_parks
-- Run after Section 1. Should return 63 parks.
-- ============================================================

INSERT INTO dim_parks (UnitCode, ParkName, ParkType, Region, State)
SELECT DISTINCT
    TRIM(UnitCode),
    TRIM(ParkName),
    TRIM(ParkType),
    TRIM(Region),
    TRIM(State)
FROM staging_raw
ORDER BY UnitCode;

-- Verify: expect 63 parks, 6 regions, 30 states
SELECT
    COUNT(*)               AS ParkCount,
    COUNT(DISTINCT Region) AS RegionCount,
    COUNT(DISTINCT State)  AS StateCount
FROM dim_parks;


-- ============================================================
-- SECTION 3: LOAD dim_date
-- Run after Section 2. Should return 300 months.
-- ============================================================

INSERT INTO dim_date (DateKey, Year, Month, MonthName, Quarter, Season)
SELECT DISTINCT
    (Year * 100) + Month AS DateKey,
    Year,
    Month,
    CASE Month
        WHEN 1  THEN 'January'    WHEN 2  THEN 'February'
        WHEN 3  THEN 'March'      WHEN 4  THEN 'April'
        WHEN 5  THEN 'May'        WHEN 6  THEN 'June'
        WHEN 7  THEN 'July'       WHEN 8  THEN 'August'
        WHEN 9  THEN 'September'  WHEN 10 THEN 'October'
        WHEN 11 THEN 'November'   WHEN 12 THEN 'December'
    END AS MonthName,
    CASE
        WHEN Month IN (1, 2, 3)    THEN 1
        WHEN Month IN (4, 5, 6)    THEN 2
        WHEN Month IN (7, 8, 9)    THEN 3
        WHEN Month IN (10, 11, 12) THEN 4
    END AS Quarter,
    CASE
        WHEN Month IN (12, 1, 2)  THEN 'Winter'
        WHEN Month IN (3, 4, 5)   THEN 'Spring'
        WHEN Month IN (6, 7, 8)   THEN 'Summer'
        WHEN Month IN (9, 10, 11) THEN 'Fall'
    END AS Season
FROM staging_raw
ORDER BY DateKey;

-- Verify: expect 300 months, 2000-2024, 4 seasons
SELECT
    COUNT(*)               AS TotalMonths,
    MIN(Year)              AS EarliestYear,
    MAX(Year)              AS LatestYear,
    COUNT(DISTINCT Season) AS SeasonCount
FROM dim_date;


-- ============================================================
-- SECTION 4: LOAD fact_visits
-- Run after Section 3. Should return 18,851 rows.
-- ============================================================

INSERT INTO fact_visits (
    UnitCode, DateKey, RecreationVisits, NonRecreationVisits,
    RecreationHours, ConcessionerLodging, ConcessionerCamping,
    TentCampers, RVCampers, Backcountry, MiscOvernightStays,
    TotalOvernightStays
)
SELECT
    TRIM(s.UnitCode),
    (s.Year * 100) + s.Month,
    COALESCE(s.RecreationVisits, 0),
    COALESCE(s.NonRecreationVisits, 0),
    COALESCE(s.RecreationHours, 0),
    COALESCE(s.ConcessionerLodging, 0),
    COALESCE(s.ConcessionerCamping, 0),
    COALESCE(s.TentCampers, 0),
    COALESCE(s.RVCampers, 0),
    COALESCE(s.Backcountry, 0),
    COALESCE(s.MiscellaneousOvernightStays, 0),
    COALESCE(s.ConcessionerLodging, 0)  +
    COALESCE(s.ConcessionerCamping, 0)  +
    COALESCE(s.TentCampers, 0)          +
    COALESCE(s.RVCampers, 0)            +
    COALESCE(s.Backcountry, 0)          +
    COALESCE(s.MiscellaneousOvernightStays, 0)
FROM staging_raw s
ORDER BY s.UnitCode, (s.Year * 100) + s.Month;

-- Verify: expect 18851 rows, 63 parks, 1.9B visits
SELECT
    COUNT(*)                 AS TotalRows,
    COUNT(DISTINCT UnitCode) AS UniqueParkCount,
    SUM(RecreationVisits)    AS AllTimeVisits,
    MIN(DateKey)             AS EarliestDate,
    MAX(DateKey)             AS LatestDate
FROM fact_visits;


-- ============================================================
-- SECTION 5: CREATE VIEWS
-- Run after Section 4. Creates 5 analytical views.
-- ============================================================

-- View 1: Annual trends (trend line chart in Tableau)
CREATE VIEW vw_annual_trends AS
SELECT
    d.Year,
    SUM(f.RecreationVisits)        AS TotalVisits,
    SUM(f.TotalOvernightStays)     AS TotalOvernightStays,
    SUM(f.RecreationHours)         AS TotalRecreationHours,
    COUNT(DISTINCT f.UnitCode)     AS ActiveParks,
    ROUND(AVG(f.RecreationVisits), 0) AS AvgMonthlyVisitsPerPark
FROM fact_visits f
JOIN dim_date d ON f.DateKey = d.DateKey
GROUP BY d.Year
ORDER BY d.Year;

-- View 2: Top parks all time (bar chart in Tableau)
CREATE VIEW vw_top_parks AS
SELECT
    p.ParkName,
    p.UnitCode,
    p.Region,
    p.State,
    SUM(f.RecreationVisits)           AS TotalVisits,
    SUM(f.TotalOvernightStays)        AS TotalOvernightStays,
    ROUND(AVG(f.RecreationVisits), 0) AS AvgMonthlyVisits,
    RANK() OVER (ORDER BY SUM(f.RecreationVisits) DESC) AS VisitRank
FROM fact_visits f
JOIN dim_parks p ON f.UnitCode = p.UnitCode
GROUP BY p.ParkName, p.UnitCode, p.Region, p.State
ORDER BY TotalVisits DESC;

-- View 3: Regional breakdown by year (area chart in Tableau)
CREATE VIEW vw_regional_breakdown AS
SELECT
    p.Region,
    d.Year,
    SUM(f.RecreationVisits)           AS TotalVisits,
    SUM(f.TotalOvernightStays)        AS TotalOvernightStays,
    COUNT(DISTINCT f.UnitCode)        AS ParkCount,
    ROUND(AVG(f.RecreationVisits), 0) AS AvgMonthlyVisitsPerPark
FROM fact_visits f
JOIN dim_parks p ON f.UnitCode = p.UnitCode
JOIN dim_date d ON f.DateKey = d.DateKey
GROUP BY p.Region, d.Year
ORDER BY p.Region, d.Year;

-- View 4: Seasonal patterns (seasonality bar chart in Tableau)
CREATE VIEW vw_seasonal_patterns AS
SELECT
    d.Month,
    d.MonthName,
    d.Season,
    d.Quarter,
    ROUND(AVG(f.RecreationVisits), 0)    AS AvgVisitsPerPark,
    SUM(f.RecreationVisits)              AS TotalVisitsAllTime,
    ROUND(AVG(f.TotalOvernightStays), 0) AS AvgOvernightStaysPerPark
FROM fact_visits f
JOIN dim_date d ON f.DateKey = d.DateKey
GROUP BY d.Month, d.MonthName, d.Season, d.Quarter
ORDER BY d.Month;

-- View 5: COVID impact analysis (diverging bar chart in Tableau)
CREATE VIEW vw_covid_impact AS
SELECT
    p.ParkName,
    p.Region,
    p.State,
    SUM(CASE WHEN d.Year = 2019 THEN f.RecreationVisits ELSE 0 END) AS Visits2019,
    SUM(CASE WHEN d.Year = 2020 THEN f.RecreationVisits ELSE 0 END) AS Visits2020,
    SUM(CASE WHEN d.Year = 2020 THEN f.RecreationVisits ELSE 0 END) -
    SUM(CASE WHEN d.Year = 2019 THEN f.RecreationVisits ELSE 0 END) AS VisitDrop,
    ROUND(
        (SUM(CASE WHEN d.Year = 2020 THEN f.RecreationVisits ELSE 0 END) -
         SUM(CASE WHEN d.Year = 2019 THEN f.RecreationVisits ELSE 0 END)) * 100.0 /
        NULLIF(SUM(CASE WHEN d.Year = 2019 THEN f.RecreationVisits ELSE 0 END), 0)
    , 1) AS PctChange
FROM fact_visits f
JOIN dim_parks p ON f.UnitCode = p.UnitCode
JOIN dim_date d ON f.DateKey = d.DateKey
WHERE d.Year IN (2019, 2020)
GROUP BY p.ParkName, p.Region, p.State
ORDER BY PctChange ASC;

-- Verify: all 5 views created
SELECT name FROM sqlite_master WHERE type='view' ORDER BY name;


-- ============================================================
-- SECTION 6: FINAL VALIDATION
-- Run last. All orphan counts should be 0.
-- ============================================================

-- Row counts across all tables
SELECT 'dim_parks'   AS TableName, COUNT(*) AS RowCount FROM dim_parks
UNION ALL
SELECT 'dim_date'    AS TableName, COUNT(*) AS RowCount FROM dim_date
UNION ALL
SELECT 'fact_visits' AS TableName, COUNT(*) AS RowCount FROM fact_visits;

-- Orphan check: visits with no matching park
SELECT COUNT(*) AS OrphanedVisits
FROM fact_visits f
LEFT JOIN dim_parks p ON f.UnitCode = p.UnitCode
WHERE p.UnitCode IS NULL;

-- Orphan check: visits with no matching date
SELECT COUNT(*) AS OrphanedDates
FROM fact_visits f
LEFT JOIN dim_date d ON f.DateKey = d.DateKey
WHERE d.DateKey IS NULL;

-- Quick data check: top 5 parks by total visits
SELECT ParkName, Region, TotalVisits, VisitRank
FROM vw_top_parks
LIMIT 5;

-- Quick data check: COVID impact top 10 hardest hit
SELECT ParkName, Visits2019, Visits2020, PctChange
FROM vw_covid_impact
LIMIT 10;




SELECT
    MonthName,
    RecreationVisits
FROM staging_raw
WHERE ParkName = 'Acadia NP'
  AND Year = 2019
ORDER BY Month;

SELECT
    COUNT(*)                            AS TotalRows,
    SUM(RecreationVisits)               AS TotalVisits,
    ROUND(AVG(RecreationVisits), 0)     AS AvgMonthlyVisits,
    MIN(RecreationVisits)               AS LowestMonth,
    MAX(RecreationVisits)               AS HighestMonth
FROM staging_raw;


SELECT
    Region,
    SUM(RecreationVisits)               AS TotalVisits,
    COUNT(DISTINCT ParkName)            AS NumberOfParks,
    ROUND(AVG(RecreationVisits), 0)     AS AvgMonthlyVisits
FROM staging_raw
GROUP BY Region
ORDER BY TotalVisits DESC;