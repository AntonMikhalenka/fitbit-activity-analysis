-- Merges two tables containing different time periods into one
CREATE TABLE dailyActivity_merged AS
SELECT * FROM dailyActivity _1
UNION ALL
SELECT * FROM dailyActivity _2

-- Selects all rows where TotalSteps = 0, likely caused by users not wearing the tracker
SELECT *
FROM dailyActivity_merged
WHERE TotalSteps=0

-- Deletes all rows where TotalSteps = 0
DELETE
FROM dailyActivity_merged
WHERE TotalSteps=0

-- Removes time portion of date columns
UPDATE dailyActivity_merged
    SET ActivityDate = SUBSTRING(ActivityDate, 1, LENGTH(ActivityDate) - 11)

-- Identifies duplicated rows
SELECT Id, ActivityDate,
COUNT(*) as duplicates
FROM dailyActivity_merged
GROUP BY Id, 
ActivityDate HAVING COUNT(*)>1

-- Counts number of times each user recorded data
SELECT id, count(id) as times_used
FROM dailyActivity_merged
GROUP BY id
ORDER BY times_used asc

-- Users are grouped into three categories based on their tracker usage patterns
SELECT 
    id,
    CASE
        WHEN COUNT(id) BETWEEN 0 AND 30 THEN 'inactive_user'
        WHEN COUNT(id) BETWEEN 31 AND 44 THEN 'moderately_active_user'
        WHEN COUNT(id) BETWEEN 45 AND 55 THEN 'active_user'
        ELSE 'very_active_user'
    END AS user_type
FROM dailyActivity_merged
GROUP BY id
ORDER BY user_type;

-- Calculates the number of weight logs per user
SELECT Id, count(id) as times_logged
FROM weightLogInfo_merged
GROUP BY id
ORDER BY times_logged

-- Calculates users' average weight
SELECT AVG(user_avg_weight) as average_weight
FROM (
SELECT id, AVG(WeightKG) as user_avg_weight
FROM weightLogInfo_merged
GROUP BY Id 
)

-- Average sleep per person is calculated, filtering for users with more than 3 logs
SELECT id, LEFT(AVG(TotalMinutesAsleep), 6) as avg_sleep_per_person
FROM sleepDay
GROUP BY id
HAVING COUNT(id) > 3
ORDER BY avg_sleep_per_person

-- Calculates median sleep duration across users, filtering for users with more than 3 logs
SELECT Median(avg_sleep_per_person) as median_sleep_duration
FROM (
SELECT id, AVG(TotalMinutesAsleep) as avg_sleep_per_person
GROUP BY id
HAVING COUNT(id) > 3
)

-- Average time spent in bed before falling asleep was calculated per user, filtering for users with more than 3 logs
SELECT id, AVG(TotalTimeInBed - TotalMinutesAsleep) as avg_time_to_fall_asleep
FROM sleepDay
GROUP BY id
HAVING COUNT(id) > 3

-- Median active and inactive minutes are calculated across users
SELECT 
MEDIAN(Average_active_minutes_per_person) as Median_active_minutes, 
MEDIAN(Average_inactive_minutes_per_person) as Median_inactive_minutes
FROM (
SELECT ID, 
AVG(VeryActiveMinutes + FairlyActiveMinutes) as Average_active_minutes_per_person, 
AVG(LightlyActiveMinutes + SedentaryMinutes) as Average_inactive_minutes_per_person
FROM dailyActivity_merged
GROUP BY ID
HAVING COUNT(ID)>3
)

-- Users are classified into four groups relative to the median
WITH
averages_per_person AS (
SELECT ID, 
AVG(VeryActiveMinutes+FairlyActiveMinutes) AS Average_active_minutes_per_person, AVG(LightlyActiveMinutes+SedentaryMinutes) AS Average_inactive_minutes_per_person
FROM dailyActivity_merged
GROUP BY ID
HAVING COUNT(*)>3
),
medians AS (
SELECT MEDIAN(Average_active_minutes_per_person) AS Median_active_minutes, 
MEDIAN(Average_inactive_minutes_per_person) AS Median_inactive_minutes
FROM averages_per_person
)
SELECT ID,
CASE
	WHEN Average_active_minutes_per_person >= Median_active_minutes and Average_inactive_minutes_per_person <= Median_inactive_minutes THEN 'Active'
WHEN Average_active_minutes_per_person >= Median_active_minutes and Average_inactive_minutes_per_person >= Median_inactive_minutes THEN 'Active_sedentary'
WHEN Average_active_minutes_per_person <= Median_active_minutes and Average_inactive_minutes_per_person <= Median_inactive_minutes THEN 'Low_activity_not_sedentary'
	ELSE 'Inactive'
END AS Categories_by_activity
FROM averages_per_person
CROSS JOIN medians

