-- Performance Benchmarking Script for E-commerce Database

-- Enable timing
\timing on

-- Create benchmarking log table
CREATE TABLE IF NOT EXISTS benchmark_log (
    test_id SERIAL PRIMARY KEY,
    test_name VARCHAR(100),
    execution_time INTERVAL,
    rows_affected INTEGER,
    test_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    query_plan TEXT,
    performance_metrics JSONB,
    resource_usage JSONB,
    concurrent_users INTEGER DEFAULT 1
);

-- Function to log benchmark results
CREATE OR REPLACE FUNCTION log_benchmark(
    p_test_name VARCHAR,
    p_execution_time INTERVAL,
    p_rows_affected INTEGER,
    p_query_plan TEXT,
    p_metrics JSONB,
    p_resource_usage JSONB DEFAULT NULL,
    p_concurrent_users INTEGER DEFAULT 1
) RETURNS void AS $$
BEGIN
    INSERT INTO benchmark_log (
        test_name, 
        execution_time, 
        rows_affected, 
        query_plan, 
        performance_metrics,
        resource_usage,
        concurrent_users
    )
    VALUES (
        p_test_name, 
        p_execution_time, 
        p_rows_affected, 
        p_query_plan, 
        p_metrics,
        p_resource_usage,
        p_concurrent_users
    );
END;
$$ LANGUAGE plpgsql;

