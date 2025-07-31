-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create custom types for better data integrity
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
CREATE TYPE payment_method AS ENUM ('credit_card', 'debit_card', 'upi', 'net_banking', 'wallet');
CREATE TYPE inventory_action AS ENUM ('increase', 'decrease', 'adjustment');
CREATE TYPE return_status AS ENUM ('requested', 'approved', 'rejected', 'received', 'refunded');
CREATE TYPE shipping_status AS ENUM ('pending', 'processing', 'shipped', 'delivered', 'failed');
CREATE TYPE coupon_type AS ENUM ('percentage', 'fixed', 'buy_x_get_y', 'free_shipping');

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
    loyalty_points INT DEFAULT 0,
    tier_status VARCHAR(20) DEFAULT 'bronze',
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
    is_billing_address BOOLEAN DEFAULT false,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
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
    image_url TEXT,
    meta_title VARCHAR(255),
    meta_description TEXT,
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
    is_digital BOOLEAN DEFAULT false,
    brand VARCHAR(100),
    tags TEXT[],
    attributes JSONB,
    average_rating DECIMAL(3, 2) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    meta_title VARCHAR(255),
    meta_description TEXT,
    warranty_info TEXT,
    status order_status DEFAULT 'pending',
    shipping_address_id INTEGER REFERENCES Address(address_id),
    billing_address_id INTEGER REFERENCES Address(address_id),
    shipping_method VARCHAR(50),
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    tax_amount DECIMAL(10, 2) DEFAULT 0,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    coupon_code VARCHAR(50),
    notes TEXT,
    estimated_delivery TIMESTAMP,
    tracking_number VARCHAR(100),
    shipping_status shipping_status DEFAULT 'pending',
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Product Variants table
CREATE TABLE Product_Variant (
    variant_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES Product(product_id),
    SKU VARCHAR(100) UNIQUE NOT NULL,
    variant_name VARCHAR(255) NOT NULL,
    attributes JSONB NOT NULL,
    price_adjustment DECIMAL(10, 2) DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    weight DECIMAL(8, 2),
    dimensions JSONB,
    images JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Product Bundles table
CREATE TABLE Product_Bundle (
    bundle_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    discount_percentage DECIMAL(5, 2),
    is_active BOOLEAN DEFAULT true,
    valid_from TIMESTAMP,
    valid_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Bundle Items table
CREATE TABLE Bundle_Item (
    bundle_id INTEGER REFERENCES Product_Bundle(bundle_id),
    product_id INTEGER REFERENCES Product(product_id),
    quantity INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (bundle_id, product_id)
);

-- Create Coupons table
CREATE TABLE Coupon (
    coupon_id SERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    type coupon_type NOT NULL,
    value DECIMAL(10, 2) NOT NULL,
    min_purchase_amount DECIMAL(10, 2),
    max_discount_amount DECIMAL(10, 2),
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP NOT NULL,
    usage_limit INTEGER,
    used_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    applies_to JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Returns table
CREATE TABLE Return (
    return_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES "Order"(order_id),
    customer_id INTEGER REFERENCES Customer(customer_id),
    status return_status DEFAULT 'requested',
    reason TEXT NOT NULL,
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP,
    received_at TIMESTAMP,
    refunded_at TIMESTAMP,
    refund_amount DECIMAL(10, 2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Return Items table
CREATE TABLE Return_Item (
    return_id INTEGER REFERENCES Return(return_id),
    product_id INTEGER REFERENCES Product(product_id),
    quantity INTEGER NOT NULL,
    reason TEXT,
    condition_notes TEXT,
    PRIMARY KEY (return_id, product_id)
);
    return_policy TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB,
    CONSTRAINT valid_prices CHECK (
        (discount_price IS NULL OR discount_price <= price) AND
        (cost_price IS NULL OR cost_price <= price)
    )
);

-- Create Product Variants table
CREATE TABLE Product_Variant (
    variant_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES Product(product_id),
    SKU VARCHAR(100) UNIQUE NOT NULL,
    variant_name VARCHAR(255) NOT NULL,
    attributes JSONB NOT NULL,
    price_adjustment DECIMAL(10, 2) DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    weight DECIMAL(8, 2),
    dimensions JSONB,
    images JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Product Bundles table
CREATE TABLE Product_Bundle (
    bundle_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    discount_percentage DECIMAL(5, 2),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
