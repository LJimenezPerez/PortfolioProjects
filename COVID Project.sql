
SELECT 
	Continent,
	Location,
	Date,
	Total_Cases,
	New_Cases,
	Total_Deaths,
	Population
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
ORDER BY 1,2


--Total Cases vs Total Deaths

SELECT 
	Continent,
	Location,
	Date,
	Total_Cases,
	New_Cases,
	Total_Deaths,
	(total_deaths/total_cases)*100 AS DeathPercentage
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
ORDER BY 1,2


--Total Cases vs Population

SELECT 
	Continent,
	Location,
	Date,
	Total_Cases,
	Population,
	(total_cases/population)*100 AS CovidPercentage
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
ORDER BY 1,2


--Countries with High Infection Rate vs Population

SELECT 
	Continent,
	Location,
	Population,
	MAX(Total_Cases) AS HighestInfectionCount,
	MAX((total_cases/population))*100 AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
GROUP BY Location, Continent, Population
ORDER BY PercentPopulationInfected DESC


--Countries with Highest Death Count per Population

SELECT 
	Continent,
	Location,
	MAX(CAST(Total_Deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
GROUP BY Location, Continent
ORDER BY TotalDeathCount DESC


--Continents with Highest Death Count

SELECT 
	Location,
	MAX(CAST(Total_Deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NULL AND Location NOT LIKE '%income'
GROUP BY Location
ORDER BY TotalDeathCount DESC


--Income with Highest Death Count

SELECT 
	Location,
	MAX(CAST(Total_Deaths AS INT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NULL AND Location LIKE '%income'
GROUP BY Location
ORDER BY TotalDeathCount DESC


--Global Numbers by Date

SELECT 
	Date,
	SUM(New_Cases) AS TotalCases,
	SUM(CAST(New_Deaths AS INT)) AS TotalDeaths,
	SUM(CAST(New_Deaths AS INT))/SUM(New_Cases)*100 AS DeathPercentage
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
GROUP BY Date
ORDER BY 1,2


--Global Numbers

SELECT 
	SUM(New_Cases) AS TotalCases,
	SUM(CAST(New_Deaths AS INT)) AS TotalDeaths,
	SUM(CAST(New_Deaths AS INT))/SUM(New_Cases)*100 AS DeathPercentage
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
ORDER BY 1,2


--Total Population vs Vaccinations

WITH PopVsVac AS
(
SELECT 
	a.Continent,
	a.Location,
	a.Date,
	a.Population,
	b.New_Vaccinations,
	SUM(CONVERT(FLOAT,b.New_Vaccinations)) OVER (PARTITION BY b.Location ORDER BY b.Location, b.Date) AS VaccinesRt

FROM PortfolioProject..CovidDeaths AS a
JOIN PortfolioProject..CovidVaccinations AS b
ON a.Location = b.Location AND a.Date = b.Date
WHERE a.Continent IS NOT NULL
)

SELECT *, (VaccinesRt/Population)*100 AS VaccinationsPercentage
FROM PopVsVac


--Create View for Visual

CREATE VIEW PopulationVaccinatedPercent AS

WITH PopVsVac AS
(
SELECT 
	a.Continent,
	a.Location,
	a.Date,
	a.Population,
	b.New_Vaccinations,
	SUM(CONVERT(FLOAT,b.New_Vaccinations)) OVER (PARTITION BY b.Location ORDER BY b.Location, b.Date) AS VaccinesRt

FROM PortfolioProject..CovidDeaths AS a
JOIN PortfolioProject..CovidVaccinations AS b
ON a.Location = b.Location AND a.Date = b.Date
WHERE a.Continent IS NOT NULL
)

SELECT *, (VaccinesRt/Population)*100 AS VaccinationsPercentage
FROM PopVsVac

