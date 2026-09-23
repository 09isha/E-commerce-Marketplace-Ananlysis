-- ============================================================================
-- 01_funnel_analysis.sql — Purchase Funnel Conversion Analysis
-- ============================================================================
--
-- BUSINESS QUESTION:
--   "What percentage of users drop off at each step of the purchase journey?"
--
-- FUNNEL STEPS:
--   homepage_view → product_view → add_to_cart → checkout_start → purchase
--
-- WHY IT MATTERS:
--   Identifying where users drop off tells us where to focus product
--   improvements. A big drop between add_to_cart and checkout_start might
--   mean the checkout UX needs work — exactly what our A/B test addresses.
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 1: Overall Funnel — Step-by-step conversion rates
-- ─────────────────────────────────────────────────────────────────────────────
-- Shows: unique users at each step, % who reached that step (from the top),
--        and step-over-step conversion rate.

WITH funnel AS (
    SELECT
        event_name,
        COUNT(DISTINCT user_id) AS users_at_step
    FROM events
    WHERE event_name IN (
        'homepage_view', 'product_view', 'add_to_cart',
        'checkout_start', 'purchase'
    )
    GROUP BY event_name
),
ordered_funnel AS (
    SELECT
        event_name,
        users_at_step,
        -- Assign a sort order to funnel steps
        CASE event_name
            WHEN 'homepage_view'  THEN 1
            WHEN 'product_view'   THEN 2
            WHEN 'add_to_cart'    THEN 3
            WHEN 'checkout_start' THEN 4
            WHEN 'purchase'       THEN 5
        END AS step_order
    FROM funnel
)
SELECT
    event_name                                     AS step,
    users_at_step,
    -- % of total users who made it to this step
    ROUND(100.0 * users_at_step /
        (SELECT users_at_step FROM ordered_funnel
         WHERE step_order = 1), 1)                 AS pct_of_total,
    -- Step-over-step conversion rate
    ROUND(100.0 * users_at_step /
        LAG(users_at_step) OVER (ORDER BY step_order), 1)
                                                   AS step_conversion_pct
FROM ordered_funnel
ORDER BY step_order;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 2: Funnel by Traffic Source
-- ─────────────────────────────────────────────────────────────────────────────
-- Answers: "Which acquisition channel has the best conversion rate?"
-- This is a classic product analytics question in interviews.

WITH user_max_step AS (
    -- For each user, find the deepest funnel step they reached
    SELECT
        e.user_id,
        u.traffic_source,
        MAX(CASE e.event_name
            WHEN 'homepage_view'  THEN 1
            WHEN 'product_view'   THEN 2
            WHEN 'add_to_cart'    THEN 3
            WHEN 'checkout_start' THEN 4
            WHEN 'purchase'       THEN 5
            ELSE 0
        END) AS max_step
    FROM events e
    JOIN users u ON e.user_id = u.user_id
    WHERE e.event_name IN (
        'homepage_view', 'product_view', 'add_to_cart',
        'checkout_start', 'purchase'
    )
    GROUP BY e.user_id, u.traffic_source
)
SELECT
    traffic_source,
    COUNT(DISTINCT user_id)                                AS total_users,
    SUM(CASE WHEN max_step >= 2 THEN 1 ELSE 0 END)        AS viewed_product,
    SUM(CASE WHEN max_step >= 3 THEN 1 ELSE 0 END)        AS added_to_cart,
    SUM(CASE WHEN max_step >= 4 THEN 1 ELSE 0 END)        AS started_checkout,
    SUM(CASE WHEN max_step >= 5 THEN 1 ELSE 0 END)        AS purchased,
    ROUND(100.0 * SUM(CASE WHEN max_step >= 5 THEN 1 ELSE 0 END) /
        COUNT(DISTINCT user_id), 1)                        AS conversion_rate_pct
FROM user_max_step
GROUP BY traffic_source
ORDER BY conversion_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 3: Funnel by Device Type
-- ─────────────────────────────────────────────────────────────────────────────
-- Answers: "Do mobile users convert worse than desktop users?"

WITH user_max_step AS (
    SELECT
        e.user_id,
        u.device_type,
        MAX(CASE e.event_name
            WHEN 'homepage_view'  THEN 1
            WHEN 'product_view'   THEN 2
            WHEN 'add_to_cart'    THEN 3
            WHEN 'checkout_start' THEN 4
            WHEN 'purchase'       THEN 5
            ELSE 0
        END) AS max_step
    FROM events e
    JOIN users u ON e.user_id = u.user_id
    WHERE e.event_name IN (
        'homepage_view', 'product_view', 'add_to_cart',
        'checkout_start', 'purchase'
    )
    GROUP BY e.user_id, u.device_type
)
SELECT
    device_type,
    COUNT(DISTINCT user_id)                                AS total_users,
    SUM(CASE WHEN max_step >= 2 THEN 1 ELSE 0 END)        AS viewed_product,
    SUM(CASE WHEN max_step >= 3 THEN 1 ELSE 0 END)        AS added_to_cart,
    SUM(CASE WHEN max_step >= 4 THEN 1 ELSE 0 END)        AS started_checkout,
    SUM(CASE WHEN max_step >= 5 THEN 1 ELSE 0 END)        AS purchased,
    ROUND(100.0 * SUM(CASE WHEN max_step >= 5 THEN 1 ELSE 0 END) /
        COUNT(DISTINCT user_id), 1)                        AS conversion_rate_pct
FROM user_max_step
GROUP BY device_type
ORDER BY conversion_rate_pct DESC;
