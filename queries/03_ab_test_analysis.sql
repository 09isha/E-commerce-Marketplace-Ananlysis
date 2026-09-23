-- ============================================================================
-- 03_ab_test_analysis.sql — A/B Test: Checkout Redesign Experiment
-- ============================================================================
--
-- BUSINESS QUESTION:
--   "Did our new checkout page design (treatment) improve conversion rate
--    compared to the old design (control)?"
--
-- EXPERIMENT SETUP:
--   - Name: checkout_redesign
--   - ~800 users randomly assigned (40% of all users)
--   - 50/50 split: control vs treatment
--   - Primary metric: conversion rate (% who completed a purchase)
--   - Secondary metric: average order value (AOV)
--
-- METHODOLOGY:
--   - Intent-to-treat (ITT) analysis: count ALL assigned users, not just
--     those who visited checkout. This avoids selection bias.
--   - Statistical significance via Z-test for proportions.
--
-- WHY IT MATTERS:
--   Product Analysts are expected to design and evaluate experiments.
--   This shows you can go beyond "which number is bigger" and reason
--   about statistical significance.
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 1: Experiment Summary — Conversion Rate per Variant
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    ex.variant,
    COUNT(DISTINCT ex.user_id)                             AS total_users,
    COUNT(DISTINCT o.user_id)                              AS purchasers,
    ROUND(100.0 * COUNT(DISTINCT o.user_id) /
        COUNT(DISTINCT ex.user_id), 2)                     AS conversion_rate_pct
FROM experiments ex
-- LEFT JOIN: include users who were assigned but never purchased
LEFT JOIN orders o
    ON ex.user_id = o.user_id
    AND o.order_status = 'completed'
    AND o.order_date >= ex.assigned_date   -- only count post-assignment orders
WHERE ex.experiment_name = 'checkout_redesign'
GROUP BY ex.variant;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 2: Average Order Value (AOV) per Variant
-- ─────────────────────────────────────────────────────────────────────────────
-- Secondary metric: even if conversion rates are similar, one variant
-- might drive higher-value orders.

SELECT
    ex.variant,
    COUNT(o.order_id)                                      AS total_orders,
    ROUND(AVG(o.order_total), 2)                           AS avg_order_value,
    ROUND(SUM(o.order_total), 2)                           AS total_revenue
FROM experiments ex
JOIN orders o
    ON ex.user_id = o.user_id
    AND o.order_status = 'completed'
    AND o.order_date >= ex.assigned_date
WHERE ex.experiment_name = 'checkout_redesign'
GROUP BY ex.variant;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 3: Statistical Significance — Z-Test for Proportions
-- ─────────────────────────────────────────────────────────────────────────────
--
-- FORMULA (two-proportion Z-test):
--   p_control   = conversions_control / n_control
--   p_treatment = conversions_treatment / n_treatment
--   p_pooled    = (conversions_control + conversions_treatment) /
--                 (n_control + n_treatment)
--   SE          = sqrt(p_pooled * (1 - p_pooled) * (1/n_control + 1/n_treatment))
--   Z           = (p_treatment - p_control) / SE
--
-- INTERPRETATION:
--   |Z| > 1.96  →  Statistically significant at 95% confidence (p < 0.05)
--   |Z| > 2.58  →  Statistically significant at 99% confidence (p < 0.01)
--
-- NOTE: SQLite has no SQRT() — we use a power-of-0.5 workaround.
--       In production you'd use Python/R for stats, but showing this in SQL
--       is a strong interview talking point.

WITH variant_stats AS (
    SELECT
        ex.variant,
        COUNT(DISTINCT ex.user_id)                         AS n,
        COUNT(DISTINCT o.user_id)                          AS conversions
    FROM experiments ex
    LEFT JOIN orders o
        ON ex.user_id = o.user_id
        AND o.order_status = 'completed'
        AND o.order_date >= ex.assigned_date
    WHERE ex.experiment_name = 'checkout_redesign'
    GROUP BY ex.variant
),
control AS (
    SELECT n, conversions, 1.0 * conversions / n AS p
    FROM variant_stats WHERE variant = 'control'
),
treatment AS (
    SELECT n, conversions, 1.0 * conversions / n AS p
    FROM variant_stats WHERE variant = 'treatment'
),
pooled AS (
    SELECT
        (c.conversions + t.conversions) * 1.0 / (c.n + t.n) AS p_pooled,
        c.n AS n_control,
        t.n AS n_treatment,
        c.p AS p_control,
        t.p AS p_treatment,
        c.conversions AS conv_control,
        t.conversions AS conv_treatment
    FROM control c, treatment t
)
SELECT
    ROUND(p_control, 4)                                    AS control_rate,
    ROUND(p_treatment, 4)                                  AS treatment_rate,
    ROUND(p_treatment - p_control, 4)                      AS absolute_lift,
    ROUND(100.0 * (p_treatment - p_control) / p_control, 2)
                                                           AS relative_lift_pct,
    ROUND(p_pooled, 4)                                     AS pooled_rate,
    -- Z-score: (p_treatment - p_control) / SE
    -- SE = sqrt(p_pooled * (1 - p_pooled) * (1/n_control + 1/n_treatment))
    -- SQLite workaround: use pow(x, 0.5) instead of sqrt(x)
    ROUND(
        (p_treatment - p_control) /
        POWER(
            p_pooled * (1.0 - p_pooled) *
            (1.0 / n_control + 1.0 / n_treatment),
            0.5
        ),
        4
    )                                                      AS z_score,
    -- Plain-English interpretation
    CASE
        WHEN ABS(
            (p_treatment - p_control) /
            POWER(
                p_pooled * (1.0 - p_pooled) *
                (1.0 / n_control + 1.0 / n_treatment),
                0.5
            )
        ) > 2.58 THEN 'Significant at 99% (p < 0.01)'
        WHEN ABS(
            (p_treatment - p_control) /
            POWER(
                p_pooled * (1.0 - p_pooled) *
                (1.0 / n_control + 1.0 / n_treatment),
                0.5
            )
        ) > 1.96 THEN 'Significant at 95% (p < 0.05)'
        ELSE 'NOT statistically significant'
    END                                                    AS significance


FROM pooled;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 4: Sanity Check — Sample Ratio Mismatch (SRM)
-- ─────────────────────────────────────────────────────────────────────────────
-- Before trusting results, check that the randomization worked.
-- If control/treatment split deviates significantly from 50/50,
-- the experiment instrumentation may be broken.

SELECT
    variant,
    COUNT(*) AS assigned_users,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM experiments
WHERE experiment_name = 'checkout_redesign'
GROUP BY variant;
