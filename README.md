# E-commerce Marketplace: Conversion, Retention & Experiment Analytics

A Product Analytics portfolio project demonstrating SQL skills through real-world e-commerce analyses: purchase funnel optimization, retention cohort tracking, A/B test evaluation, and KPI monitoring.

---

## Project Summary

| Area | What it answers |
|---|---|
| **Funnel Analysis** | Where are we losing users in the purchase journey? |
| **Retention Cohorts** | Are users coming back month over month? |
| **A/B Testing** | Did our checkout redesign experiment improve conversion? |
| **KPI Dashboard** | What are our core product health metrics? |

**Tech Stack:** Python (standard library) · SQLite · SQL

---

## Database Schema

The project uses a synthetic e-commerce dataset with **6 tables**:

```
users (2,000 rows)          — Signups over 6 months (Jan–Jun 2024)
events (~10,800 rows)       — Page views and funnel actions
products (50 rows)          — Across 5 categories
orders (~570 rows)          — Completed, refunded, and cancelled
order_items (~1,100 rows)   — Line items per order
experiments (800 rows)      — A/B test assignments (checkout redesign)
```

**Relationships:**

```
users ──< events         (one user → many events)
users ──< orders ──< order_items >── products
users ──< experiments    (A/B test assignment)
```

---

## Key Findings

### 1. Purchase Funnel

```
homepage_view   2,000 users  (100%)
product_view    1,746 users  ( 87%)   ← 87% view a product
add_to_cart       941 users  ( 47%)   ← Biggest drop: only 54% of viewers add to cart
checkout_start    612 users  ( 31%)   ← 65% of cart users start checkout
purchase          508 users  ( 25%)   ← 83% of checkout starters complete purchase
```

**Insight:** The largest drop-off is between **product_view → add_to_cart** (54% conversion). This suggests the product pages need better CTAs, reviews, or pricing clarity.

**By Traffic Source:**

| Source | Users | Conversion Rate |
|---|---|---|
| Paid Search | 496 | **28.4%** |
| Organic | 599 | 26.0% |
| Social | 431 | 24.1% |
| Email | 183 | 24.0% |
| Direct | 291 | 21.6% |

Paid search users convert best — worth investing more acquisition budget there.

---

### 2. Retention Cohorts

Monthly purchase retention by signup cohort:

| Cohort | Size | Month 0 | Month 1 | Month 2 | Month 3 | Month 4 | Month 5 |
|---|---|---|---|---|---|---|---|
| 2024-01 | 321 | 1.9% | 5.9% | 5.9% | 4.4% | 7.2% | 5.3% |
| 2024-02 | 311 | 1.6% | 4.8% | 5.5% | 5.1% | 6.4% | — |
| 2024-03 | 364 | 3.0% | 6.6% | 7.1% | 9.9% | — | — |
| 2024-04 | 331 | 3.9% | 6.6% | 11.2% | — | — | — |
| 2024-05 | 373 | 6.4% | 15.8% | — | — | — | — |
| 2024-06 | 300 | 22.7% | — | — | — | — | — |

**Insight:** Later cohorts show improving Month 0 retention (1.9% → 22.7%), suggesting product or onboarding improvements over time. The 10.3% repeat purchase rate indicates room for loyalty program investment.

---

### 3. A/B Test: Checkout Redesign

| Metric | Control | Treatment |
|---|---|---|
| Users | 408 | 392 |
| Purchasers | 51 | 95 |
| **Conversion Rate** | **12.5%** | **24.2%** |
| Avg Order Value | $65.62 | $38.37 |

**Statistical Significance:**

```
Absolute lift:   +11.7 percentage points
Relative lift:   +93.9%
Z-score:         4.30
Result:          Significant at 99% confidence (p < 0.01)
```

**Recommendation:** Ship the new checkout design. Conversion rate nearly doubled. The lower AOV in treatment is expected — more users converting means more small orders, which is healthy for growth.

**Sanity Check (SRM):** Control 51.0% / Treatment 49.0% — no sample ratio mismatch.

---

### 4. Product KPIs

| Metric | Value |
|---|---|
| Total Revenue (6 months) | ~$30,965 |
| Avg Order Value | $56–$87 (varies by month) |
| Repeat Purchase Rate | **10.3%** |
| Top Product | Webcam HD ($1,740 revenue) |
| DAU/MAU Stickiness | 4–6% |

---

## How to Run

### Prerequisites
- Python 3.8+
- SQLite3 (included with Python on most systems)

### Steps

```bash
# 1. Clone the repository
git clone <repo-url>
cd isha

# 2. Generate the database (no pip install needed!)
python generate_data.py

# 3. Run any analysis (example: funnel)
sqlite3 -header -column ecommerce.db < queries/01_funnel_analysis.sql

# Run all analyses
sqlite3 -header -column ecommerce.db < queries/01_funnel_analysis.sql
sqlite3 -header -column ecommerce.db < queries/02_retention_cohorts.sql
sqlite3 -header -column ecommerce.db < queries/03_ab_test_analysis.sql
sqlite3 -header -column ecommerce.db < queries/04_product_metrics.sql
```

> **Windows PowerShell users:** Use `cmd /c "sqlite3 -header -column ecommerce.db < queries\01_funnel_analysis.sql"` since PowerShell doesn't support `<` redirection.

---

## Project Structure

```
isha/
├── README.md                        # This file
├── generate_data.py                 # Synthetic data generator (stdlib only)
├── ecommerce.db                     # SQLite database (generated)
└── queries/
    ├── 01_funnel_analysis.sql       # Purchase funnel conversion
    ├── 02_retention_cohorts.sql     # Monthly retention cohort analysis
    ├── 03_ab_test_analysis.sql      # A/B test with Z-test significance
    └── 04_product_metrics.sql       # KPI dashboard queries
```

---

## SQL Concepts Demonstrated

| Concept | Where Used |
|---|---|
| CTEs (Common Table Expressions) | All query files — modular, readable query structure |
| Window Functions (`LAG`, `ROW_NUMBER`, `SUM() OVER`) | Funnel step-over-step conversion, product ranking, SRM check |
| `COUNT(DISTINCT)` | Unique user counts at each funnel step |
| `CASE WHEN` aggregations | Pivot tables, conditional counting, funnel flags |
| Date manipulation (`strftime`) | Cohort bucketing, month arithmetic |
| `LEFT JOIN` for intent-to-treat | A/B test — counting non-converters |
| Statistical Z-test in pure SQL | A/B test significance (strong interview talking point) |
| Self-joins | Cohort retention — joining users to their own order activity |

---

## Interview Talking Points

1. **"Walk me through your funnel analysis."**
   - Explain the 5-step funnel, how you used `COUNT(DISTINCT)` per step, and the biggest insight (product page → cart drop-off).

2. **"How did you build the retention cohort table?"**
   - Explain cohort assignment via `strftime('%Y-%m', signup_date)`, month-since-signup arithmetic, and why you used `COUNT(DISTINCT)` over cohort size.

3. **"Is the A/B test result trustworthy?"**
   - Mention intent-to-treat (LEFT JOIN), the SRM sanity check, Z-test formula, and why 99% confidence matters.

4. **"Why SQLite?"**
   - Zero setup, portable, interviewer can clone and run in 10 seconds. The SQL is standard and transfers to PostgreSQL/BigQuery.
