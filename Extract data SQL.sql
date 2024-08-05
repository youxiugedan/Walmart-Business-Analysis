-- CTE to Extract Weekly Active Users
WITH WeeklyActiveUsers AS (
    SELECT 
        user_id,
        DATE_PART('week', activity_date) AS week, -- Extract week from activity date
        COUNT(*) AS activity_count -- Count the number of activities per user per week
    FROM 
        UserActivity
    WHERE 
        activity_date IS NOT NULL -- Filter out records with null activity dates
    GROUP BY 
        user_id, 
        DATE_PART('week', activity_date) -- Group by user and week
),

-- CTE to Calculate Retention Metrics
RetentionMetrics AS (
    SELECT 
        start_week AS week,
        COUNT(DISTINCT wau1.user_id) AS active_num, -- Count distinct users active in the start week
        COUNT(DISTINCT wau2.user_id) AS retention_week1, -- Count distinct users retained in week 1
        COUNT(DISTINCT wau3.user_id) AS retention_week4, -- Count distinct users retained in week 4
        COUNT(DISTINCT wau4.user_id) AS retention_week8, -- Count distinct users retained in week 8
        (COUNT(DISTINCT wau2.user_id) * 1.0 / NULLIF(COUNT(DISTINCT wau1.user_id), 0)) AS retention_rate_week1, -- Calculate retention rate for week 1
        (COUNT(DISTINCT wau3.user_id) * 1.0 / NULLIF(COUNT(DISTINCT wau1.user_id), 0)) AS retention_rate_week4, -- Calculate retention rate for week 4
        (COUNT(DISTINCT wau4.user_id) * 1.0 / NULLIF(COUNT(DISTINCT wau1.user_id), 0)) AS retention_rate_week8 -- Calculate retention rate for week 8
    FROM 
        WeeklyActiveUsers wau1
    LEFT JOIN WeeklyActiveUsers wau2 ON wau1.user_id = wau2.user_id AND wau2.week = wau1.week + 1 -- Join to calculate week 1 retention
    LEFT JOIN WeeklyActiveUsers wau3 ON wau1.user_id = wau3.user_id AND wau3.week = wau1.week + 4 -- Join to calculate week 4 retention
    LEFT JOIN WeeklyActiveUsers wau4 ON wau1.user_id = wau4.user_id AND wau4.week = wau1.week + 8 -- Join to calculate week 8 retention
    GROUP BY 
        wau1.week
),

-- CTE to Aggregate User and Order Information
UserOrderMetrics AS (
    SELECT
        u.user_id,
        u.week,
        u.user_level,
        u.source,
        u.status,
        u.state,
        COALESCE(SUM(o.purchased_item_num), 0) AS purchased_item_num -- Sum purchased items, default to 0 if no purchases
    FROM 
        Users u
    LEFT JOIN Orders o ON u.user_id = o.user_id -- Join with Orders table to get purchased items
    GROUP BY 
        u.user_id, 
        u.week, 
        u.user_level, 
        u.source, 
        u.status, 
        u.state
)

-- Final SELECT Statement to Combine All Metrics
SELECT 
    uom.week,
    uom.user_level,
    uom.source,
    uom.purchased_item_num,
    uom.status,
    uom.state,
    rm.active_num,
    rm.retention_week1,
    rm.retention_week4,
    rm.retention_week8,
    rm.retention_rate_week1,
    rm.retention_rate_week4,
    rm.retention_rate_week8
FROM 
    UserOrderMetrics uom
LEFT JOIN RetentionMetrics rm ON uom.week = rm.week -- Join with RetentionMetrics to get retention data
ORDER BY 
    uom.week, 
    uom.user_id; -- Order the results by week and user_id for better readability
