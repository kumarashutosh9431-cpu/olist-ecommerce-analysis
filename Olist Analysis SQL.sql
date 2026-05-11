use olist_analysis;

-- Q1. What is the monthly order trend and MoM growth rate?

-- 1.a. Basic monthly order count

select 
	date_format (order_purchase_timestamp, '%Y-%m') as order_month,
	count(order_id)									as total_orders
from olist_orders
where order_status = "delivered"
group by order_month
order by order_month;

-- 1.b. Month-on-month growth rate

WITH monthly_orders AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS order_month,
        COUNT(order_id)                                AS total_orders
    FROM olist_orders
    WHERE order_status = 'delivered'
    GROUP BY order_month
)

SELECT
    order_month,
    total_orders,
    
    LAG(total_orders) OVER (ORDER BY order_month)  AS prev_month_orders,
    
    ROUND(
        (total_orders - LAG(total_orders) OVER (ORDER BY order_month))
        / LAG(total_orders) OVER (ORDER BY order_month) * 100
    , 1)                                           AS mom_growth_pct

FROM monthly_orders
ORDER BY order_month;

-- Q2. Which product categories have highest revenue but lowest review scores?

-- 2.a. Revenue by category

SELECT
    t.product_category_name_english  AS category,
    ROUND(SUM(oi.price), 2)          AS total_revenue,
    COUNT(DISTINCT oi.order_id)      AS total_orders
FROM olist_order_items oi
JOIN olist_products p
    ON oi.product_id = p.product_id

JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name

GROUP BY category
ORDER BY total_revenue DESC
;

-- 2.b. Average review score per category

SELECT
    t.product_category_name_english     AS category,
    ROUND(SUM(oi.price), 2)             AS total_revenue,
    COUNT(DISTINCT oi.order_id)         AS total_orders,
    ROUND(AVG(r.review_score), 2)       AS avg_review_score

FROM olist_orders o

JOIN olist_order_items oi
    ON o.order_id = oi.order_id

JOIN olist_products p
    ON oi.product_id = p.product_id

JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name

JOIN olist_order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'      

GROUP BY category
ORDER BY total_revenue desc
;

-- 2.c. “High revenue + Low rating”

SELECT
    t.product_category_name_english          AS category,
    ROUND(SUM(oi.price), 2)                  AS total_revenue,
    COUNT(DISTINCT oi.order_id)              AS total_orders,
    ROUND(AVG(r.review_score), 2)            AS avg_review_score,

    -- Categories where revenue is high but satisfaction is low
    CASE
    	WHEN SUM(oi.price) > 500000
     	AND AVG(r.review_score) < 4.1  THEN 'HIGH RISK'
    	WHEN SUM(oi.price) > 500000
     	AND AVG(r.review_score) < 4.3  THEN 'WATCH'
    	ELSE 'OK'
	END 								AS risk_flag

FROM olist_order_items oi

JOIN olist_products p
    ON oi.product_id = p.product_id

JOIN product_category_name_translation t
    ON p.product_category_name = t.product_category_name

JOIN olist_order_reviews r
    ON oi.order_id = r.order_id

JOIN olist_orders o
    ON oi.order_id = o.order_id
    AND o.order_status = 'delivered'

GROUP BY category
ORDER BY total_revenue DESC;

-- Q3. What is average delivery delay by region and how does it correlate with review score?
-- 3.a. Delivery delay per order

SELECT
    o.order_id,
    c.customer_state                                     AS region,
    
    -- actual days taken to deliver
    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_purchase_timestamp
    )                                                    AS actual_delivery_days,
    
    -- how many days late or early vs promise
    DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    )                                                    AS delay_days,
    
    r.review_score

FROM olist_orders o

JOIN olist_customers c
    ON o.customer_id = c.customer_id

JOIN olist_order_reviews r
    ON o.order_id = r.order_id

-- only delivered orders with all dates present
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

LIMIT 20;

-- 3.b. Aggregation by region

SELECT
    c.customer_state                                         AS region,
    COUNT(DISTINCT o.order_id)                               AS total_orders,
    
    -- average days from purchase to delivery
    ROUND(AVG(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_purchase_timestamp)), 1)                     AS avg_delivery_days,
    
    -- average delay vs promised date (positive = late)
    ROUND(AVG(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date)), 1)                AS avg_delay_days,
    
    -- share of orders that arrived late
    ROUND(
        SUM(CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1 ELSE 0
        END) * 100.0 / COUNT(*), 1)                         AS pct_late_orders,
    
    ROUND(AVG(r.review_score), 2)                           AS avg_review_score

