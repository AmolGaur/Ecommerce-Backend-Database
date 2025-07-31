#!/bin/bash

# Redis Integration Testing Script for E-commerce Database
# This script implements advanced Redis caching patterns and features

# Configuration
REDIS_HOST="localhost"
REDIS_PORT=6379
DB_HOST="localhost"
DB_PORT=5432
DB_NAME="ecommerce"
DB_USER="postgres"
TEST_LOG="redis_test_results.log"
REDIS_CHANNEL="cache_updates"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $TEST_LOG
}

# Function to check Redis connection
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

# Cache-Aside Pattern Implementation
get_product_cache_aside() {
    local product_id=$1
    local cache_key="product:$product_id"
    
    # Try cache first
    local cached_data=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT GET "$cache_key")
    
    if [ -n "$cached_data" ]; then
        echo "$cached_data"
        return 0
    fi
    
    # Cache miss - get from DB and cache
    local product_data=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c \
        "SELECT row_to_json(p) FROM product p WHERE product_id = $product_id;")
    
    if [ -n "$product_data" ]; then
        redis-cli -h $REDIS_HOST -p $REDIS_PORT SET "$cache_key" "$product_data" EX 3600
        echo "$product_data"
    fi
}

# Write-Through Pattern Implementation
update_product_write_through() {
    local product_id=$1
    local new_data=$2
    
    # Update DB first
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c \
        "UPDATE product SET $new_data WHERE product_id = $product_id;"
    
    # Then update cache
    local updated_data=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c \
        "SELECT row_to_json(p) FROM product p WHERE product_id = $product_id;")
    
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SET "product:$product_id" "$updated_data" EX 3600
    
    # Publish update event
    redis-cli -h $REDIS_HOST -p $REDIS_PORT PUBLISH "$REDIS_CHANNEL" \
        "{\"type\":\"product_update\",\"id\":$product_id}"
}

# Rate Limiting Implementation
check_rate_limit() {
    local user_id=$1
    local limit=100
    local window=3600
    local current_time=$(date +%s)
    local key="ratelimit:$user_id"
    
    # Check current count
    local count=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT GET "$key")
    if [ -z "$count" ]; then
        redis-cli -h $REDIS_HOST -p $REDIS_PORT SETEX "$key" $window 1
        return 0
    elif [ "$count" -lt "$limit" ]; then
        redis-cli -h $REDIS_HOST -p $REDIS_PORT INCR "$key"
        return 0
    else
        return 1
    fi
}

# Session Management
manage_user_session() {
    local user_id=$1
    local session_data=$2
    local session_key="session:$user_id"
    
    # Store session with 30-minute expiry
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SETEX "$session_key" 1800 "$session_data"
    
    # Track active sessions
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SADD "active_sessions" "$user_id"
}

# Leaderboard Implementation
update_leaderboard() {
    local user_id=$1
    local score=$2
    
    redis-cli -h $REDIS_HOST -p $REDIS_PORT ZADD "user_leaderboard" "$score" "$user_id"
}

get_leaderboard() {
    local start=$1
    local end=$2
    
    redis-cli -h $REDIS_HOST -p $REDIS_PORT ZREVRANGE "user_leaderboard" "$start" "$end" WITHSCORES
}

# Search Suggestions Implementation
add_search_suggestion() {
    local term=$1
    
    redis-cli -h $REDIS_HOST -p $REDIS_PORT ZADD "search_suggestions" 1 "$term" INCR
}

get_search_suggestions() {
    local prefix=$1
    local count=$2
    
    redis-cli -h $REDIS_HOST -p $REDIS_PORT ZRANGEBYLEX "search_suggestions" "[$prefix" "[$prefix\xff" LIMIT 0 "$count"
}

# Cache Invalidation
invalidate_product_cache() {
    local product_id=$1
    
    redis-cli -h $REDIS_HOST -p $REDIS_PORT DEL "product:$product_id"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT PUBLISH "$REDIS_CHANNEL" \
        "{\"type\":\"cache_invalidation\",\"key\":\"product:$product_id\"}"
}

# Monitor Cache Hit/Miss Ratio
monitor_cache_performance() {
    local hits=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT PFCOUNT "cache_hits")
    local misses=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT PFCOUNT "cache_misses")
    local total=$((hits + misses))
    
    if [ "$total" -gt 0 ]; then
        local ratio=$(echo "scale=2; $hits * 100 / $total" | bc)
        log_message "Cache Hit Ratio: ${ratio
}%"
        log_message "Total requests: $total"
        log_message "Cache hits: $hits"
        log_message "Cache misses: $misses"
        log_message "Hit ratio: ${ratio}%"
    fi
}

# Function to test product variant caching
test_variant_cache() {
    local product_id=$1
    log_message "Testing product variant caching for product ID: $product_id"
    
    # Get variants from PostgreSQL
    local start_time=$(date +%s%N)
    local variants_data=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c \
        "SELECT json_agg(v) FROM product_variant v WHERE product_id = $product_id;")
    local pg_time=$((($(date +%s%N) - $start_time)/1000000))
    
    # Cache in Redis
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SET "product:$product_id:variants" "$variants_data" EX 3600
    
    # Get from Redis
    start_time=$(date +%s%N)
    local cached_data=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT GET "product:$product_id:variants")
    local redis_time=$((($(date +%s%N) - $start_time)/1000000))
    
    log_message "PostgreSQL fetch time: ${pg_time}ms"
    log_message "Redis fetch time: ${redis_time}ms"
    log_message "Cache performance improvement: $(( pg_time - redis_time ))ms"
}