-- Function to analyze query performance
CREATE OR REPLACE FUNCTION analyze_query_performance(p_test_id INTEGER)
RETURNS TABLE (
    metric_name TEXT,
    metric_value TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.key as metric_name,
        m.value::text as metric_value
    FROM benchmark_log b,
    jsonb_each(b.performance_metrics) m
    WHERE b.test_id = p_test_id;
END;
$$ LANGUAGE plpgsql;

-- Function to generate performance report
CREATE OR REPLACE FUNCTION generate_performance_report()
RETURNS TABLE (
    test_name VARCHAR(100),
    avg_execution_time INTERVAL,
    max_execution_time INTERVAL,
    min_execution_time INTERVAL,
    total_runs INTEGER,
    avg_rows_affected NUMERIC,
    avg_concurrent_users NUMERIC,
    p95_execution_time INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.test_name,
        AVG(b.execution_time) as avg_execution_time,
        MAX(b.execution_time) as max_execution_time,
        MIN(b.execution_time) as min_execution_time,
        COUNT(*) as total_runs,
        AVG(b.rows_affected::numeric) as avg_rows_affected,
        AVG(b.concurrent_users::numeric) as avg_concurrent_users,
        percentile_cont(0.95) WITHIN GROUP (ORDER BY b.execution_time) as p95_execution_time
    FROM benchmark_log b
    GROUP BY b.test_name
    ORDER BY avg_execution_time DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to identify slow queries
CREATE OR REPLACE FUNCTION identify_slow_queries(p_threshold_ms INTEGER)
RETURNS TABLE (
    test_name VARCHAR(100),
    avg_execution_time INTERVAL,
    frequency INTEGER,
    last_occurrence TIMESTAMP,
    avg_resource_usage JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.test_name,
        AVG(b.execution_time) as avg_execution_time,
        COUNT(*) as frequency,
        MAX(b.test_date) as last_occurrence,
        jsonb_build_object(
            'cpu_usage', AVG((b.resource_usage->>'cpu_usage')::numeric),
            'memory_usage', AVG((b.resource_usage->>'memory_usage')::numeric),
            'io_wait', AVG((b.resource_usage->>'io_wait')::numeric)
        ) as avg_resource_usage
    FROM benchmark_log b
    WHERE EXTRACT(EPOCH FROM b.execution_time) * 1000 > p_threshold_ms
    GROUP BY b.test_name
    ORDER BY avg_execution_time DESC;
END;
$$ LANGUAGE plpgsql;

-- Performance Tests

-- Test 1: Product Search and Filtering Performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    query_plan TEXT;
    resource_metrics JSONB;
BEGIN
    -- Get resource usage before test
    SELECT jsonb_build_object(
        'cpu_usage', pg_stat_get_backend_activity(pg_backend_pid()),
        'memory_usage', pg_memory_context_statistics()
    ) INTO resource_metrics;

    start_time := clock_timestamp();
    
    WITH RECURSIVE search_results AS (
        SELECT p.*, 
               ts_rank_cd(to_tsvector('english', p.title || ' ' || COALESCE(p.description, '')), 
               plainto_tsquery('english', 'smartphone')) AS rank
        FROM product p
        WHERE p.is_active = true
        AND p.stock > 0
        AND p.price BETWEEN 100 AND 1000
        AND p.category_id IN (
            SELECT category_id FROM category 
            WHERE name ILIKE '%electronics%'
        )
    )
    SELECT COUNT(*) INTO affected_rows 
    FROM search_results 
    WHERE rank > 0 
    ORDER BY rank DESC;
    
    end_time := clock_timestamp();
    
    -- Get query plan
    EXPLAIN (FORMAT JSON)
    SELECT * FROM search_results WHERE rank > 0 ORDER BY rank DESC
    INTO query_plan;
    
    -- Update resource metrics
    SELECT resource_metrics || jsonb_build_object(
        'io_wait', pg_stat_get_backend_wait_event(pg_backend_pid())
    ) INTO resource_metrics;
    
    PERFORM log_benchmark(
        'Product Search Test',
        end_time - start_time,
        affected_rows,
        query_plan::text,
        jsonb_build_object(
            'rank_threshold', 0,
            'price_range', '[100,1000]',
            'category_filter', 'electronics'
        ),
        resource_metrics
    );
END;
$$;

-- Test 2: Order Processing Performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    query_plan TEXT;
    resource_metrics JSONB;
BEGIN
    start_time := clock_timestamp();
    
    -- Simulate order processing
    WITH new_order AS (
        INSERT INTO "Order" (customer_id, status, total_price)
        SELECT 
            customer_id,
            'pending',
            (random() * 1000)::numeric(10,2)
        FROM
        Customer 
        WHERE customer_id <= 100
        LIMIT 10
        RETURNING order_id
    )
    INSERT INTO Order_Item (order_id, product_id, quantity, unit_price)
    SELECT 
        o.order_id,
        p.product_id,
        (random() * 5 + 1)::integer,
        p.price
    FROM new_order o
    CROSS JOIN (
        SELECT product_id, price 
        FROM Product 
        WHERE is_active = true 
        LIMIT 5
    ) p;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    end_time := clock_timestamp();
    
    -- Get query plan and resource metrics
    EXPLAIN (FORMAT JSON)
    SELECT * FROM new_order
    INTO query_plan;
    
    SELECT jsonb_build_object(
        'cpu_usage', pg_stat_get_backend_activity(pg_backend_pid()),
        'memory_usage', pg_memory_context_statistics(),
        'io_wait', pg_stat_get_backend_wait_event(pg_backend_pid())
    ) INTO resource_metrics;
    
    PERFORM log_benchmark(
        'Order Processing Test',
        end_time - start_time,
        affected_rows,
        query_plan::text,
        jsonb_build_object(
            'orders_created', 10,
            'items_per_order', 5,
            'total_items', affected_rows
        ),
        resource_metrics
    );
END;
$$;

-- Test 3: Analytics Query Performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    query_plan TEXT;
    resource_metrics JSONB;
BEGIN
    start_time := clock_timestamp();
    
    WITH sales_analysis AS (
        SELECT 
            c.category_id,
            c.name as category_name,
            COUNT(DISTINCT o.order_id) as total_orders,
            COUNT(DISTINCT o.customer_id) as unique_customers,
            SUM(oi.quantity * oi.unit_price) as total_revenue,
            AVG(oi.unit_price) as avg_unit_price,
            percentile_cont(0.5) WITHIN GROUP (ORDER BY oi.unit_price) as median_price,
            VARIANCE(oi.quantity) as quantity_variance
        FROM Category c
        JOIN Product p ON c.category_id = p.category_id
        JOIN Order_Item oi ON p.product_id = oi.product_id
        JOIN "Order" o ON oi.order_id = o.order_id
        WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY c.category_id, c.name
    )
    SELECT COUNT(*) INTO affected_rows FROM sales_analysis;
    
    end_time := clock_timestamp();
    
    -- Get query plan and resource metrics
    EXPLAIN (FORMAT JSON, ANALYZE)
    SELECT * FROM sales_analysis
    INTO query_plan;
    
    SELECT jsonb_build_object(
        'cpu_usage', pg_stat_get_backend_activity(pg_backend_pid()),
        'memory_usage', pg_memory_context_statistics(),
        'io_wait', pg_stat_get_backend_wait_event(pg_backend_pid())
    ) INTO resource_metrics;
    
    PERFORM log_benchmark(
        'Analytics Query Test',
        end_time - start_time,
        affected_rows,
        query_plan::text,
        jsonb_build_object(
            'date_range', '30 days',
            'metrics_calculated', 8,
            'grouping_level', 'category'
        ),
        resource_metrics
    );
END;
$$;

-- Test 4: Concurrent Cart Operations
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    query_plan TEXT;
    resource_metrics JSONB;
    concurrent_users INTEGER := 50;
BEGIN
    start_time := clock_timestamp();
    
    -- Simulate concurrent cart updates
    FOR i IN 1..concurrent_users LOOP
        INSERT INTO Cart (customer_id, product_id, quantity)
        SELECT 
            (random() * 100 
            + 1)::integer as customer_id,
            (random() * 1000 + 1)::integer as product_id,
            (random() * 5 + 1)::integer as quantity
        ON CONFLICT (customer_id, product_id) 
        DO UPDATE SET quantity = Cart.quantity + EXCLUDED.quantity;
    END LOOP;

    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    end_time := clock_timestamp();
    
    -- Get resource metrics
    SELECT jsonb_build_object(
        'cpu_usage', pg_stat_get_backend_activity(pg_backend_pid()),
        'memory_usage', pg_memory_context_statistics(),
        'io_wait', pg_stat_get_backend_wait_event(pg_backend_pid())
    ) INTO resource_metrics;
    
    PERFORM log_benchmark(
        'Concurrent Cart Operations Test',
        end_time - start_time,
        affected_rows,
        NULL,
        jsonb_build_object(
            'concurrent_users', concurrent_users,
            'operations_per_user', 1,
            'total_operations', affected_rows
        ),
        resource_metrics,
        concurrent_users
    );
END;
$$;

-- Test 5: Cache Performance with Redis
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    cache_hits INTEGER;
    cache_misses INTEGER;
    resource_metrics JSONB;
BEGIN
    start_time := clock_timestamp();
    
    -- Test product cache performance
    SELECT COUNT(*) INTO cache_hits
    FROM (
        SELECT redis.get('product:' || p.product_id::text) as cached
        FROM Product p
        WHERE p.is_active = true
        AND redis.exists('product:' || p.product_id::text) = 1
    ) as cache_check
    WHERE cached IS NOT NULL;
    
    SELECT COUNT(*) INTO cache_misses
    FROM Product p
    WHERE p.is_active = true
    AND redis.exists('product:' || p.product_id::text) = 0;
    
    affected_rows := cache_hits + cache_misses;
    end_time := clock_timestamp();
    
    -- Get resource metrics
    SELECT jsonb_build_object(
        'cpu_usage', pg_stat_get_backend_activity(pg_backend_pid()),
        'memory_usage', pg_memory_context_statistics(),
        'redis_memory', redis.info('memory')::jsonb->>'used_memory_human'
    ) INTO resource_metrics;
    
    PERFORM log_benchmark(
        'Cache Performance Test',
        end_time - start_time,
        affected_rows,
        NULL,
        jsonb_build_object(
            'cache_hits', cache_hits,
            'cache_misses', cache_misses,
            'hit_ratio', (cache_hits::float / NULLIF(affected_rows, 0) * 100)::numeric(5,2)
        ),
        resource_metrics
    );
END;
$$;

-- Test 6: Data Import/Export Performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    resource_metrics JSONB;
BEGIN
    start_time := clock_timestamp();
    
    -- Export test data
    COPY (
        SELECT row_to_json(p)
        FROM Product p
        WHERE p.is_active = true
    ) TO '/tmp/product_export.json';
    
    -- Import test data
    CREATE TEMP TABLE temp_import (data jsonb);
    COPY temp_import FROM '/tmp/product_export.json';
    
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    end_time := clock_timestamp();
    
    -- Get resource metrics
    SELECT jsonb_build_object(
        'cpu_usage', pg_stat_get_backend_activity(pg_backend_pid()),
        'memory_usage', pg_memory_context_statistics(),
        'io_wait', pg_stat_get_backend_wait_event(pg_backend_pid()),
        'disk_usage', pg_size_pretty(pg_relation_size('temp_import'))
    ) INTO resource_metrics;
    
    PERFORM log_benchmark(
        'Data Import/Export Test',
        end_time - start_time,
        affected_rows,
        NULL,
        jsonb_build_object(
            'export_format', 'JSON',
            'file_size', pg_size_pretty(pg_relation_size('temp_import')),
            'records_processed', affected_rows
        ),
        resource_metrics
    );
    
    DROP TABLE temp_import;
END;
$$;

-- Test 7: Full-Text Search Performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    query_plan TEXT;
    resource_metrics JSONB;
BEGIN
    start_time := clock_timestamp();
    
    WITH search_results AS (
        SELECT 
            p.*,
            ts_rank_cd(
                setweight(to_tsvector('english', p.title), 'A') ||
                setweight(to_tsvector('english', COALESCE(p.description, '')), 'B'),
                plainto_tsquery('english', 'wireless charging smartphone')
            ) as rank
        FROM Product p
        WHERE p.is_active = true
    )
    SELECT COUNT(*) INTO affected_rows 
    FROM search_results 
    WHERE rank > 0;
    
    end_time := clock_timestamp();
    
    -- Get query plan
    EXPLAIN (FORMAT JSON, ANALYZE)
    SELECT * FROM search_results WHERE rank > 0 ORDER BY rank DESC
    INTO query_plan;
    
    -- Get resource metrics
    SELECT jsonb_build_object(
        'cpu_usage', pg_stat_get_backend_activity(pg_backend_pid()),
        'memory_usage', pg_memory_context_statistics(),
        'io_wait', pg_stat_get_backend_wait_event(pg_backend_pid())
    ) INTO resource_metrics;
    
    PERFORM log_benchmark(
        'Full-Text Search Test',
        end_time - start_time,
        affected_rows,
        query_plan::text,
        jsonb_build_object(
            'search_terms', 'wireless charging smartphone',
            'weight_config', 'title=A, description=B',
            'matching_products', affected_rows
        ),
        resource_metrics
    );
END;
$$;

-- Generate comprehensive performance report
SELECT * FROM generate_performance_report();
SELECT * FROM identify_slow_queries(100);

-- Documentation
COMMENT ON TABLE benchmark_log IS 'Stores performance test results with detailed metrics';
COMMENT ON FUNCTION log_benchmark IS 'Records benchmark results with execution time and resource usage';
COMMENT ON FUNCTION analyze_query_performance IS 'Analyzes performance metrics for specific test runs';
COMMENT ON FUNCTION generate_performance_report IS 'Generates summary report of all performance tests';
COMMENT ON FUNCTION identify_slow_queries IS 'Identifies queries exceeding specified time threshold';

/*
Performance Benchmarking Documentation:

1. Test Scenarios:
   - Product Search and Filtering
   - Order Processing
   - Analytics Queries
   - Concurrent Cart Operations
   - Cache Performance
   - Data Import/Export
   - Full-Text Search

2. Metrics Collected:
   - Execution Time
   - Rows Affected
   - Query Plans
   - Resource Usage (CPU, Memory, I/O)
   - Cache Hit Ratios
   - Concurrent User Impact

3. Analysis Tools:
   - Performance Reports
   - Slow Query Identification
   - Resource Usage Tracking
   - Query Plan Analysis

4. Best Practices:
   - Regular benchmark execution
   - Monitor trends over time
   - Analyze query plans
   - Track resource utilization
   - Optimize based on results
   