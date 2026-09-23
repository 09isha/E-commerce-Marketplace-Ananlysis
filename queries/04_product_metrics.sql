-- ============================================================================
-- 04_product_metrics.sql — KPI Dashboard Queries
-- ============================================================================
--
-- BUSINESS QUESTION:
--   "What are the core health metrics for our marketplace?"
--
-- These are the queries a Product Analyst would run regularly to monitor
-- product health. Think of this as "what goes on the weekly team dashboard."
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 1: Daily Active Users (DAU) — last 30 days of data
-- ─────────────────────────────────────────────────────────────────────────────
-- DAU = unique users who triggered any event on a given day.

SELECT
    event_date,
    COUNT(DISTINCT user_id) AS dau
FROM events
WHERE event_date >= '2024-06-01'
GROUP BY event_date
ORDER BY event_date;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 2: Weekly Active Users (WAU)
-- ─────────────────────────────────────────────────────────────────────────────
-- Uses strftime('%W') for ISO week number.

SELECT
    strftime('%Y-W%W', event_date)              AS year_week,
    COUNT(DISTINCT user_id)                     AS wau
FROM events
GROUP BY year_week
ORDER BY year_week;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 3: Monthly Active Users (MAU)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    strftime('%Y-%m', event_date)               AS month,
    COUNT(DISTINCT user_id)                     AS mau
FROM events
GROUP BY month
ORDER BY month;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 4: Revenue by Category and Month
-- ─────────────────────────────────────────────────────────────────────────────
-- Shows which product categories drive the most revenue over time.

SELECT
    strftime('%Y-%m', o.order_date)             AS month,
    p.category,
    ROUND(SUM(oi.quantity * oi.unit_price), 2)  AS revenue,
    COUNT(DISTINCT o.order_id)                  AS num_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p     ON oi.product_id = p.product_id
WHERE o.order_status = 'completed'
GROUP BY month, p.category
ORDER BY month, revenue DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 5: Average Order Value (AOV) Trend by Month
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    strftime('%Y-%m', order_date)               AS month,
    COUNT(*)                                    AS total_orders,
    ROUND(AVG(order_total), 2)                  AS avg_order_value,
    ROUND(SUM(order_total), 2)                  AS total_revenue
FROM orders
WHERE order_status = 'completed'
GROUP BY month
ORDER BY month;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 6: Top 10 Products by Revenue
-- ─────────────────────────────────────────────────────────────────────────────
-- Uses ROW_NUMBER() window function for ranking.

SELECT
    ROW_NUMBER() OVER (ORDER BY SUM(oi.quantity * oi.unit_price) DESC)
                                                AS rank,
    p.product_name,
    p.category,
    SUM(oi.quantity)                             AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2)   AS total_revenue,
    ROUND(AVG(oi.unit_price), 2)                 AS avg_selling_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN orders o   ON oi.order_id = o.order_id
WHERE o.order_status = 'completed'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY total_revenue DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 7: Repeat Purchase Rate
-- ─────────────────────────────────────────────────────────────────────────────
-- What % of customers have made 2+ purchases?
-- High repeat rate = strong product-market fit.

WITH user_order_counts AS (
    SELECT
        user_id,
        COUNT(*) AS order_count
    FROM orders
    WHERE order_status = 'completed'
    GROUP BY user_id
)
SELECT
    COUNT(*)                                            AS total_customers,
    SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)  AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN order_count >= 2 THEN 1 ELSE 0 END)
        / COUNT(*), 1)                                  AS repeat_rate_pct
FROM user_order_counts;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 8: DAU / MAU Ratio (Stickiness)
-- ─────────────────────────────────────────────────────────────────────────────
-- DAU/MAU ratio measures how "sticky" the product is.
-- Higher = users come back more frequently within a month.
-- Good benchmark: 20-30% for marketplaces, 50%+ for social apps.

WITH daily_users AS (
    SELECT
        event_date,
        strftime('%Y-%m', event_date)   AS month,
        COUNT(DISTINCT user_id)         AS dau
    FROM events
    GROUP BY event_date
),
monthly_users AS (
    SELECT
        strftime('%Y-%m', event_date)   AS month,
        COUNT(DISTINCT user_id)         AS mau
    FROM events
    GROUP BY month
)
SELECT
    m.month,
    m.mau,
    ROUND(AVG(d.dau), 0)                              AS avg_dau,
    ROUND(100.0 * AVG(d.dau) / m.mau, 1)              AS stickiness_pct
FROM monthly_users m
JOIN daily_users d ON m.month = d.month
GROUP BY m.month, m.mau
ORDER BY m.month;
