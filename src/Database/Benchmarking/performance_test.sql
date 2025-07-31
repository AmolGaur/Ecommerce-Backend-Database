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
    performance_metrics JSONB
);

-- Function to log benchmark results
CREATE OR REPLACE FUNCTION log_benchmark(
    p_test_name VARCHAR,
    p_execution_time INTERVAL,
    p_rows_affected INTEGER,
    p_query_plan TEXT,
    p_metrics JSONB
) RETURNS void AS $$
BEGIN
    INSERT INTO benchmark_log (test_name, execution_time, rows_affected, query_plan, performance_metrics)
    VALUES (p_test_name, p_execution_time, p_rows_affected, p_query_plan, p_metrics);
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
    avg_rows_affected NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.test_name,
        AVG(b.execution_time) as avg_execution_time,
        MAX(b.execution_time) as max_execution_time,
        MIN(b.execution_time) as min_execution_time,
        COUNT(*) as total_runs,
        AVG(b.rows_affected::numeric) as avg_rows_affected
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
    last_occurrence TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.test_name,
        AVG(b.execution_time) as avg_execution_time,
        COUNT(*) as frequency,
        MAX(b.test_date) as last_occurrence
    FROM benchmark_log b
    WHERE EXTRACT(EPOCH FROM b.execution_time) * 1000 > p_threshold_ms
    GROUP BY b.test_name
    ORDER BY avg_execution_time DESC;
END;
$$ LANGUAGE plpgsql;

-- Performance Tests

-- Test 1: Product Search Performance
DO $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    affected_rows INTEGER;
    query_plan JSONB;
BEGIN
    start_time := clock_timestamp();
    
    WITH RECURSIVE search_results AS (
        SELECT p.*, 
               ts_rank_cd(to_tsvector('english', p.title || ' ' || COALESCE(p.description, '')), 
               plainto_tsquery('english', 'smartphone')) AS rank
        FROM product p
        WHERE p.is_active = true
        AND p.stock > 0
    )
    SELECT * INTO affected_rows FROM search_results WHERE rank > 0 ORDER BY rank DESC LIMIT 20;
    
    end_time := clock_timestamp();
    
    PERFORM log_benchmark(
        'Product Search Test',
        end_time - start_time,
        affected_