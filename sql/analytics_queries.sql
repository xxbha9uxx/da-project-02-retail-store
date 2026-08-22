
/* ============================================================
   1. REALIZED REVENUE, TOTAL ORDERS & AVERAGE ORDER VALUE (AOV)
   ============================================================ */

SELECT 
    COUNT(order_id) AS valid_orders,
    ROUND(SUM(total_amount), 2) AS realized_revenue,
    ROUND(AVG(total_amount), 2) AS average_order_value
FROM orders
WHERE status != 'Cancelled';


/* ============================================================
   2. CATEGORY PERFORMANCE: VOLUME VS REVENUE CONTRIBUTION
   ============================================================ */

SELECT 
    p.category,
    SUM(oi.quantity) AS total_units_sold,
    ROUND(SUM(oi.quantity * oi.item_price), 2) AS category_revenue,
    ROUND(AVG(p.price), 2) AS avg_catalog_price
FROM order_items oi
INNER JOIN products p 
    ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY category_revenue DESC;


/* ============================================================
   3. PAYMENT CHANNEL ADOPTION & COLLECTION BREAKDOWN
   ============================================================ */

SELECT 
    method,
    COUNT(payment_id) AS transaction_count,
    ROUND(SUM(amount_paid), 2) AS total_collected,
    ROUND(AVG(amount_paid), 2) AS avg_transaction_value
FROM payments
GROUP BY method
ORDER BY total_collected DESC;


/* ============================================================
   4. INVENTORY RISK ASSESSMENT: STOCKOUT & ZERO-SALES DETECTION
   ============================================================ */

SELECT 
    p.product_id,
    p.name AS product_name,
    p.category,
    p.stock_quantity,
    COALESCE(SUM(oi.quantity), 0) AS total_units_sold
FROM products p
LEFT JOIN order_items oi 
    ON p.product_id = oi.product_id
WHERE p.stock_quantity = 0
GROUP BY 
    p.product_id, 
    p.name, 
    p.category, 
    p.stock_quantity
ORDER BY total_units_sold DESC;


/* ============================================================
   5. CUSTOMER LIFETIME VALUE (CLV) & HIGH-VALUE SEGMENT
   ============================================================ */

SELECT 
    c.customer_id,
    c.name AS customer_name,
    COUNT(DISTINCT o.order_id) AS total_orders_placed,
    ROUND(SUM(o.total_amount), 2) AS lifetime_spend
FROM customers c
INNER JOIN orders o 
    ON c.customer_id = o.customer_id
WHERE o.status != 'Cancelled'
GROUP BY 
    c.customer_id, 
    c.name
ORDER BY lifetime_spend DESC
LIMIT 10;


/* ============================================================
   6. OUTLIER DETECTION: ORDERS EXCEEDING CUSTOMER'S OWN AVERAGE
   ============================================================ */

WITH CustomerSpendProfile AS (
    SELECT 
        order_id,
        customer_id,
        total_amount,
        order_date,
        AVG(total_amount) OVER (
            PARTITION BY customer_id
        ) AS avg_cust_spend
    FROM orders
    WHERE status != 'Cancelled'
)
SELECT 
    order_id,
    customer_id,
    total_amount,
    ROUND(avg_cust_spend, 2) AS customer_avg_order,
    ROUND(total_amount - avg_cust_spend, 2) AS spend_above_average
FROM CustomerSpendProfile
WHERE total_amount > (avg_cust_spend * 1.5)
ORDER BY spend_above_average DESC;


/* ============================================================
   7. TOP-1 HIGHEST VALUE TRANSACTION PER CUSTOMER
   ============================================================ */

WITH RankedCustomerOrders AS (
    SELECT 
        o.order_id,
        o.customer_id,
        c.name AS customer_name,
        o.order_date,
        o.total_amount,
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.total_amount DESC, o.order_id ASC
        ) AS ranking
    FROM orders o
    INNER JOIN customers c 
        ON o.customer_id = c.customer_id
    WHERE o.status != 'Cancelled'
)
SELECT 
    customer_id,
    customer_name,
    order_id AS highest_order_id,
    order_date,
    total_amount AS peak_spend_amount
FROM RankedCustomerOrders
WHERE ranking = 1
ORDER BY peak_spend_amount DESC;


/* ============================================================
   8. ACTIVE VS. DISENGAGED USER BASE ANALYSIS
   ============================================================ */

SELECT 
    COUNT(DISTINCT c.customer_id) AS total_registered_customers,
    COUNT(DISTINCT o.customer_id) AS active_ordering_customers,
    COUNT(DISTINCT c.customer_id) 
        - COUNT(DISTINCT o.customer_id) AS inactive_customers,
    ROUND(
        (COUNT(DISTINCT o.customer_id) * 100.0) 
        / COUNT(DISTINCT c.customer_id), 
        2
    ) AS conversion_rate_pct
FROM customers c
LEFT JOIN orders o 
    ON c.customer_id = o.customer_id;
