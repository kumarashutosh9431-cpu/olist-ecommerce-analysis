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