FROM olist_orders o

JOIN olist_customers c
    ON o.customer_id = c.customer_id

JOIN olist_order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY region
ORDER BY avg_delay_days DESC;

-- 3.c. Delay severity flag by worst regions

SELECT
    c.customer_state                                         AS region,
    COUNT(DISTINCT o.order_id)                               AS total_orders,
    ROUND(AVG(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_purchase_timestamp)), 1)                     AS avg_delivery_days,
    ROUND(AVG(DATEDIFF(
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date)), 1)                AS avg_delay_vs_estimate,
    ROUND(
        SUM(CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1 ELSE 0
        END) * 100.0 / COUNT(*), 1)                         AS pct_late_orders,
    ROUND(AVG(r.review_score), 2)                           AS avg_review_score,

    -- reclassify by actual delivery time, not vs estimate
    CASE
        WHEN AVG(DATEDIFF(
            o.order_delivered_customer_date,
            o.order_purchase_timestamp)) > 20  THEN 'SLOW'
        WHEN AVG(DATEDIFF(
            o.order_delivered_customer_date,
            o.order_purchase_timestamp)) > 13  THEN 'MODERATE'
        ELSE 'FAST'
    END                                                      AS delivery_band

FROM olist_orders o

JOIN olist_customers c
    ON o.customer_id = c.customer_id

JOIN olist_order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY region
ORDER BY avg_delivery_days DESC;

-- 3.d. Correlation

SELECT
    (AVG(delay_days * review_score) 
     - AVG(delay_days) * AVG(review_score))
    /
    (STDDEV(delay_days) * STDDEV(review_score)) AS correlation
FROM (
    SELECT
        DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delay_days,
        r.review_score
    FROM olist_orders o
    LEFT JOIN olist_order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
) t;

-- Q4. Identify top 20% sellers driving 80% of revenue (Pareto Analysis)

-- 4.a. Revenue per seller

SELECT
    oi.seller_id,
    s.seller_state,
    ROUND(SUM(oi.price), 2)          AS seller_revenue,
    COUNT(DISTINCT oi.order_id)      AS total_orders
    
FROM olist_order_items oi

JOIN olist_sellers s
    ON oi.seller_id = s.seller_id

GROUP BY oi.seller_id, s.seller_state
ORDER BY seller_revenue DESC
;

-- 4.b. Revenue rank and cumulative revenue share

WITH seller_revenue AS (
    -- step 1: calculate revenue per seller
    select	
        oi.seller_id,
        s.seller_state,
        ROUND(SUM(oi.price), 2)              AS seller_revenue,
        COUNT(DISTINCT oi.order_id)          AS total_orders
    FROM olist_order_items oi
    JOIN olist_sellers s
        ON oi.seller_id = s.seller_id
    GROUP BY oi.seller_id, s.seller_state
),

ranked_sellers AS (
    -- step 2: rank sellers by revenue and calculate cumulative share
    SELECT
        seller_id,
        seller_state,
        seller_revenue,
        total_orders,
        
        -- rank 1 = highest revenue seller
        RANK() OVER (ORDER BY seller_revenue DESC)   AS revenue_rank,
        
        -- what % of total revenue does this seller alone contribute
        ROUND(seller_revenue * 100.0 /
            SUM(seller_revenue) OVER (), 2)          AS revenue_share_pct,
        
        -- running total of revenue share from rank 1 down to this seller
        ROUND(SUM(seller_revenue) OVER (
            ORDER BY seller_revenue DESC) * 100.0 /
            SUM(seller_revenue) OVER (), 2)          AS cumulative_revenue_pct,
        
        -- what percentile does this seller fall in (by count)
        ROUND(PERCENT_RANK() OVER (
            ORDER BY seller_revenue) * 100, 1)       AS seller_percentile

    FROM seller_revenue
)

SELECT
    seller_id,
    seller_state,
    seller_revenue,
    total_orders,
    revenue_rank,
    revenue_share_pct,
    cumulative_revenue_pct,
    seller_percentile,
    
    -- classify into pareto segments
    CASE
        WHEN cumulative_revenue_pct <= 80  THEN 'TOP 20% — Pareto Core'
        WHEN cumulative_revenue_pct <= 95  THEN 'MID 30% — Growth Tier'
        ELSE                                    'BOTTOM 50% — Long Tail'
    END                                          AS seller_segment

FROM ranked_sellers
ORDER BY revenue_rank;

