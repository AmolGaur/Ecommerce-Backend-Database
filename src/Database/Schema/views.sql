-- Advanced Analytics Views for E-commerce Database

-- Customer Analytics Views
CREATE MATERIALIZED VIEW customer_analytics AS
SELECT 
    c.customer_id,
    c.email,
    c.type AS customer_type,
    c.tier_status,
    c.loyalty_points,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COALESCE(SUM(o.total_price), 0) AS total_spent,
    COALESCE(AVG(o.total_price), 0) AS avg_order_value,
    MAX(o.order_date) AS last_order_date,
    COUNT(DISTINCT oi.product_id) AS unique_products_bought,
    CASE 
        WHEN c.tier_status = 'platinum' THEN 'VIP'
        WHEN c.tier_status = 'gold' THEN 'Premium'
        WHEN c.tier_status = 'silver' THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    COALESCE(AVG(r.rating), 0) AS avg_rating_given,
    COUNT(DISTINCT ret.return_id) AS total_returns,
    COALESCE(SUM(ret.refund_amount), 0) AS total_refunded
FROM 
    Customer c
    LEFT JOIN "Order" o ON c.customer_id = o.customer_id
    LEFT JOIN Order_Item oi ON o.order_id = oi.order_id
    LEFT JOIN Review r ON c.customer_id = r.customer_id
    LEFT JOIN Return ret ON c.customer_id = ret.customer_id
GROUP BY 
    c.customer_id, c.email, c.type, c.tier_status, c.loyalty_points
WITH DATA;

-- Sales Performance Analytics
CREATE MATERIALIZED VIEW sales_analytics AS
SELECT 
    DATE_TRUNC('day', o.order_date) AS sale_date,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_price) AS total_revenue,
    SUM(o.discount_amount) AS total_discounts,
    SUM(o.shipping_cost) AS total_shipping,
    AVG(o.total_price) AS avg_order_value,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * (p.price - COALESCE(p.cost_price, p.price * 0.7))) AS estimated_profit,
    COUNT(DISTINCT p.category_id) AS categories_sold,
    COUNT(DISTINCT CASE WHEN o.coupon_code IS NOT NULL THEN o.order_id END) AS orders_with_coupon,
    COUNT(DISTINCT CASE WHEN pv.variant_id IS NOT NULL THEN o.order_id END) AS orders_with_variants
