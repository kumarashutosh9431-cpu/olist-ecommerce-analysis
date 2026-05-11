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