-- 4.c.  Summary: how many sellers make up 80% of revenue

WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        ROUND(SUM(oi.price), 2)      AS seller_revenue
    FROM olist_order_items oi
    GROUP BY oi.seller_id
),

ranked_sellers AS (
    SELECT
        seller_id,
        seller_revenue,
        ROUND(SUM(seller_revenue) OVER (
            ORDER BY seller_revenue DESC) * 100.0 /
            SUM(seller_revenue) OVER (), 2)   AS cumulative_revenue_pct,
        ROUND(PERCENT_RANK() OVER (
            ORDER BY seller_revenue) * 100, 1) AS seller_percentile
    FROM seller_revenue
)

SELECT
    -- how many sellers sit in each segment
    SUM(CASE WHEN cumulative_revenue_pct <= 80 THEN 1 ELSE 0 END)  AS pareto_core_sellers,
    SUM(CASE WHEN cumulative_revenue_pct <= 80 THEN 1 ELSE 0 END) * 100.0
        / COUNT(*)                                                   AS pareto_core_pct_of_total,
    COUNT(*)                                                         AS total_sellers,
    
    -- revenue contribution check
    MAX(CASE WHEN cumulative_revenue_pct <= 80
        THEN cumulative_revenue_pct END)                             AS revenue_covered_pct

FROM ranked_sellers;

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


-- Q6.  Which payment methods correlate with higher order values?
-- 6.a. Basic payment method breakdown

SELECT
    payment_type,
    COUNT(DISTINCT order_id)             AS total_orders,
    ROUND(AVG(payment_value), 2)         AS avg_order_value,
    ROUND(SUM(payment_value), 2)         AS total_revenue,
    ROUND(MIN(payment_value), 2)         AS min_order_value,
    ROUND(MAX(payment_value), 2)         AS max_order_value

FROM olist_order_payments

WHERE payment_type != 'not_defined'      -- exclude uncategorised rows

GROUP BY payment_type
ORDER BY avg_order_value DESC;


-- 6.b. Installment analysis for credit cards

SELECT
    payment_type,
    payment_installments,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(AVG(payment_value), 2)          AS avg_order_value,
    ROUND(SUM(payment_value), 2)          AS total_revenue

FROM olist_order_payments

WHERE payment_type = 'credit_card'
  AND payment_installments > 0           -- exclude zero installment edge cases

GROUP BY payment_type, payment_installments
ORDER BY payment_installments;

-- 6.c. payment behaviour segments (full picture)

WITH payment_summary AS (
    SELECT
        op.payment_type,
        COUNT(DISTINCT op.order_id)               AS total_orders,
        ROUND(AVG(op.payment_value), 2)           AS avg_order_value,
        ROUND(SUM(op.payment_value), 2)           AS total_revenue,
        ROUND(AVG(op.payment_installments), 1)    AS avg_installments,

        -- share of total orders this payment method represents
        ROUND(COUNT(DISTINCT op.order_id) * 100.0 /
            SUM(COUNT(DISTINCT op.order_id)) OVER (), 1) AS order_share_pct,

        -- share of total revenue
        ROUND(SUM(op.payment_value) * 100.0 /
            SUM(SUM(op.payment_value)) OVER (), 1)       AS revenue_share_pct

    FROM olist_order_payments op

    JOIN olist_orders o
        ON op.order_id = o.order_id
        AND o.order_status = 'delivered'

    WHERE op.payment_type != 'not_defined'

    GROUP BY op.payment_type
)

SELECT
    payment_type,
    total_orders,
    avg_order_value,
    total_revenue,
    avg_installments,
    order_share_pct,
    revenue_share_pct,

    -- classify payment method by average order value vs overall average
    CASE
        WHEN avg_order_value > (SELECT AVG(payment_value)
                                FROM olist_order_payments
                                WHERE payment_type != 'not_defined')
            THEN 'HIGH VALUE'
        ELSE 'STANDARD VALUE'
    END                                            AS value_segment,

    -- business interpretation
    CASE
        WHEN payment_type = 'credit_card'  THEN 'Primary driver — installments enable big purchases'
        WHEN payment_type = 'boleto'       THEN 'Brazilian bank slip — typically lower value, no card needed'
        WHEN payment_type = 'voucher'      THEN 'Promotional — likely discount-driven purchases'
        WHEN payment_type = 'debit_card'   THEN 'Immediate payment — moderate values'
        ELSE 'Other'
    END                                            AS business_context

FROM payment_summary
ORDER BY avg_order_value DESC;