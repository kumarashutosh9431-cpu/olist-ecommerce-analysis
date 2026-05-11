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