-- Advanced Analytics Views for E-commerce Database

-- Customer Analytics Views
CREATE MATERIALIZED VIEW customer_analytics AS
SELECT 
    c.customer_id,
    c.email,
    c.type AS customer_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(o.total_price), 0) AS total_spent,
    COALESCE(AVG(o.total_price), 0) AS avg_order_value,
    MAX(o.order_date) AS last_order_date,
    COUNT(DISTINCT oi.product_id) AS unique_products_bought,
    CASE 
        WHEN COALESCE(SUM(o.total_price), 0) > 1000 THEN 'VIP'
        WHEN COALESCE(SUM(o.total_price), 0) > 500 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    COALESCE(AVG(r.rating), 0) AS avg_rating_given
FROM 
    Customer c
    LEFT JOIN "Order" o ON c.customer_id = o.customer_id
    LEFT JOIN Order_Item oi ON o.order_id = oi.order_id
    LEFT JOIN Review r ON c.customer_id = r.customer_id
GROUP BY 
    c.customer_id, c.email, c.type
WITH DATA;

-- Sales Performance Analytics
CREATE MATERIALIZED VIEW sales_analytics AS
SELECT 
    DATE_TRUNC('day', o.order_date) AS sale_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_price) AS total_revenue,
    AVG(o.total_price) AS avg_order_value,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * (p.price - COALESCE(p.cost_price, p.price * 0.7))) AS estimated_profit,
    COUNT(DISTINCT p.category_id) AS categories_sold
FROM 
    "Order" o
    JOIN Order_Item oi ON o.order_id = oi.order_id
    JOIN Product p ON oi.product_id = p.product_id
GROUP BY 
    DATE_TRUNC('day', o.order_date)
WITH DATA;

-- Product Performance Analytics
CREATE MATERIALIZED VIEW product_analytics AS
SELECT 
    p.product_id,
    p.title,
    p.category_id,
    c.name AS category_name,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.quantity * oi.price) AS total_revenue,
    AVG(r.rating) AS avg_rating,
    COUNT(r.review_id) AS review_count,
    p.stock AS current_stock,
    CASE 
        WHEN p.stock < p.low_stock_threshold THEN 'Low'
        WHEN p.stock < (p.low_stock_threshold * 2) THEN 'Medium'
        ELSE 'Good'
    END AS stock_status,
    COALESCE(
        SUM(oi.quantity) / NULLIF(EXTRACT(DAYS FROM (NOW() - MIN(o.order_date))), 0),
        0
    ) AS daily_sales_rate
FROM 
    Product p
    LEFT JOIN Category c ON p.category_id = c.category_id
    LEFT JOIN Order_Item oi ON p.product_id = oi.product_id
    LEFT JOIN "Order" o ON oi.order_id = o.order_id
    LEFT JOIN Review r ON p.product_id = r.product_id
GROUP BY 
    p.product_id, p.title, p.category_id, c.name, p.stock, p.low_stock_threshold
WITH DATA;

-- Inventory Analytics
CREATE MATERIALIZED VIEW inventory_analytics AS
SELECT 
    p.product_id,
    p.title,
    p.stock AS current_stock,
    p.low_stock_threshold,
    COUNT(il.log_id) AS stock_updates,
    COALESCE(SUM(il.change), 0) AS total_stock_change,
    MAX(il.change_date) AS last_stock_update,
    COALESCE(AVG(oi.quantity), 0) AS avg_order_quantity,
    COALESCE(
        SUM(CASE 
            WHEN o.order_date >= NOW() - INTERVAL '30 days' 
            THEN oi.quantity 
        END), 0
    ) AS last_30_days_sales,
    CEIL
