#-- Q1. What is the monthly order trend and MoM growth rate?

#-- 1.a. Basic monthly order count

select 
	date_format (order_purchase_timestamp, '%Y-%m') as order_month,
	count(order_id)									as total_orders
from olist_orders
where order_status = "delivered"
group by order_month
order by order_month;

#-- 1.b. Month-on-month growth rate

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