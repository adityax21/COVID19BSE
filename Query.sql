--Tables
SELECT *
FROM CovidProject..CovidDeaths

SELECT *
FROM CovidProject..CovidVaccinations

SELECT *
FROM CovidProject..BSEIndex

--A1 : GLOBAL : Cases, Deaths, Death Rate - chances of death
SELECT location, date, total_cases, total_deaths, (cast(total_deaths as numeric)/(cast(total_cases as numeric))) * 100 as DeathRate
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

--A2 : INDIA : cases, deaths, death rate
SELECT location, date, total_cases, total_deaths, (cast(total_deaths as numeric)/(cast(total_cases as numeric))) * 100 as DeathRate
FROM CovidProject..CovidDeaths
WHERE location = 'India'
ORDER BY date;

--A3 GLOBAL : Infection Rate per Population by Country & Date
SELECT location, date, total_cases, population, (cast(total_cases as numeric)/(cast(population as numeric))) * 100 AS InfectionRate
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

--A4 INDIA : Infection Rate per Population by Date
SELECT location, date, total_cases, population, (cast(total_cases as numeric)/(cast(population as numeric))) * 100 AS infection_rate
FROM CovidProject..CovidDeaths
WHERE location = 'India'
ORDER BY date;

--A5 GLOBAL : Countries with Highest Infection Rate compared to Population
SELECT location, population, MAX(total_cases) AS total_cases, MAX((cast(total_cases as numeric)/(cast(population as numeric)))) * 100 AS infection_rate
FROM CovidProject..CovidDeaths
GROUP BY location, population
ORDER BY infection_rate DESC;

--A6 INDIA : Overall Highest Infection Rate in INDIA
SELECT location, population, MAX(total_cases) AS total_cases, MAX((cast(total_cases as numeric)/(cast(population as numeric)))) * 100 AS infection_rate
FROM CovidProject..CovidDeaths
WHERE location = 'INDIA'
GROUP BY location, population
--ORDER BY infection_rate DESC;

--A7 GLOBAL : Highest Death Count per Population & Death Rate
SELECT location, population, MAX(total_deaths) AS total_deaths, (MAX(cast(total_deaths as numeric))/(cast(population as numeric))) * 100 AS death_rate_by_population
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY death_rate_by_population DESC;

-- A8 INDIA : Highest Death Count by Population & Death Rate
SELECT location, population, MAX(total_deaths) AS total_deaths, 
	(MAX(total_deaths)/population) * 100 AS death_rate_by_population
FROM CovidProject..CovidDeaths
WHERE location = 'India'
GROUP BY location, population

-- ANALYSIS BY CONTINENT

-- GLOBAL : Infection Rate & Death Rate by Continent
SELECT d.location, d.population, MAX(cast(total_cases as numeric)) AS total_cases, MAX(cast(total_deaths as numeric)) AS total_deaths,
	(MAX(cast(total_cases as numeric))/d.population) * 100 AS infection_rate, 
	(MAX(cast(total_deaths as numeric))/MAX(cast(total_cases as numeric))) * 100 AS death_perc
FROM CovidProject..CovidDeaths AS d
JOIN CovidProject..CovidVaccinations AS v
	ON d.date = v.date
WHERE d.continent IS NULL
	AND d.location != 'World'
	AND d.location != 'International'
	AND d.location != 'European Union'
	AND d.location != 'Upper middle income'
	AND d.location != 'Lower middle income'
	AND d.location != 'High income'

GROUP BY d.continent, d.location, d.population
ORDER BY (MAX(total_cases)/d.population) * 100 DESC;

-- ANALYSIS BY VACCINATION

-- A10 : GLOBAL : Rolling Vaccinations by Country & Date
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations, 
	SUM(CONVERT(BIGINT,v.new_vaccinations)) OVER (PARTITION BY d.location
	ORDER BY d.location, d.date) 
	AS rolling_vaccinations
-- Partition by location & date to ensure that once the rolling sum of new vaccinations for a location stops, the rolling sum starts for the next location
FROM CovidProject..CovidDeaths AS d
JOIN CovidProject..CovidVaccinations AS v
	ON d.location = v.location 
AND d.date = v.date
WHERE d.continent IS NOT NULL
ORDER BY d.location, d.date;

--A11 - INDIA : Rolling Vaccinations by Date
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations, 
	SUM(CONVERT(INT,v.new_vaccinations)) OVER (PARTITION BY d.location
		ORDER BY d.location, d.date) AS rolling_vaccinations
FROM CovidProject..CovidDeaths AS d
JOIN CovidProject..CovidVaccinations AS v
	ON d.location = v.location 
	AND d.date = v.date
WHERE d.location = 'India'
ORDER BY d.location, d.date;

-- 12 India : Rolling Vaccinations & Percentage of Vaccinated Population
WITH vaccination_per_population (continent, location, date, population, new_vaccinations, rolling_vaccinations) 
AS 
(
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations, 
	SUM(CONVERT(INT,v.new_vaccinations)) OVER (PARTITION BY d.location
		ORDER BY d.location, d.date) AS rolling_vaccinations
FROM CovidProject..CovidDeaths AS d
JOIN CovidProject..CovidVaccinations AS v
	ON d.location = v.location 
	AND d.date = v.date
WHERE d.continent IS NOT NULL AND d.location = 'India'
)
SELECT *, (rolling_vaccinations/population) * 100 AS vaccinated_per_population
FROM vaccination_per_population;