# Function to test bundle caching
test_bundle_cache() {
    local bundle_id=$1
    log_message "Testing bundle caching for bundle ID: $bundle_id"
    
    # Get bundle data from PostgreSQL
    local start_time=$(date +%s%N)
    local bundle_data=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c \
        "SELECT json_build_object(
            'bundle', b,
            'products', (
                SELECT json_agg(p) FROM product p
                JOIN bundle_item bi ON p.product_id = bi.product_id
                WHERE bi.bundle_id = b.bundle_id
            )
        ) FROM product_bundle b WHERE b.bundle_id = $bundle_id;")
    local pg_time=$((($(date +%s%N) - $start_time)/1000000))
    
    # Cache in Redis
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SET "bundle:$bundle_id" "$bundle_data" EX 3600
    
    # Get from Redis
    start_time=$(date +%s%N)
    local cached_data=$(redis-cli -h $REDIS_HOST -p $REDIS_PORT GET "bundle:$bundle_id")
    local redis_time=$((($(date +%s%N) - $start_time)/1000000))
    
    log_message "PostgreSQL fetch time: ${pg_time}ms"
    log_message "Redis fetch time: ${redis_time}ms"
    log_message "Cache performance improvement: $(( pg_time - redis_time ))ms"
}

# Main test execution
main() {
    log_message "Starting Redis integration tests..."
    
    # Check connections
    check_redis || exit 1
    check_postgres || exit 1
    
    # Test cache-aside pattern
    log_message "${YELLOW}Testing Cache-Aside Pattern${NC}"
    get_product_cache_aside 1
    
    # Test write-through pattern
    log_message "${YELLOW}Testing Write-Through Pattern${NC}"
    update_product_write_through 1 "stock = stock - 1"
    
    # Test rate limiting
    log_message "${YELLOW}Testing Rate Limiting${NC}"
    check_rate_limit 1
    
    # Test session management
    log_message "${YELLOW}Testing Session Management${NC}"
    manage_user_session 1 '{"last_access": "'$(date -u +"%Y-%m-%dT%H:%M:%S
Z")'}"}'

    # Test leaderboard functionality
    log_message "${YELLOW}Testing Leaderboard${NC}"
    update_leaderboard 1 100
    update_leaderboard 2 150
    update_leaderboard 3 75
    get_leaderboard 0 2

    # Test search suggestions
    log_message "${YELLOW}Testing Search Suggestions${NC}"
    add_search_suggestion "iphone"
    add_search_suggestion "iphone pro"
    add_search_suggestion "iphone case"
    get_search_suggestions "iphone" 5

    # Test product caching
    log_message "${YELLOW}Testing Product Caching${NC}"
    test_product_cache 1
    test_product_cache 2

    # Test category caching
    log_message "${YELLOW}Testing Category Caching${NC}"
    test_category_cache 1
    test_category_cache 2

    # Test cart caching
    log_message "${YELLOW}Testing Cart Caching${NC}"
    test_cart_cache 1
    test_cart_cache 2

    # Test variant caching
    log_message "${YELLOW}Testing Variant Caching${NC}"
    test_variant_cache 1
    test_variant_cache 2

    # Test bundle caching
    log_message "${YELLOW}Testing Bundle Caching${NC}"
    test_bundle_cache 1
    test_bundle_cache 2

    # Test cache invalidation
    log_message "${YELLOW}Testing Cache Invalidation${NC}"
    invalidate_product_cache 1

    # Monitor cache performance
    log_message "${YELLOW}Monitoring Cache Performance${NC}"
    monitor_cache_performance

    log_message "${GREEN}Redis integration tests completed${NC}"
}

# Start Redis subscriber in background for real-time updates
redis_subscriber() {
    redis-cli -h $REDIS_HOST -p $REDIS_PORT SUBSCRIBE "$REDIS_CHANNEL" | while read -r line; do
        if [[ $line == *"cache_invalidation"* ]]; then
            log_message "Received cache invalidation event: $line"
        elif [[ $line == *"product_update"* ]]; then
            log_message "Received product update event: $line"
        fi
    done
}

# Error handling function
handle_error() {
    local error_message=$1
    log_message "${RED}Error: $error_message${NC}"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT INCR "error_count"
    redis-cli -h $REDIS_HOST -p $REDIS_PORT LPUSH "error_log" "$(date '+%Y-%m-%d %H:%M:%S'): $error_message"
}

# Cleanup function
cleanup() {
    log_message "Performing cleanup..."
    redis-cli -h $REDIS_HOST -p $REDIS_PORT FLUSHDB
    log_message "Cleanup completed"
}

# Start subscriber in background
redis_subscriber &
SUBSCRIBER_PID=$!

# Trap for cleanup
trap 'cleanup; kill $SUBSCRIBER_PID' EXIT

# Run main function
main

# Documentation
: '
Redis Integration Features:
1. Cache-Aside Pattern: Efficient data retrieval with cache fallback
2. Write-Through Pattern: Consistent data updates across cache and DB
3. Rate Limiting: Prevent API abuse
4. Session Management: Handle user sessions with TTL
5. Leaderboard: Sorted sets for rankings
6. Search Suggestions: Auto-complete functionality
7. Real-time Updates: Pub/Sub for cache invalidation
8. Performance Monitoring: Track cache hit/miss ratios
9. Error Handling: Logging and recovery
10. Cleanup: Proper resource management

Usage:
1. Ensure Redis and PostgreSQL are running
2. Configure connection parameters at the top
3. Run: ./redis_integration.sh

Best Practices:
1. Use appropriate TTL for cached data
2. Implement proper error handling
3. Monitor cache performance
4. Handle cache invalidation
5. Use atomic operations where possible
6. Implement proper cleanup
7. Use background processes for subscriptions
8. Log all operations for debugging
'