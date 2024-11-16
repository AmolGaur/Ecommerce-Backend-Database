-- Step 1: Create Tables Without Foreign Keys

-- Customer table, storing customer details with a reference to the default address
-- Modify Customer table to store hashed passwords in BYTEA format
CREATE TABLE Customer (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role INT DEFAULT 555,
    age INT DEFAULT 18 CHECK (age >= 18),
    photoUrl TEXT,
    type VARCHAR(255) DEFAULT 'local',
    total_spent DECIMAL(12, 2) DEFAULT 0, -- Tracks cumulative spending by the customer
    default_address INTEGER
);

-- Address table, storing customer addresses
CREATE TABLE Address (
    address_id SERIAL PRIMARY KEY,
    line1 VARCHAR(255),
    line2 VARCHAR(255),
    city VARCHAR(45),
    state VARCHAR(45),
    street_name VARCHAR(45),
    country VARCHAR(45),
    phone VARCHAR(10),
    pincode INT,
    customer_id INTEGER NOT NULL
);

-- Shipment table, storing shipment details associated with customers
CREATE TABLE Shipment (
    shipment_id SERIAL PRIMARY KEY,
    shipment_date TIMESTAMP NOT NULL,
    address VARCHAR(100),
    city VARCHAR(20),
    state VARCHAR(100),
    country VARCHAR(50),
    zip_code VARCHAR(10),
    customer_id INTEGER NOT NULL
);

-- Cart table, managing customer carts with product quantities
CREATE TABLE Cart (
    cart_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0)
);

-- Wishlist table, managing customer wishlists
CREATE TABLE Wishlist (
    wishlist_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL
);

-- Payment table, storing payment details associated with orders
CREATE TABLE Payment (
    payment_id SERIAL PRIMARY KEY,
    payment_date TIMESTAMP NOT NULL,
    payment_method VARCHAR(100) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount >= 0),
    customer_id INTEGER NOT NULL
);

-- Order table, managing customer orders
CREATE TABLE "Order" (
    order_id SERIAL PRIMARY KEY,
    order_date TIMESTAMP NOT NULL,
    total_price DECIMAL(10, 2) DEFAULT 0,
    customer_id INTEGER NOT NULL
);

-- Order_Item table, managing individual items within an order
CREATE TABLE Order_Item (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    price DECIMAL(10, 2) NOT NULL,
    product_snapshot JSONB
);

-- Product table, managing product details
CREATE TABLE Product (
    product_id SERIAL PRIMARY KEY,
    SKU VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    image VARCHAR(255),
    images TEXT,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock INTEGER NOT NULL CHECK (stock >= 0),
    short_desc VARCHAR(255),
    category_id INTEGER,
    average_rating DECIMAL(3, 2) DEFAULT 0 -- Column to store average rating
);

-- Category table, managing product categories
CREATE TABLE Category (
    category_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- Review table, storing product reviews from customers
CREATE TABLE Review (
    review_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    review_date TIMESTAMP DEFAULT NOW()
);

-- Inventory_Log table, tracking inventory changes over time
CREATE TABLE Inventory_Log (
    log_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    change INT NOT NULL,
    change_date TIMESTAMP DEFAULT NOW()
);

-- Alert_Log table, for low stock notifications
CREATE TABLE Alert_Log (
    alert_id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    alert_message TEXT,
    alert_date TIMESTAMP DEFAULT NOW()
);

-- Step 2: Add Foreign Key Constraints

-- Add foreign key constraints to Customer and Address tables
ALTER TABLE Customer
ADD FOREIGN KEY (default_address) REFERENCES Address(address_id) ON DELETE SET NULL;

ALTER TABLE Address
ADD FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE ON UPDATE CASCADE;

-- Add foreign key constraints to Shipment table
ALTER TABLE Shipment
ADD FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE ON UPDATE CASCADE;

-- Add foreign key constraints to Cart and Wishlist tables
ALTER TABLE Cart
ADD FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE,
ADD FOREIGN KEY (product_id) REFERENCES Product(product_id) ON DELETE CASCADE;

ALTER TABLE Wishlist
ADD FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE,
ADD FOREIGN KEY (product_id) REFERENCES Product(product_id) ON DELETE CASCADE;

-- Add foreign key constraints to Payment table
ALTER TABLE Payment
ADD FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE;

-- Add foreign key constraints to Order and Order_Item tables
ALTER TABLE "Order"
ADD FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE;

ALTER TABLE Order_Item
ADD FOREIGN KEY (order_id) REFERENCES "Order"(order_id) ON DELETE CASCADE,
ADD FOREIGN KEY (product_id) REFERENCES Product(product_id) ON DELETE CASCADE;

-- Add foreign key constraint to Product table
ALTER TABLE Product
ADD FOREIGN KEY (category_id) REFERENCES Category(category_id) ON DELETE SET NULL;

-- Add foreign key constraints to Review table
ALTER TABLE Review
ADD FOREIGN KEY (product_id) REFERENCES Product(product_id) ON DELETE CASCADE,
ADD FOREIGN KEY (customer_id) REFERENCES Customer(customer_id) ON DELETE CASCADE;

-- Add foreign key constraint to Inventory_Log table
ALTER TABLE Inventory_Log
ADD FOREIGN KEY (product_id) REFERENCES Product(product_id) ON DELETE CASCADE;

-- Add foreign key constraint to Alert_Log table
ALTER TABLE Alert_Log
ADD FOREIGN KEY (product_id) REFERENCES Product(product_id) ON DELETE CASCADE;


-- Enable pgcrypto extension to allow encryption functions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Modify Customer table to store hashed passwords in BYTEA format
-- Add encrypted payment method column in Payment table
ALTER TABLE Payment
ADD COLUMN encrypted_payment_method VARCHAR(255);

-- Example usage: Insert an encrypted payment method (replace 'encryption_key' with an actual secure key)
-- INSERT INTO Payment (encrypted_payment_method) VALUES (pgp_sym_encrypt('credit_card', 'encryption_key'));

-- Modify the Customer table to add a CHECK constraint for email format
ALTER TABLE Customer
ADD CONSTRAINT email_format_check 
CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Modify the Address table to add a CHECK constraint for phone number format
ALTER TABLE Address
ADD CONSTRAINT phone_format_check 
CHECK (phone ~ '^[0-9]{10}$');

