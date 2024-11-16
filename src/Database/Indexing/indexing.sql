-- Index on Product.SKU for faster SKU-based product searches
CREATE INDEX product_sku_idx ON Product (SKU);

-- Full-text index on Product.description for optimized keyword-based product searches
CREATE INDEX product_description_fulltext_idx ON Product USING GIN (to_tsvector('english', description));

-- Index on Order.order_date to optimize date-based filtering and grouping in revenue reports
CREATE INDEX order_date_idx ON "Order" (order_date);

-- Index on Order.customer_id for faster retrieval of order history by customer
CREATE INDEX order_customer_idx ON "Order" (customer_id);

-- Compound index on Order_Item.product_id and Order_Item.order_id for join optimization in product-based sales analysis
CREATE INDEX order_item_product_order_idx ON Order_Item (product_id, order_id);

-- Partial Index on Cart table for active cart entries filtering
CREATE INDEX active_cart_idx ON Cart (customer_id) WHERE quantity > 0;

-- Partial Index on Wishlist table for active wishlist entries filtering
CREATE INDEX active_wishlist_idx ON Wishlist (customer_id) WHERE product_id IS NOT NULL;

-- Full-text search index on product title and description
CREATE INDEX product_full_text_idx 
ON Product 
USING GIN (to_tsvector('english', title || ' ' || description));

-- Index on category_id for filtering by category
CREATE INDEX idx_product_category_id ON Product (category_id);

-- Index on price for efficient range filtering
CREATE INDEX idx_product_price ON Product (price);

-- Index on average_rating for filtering by rating
CREATE INDEX idx_product_rating ON Product (average_rating);


x