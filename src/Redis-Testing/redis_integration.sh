#!/bin/bash

# Redis Integration Testing Script for E-commerce Database
# This script tests Redis caching integration with PostgreSQL

# Configuration
REDIS_HOST="localhost"
REDIS_PORT=6379
DB_HOST="localhost"
DB_PORT=5432
DB_NAME="ecommerce"
DB_USER="postgres"
TEST_LOG="redis_test_results.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $TEST_LOG
}

# Function to check if Redis is running
check_redis() {
    log_message "Checking Redis connection..."
    if redis-cli -h $REDIS_HOST -p $REDIS_PORT ping > /dev/null; then
        log_message "${GREEN}Redis connection successful${NC}"
        return 0
    else
        log_message "${RED}Redis connection failed${NC}"
        return 1
    fi
}

# Function to check PostgreSQL connection
check_postgres() {
    log_message "Checking PostgreSQL connection..."
    if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c '\q' > /dev/null 2>&1; then
        log_message "${GREEN}PostgreSQL connection successful${NC}"
        return 0
    else
        log_message "${RED}PostgreSQL connection failed${NC}"
        return 1
    fi
}

# Function to test product caching
test_product_cache() {
    local product_id=$1
    log_message "Testing product caching for ID: $product_id"
    
    # Get product from PostgreSQL
    local start_time=$(date +%s%N)
    local product_data=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT row_to_json(p) FROM product p WHERE product_id = $product_id;")
    local pg_time=$((($(date +%s%N) - $start_time)/1000000))
    
    # Cache in Redis
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SET "product:$product_id" "$product_data" EX 3600
    
    # Get from Redis
    start_time=$(date +%s%N)
    local cached_data=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT GET "product:$product_id")
    local redis_time=$((($(date +%s%N) - $start_time)/1000000))
    
    log_message "PostgreSQL fetch time: ${pg_time}ms"
    log_message "Redis fetch time: ${redis_time}ms"
    log_message "Cache performance improvement: $(( pg_time - redis_time ))ms"
}

# Function to test category caching
test_category_cache() {
    local category_id=$1
    log_message "Testing category products caching for ID: $category_id"
    
    # Get products from PostgreSQL
    local start_time=$(date +%s%N)
    local products_data=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT json_agg(p) FROM product p WHERE category_id = $category_id;")
    local pg_time=$((($(date +%s%N) - $start_time)/1000000))
    
    # Cache in Redis
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SET "category:$category_id:products" "$products_data" EX 3600
    
    # Get from Redis
    start_time=$(date +%s%N)
    local cached_data=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT GET "category:$category_id:products")
    local redis_time=$((($(date +%s%N) - $start_time)/1000000))
    
    log_message "PostgreSQL fetch time: ${pg_time}ms"
    log_message "Redis fetch time: ${redis_time}ms"
    log_message "Cache performance improvement: $(( pg_time - redis_time ))ms"
}

# Function to test cart caching
test_cart_cache() {
    local customer_id=$1
    log_message "Testing cart caching for customer ID: $customer_id"
    
    # Get cart from PostgreSQL
    local start_time=$(date +%s%N)
    local cart_data=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "
        SELECT json_agg(json_build_object(
            'product', p,
            'quantity', c.quantity
        ))
        FROM cart c
        JOIN product p ON c.product_id = p.product_id
        WHERE c.customer_id = $customer_id;")
    local pg_time=$((($(date +%s%N) - $start_time)/1000000))
    
    # Cache in Redis
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SET "cart:$customer_id" "$cart_data" EX 1800
    
    # Get from Redis
    start_time=$(date +%s%