-- Materialized view for daily revenue summaries
CREATE MATERIALIZED VIEW daily_sales_summary AS
SELECT 
    DATE_TRUNC('day', order_date) AS day,
    SUM(total_price) AS daily_revenue
FROM "Order"
GROUP BY day
ORDER BY day;

-- Materialized view for monthly revenue summaries
CREATE MATERIALIZED VIEW monthly_revenue_summary AS
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    SUM(total_price) AS monthly_revenue
FROM "Order"
GROUP BY month
ORDER BY month;

-- Materialized view for popular product categories
CREATE MATERIALIZED VIEW popular_categories AS
SELECT 
    Product.category_id,
    Category.name AS category_name,
    COUNT(Order_Item.product_id) AS product_sales_count
FROM Order_Item
JOIN Product ON Order_Item.product_id = Product.product_id
JOIN Category ON Product.category_id = Category.category_id
GROUP BY Product.category_id, Category.name
ORDER BY product_sales_count DESC;

-- Materialized view for top-selling products summary
CREATE MATERIALIZED VIEW top_selling_products_summary AS
SELECT 
    Order_Item.product_id,
    Product.title,
    SUM(Order_Item.quantity) AS total_quantity_sold
FROM Order_Item
JOIN Product ON Order_Item.product_id = Product.product_id
GROUP BY Order_Item.product_id, Product.title
ORDER BY total_quantity_sold DESC;

-- Materialized view for product popularity trends over time
CREATE MATERIALIZED VIEW product_popularity_trends AS
SELECT 
    Product.product_id,
    Product.title,
    DATE_TRUNC('month', "Order".order_date) AS month,
    SUM(Order_Item.quantity) AS quantity_sold
FROM Order_Item
JOIN Product ON Order_Item.product_id = Product.product_id
JOIN "Order" ON Order_Item.order_id = "Order".order_id
GROUP BY Product.product_id, Product.title, month
ORDER BY month, quantity_sold DESC;

-- View for filtering products by category
CREATE VIEW products_by_category AS
SELECT 
    product_id, 
    title, 
    description, 
    price, 
    average_rating, 
    category_id 
FROM Product
WHERE category_id IS NOT NULL;

-- View for filtering products by price range
CREATE VIEW products_by_price_range AS
SELECT 
    product_id, 
    title, 
    description, 
    price, 
    average_rating, 
    category_id 
FROM Product
WHERE price BETWEEN 10 AND 100;  -- Replace with dynamic range as needed

-- View for filtering products by rating
CREATE VIEW products_by_rating AS
SELECT 
    product_id, 
    title, 
    description, 
    price, 
    average_rating, 
    category_id 
FROM Product
WHERE average_rating >= 4;  -- Replace with desired minimum rating

-- Materialized view for frequently accessed top-rated products
CREATE MATERIALIZED VIEW top_rated_products AS
SELECT 
    product_id, 
    title, 
    description, 
    price, 
    average_rating, 
    category_id 
FROM Product
WHERE average_rating >= 4
ORDER BY average_rating DESC;
