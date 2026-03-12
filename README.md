# Bellabeat Case Study: How Can a Wellness Technology Company Play It Smart?
**Tools**: SQL (SQLite), Tableau  
**Course**: Google Data Analytics Professional Certificate - Capstone Project  
**Dataset**: [FitBit Fitness Tracker Data](https://www.kaggle.com/datasets/arashnic/fitbit)

## Introduction
Bellabeat is a high-tech manufacturer of health-focused products for women. Despite being a small company, Bellabeat has the potential to become a larger player in the global smart device market. To support that growth, the company decided to conduct an analysis of smart device usage data to uncover trends and shape its marketing strategy.

## Ask
The first step was identifying the key stakeholders:
- **Urška Sršen** - Co-founder and Chief Creative Officer
- **Sando Mur** - Co-founder and key member of the executive team
- **Bellabeat marketing analytics team** - Responsible for data-driven marketing strategy

The following questions guided the analysis:
- How often do people wear their FitBit fitness trackers?
- What is the weight dynamic among FitBit users?
- Do users sleep enough?
- How much time do users spend in bed without being asleep?
- How much time per day do users spend being active, and how many steps do they take?
- Is there a correlation between steps taken and sleep duration?

## Prepare
The dataset was stored on Kaggle, where it was uploaded by Bellabeat. On the website, the dataset has a usability rating of **9.41** with credibility and completeness categories scoring 100%. It was also described as “well-documented, well-maintained and original”.
The dataset contains FitBit data from 30 users, stored across two time periods: March 12 - April 11 and April 12 - May 12. Some tables (daily calories, intensities, sleep, and steps) only cover the second period, which limits the analysis.

The following tables were selected for analysis:
- `dailyActivity`
- `sleepDay`
- `weightLogInfo`
- `hourlyCalories`
- `hourlySteps`
- `hourlyIntensities`

### ROCCC assessment
|Criterion|Rating|Notes|
|---|---|---|
|Reliable|LOW|Collected via survey from only 30 respondents, which is too small to represent a population|
|Original|MEDIUM|Collected by a second party, Amazon Mechanical Turk, not Bellabeat directly|
|Comprehensive|LOW|Important data missing (age, height, health, occupation)|
|Current|LOW|Dataset is from 2016 and has not been updated|
|Cited|LOW|Low citation count on Kaggle|

Given these limitations, the analysis can provide general information and directions rather than definitive conclusions. All findings should later be verified using more complete and current data

## Process
### Merging tables
Tables containing different time periods were merged into single tables using `UNION ALL`:

```sql
CREATE TABLE dailyActivity_merged AS
SELECT * FROM dailyActivity_1
UNION ALL
SELECT * FROM dailyActivity_2
```

After merging, the number of distinct IDs has been identified:
|Table|Unique IDs|
|---|---|
|dailyActivity_merged|35|
|sleepDay|24|
|weightLogInfo_merged|13|
|hourlyCalories_merged|35|
|hourlyIntensities_merged|35|
|hourlySteps_merged|35|

`weightLogInfo_merged` contains 13 unique IDs, which limits the reliability of any weight-related findings.  
It should also be noted that even though Kaggle states the dataset contains data from 30 users, 35 unique IDs were identified during processing. The reason for this is unclear and could reflect data collection issues.

### Removing zero-step rows
138 rows with `TotalSteps = 0` were identified. Since zero steps over a 24-hour period is unlikely, these rows were treated as missing data - possibly because users forgot to wear the tracker or did not enter their data.

```sql
SELECT *
FROM dailyActivity_merged
WHERE TotalSteps=0
```

```sql
DELETE
FROM dailyActivity_merged
WHERE TotalSteps=0
```

### Removing time from date columns
Since data was gathered on a daily basis, there is no need for time portion of date columns.

```sql
UPDATE dailyActivity_merged
    SET ActivityDate = SUBSTRING(ActivityDate, 1, LENGTH(ActivityDate) - 11)
```

### Finding and removing duplicates
```sql
SELECT Id, ActivityDate,
COUNT(*) as duplicates
FROM dailyActivity_merged
GROUP BY Id, ActivityDate
HAVING COUNT(*)>1
```

Duplicates were identified and removed. The same process was applied to all other tables.

## Analyze and Share
### 1. Usage frequency
The number of times each user recorded data was calculated to determine tracker usage patterns:

```sql
SELECT id, count(id) as times_used
FROM dailyActivity_merged
GROUP BY id
ORDER BY times_used asc
```

The users were grouped into three categories based on their tracker usage patterns:
```sql
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
ORDER BY user_type
```
The results:
|User type|Number of users|Share|
|---|---|---|
|Active|4|11.4%|
|Moderately active|21|60%|
|Inactive|10|28.6%|
<img width="940" height="592" alt="image" src="https://github.com/user-attachments/assets/0564a210-da82-45bb-ae6a-748f95f63ebc" />

Only **11.4%** of users wore their tracker consistently throughout the period, while **28.6%** were inactive. Taking into account the dataset only covers 62 days, this result suggests rapid disengagement. The average usage was **35** times, meaning the typical user wore their tracker roughly once every two days. Lack of qualitative data makes it difficult to find a clear cause for that. Possible explanations include problems with design (inconvenient or unappealing), battery problems, notification fatigue, or users not finding the data useful enough.

### 2. Weight dynamics
The number of weight logs per user was first examined:
```sql
SELECT Id, count(id) as times_logged
FROM weightLogInfo_merged
GROUP BY id
ORDER BY times_logged
```
Most users only logged their weight once or twice, with just two users logging consistently (32 and 43 times). Further analysis was not possible.
The only useful metric that could be extracted was average weight across users:
```sql
SELECT AVG(user_avg_weight) as average_weight
FROM (
SELECT id, AVG(WeightKG) as user_avg_weight
FROM weightLogInfo_merged
GROUP BY Id 
)
```
The result was **80** kg, compared to the US female average of 77.5 kg (Medical News Today). However, given that only 13 of 35 users logged weight at all, this figure should be treated with caution.

### 3. Sleep analysis
#### 3.1 Dataset
The sleep dataset covers one month and contains data for 24 of the 35 users. Users with fewer than 4 sleep logs were excluded from trend analysis due to insufficient data.

#### 3.2 Amount of sleep
Average sleep per person was calculated, filtering for users with more than 3 logs:
```sql
SELECT id, LEFT(AVG(TotalMinutesAsleep), 6) as avg_sleep_per_person
FROM sleepDay
GROUP BY id
HAVING COUNT(id) > 3
ORDER BY avg_sleep_per_person
```
Due to a clear outlier in the data, median was used instead of mean:
```sql
SELECT Median(avg_sleep_per_person) as median_sleep_duration
FROM (
SELECT id, AVG(TotalMinutesAsleep) as avg_sleep_per_person
GROUP BY id
HAVING COUNT(id) > 3
)
```
<img width="1027" height="911" alt="image" src="https://github.com/user-attachments/assets/8def9817-89ce-4d3d-8dc1-f99c38bd3676" />

Most values fall between **350 and 500 minutes**. According to the National Heart, Lung, and Blood Institute, adults who sleep fewer than 7 hours (420 minutes) a night may experience more health issues than those who sleep longer. Roughly half of respondents fall below this mark. One extreme outlier (average of 127.6 minutes) only had 5 logs, which means it is likely a short-term occurrence.

#### 3.3 Time to fall asleep
Average time spent in bed before falling asleep was calculated per user:
```sql
SELECT id, AVG(TotalTimeInBed - TotalMinutesAsleep) as avg_time_to_fall_asleep
FROM sleepDay
GROUP BY id
HAVING COUNT(id) > 3
```
<img width="1031" height="917" alt="image" src="https://github.com/user-attachments/assets/19567010-6044-4a28-a308-2c1fe0c81fed" />

The range was 12.4 to 167.5 minutes. **79%** of respondents spent more time lying in bed than necessary to fall asleep. Since the dataset doesn't specify how time in bed is measured, certain conclusions are difficult to make, but the pattern is notable.

### 4. Activity analysis
#### 4.1 User types by activity
After calculating the number of records for each ID, two users, who only had 2 and 3 records, were excluded from further analysis.  
Activity in the dataset is broken into four categories: Very Active, Fairly Active, Lightly Active, and Sedentary. For this analysis, "active" was defined as Very Active + Fairly Active minutes combined; "inactive" as Lightly Active + Sedentary combined.

Median active and inactive minutes were calculated across users:
```sql
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
```

Results: **median active minutes = 28.8**, **median inactive minutes = 1231.1**.  
Users were then classified into four groups relative to the median:
1.	Highly active.
Consistently active people with low sedentary time. Their active minutes are above median and inactive are below median.
2.	Active, but sedentary.
Consistently active people, who still spend a lot of time being inactive. Typically, they are office workers, who exercise regularly. Their active and inactive minutes are above median.
3.	Low activity, but not extremely sedentary.
Inactive people, who aren't constantly sedentary. Their active and inactive minutes are below median.
4.	Highly sedentary.
Inactive people, who do not exercise on a regular basis. Their active minutes are below median and inactive are above median.

```sql
WITH
averages_per_person AS (
SELECT ID, 
AVG(VeryActiveMinutes+FairlyActiveMinutes) AS Average_active_minutes_per_person,
AVG(LightlyActiveMinutes+SedentaryMinutes) AS Average_inactive_minutes_per_person
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
```

<img width="940" height="577" alt="image" src="https://github.com/user-attachments/assets/76107cb6-aae3-47bb-8d67-b4c190ccb62f" />

#### 4.2 Activity and steps recommendations
According to the World Health Organization, adults aged 18-64 should do at least 150 minutes of moderate-intensity physical activity throughout the week - equivalent to 21.4 minutes per day:

```sql
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
```

**54.55%** of users meet the WHO activity recommendation.
Steps were analysed separately, using 8,000 steps/day as the benchmark (the point at which health benefits plateau for adults under 60, according to UCLA Health):

```sql
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
```
Only **45.46%** of users take enough daily steps - fewer than half.

#### 4.3 Correlation between steps and sleep
Average daily steps and average sleep duration were joined per user to test whether a correlation exists:
```sql
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
LEFT JOIN steps st ON sl.id = st.id
```
<img width="1175" height="886" alt="image" src="https://github.com/user-attachments/assets/69f421ee-305c-4967-a615-9f4218c7eea7" />

There is **no significant correlation** between average daily steps and sleep duration. While a cluster of users in the upper-right quadrant suggests a weak positive relationship, the trendline and outliers don't support a certain conclusion. This is not surprising. Sleep duration is influenced by many factors beyond physical activity, such as stress, work schedules, screen time, etc. A more comprehensive dataset would be needed to model sleep patterns.

### 5. Profiling users
A final query combines all classifications into a single user profile table, joining FitBit usage category, sleep category, activity category, WHO criteria, and steps category:

```sql
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
LEFT JOIN steps_column st ON f.id = st.id
```

The resulting table:
| # | ID | FitBit Usage | Sleep | Category by Activity | Activity by WHO Criteria |
|---|---|---|---|---|---|
| 1 | 1503960366 | active_user | Bad_sleeper | Active | Fits WHO criteria |
| 2 | 1624580081 | active_user | NULL | Inactive | Does not fit criteria |
| 3 | 1644430081 | moderately_active_user | Bad_sleeper | Active_sedentary | Fits WHO criteria |
| 4 | 1844505072 | inactive_user | NULL | Inactive | Does not fit criteria |
| 5 | 1927972279 | inactive_user | Bad_sleeper | Inactive | Does not fit criteria |
| 6 | 2022484408 | moderately_active_user | NULL | Active_sedentary | Fits WHO criteria |
| 7 | 2026352035 | moderately_active_user | Good_sleeper | Low_activity_not_sedentary | Does not fit criteria |
| 8 | 2320127002 | moderately_active_user | NULL | Inactive | Does not fit criteria |
| 9 | 2347167796 | moderately_active_user | Good_sleeper | Active | Fits WHO criteria |
| 10 | 2873212765 | moderately_active_user | NULL | Inactive | Does not fit criteria |
| 11 | 2891001357 | inactive_user | NULL | NULL | NULL |
| 12 | 3372868164 | inactive_user | NULL | Inactive | Does not fit criteria |
| 13 | 3977333714 | moderately_active_user | Bad_sleeper | Active | Fits WHO criteria |
| 14 | 4020332650 | active_user | Bad_sleeper | Low_activity_not_sedentary | Does not fit criteria |
| 15 | 4057192912 | inactive_user | NULL | Inactive | Does not fit criteria |
| 16 | 4319703577 | moderately_active_user | Good_sleeper | Low_activity_not_sedentary | Does not fit criteria |
| 17 | 4388161847 | moderately_active_user | Bad_sleeper | Active | Fits WHO criteria |
| 18 | 4445114986 | active_user | Bad_sleeper | Low_activity_not_sedentary | Does not fit criteria |
| 19 | 4558609924 | moderately_active_user | Bad_sleeper | Inactive | Does not fit criteria |
| 20 | 4702921684 | moderately_active_user | Bad_sleeper | Active | Fits WHO criteria |
| 21 | 5553957443 | moderately_active_user | Good_sleeper | Active | Fits WHO criteria |
| 22 | 5577150313 | moderately_active_user | Good_sleeper | Active | Fits WHO criteria |
| 23 | 6117666160 | moderately_active_user | Good_sleeper | Low_activity_not_sedentary | Does not fit criteria |
| 24 | 6290855005 | inactive_user | NULL | Inactive | Does not fit criteria |
| 25 | 6391747486 | inactive_user | NULL | NULL | NULL |
| 26 | 6775888955 | inactive_user | NULL | Active | Fits WHO criteria |
| 27 | 6962181067 | moderately_active_user | Good_sleeper | Active | Fits WHO criteria |
| 28 | 7007744171 | moderately_active_user | NULL | Active_sedentary | Fits WHO criteria |
| 29 | 7086361926 | moderately_active_user | Good_sleeper | Active | Fits WHO criteria |
| 30 | 8053475328 | moderately_active_user | NULL | Active_sedentary | Fits WHO criteria |
| 31 | 8253242879 | inactive_user | NULL | Active_sedentary | Fits WHO criteria |
| 32 | 8378563200 | moderately_active_user | Good_sleeper | Active | Fits WHO criteria |
| 33 | 8583815059 | moderately_active_user | NULL | Inactive | Fits WHO criteria |
| 34 | 8792009665 | inactive_user | Good_sleeper | Low_activity_not_sedentary | Does not fit criteria |
| 35 | 8877689391 | moderately_active_user | NULL | Active_sedentary | Fits WHO criteria |

This table provides a multi-dimensional profile for each user and can serve as a foundation for targeted marketing, personalised notifications, and product recommendations. It can also be filtered and extended depending on the business question.

## Conclusion
The analysis reveals that engagement with the FitBit tracker is the biggest issue - only **11.4%** of users wore their tracker consistently throughout the study period, while **28.6%** were inactive. The average user tracked roughly once every two days over a 62-day period.  
On the health side, around half of users sleep below the recommended level and fewer than half take enough daily steps, suggesting that the users who do use the tracker have significant room for improvement in their habits. However, these findings should be seen as directional, not conclusive, given the dataset's small sample size, age, and lack of demographic data (age, height, occupation, etc.) about users.  
The central takeaway for Bellabeat is that the product's potential can only be reached if users wear it regularly, which makes engagement and habit formation the highest priority before any other feature investment.

## Act
### 1. Usage frequency and activity
Several recommendations follow from usage analysis:

**Personalise activity goals**. Activity goals shouldn’t be based on rigid recommendations and global averages. Instead, Bellabeat should introduce a system of progress streaks and relative improvements. The goals should be dynamically assigned based on the user’s past activity, accompanied with messages like “+10% vs yesterday”.

**Support habit formation in early weeks**. New users should receive a short overview of its features, highlighting the benefits of daily wear, including the streak and dynamic goal features.

**Re-engage inactive users**. Trigger automated re-engagement after 3–5 inactive days with personalised notifications like "You were most active on Thursday" and soft re-entry challenges ("Even 5 minutes of physical activity can improve your health").

**Introduce additional benefits for regular activity**. Users who maintain a streak for 20+ days in a month could receive discounted premium features. Some health insights could be unlocked only after 25+ days of wearing the tracker.

**Add social comparison carefully**. There are many ways to add some competitiveness into the fitness space. The most responsible and safe one is to add a system of comparing consistency, not results. Comparisons should also only be made with similar peers. Comparing oneself to more active people can encourage one to exercise more, but it can also easily discourage them. This feature should be added with caution and should be tested first.

### 2. Weight measurements and sleep
Several recommendations follow from weight and sleep analyses:

**Send timely notifications**. Morning reminders to log weight (triggered when the tracker is first put on) and evening reminders to wear the tracker to bed could improve data completeness.

**Expand sleep and weight features**. If users don't find the app's weight and sleep tracking useful enough, they won't enter data. Adding richer insights - such as adjusting daily goals based on sleep quality or weight trends - would increase the value of logging.

**Consider a smart scale partnership**. Collaborating with a smart scale manufacturer would automate weight logging entirely. A partnership would also open a potential new customer acquisition channel, as smart scale users could be introduced to Bellabeat's ecosystem of health products.
