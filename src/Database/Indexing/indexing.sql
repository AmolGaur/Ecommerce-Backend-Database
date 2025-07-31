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

-- Indexes for Product Variants and Bundles
CREATE INDEX IF NOT EXISTS variant_product_idx ON Product_Variant (product_id);
CREATE INDEX IF NOT EXISTS variant_stock_price_idx ON Product_Variant (variant_id, stock, price_adjustment);
CREATE INDEX IF NOT EXISTS variant_attributes_idx ON Product_Variant USING GIN (attributes);
CREATE INDEX IF NOT EXISTS bundle_active_date_idx ON Product_Bundle (valid_from, valid_until) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS bundle_items_idx ON Bundle_Item (bundle_id, product_id);

-- Indexes for Loyalty Program
CREATE INDEX IF NOT EXISTS customer_loyalty_idx ON Customer (loyalty_points DESC, tier_status);
CREATE INDEX IF NOT EXISTS loyalty_transaction_idx ON Loyalty_Transaction (customer_id, transaction_date);
CREATE INDEX IF NOT EXISTS customer_tier_spent_idx ON Customer (tier_status, total_spent);

-- Indexes for Returns Management
CREATE INDEX IF NOT EXISTS return_status_date_idx ON Return (status, requested_at);
CREATE INDEX IF NOT EXISTS return_customer_idx ON Return (customer_id, status);
CREATE INDEX IF NOT EXISTS return_order_idx ON Return (order_id);
CREATE INDEX IF NOT EXISTS return_items_idx ON Return_Item (return_id, product_id);
CREATE INDEX IF NOT EXISTS return_date_range_idx ON Return USING BRIN (requested_at);

-- Indexes for Coupon Management
CREATE INDEX IF NOT EXISTS coupon_code_idx ON Coupon USING hash (code);
CREATE INDEX IF NOT EXISTS coupon_validity_idx ON Coupon (valid_from, valid_until, is_active);
CREATE INDEX IF NOT EXISTS coupon_usage_idx ON Coupon (used_count, usage_limit) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS order_coupon_idx ON "Order" (coupon_code);

-- Hash Indexes for Exact Matches
CREATE INDEX IF NOT EXISTS product_sku_hash_idx ON Product USING hash (SKU);
CREATE INDEX IF NOT EXISTS customer_email_hash_idx ON Customer USING hash (email);
CREATE INDEX IF NOT EXISTS order_tracking_hash_idx ON "Order" USING hash (tracking_number);

-- BRIN Indexes for Large Tables (more efficient for large sequential scans)
CREATE INDEX IF NOT EXISTS order_date_brin_idx ON "Order" USING BRIN (order_date);
CREATE INDEX IF NOT EXISTS inventory_log_date_brin_idx ON Inventory_Log USING BRIN (change_date);
CREATE INDEX IF NOT EXISTS audit_log_date_brin_idx ON Audit_Log USING BRIN (action_time);

-- Indexes for Materialized Views
CREATE UNIQUE INDEX IF NOT EXISTS customer_analytics_id_idx ON customer_analytics (customer_id);
CREATE INDEX IF NOT EXISTS sales_analytics_date_idx ON sales_analytics (sale_date);
CREATE INDEX IF NOT EXISTS product_analytics_id_idx ON product_analytics (product_id);
CREATE INDEX IF NOT EXISTS returns_analytics_id_idx ON returns_analytics (product_id);
CREATE INDEX IF NOT EXISTS variant_analytics_id_idx ON variant_analytics (variant_id);
CREATE INDEX IF NOT EXISTS bundle_analytics_id_idx ON bundle_analytics (bundle_id);

-- Additional Comments
COMMENT ON INDEX variant_product_idx IS 'Optimizes queries joining products with their variants';
COMMENT ON INDEX variant_attributes_idx IS 'Enables efficient search across variant attributes';
COMMENT ON INDEX customer_loyalty_idx IS 'Supports loyalty program queries and tier-based operations';
COMMENT ON INDEX return_status_date_idx IS 'Optimizes return processing and reporting queries';
COMMENT ON INDEX coupon_validity_idx IS 'Supports coupon validation and usage tracking';
COMMENT ON INDEX order_date_brin_idx IS 'Efficient range queries on order dates for large datasets';