-- Users are categorised into two groups based on whether they fit WHO criteria for activity
SELECT 1.0 * SUM(CASE WHEN criteria = "Fits WHO criteria" THEN 1 ELSE 0 END) / COUNT(*) AS People_who_fit_criteria
FROM
(SELECT ID, 
CASE WHEN AVG(VeryActiveMinutes + FairlyActiveMinutes) >= 21.4 THEN "Fits WHO criteria"
ELSE "Doesn't fit criteria"
END AS criteria
FROM dailyActivity_merged
GROUP BY ID
HAVING COUNT(ID)>3
)

-- Users are categorised into two groups based on whether they take 8,000 steps a day
SELECT 1.0 * SUM(CASE WHEN criteria = "Active" THEN 1 ELSE 0 END) / COUNT(*) AS People_who_fit_criteria
FROM
(SELECT ID, 
CASE WHEN AVG(TotalSteps) >= 8000 THEN "Active"
ELSE "Inactive"
END AS criteria
FROM dailyActivity_merged
GROUP BY ID
HAVING COUNT(ID)>3
)

-- Average daily steps and average sleep duration are joined per user to test whether a correlation exists
WITH
sleep AS (
    SELECT id,
        AVG(TotalMinutesAsleep) AS average_sleep_minutes
    FROM sleepDay
    GROUP BY id
    HAVING COUNT(*)>3
),
steps AS (
    SELECT id,
        AVG(TotalSteps) AS average_steps
    FROM dailyActivity_merged
    GROUP BY id
    HAVING COUNT(*)>3
)
SELECT
    sl.id,
    sl.average_sleep_minutes,
    st.average_steps
FROM sleep sl
LEFT JOIN steps st ON sl.id = st.id;

-- Users are profiled based on all criteria used earlier
WITH
-- 1. Fitbit usage
fitbit_usage AS (
    SELECT id,
        CASE
            WHEN COUNT(*) BETWEEN 0 AND 30 THEN 'inactive_user'
            WHEN COUNT(*) BETWEEN 31 AND 44 THEN 'moderately_active_user'
            WHEN COUNT(*) BETWEEN 45 AND 55 THEN 'active_user'
            ELSE 'very_active_user'
        END AS FitBit_usage
    FROM dailyActivity_merged
    GROUP BY id
),

-- 2. Sleep category
sleep_column AS (
    SELECT
        id,
        CASE
            WHEN AVG(TotalMinutesAsleep) >= 420 THEN 'Good_sleeper'
            ELSE 'Bad_sleeper'
        END AS Sleep
    FROM sleepDay
    GROUP BY id
    HAVING COUNT(*) > 3
),

-- 3. Average activity per person
averages_per_person AS (
    SELECT id, 
        AVG(VeryActiveMinutes+FairlyActiveMinutes) AS Average_active_minutes_per_person, 
        AVG(LightlyActiveMinutes+SedentaryMinutes) AS Average_inactive_minutes_per_person
    FROM dailyActivity_merged
    GROUP BY ID
    HAVING COUNT(*)>3
),

-- 4. Medians across users
medians AS ( 
    SELECT 
        MEDIAN(Average_active_minutes_per_person) AS Median_active_minutes, 
        MEDIAN(Average_inactive_minutes_per_person) AS Median_inactive_minutes
    FROM averages_per_person
),

-- 5. Activity based on median
activity_category AS (
    SELECT id,
        CASE
	        WHEN Average_active_minutes_per_person >= Median_active_minutes and Average_inactive_minutes_per_person <= Median_inactive_minutes THEN 'Active'
	        WHEN Average_active_minutes_per_person >= Median_active_minutes and Average_inactive_minutes_per_person >= Median_inactive_minutes THEN 'Active_sedentary'
	        WHEN Average_active_minutes_per_person <= Median_active_minutes and Average_inactive_minutes_per_person <= Median_inactive_minutes THEN 'Low_activity_not_sedentary'
	    ELSE 'Inactive'
	END AS Category_by_activity
	FROM averages_per_person a
	CROSS JOIN medians m
),

-- 6. Activity based on WHO criteria
Activity_WHO AS (
    SELECT id,
        CASE 
            WHEN AVG(VeryActiveMinutes + FairlyActiveMinutes) >= 21.4 THEN 'Fits WHO criteria'
            ELSE 'Does not fit criteria'
        END AS Activity_WHO
    FROM dailyActivity_merged
    GROUP BY id
    HAVING COUNT(*) > 3
),

-- 7. Steps category
steps_column AS (
    SELECT id,
        CASE 
            WHEN AVG(TotalSteps) >= 8000 THEN 'Active'
            ELSE 'Inactive'
        END AS Steps
    FROM dailyActivity_merged
    GROUP BY id
    HAVING COUNT(*) > 3
)

-- 8. Final result
SELECT
    f.ID,
    f.fitbit_usage,
    sl.sleep,
    ac.category_by_activity,
    aw.activity_who,
    st.steps
FROM fitbit_usage f
LEFT JOIN sleep_column sl ON f.id = sl.id
LEFT JOIN activity_category ac ON f.id = ac.id
LEFT JOIN activity_who aw ON f.id = aw.id
LEFT JOIN steps_column st ON f.id = st.id;

