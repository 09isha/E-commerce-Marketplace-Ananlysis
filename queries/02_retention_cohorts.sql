-- ============================================================================
-- 02_retention_cohorts.sql — Monthly Retention Cohort Analysis
-- ============================================================================
--
-- BUSINESS QUESTION:
--   "Of users who signed up in month X, what % placed an order in months
--    0, 1, 2, 3, 4, 5 after signup?"
--
-- WHY IT MATTERS:
--   Retention is the single most important metric for product-market fit.
--   If users don't come back, no amount of acquisition spend will save you.
--   Cohort analysis lets us see if newer cohorts retain better than older
--   ones (sign of product improvement).
--
-- KEY CONCEPTS:
--   - Cohort = group of users by their signup month
--   - Month 0 = same calendar month as signup
--   - Retention % = (users who ordered in month N) / (total users in cohort)
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 1: Classic Cohort Retention Table
-- ─────────────────────────────────────────────────────────────────────────────
-- Output: one row per (signup_month, months_since_signup) with retention %.
-- This is the data you'd plug into a retention heatmap.

WITH user_cohort AS (
    -- Step 1: Assign each user to their signup-month cohort
    SELECT
        user_id,
        strftime('%Y-%m', signup_date) AS cohort_month
    FROM users
),
user_orders AS (
    -- Step 2: For each user, find the months they placed orders
    SELECT DISTINCT
        o.user_id,
        strftime('%Y-%m', o.order_date) AS order_month
    FROM orders o
    WHERE o.order_status = 'completed'
),
cohort_activity AS (
    -- Step 3: Join to compute months-since-signup for each order
    SELECT
        uc.cohort_month,
        uo.user_id,
        -- Calculate months between signup and order
        -- Using year*12+month arithmetic for simplicity
        (CAST(strftime('%Y', uo.order_month || '-01') AS INT) * 12 +
         CAST(strftime('%m', uo.order_month || '-01') AS INT))
        -
        (CAST(strftime('%Y', uc.cohort_month || '-01') AS INT) * 12 +
         CAST(strftime('%m', uc.cohort_month || '-01') AS INT))
            AS months_since_signup
    FROM user_cohort uc
    JOIN user_orders uo ON uc.user_id = uo.user_id
),
cohort_sizes AS (
    -- Step 4: Count total users per cohort (denominator for retention %)
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM user_cohort
    GROUP BY cohort_month
)
-- Step 5: Final output
SELECT
    ca.cohort_month,
    cs.cohort_size,
    ca.months_since_signup,
    COUNT(DISTINCT ca.user_id)                              AS retained_users,
    ROUND(100.0 * COUNT(DISTINCT ca.user_id) / cs.cohort_size, 1)
                                                            AS retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
WHERE ca.months_since_signup >= 0
  AND ca.months_since_signup <= 5
GROUP BY ca.cohort_month, cs.cohort_size, ca.months_since_signup
ORDER BY ca.cohort_month, ca.months_since_signup;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 2: Cohort Retention — Pivoted View
-- ─────────────────────────────────────────────────────────────────────────────
-- Same data as above but pivoted into a matrix (easier to read as a table).
-- Each row = one cohort, columns = Month 0 through Month 5 retention %.

WITH user_cohort AS (
    SELECT
        user_id,
        strftime('%Y-%m', signup_date) AS cohort_month
    FROM users
),
user_orders AS (
    SELECT DISTINCT
        o.user_id,
        strftime('%Y-%m', o.order_date) AS order_month
    FROM orders o
    WHERE o.order_status = 'completed'
),
cohort_activity AS (
    SELECT
        uc.cohort_month,
        uo.user_id,
        (CAST(strftime('%Y', uo.order_month || '-01') AS INT) * 12 +
         CAST(strftime('%m', uo.order_month || '-01') AS INT))
        -
        (CAST(strftime('%Y', uc.cohort_month || '-01') AS INT) * 12 +
         CAST(strftime('%m', uc.cohort_month || '-01') AS INT))
            AS months_since_signup
    FROM user_cohort uc
    JOIN user_orders uo ON uc.user_id = uo.user_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(*) AS cohort_size
    FROM user_cohort
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.cohort_size,
    -- Pivot: one column per month
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN ca.user_id END)
        / cs.cohort_size, 1) AS month_0,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 1 THEN ca.user_id END)
        / cs.cohort_size, 1) AS month_1,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 2 THEN ca.user_id END)
        / cs.cohort_size, 1) AS month_2,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 3 THEN ca.user_id END)
        / cs.cohort_size, 1) AS month_3,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 4 THEN ca.user_id END)
        / cs.cohort_size, 1) AS month_4,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 5 THEN ca.user_id END)
        / cs.cohort_size, 1) AS month_5
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
GROUP BY ca.cohort_month, cs.cohort_size
ORDER BY ca.cohort_month;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 3: Retention by Traffic Source
-- ─────────────────────────────────────────────────────────────────────────────
-- Answers: "Which acquisition channel brings back users who actually purchase?"
-- Useful for understanding which channels deliver high-LTV users.

WITH user_cohort AS (
    SELECT
        user_id,
        traffic_source,
        strftime('%Y-%m', signup_date) AS cohort_month
    FROM users
),
user_orders AS (
    SELECT DISTINCT
        o.user_id,
        strftime('%Y-%m', o.order_date) AS order_month
    FROM orders o
    WHERE o.order_status = 'completed'
),
cohort_activity AS (
    SELECT
        uc.traffic_source,
        uc.user_id,
        (CAST(strftime('%Y', uo.order_month || '-01') AS INT) * 12 +
         CAST(strftime('%m', uo.order_month || '-01') AS INT))
        -
        (CAST(strftime('%Y', uc.cohort_month || '-01') AS INT) * 12 +
         CAST(strftime('%m', uc.cohort_month || '-01') AS INT))
            AS months_since_signup
    FROM user_cohort uc
    JOIN user_orders uo ON uc.user_id = uo.user_id
),
source_sizes AS (
    SELECT traffic_source, COUNT(*) AS total_users
    FROM user_cohort
    GROUP BY traffic_source
)
SELECT
    ca.traffic_source,
    ss.total_users,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 0 THEN ca.user_id END)
        / ss.total_users, 1) AS month_0,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 1 THEN ca.user_id END)
        / ss.total_users, 1) AS month_1,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 2 THEN ca.user_id END)
        / ss.total_users, 1) AS month_2,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN months_since_signup = 3 THEN ca.user_id END)
        / ss.total_users, 1) AS month_3
FROM cohort_activity ca
JOIN source_sizes ss ON ca.traffic_source = ss.traffic_source
GROUP BY ca.traffic_source, ss.total_users
ORDER BY month_0 DESC;
