
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