-- TEMP TABLE
DROP TABLE IF EXISTS perc_population_vaccinated
CREATE TABLE perc_population_vaccinated
	(
	continent NVARCHAR(255),
	location NVARCHAR(255),
	date DATETIME,
	population NUMERIC,
	new_vaccinations NUMERIC,
	rolling_vaccinations NUMERIC
	)

-- Insert TEMP TABLE
INSERT INTO perc_population_vaccinated
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations, 
	SUM(CONVERT(BIGINT,v.new_vaccinations)) OVER (PARTITION BY d.location
		ORDER BY d.location, d.date) AS rolling_vaccinations
FROM CovidProject..CovidDeaths AS d
JOIN CovidProject..CovidVaccinations AS v
	ON d.location = v.location 
	AND d.date = v.date
WHERE d.continent IS NOT NULL

SELECT *, (rolling_vaccinations/population) * 100 AS vaccinated_per_population
FROM perc_population_vaccinated
WHERE location = 'India';

-- VIEW FOR VISUALISATION
CREATE VIEW perc_population_vaccinated_view AS
SELECT d.continent, d.location, d.date, d.population, v.new_vaccinations, 
	SUM(CONVERT(INT,v.new_vaccinations)) OVER (PARTITION BY d.location
		ORDER BY d.location, d.date) 
		AS rolling_vaccinations
FROM CovidProject..CovidDeaths AS d
JOIN CovidProject..CovidVaccinations AS v
	ON d.location = v.location 
	AND d.date = v.date
WHERE d.continent IS NOT NULL;

-- IMPACT ON BSE-500

-- A13 INDIA : Infection Rate & Death Rate vs BSE Index Price by Date during First Wave of COVID19
SELECT d.date, location, new_cases, total_cases, new_deaths, total_deaths, (total_cases/population) * 100 AS infection_rate, 
	(total_deaths/population) * 100 AS death_perc, 
	k.[Adj Close]
FROM CovidProject..CovidDeaths AS d
LEFT JOIN CovidProject..BSEIndex AS k
	ON d.date = k.Date
WHERE location = 'India' 
	AND d.date BETWEEN '2020-03-15' AND '2020-09-30'
ORDER BY d.date ASC;

-- A14 INDIA : Infection Rate & Death Rate vs BSE Index Price by Date during second wave
SELECT d.date, location, new_cases, total_cases, new_deaths, total_deaths, (total_cases/population) * 100 AS infection_rate,  
	(total_deaths/population) * 100 AS death_perc, 
	k.[Adj Close]
FROM CovidProject..CovidDeaths AS d
LEFT JOIN CovidProject..BSEIndex AS k
	ON d.date = k.Date
WHERE location = 'India' 
	AND d.date BETWEEN '2021-03-15' AND '2021-06-30'
ORDER BY d.date ASC;

-- A15 INDIA : Infection Rate & Death Rate vs BSE-500 Index Price - Feb 2020 : Before first wave
SELECT d.date, location, new_cases, total_cases, new_deaths, total_deaths, (total_cases/population) * 100 AS infection_rate, 
	(total_deaths/population) * 100 AS death_perc, 
	k.[Adj Close]
FROM CovidProject..CovidDeaths AS d
LEFT JOIN CovidProject..BSEIndex AS k
	ON d.date = k.Date
WHERE location = 'India' 
	AND d.date BETWEEN '2020-02-01' AND '2020-03-15';

-- A16 INDIA : Infection Rate & Death Rate vs BSE-500 Index Price by Date in : Feb-March 2021 : Pre Second Wave
SELECT d.date, location, new_cases, total_cases, new_deaths, total_deaths, (total_cases/population) * 100 AS infection_rate, 
	(total_deaths/population) * 100 AS death_perc, 
	k.[Adj Close]
FROM CovidProject..CovidDeaths AS d
LEFT JOIN CovidProject..BSEIndex AS k
	ON d.date = k.Date
WHERE location = 'India' 
ORDER BY d.date DESC;

-- A17 INDIA : Vaccination Rate by Date
SELECT v.date, location, new_vaccinations, total_vaccinations, (total_vaccinations/population) * 100 AS vaccination_rate, k.[Adj Close]
FROM CovidProject..CovidVaccinations AS v
LEFT JOIN CovidProject..BSEIndex AS k
	ON v.date = k.Date
WHERE location = 'India' 
	AND (total_vaccinations/population) * 100 > 1
ORDER BY v.date DESC;



DROP VIEW IF EXISTS covid_cases_deaths;

CREATE VIEW covid_cases_deaths AS
SELECT continent, location, population, MAX(total_cases) AS total_cases, 
	MAX(total_deaths) AS total_deaths, 
	(MAX(total_cases)/population) * 100 AS infection_rate,
	(MAX(total_deaths)/population) * 100 AS death_rate,
	(MAX(total_cases)/1000000) * 100 AS infection_rate_over_million,
	(MAX(total_deaths)/1000000) * 100 AS death_rate_over_million
FROM CovidProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent, location, population;

CREATE VIEW covid_vaccinations AS
SELECT continent, location, population, MAX(total_vaccinations) AS total_vaccinations, 
	(MAX(total_vaccinations)/population) * 100 AS people_vaccinated
FROM CovidProject..CovidVaccinations
WHERE continent IS NOT NULL
GROUP BY continent, location, population;

SELECT *
FROM CovidProject..CovidVaccinations
