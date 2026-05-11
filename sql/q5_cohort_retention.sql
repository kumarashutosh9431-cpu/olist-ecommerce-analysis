-- Q5. Repeat Purchase Rate by Customer Cohort
-- 5.a. Each customer's first order date

SELECT
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp)           AS first_order_date,
    COUNT(DISTINCT o.order_id)                AS total_orders

FROM olist_orders o

JOIN olist_customers c
    ON o.customer_id = c.customer_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_unique_id

-- only customers with more than 1 order to validate repeat logic
HAVING COUNT(DISTINCT o.order_id) > 1

ORDER BY total_orders DESC
;

-- 5.b. The full cohort table

WITH customer_orders AS (
    -- step 1: get all orders with the true customer identifier
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM olist_orders o
    JOIN olist_customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

customer_cohorts AS (
    -- step 2: assign each customer to their first purchase month
    SELECT
        customer_unique_id,
        DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m')  AS cohort_month,
        COUNT(DISTINCT order_id)                             AS total_orders
    FROM customer_orders
    GROUP BY customer_unique_id
)

SELECT
    cohort_month,
    COUNT(customer_unique_id)                                AS total_customers,
    
    -- customers who ordered more than once
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)       AS repeat_customers,
    
    -- repeat rate as a percentage
    ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(customer_unique_id), 2)             AS repeat_rate_pct

FROM customer_cohorts
GROUP BY cohort_month
ORDER BY cohort_month;

-- 5.c. Adding cohort size band and flagging strong vs weak cohorts

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM olist_orders o
    JOIN olist_customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

customer_cohorts AS (
    SELECT
        customer_unique_id,
        DATE_FORMAT(MIN(order_purchase_timestamp), '%Y-%m')  AS cohort_month,
        COUNT(DISTINCT order_id)                             AS total_orders
    FROM customer_orders
    GROUP BY customer_unique_id
),

cohort_summary AS (
    SELECT
        cohort_month,
        COUNT(customer_unique_id)                            AS total_customers,
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)   AS repeat_customers,
        ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
            * 100.0 / COUNT(customer_unique_id), 2)         AS repeat_rate_pct
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT
    cohort_month,
    total_customers,
    repeat_customers,
    repeat_rate_pct,

    -- how does this cohort's repeat rate compare to overall average
    ROUND(repeat_rate_pct - AVG(repeat_rate_pct) OVER (), 2) AS vs_avg_pct,

    -- flag cohorts by performance
    CASE
        WHEN repeat_rate_pct >= AVG(repeat_rate_pct) OVER ()
            THEN 'ABOVE AVERAGE'
        ELSE 'BELOW AVERAGE'
    END                                                      AS cohort_performance,

    -- exclude tiny cohorts from judgement — too few customers to be meaningful
    CASE
        WHEN total_customers < 100 THEN 'TOO SMALL TO JUDGE'
        WHEN repeat_rate_pct >= AVG(repeat_rate_pct) OVER () THEN 'STRONG'
        ELSE 'WEAK'
    END                                                      AS cohort_quality

FROM cohort_summary
ORDER BY cohort_month;