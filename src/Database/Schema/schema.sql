-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create custom types for better data integrity
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
CREATE TYPE payment_method AS ENUM ('credit_card', 'debit_card', 'upi', 'net_banking', 'wallet');
CREATE TYPE inventory_action AS ENUM ('increase', 'decrease', 'adjustment');

-- Create partitioned tables for better performance
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
    total_spent DECIMAL(12, 2) DEFAULT 0,
    default_address INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    account_status VARCHAR(20) DEFAULT 'active',
    marketing_preferences JSONB,
    metadata JSONB,
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
) PARTITION BY RANGE (created_at);

-- Create partitions for Customer table
CREATE TABLE customer_y2024 PARTITION OF Customer
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE customer_y2025 PARTITION OF Customer
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Create Address table with enhanced validation
CREATE TABLE Address (
    address_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    line1 VARCHAR(255) NOT NULL,
    line2 VARCHAR(255),
    city VARCHAR(45) NOT NULL,
    state VARCHAR(45) NOT NULL,
    street_name VARCHAR(45),
    country VARCHAR(45) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    pincode VARCHAR(10) NOT NULL,
    is_default BOOLEAN DEFAULT false,
    address_type VARCHAR(20) DEFAULT 'home',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_phone CHECK (phone ~ '^[+]?[0-9]{10,15}$'),
    CONSTRAINT valid_pincode CHECK (pincode ~ '^[0-9]{5,10}$')
);

-- Create Category table with hierarchical structure
CREATE TABLE Category (
    category_id SERIAL PRIMARY KEY,
    parent_id INTEGER REFERENCES Category(category_id),
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Create Product table with enhanced features
CREATE TABLE Product (
    product_id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL,
    SKU VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    short_desc VARCHAR(255),
    price DECIMAL(10, 2) NOT NULL CHECK (price >= 0),
    cost_price DECIMAL(10, 2) CHECK (cost_price >= 0),
    discount_price DECIMAL(10, 2),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    low_stock_threshold INTEGER DEFAULT 10,
    image VARCHAR(255),
    images JSONB,
    weight DECIMAL(8, 2),
    dimensions JSONB,
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    brand VARCHAR(100),
    tags TEXT[],
    attributes JSONB,
    average_rating DECIMAL(3, 2) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB,
    CONSTRAINT valid_prices CHECK (
        (discount_price IS NULL OR discount_price <= price) AND
        (cost_price IS NULL OR cost_price <= price)
    )
);

-- Create partitioned Order table
CREATE TABLE "Order" (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_price DECIMAL(10, 2) DEFAULT 0,
    status order_status DEFAULT 'pending',
