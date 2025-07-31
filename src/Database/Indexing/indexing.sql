-- Basic Indexes for Primary Query Patterns
CREATE INDEX IF NOT EXISTS product_sku_idx ON Product (SKU);
CREATE INDEX IF NOT EXISTS order_date_idx ON "Order" (order_date);
CREATE INDEX IF NOT EXISTS order_customer_idx ON "Order" (customer_id);
CREATE INDEX IF NOT EXISTS order_item_product_order_idx ON Order_Item (product_id, order_id);

-- Composite Indexes for Join Optimization
CREATE INDEX IF NOT EXISTS product_stock_price_idx ON Product (product_id, stock, price);
CREATE INDEX IF NOT EXISTS order_customer_date_idx ON "Order" (customer_id, order_date);
CREATE INDEX IF NOT EXISTS order_item_quantity_idx ON Order_Item (order_id, product_id, quantity);

-- Full Text Search Indexes
CREATE INDEX IF NOT EXISTS product_title_description_idx ON Product USING GIN (to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(description, '')));
CREATE INDEX IF NOT EXISTS product_title_idx ON Product USING GIN (to_tsvector('english', title));

-- Partial Indexes for Common Filters
CREATE INDEX IF NOT EXISTS low_stock_idx ON Product (product_id) WHERE stock < 10;
CREATE INDEX IF NOT EXISTS active_cart_idx ON Cart (customer_id, product_id) WHERE quantity > 0;
CREATE INDEX IF NOT EXISTS high_value_orders_idx ON "Order" (order_date, total_price) WHERE total_price > 1000;

-- Indexes for Analytics Queries
CREATE INDEX IF NOT EXISTS order_date_total_idx ON "Order" (order_date, total_price);
CREATE INDEX IF NOT EXISTS product_category_price_idx ON Product (category_id, price);
CREATE INDEX IF NOT EXISTS review_product_rating_idx ON Review (product_id, rating);

-- Indexes for Time-Series Analysis
CREATE INDEX IF NOT EXISTS order_date_trunc_idx ON "Order" (DATE_TRUNC('month', order_date));
CREATE INDEX IF NOT EXISTS inventory_log_date_idx ON Inventory_Log (change_date, product_id);

-- Indexes for Customer Analysis
CREATE INDEX IF NOT EXISTS customer_total_spent_idx ON Customer (total_spent DESC);
CREATE INDEX IF NOT EXISTS customer_type_idx ON Customer (type);

-- Specialized Indexes for Inventory Management
CREATE INDEX IF NOT EXISTS inventory_product_change_idx ON Inventory_Log (product_id, change);
CREATE INDEX IF NOT EXISTS alert_product_date_idx ON Alert_Log (product_id, alert_date);

-- B-tree Indexes for Range Queries
CREATE INDEX IF NOT EXISTS product_price_range_idx ON Product USING btree (price);
CREATE INDEX IF NOT EXISTS product_stock_range_idx ON Product USING btree (stock);

-- Comment explaining index usage
COMMENT ON INDEX product_stock_price_idx IS 'Optimizes order processing queries checking stock and price';
COMMENT ON INDEX order_date_total_idx IS 'Supports revenue analysis and reporting queries';
COMMENT ON INDEX low_stock_idx IS 'Efficient filtering of products needing restock';
COMMENT ON INDEX customer_total_spent_idx IS 'Supports customer segmentation and loyalty analysis';