FROM 
    "Order" o
    JOIN Order_Item oi ON o.order_id = oi.order_id
    JOIN Product p ON oi.product_id = p.product_id
    LEFT JOIN Product_Variant pv ON oi.variant_id = pv.variant_id
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
    COUNT(DISTINCT pv.variant_id) AS variant_count,
    COUNT(DISTINCT pb.bundle_id) AS bundle_appearances,
    COUNT(DISTINCT ret.return_id) AS return_count,
    COALESCE(
        COUNT(DISTINCT ret.return_id)::FLOAT / NULLIF(COUNT(DISTINCT oi.order_id), 0) * 100,
        0
    ) AS return_rate,
    CASE 
        WHEN p.stock < p.low_stock_threshold THEN 'Low'
        WHEN p.stock < (p.low_stock_threshold * 2) THEN 'Medium'
        ELSE 'Good'
    END AS stock_status,
    COALESCE(
        SUM(oi.quantity) / NULLIF(EXTRACT(DAYS FROM (NOW() - MIN(o.order_date))), 0

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

-- Returns Analytics
CREATE MATERIALIZED VIEW returns_analytics AS
SELECT 
    p.product_id,
    p.title,
    c.category_id,
    c.name AS category_name,
    COUNT(DISTINCT r.return_id) AS total_returns,
    COUNT(DISTINCT r.return_id)::FLOAT / NULLIF(COUNT(DISTINCT oi.order_id), 0) * 100 AS return_rate,
    SUM(r.refund_amount) AS total_refunded,
    AVG(r.refund_amount) AS avg_refund_amount,
    STRING_AGG(DISTINCT ri.reason, ', ') AS common_reasons,
    COUNT(CASE WHEN r.status = 'approved' THEN 1 END) AS approved_returns,
    COUNT(CASE WHEN r.status = 'rejected' THEN 1 END) AS rejected_returns,
    AVG(EXTRACT(EPOCH FROM (r.refunded_at - r.requested_at))/86400) AS avg_processing_days
FROM 
    Product p
    LEFT JOIN Category c ON p.category_id = c.category_id
    LEFT JOIN Order_Item oi ON p.product_id = oi.product_id
    LEFT JOIN Return_Item ri ON p.product_id = ri.product_id
    LEFT JOIN Return r ON ri.return_id = r.return_id
GROUP BY 
    p.product_id, p.title, c.category_id, c.name
WITH DATA;

-- Coupon Performance Analytics
CREATE MATERIALIZED VIEW coupon_analytics AS
SELECT 
    c.coupon_id,
    c.code,
    c.type,
    c.value,
    c.valid_from,
    c.valid_until,
    COUNT(DISTINCT o.order_id) AS times_used,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_price + o.discount_amount) AS gross_sales,
    SUM(o.discount_amount) AS total_discount,
    AVG(o.discount_amount) AS avg_discount,
    SUM(o.total_price) AS net_sales,
    CASE 
        WHEN c.type = 'percentage' 
        THEN ROUND(SUM(o.discount_amount) / NULLIF(SUM(o.total_price + o.discount_amount), 0) * 100, 2)
        ELSE NULL
    END AS effective_discount_percentage,
    ROUND(COUNT(DISTINCT o.order_id)::FLOAT / NULLIF(c.usage_limit, 0) * 100, 2) AS usage_rate
FROM 
WITH DATA;

-- Product Variants Analytics
CREATE MATERIALIZED VIEW variant_analytics AS
SELECT 
    p.product_id,
    p.title AS base_product,
    pv.variant_id,
    pv.variant_name,
    pv.attributes,
    COUNT(DISTINCT oi.order_id) AS orders_count,
    SUM(oi.quantity) AS total_quantity_sold,
    SUM(oi.quantity * (p.price + pv.price_adjustment)) AS total_revenue,
    pv.stock AS current_stock,
    CASE 
        WHEN pv.stock < 5 THEN 'Critical'
        WHEN pv.stock < 10 THEN 'Low'
        WHEN pv.stock < 20 THEN 'Medium'
        ELSE 'Good'
    END AS stock_status,
    COALESCE(
        SUM(oi.quantity) / NULLIF(EXTRACT(DAYS FROM (NOW() - MIN(o.order_date))), 0),
        0
    ) AS daily_sales_rate
FROM 
    Product p
    JOIN Product_Variant pv ON p.product_id = pv.product_id
    LEFT JOIN Order_Item oi ON pv.variant_id = oi.variant_id
    LEFT JOIN "Order" o ON oi.order_id = o.order_id
GROUP BY 
    p.product_id, p.title, pv.variant_id, pv.variant_name, pv.attributes, pv.stock
WITH DATA;

-- Bundle Performance Analytics
CREATE MATERIALIZED VIEW bundle_analytics AS
SELECT 
    pb.bundle_id,
    pb.name AS bundle_name,
    pb.discount_percentage,
    COUNT(DISTINCT o.order_id) AS times_purchased,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    SUM(o.total_price) AS total_revenue,
    AVG(o.total_price) AS avg_bundle_price,
    STRING_AGG(DISTINCT p.title, ', ') AS products_in_bundle,
    COUNT(DISTINCT p.product_id) AS product_count,
    SUM(bi.quantity) AS total_units_sold,
    CASE 
        WHEN pb.valid_until < NOW() THEN 'Expired'
        WHEN pb.valid_until < NOW() + INTERVAL '7 days' THEN 'Expiring Soon'
        ELSE 'Active'
    END AS bundle_status,
    COALESCE(
        COUNT(DISTINCT o.order_id)::FLOAT / 
        NULLIF(EXTRACT(DAYS FROM (NOW() - pb.valid_from)), 0),
        0
    ) AS daily_purchase_rate
FROM 
    Product_Bundle pb
    JOIN Bundle_Item bi ON pb.bundle_id = bi.bundle_id
    JOIN Product p ON bi.product_id = p.product_id
    LEFT JOIN Order_Item oi ON p.product_id = oi.product_id
    LEFT JOIN "Order" o ON oi.order_id = o.order_id
WHERE 
    o.order_date BETWEEN pb.valid_from AND COALESCE(pb.valid_until, NOW())
GROUP BY 
    pb.bundle_id, pb.name, pb.discount_percentage, pb.valid_from, pb.valid_until
WITH DATA;

-- Create indexes for materialized views
CREATE INDEX idx_customer_analytics_customer_id ON customer_analytics(customer_id);
CREATE INDEX idx_sales_analytics_sale_date ON sales_analytics(sale_date);
CREATE INDEX idx_product_analytics_product_id ON product_analytics(product_id);
CREATE INDEX idx_returns_analytics_product_id ON returns_analytics(product_id);
CREATE INDEX idx_coupon_analytics_coupon_id ON coupon_analytics(coupon_id);
CREATE INDEX idx_variant_analytics_variant_id ON variant_analytics(variant_id);
CREATE INDEX idx_bundle_analytics_bundle_id ON bundle_analytics(bundle_id);
    Coupon c
    LEFT JOIN "Order" o ON c.code = o.coupon_code
GROUP BY 
    c.coupon_id, c.code, c.type, c.value, c.valid_from, c.valid_until, c.usage_limit
WITH DATA;
