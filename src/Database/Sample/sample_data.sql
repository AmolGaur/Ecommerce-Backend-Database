-- Sample data for e-commerce database
-- This script populates the database with realistic test data

-- Insert Categories
INSERT INTO Category (name, slug, description) VALUES
('Electronics', 'electronics', 'Electronic devices and accessories'),
('Clothing', 'clothing', 'Fashion and apparel'),
('Books', 'books', 'Books and publications'),
('Home & Kitchen', 'home-kitchen', 'Home and kitchen appliances');

-- Insert Sub-categories
INSERT INTO Category (parent_id, name, slug, description) VALUES
(1, 'Smartphones', 'smartphones', 'Mobile phones and accessories'),
(1, 'Laptops', 'laptops', 'Laptops and notebooks'),
(2, 'Men''s Wear', 'mens-wear', 'Clothing for men'),
(2, 'Women''s Wear', 'womens-wear', 'Clothing for women');

-- Insert Products
INSERT INTO Product (category_id, SKU, title, slug, description, price, stock, brand) VALUES
(5, 'PHONE001', 'iPhone 13 Pro', 'iphone-13-pro', 'Latest iPhone with pro camera system', 999.99, 50, 'Apple'),
(5, 'PHONE002', 'Samsung Galaxy S21', 'samsung-s21', '5G Smartphone with 8K video', 799.99, 30, 'Samsung'),
(6, 'LAPTOP001', 'MacBook Pro 16', 'macbook-pro-16', '16-inch MacBook Pro with M1 chip', 2399.99, 20, 'Apple'),
(7, 'SHIRT001', 'Classic Cotton Shirt', 'classic-cotton-shirt', 'Men''s formal cotton shirt', 49.99, 100, 'Arrow'),
(8, 'DRESS001', 'Summer Floral Dress', 'summer-floral-dress', 'Women''s casual summer dress', 79.99, 75, 'Zara');

-- Insert Customers
INSERT INTO Customer (first_name, last_name, email, password, age) VALUES
('John', 'Doe', 'john.doe@example.com', crypt('password123', gen_salt('bf')), 30),
('Jane', 'Smith', 'jane.smith@example.com', crypt('password456', gen_salt('bf')), 25),
('Mike', 'Johnson', 'mike.j@example.com', crypt('password789', gen_salt('bf')), 35);

-- Insert Addresses
INSERT INTO Address (customer_id, line1, city, state, country, phone, pincode) VALUES
(1, '123 Main St', 'New York', 'NY', 'USA', '1234567890', '10001'),
(2, '456 Park Ave', 'Los Angeles', 'CA', 'USA', '9876543210', '90001'),
(3, '789 Oak Rd', 'Chicago', 'IL', 'USA', '5555555555', '60601');

-- Insert Orders
INSERT INTO "Order" (customer_id, status, total_price) VALUES
(1, 'delivered', 1049.98),
(2, 'processing', 2399.99),
(3, 'pending', 129.98);

-- Insert Order Items
INSERT INTO Order_Item (order_id, product_id, quantity, unit_price, total_price) VALUES
(1, 1, 1, 999.99, 999.99),
(1, 4, 1, 49.99, 49.99),
(2, 3, 1, 2399.99, 2399.99),
(3, 4, 2, 49.99, 99.98);

-- Insert Reviews
INSERT INTO Review (product_id, customer_id, rating, comment) VALUES
(1, 1, 5, 'Excellent phone, great camera quality!'),
(3, 2, 4, 'Powerful laptop, but a bit expensive'),
(4, 3, 5, 'Perfect fit and comfortable fabric');

-- Insert Cart Items
INSERT INTO Cart (customer_id, product_id, quantity) VALUES
(1, 2, 1),
(2, 5, 2),
(3, 4, 1);

-- Insert Wishlist Items
INSERT INTO Wishlist (customer_id, product_id) VALUES
(1, 3),
(2, 1),
(3, 5);

-- Insert Inventory Logs
INSERT INTO Inventory_Log (product_id, change, change_date) VALUES
(1, -1, CURRENT_TIMESTAMP),
(3, -1, CURRENT_TIMESTAMP),
(4, -2, CURRENT_TIMESTAMP);

-- Insert Alert Logs
INSERT INTO Alert_Log (product_id, alert_message) VALUES
(2, 'Stock below threshold'),
(5, 'Low stock alert');

-- Insert Payment Records
INSERT INTO Payment (payment_date, payment_method, amount, customer_id) VALUES
(CURRENT_TIMESTAMP, 'credit_card', 1049.98, 1),
(CURRENT_TIMESTAMP, 'debit_card', 2399.99, 2),
(CURRENT_TIMESTAMP, 'upi', 129.98, 3);