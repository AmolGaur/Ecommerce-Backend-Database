-- Backup and Recovery Procedures for E-commerce Database

-- Create backup roles with specific privileges
CREATE ROLE backup_admin WITH LOGIN PASSWORD 'secure_backup_password';
CREATE ROLE backup_operator WITH LOGIN PASSWORD 'backup_operator_pwd';

-- Grant necessary privileges
GRANT CONNECT ON DATABASE ecommerce TO backup_admin, backup_operator;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_admin, backup_operator;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO backup_admin;
GRANT USAGE, CREATE ON SCHEMA backup TO backup_admin;

-- Allow backup operator to execute specific functions
GRANT EXECUTE ON FUNCTION create_backup TO backup_operator;
GRANT EXECUTE ON FUNCTION validate_backup TO backup_operator;

-- Create backup schema for organization
CREATE SCHEMA IF NOT EXISTS backup;

-- Enhanced maintenance log table
CREATE TABLE IF NOT EXISTS maintenance_log (
    log_id SERIAL PRIMARY KEY,
    operation VARCHAR(50) NOT NULL,
    details TEXT,
    status VARCHAR(20) DEFAULT 'success',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    size_bytes BIGINT,
    compression_ratio NUMERIC(5,2),
    duration_seconds INT,
    error_details TEXT,
    notification_sent BOOLEAN DEFAULT false
);

-- Function to estimate backup size
CREATE OR REPLACE FUNCTION estimate_backup_size()
RETURNS TABLE(table_name TEXT, estimated_size_mb NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        relname::TEXT,
        pg_total_relation_size(relid)/1024.0/1024.0 AS size_mb
    FROM pg_stat_user_tables
    ORDER BY pg_total_relation_size(relid) DESC;
END;
$$ LANGUAGE plpgsql;

-- Enhanced backup function with compression and encryption
CREATE OR REPLACE FUNCTION create_backup(
    compression_level INT DEFAULT 9,
    encrypt BOOLEAN DEFAULT true,
    parallel_workers INT DEFAULT 4
)
RETURNS TEXT AS $$
DECLARE
    backup_path TEXT;
    timestamp_str TEXT;
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    backup_size BIGINT;
    compression_cmd TEXT;
BEGIN
    start_time := CURRENT_TIMESTAMP;
    SELECT to_char(start_time, 'YYYY_MM_DD_HH24_MI_SS') INTO timestamp_str;
    backup_path := '/var/lib/postgresql/backups/ecommerce_' || timestamp_str;

    -- Set parallel workers
    SET maintenance_work_mem = '1GB';
    SET max_parallel_maintenance_workers = parallel_workers;

    -- Create backup with compression
    compression_cmd := format('pg_dump -Fc -Z %s -j %s -f %s -d ecommerce',
        compression_level, parallel_workers, backup_path);
    
    IF encrypt THEN
        -- Add encryption
        compression_cmd := compression_cmd || ' | gpg --encrypt --recipient backup@ecommerce';
        backup_path := backup_path || '.gpg';
    END IF;

    -- Execute backup
    EXECUTE compression_cmd;

    -- Get backup size and completion time
    end_time := CURRENT_TIMESTAMP;
    SELECT pg_size_pretty(pg_database_size('ecommerce')) INTO backup_size;

    -- Log backup details
    INSERT INTO maintenance_log (
        operation,
        details,
        created_at,
        completed_at,
        size_bytes,
        compression_ratio,
        duration_seconds
    ) VALUES (
        'backup',
        'Created backup: ' || backup_path,
        start_time,
        end_time,
        backup_size,
        compression_level,
        EXTRACT(EPOCH FROM (end_time - start_time))
    );

    RETURN backup_path;
EXCEPTION WHEN OTHERS THEN
    -- Log error and release lock
    INSERT INTO maintenance_log (
        operation,
        details,
        status,
        
        error_details,
        created_at,
        completed_at
    ) VALUES (
        'backup',
        'Backup failed',
        'error',
        SQLERRM,
        start_time,
        CURRENT_TIMESTAMP
    );
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Function to validate backup integrity
CREATE OR REPLACE FUNCTION validate_backup(backup_file TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    validation_result BOOLEAN;
BEGIN
    -- Check if backup file exists and is readable
    PERFORM pg_read_file(backup_file, 0, 1);
    
    -- Verify backup format and header
    EXECUTE format('pg_restore --list %I', backup_file);
    
    -- Check for corruption
    EXECUTE format('pg_restore --exit-on-error --validate %I', backup_file);
    
    -- Log successful validation
    INSERT INTO maintenance_log (operation, details)
    VALUES ('validate', 'Successfully validated backup: ' || backup_file);
    
    RETURN true;
EXCEPTION WHEN OTHERS THEN
    -- Log validation failure
    INSERT INTO maintenance_log (operation, details, status, error_details)
    VALUES ('validate', 'Backup validation failed: ' || backup_file, 'error', SQLERRM);
    RETURN false;
END;
$$ LANGUAGE plpgsql;

-- Enhanced restore function with point-in-time recovery
CREATE OR REPLACE FUNCTION restore_from_backup(
    backup_file TEXT,
    point_in_time TIMESTAMP DEFAULT NULL,
    parallel_workers INT DEFAULT 4
)
RETURNS void AS $$
DECLARE
    start_time TIMESTAMP;
    restore_cmd TEXT;
BEGIN
    start_time := CURRENT_TIMESTAMP;
    
    -- Validate backup before restore
    IF NOT validate_backup(backup_file) THEN
        RAISE EXCEPTION 'Backup validation failed';
    END IF;

    -- Acquire exclusive lock
    PERFORM pg_advisory_lock(2);
    
    -- Terminate existing connections
    EXECUTE '
        SELECT pg_terminate_backend(pid) 
        FROM pg_stat_activity 
        WHERE pid <> pg_backend_pid() 
        AND datname = current_database()
    ';
    
    -- Set parallel workers
    SET maintenance_work_mem = '1GB';
    SET max_parallel_maintenance_workers = parallel_workers;
    
    -- Build restore command
    restore_cmd := format('pg_restore -j %s -c -d ecommerce %I', 
        parallel_workers, backup_file);
        
    -- Add point-in-time recovery if specified
    IF point_in_time IS NOT NULL THEN
        restore_cmd := restore_cmd || format(' --time=%L', point_in_time);
    END IF;
    
    -- Execute restore
    EXECUTE restore_cmd;
    
    -- Log restoration
    INSERT INTO maintenance_log (
        operation,
        details,
        created_at,
        completed_at,
        duration_seconds
    ) VALUES (
        'restore',
        'Restored from backup: ' || backup_file || 
        CASE WHEN point_in_time IS NOT NULL 
            THEN ' to point in time: ' || point_in_time::TEXT
            ELSE ''
        END,
        start_time,
        CURRENT_TIMESTAMP,
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - start_time))
    );
    
    PERFORM pg_advisory_unlock(2);
EXCEPTION WHEN OTHERS THEN
    -- Log error and release lock
    INSERT INTO maintenance_log (
        operation,
        details,
        status,
        error_details,
        created_at,
        completed_at
    ) VALUES (
        'restore',
        'Restore failed: ' || backup_file,
        'error',
        SQLERRM,
        start_time,
        CURRENT_TIMESTAMP
    );
    PERFORM pg_advisory_unlock(2);
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Function to perform selective table backup
CREATE OR REPLACE FUNCTION backup_selected_tables(
    table_names TEXT[],
    output_dir TEXT DEFAULT '/var/lib/postgresql/backups/selective'
)
RETURNS void AS $$
DECLARE
    table_name TEXT;
    start
    start_time TIMESTAMP;
BEGIN
    start_time := CURRENT_TIMESTAMP;
    
    -- Create output directory if it doesn't exist
    EXECUTE format('CREATE DIRECTORY IF NOT EXISTS %L', output_dir);
    
    -- Backup each table
    FOR table_name IN SELECT unnest(table_names)
    LOOP
        EXECUTE format(
            'COPY %I TO %L WITH (FORMAT csv, HEADER true, COMPRESSION gzip)',
            table_name,
            output_dir || '/' || table_name || '_' || 
            to_char(CURRENT_TIMESTAMP, 'YYYY_MM_DD_HH24_MI_SS') || '.csv.gz'
        );
    END LOOP;
    
    -- Log operation
    INSERT INTO maintenance_log (
        operation,
        details,
        created_at,
        completed_at
    ) VALUES (
        'selective_backup',
        'Backed up tables: ' || array_to_string(table_names, ', '),
        start_time,
        CURRENT_TIMESTAMP
    );
END;
$$ LANGUAGE plpgsql;

-- Function to clean up incomplete or corrupted backups
CREATE OR REPLACE FUNCTION cleanup_incomplete_backups()
RETURNS void AS $$
DECLARE
    incomplete_backup RECORD;
BEGIN
    FOR incomplete_backup IN 
        SELECT * FROM maintenance_log 
        WHERE status = 'error' 
        AND created_at < (NOW() - INTERVAL '1 day')
    LOOP
        -- Remove associated backup files
        EXECUTE format('rm -f %s', incomplete_backup.details);
        
        -- Update log
        UPDATE maintenance_log 
        SET status = 'cleaned'
        WHERE log_id = incomplete_backup.log_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to manage backup retention
CREATE OR REPLACE FUNCTION manage_backup_retention(
    daily_retention_days INT DEFAULT 7,
    weekly_retention_weeks INT DEFAULT 4,
    monthly_retention_months INT DEFAULT 12
)
RETURNS void AS $$
DECLARE
    backup_dir TEXT := '/var/lib/postgresql/backups/';
BEGIN
    -- Keep daily backups for specified days
    EXECUTE format(
        'find %s -name "ecommerce_*.sql*" -type f -mtime +%s -delete',
        backup_dir || 'daily/',
        daily_retention_days
    );
    
    -- Keep weekly backups for specified weeks
    EXECUTE format(
        'find %s -name "ecommerce_*.sql*" -type f -mtime +%s -delete',
        backup_dir || 'weekly/',
        weekly_retention_weeks * 7
    );
    
    -- Keep monthly backups for specified months
    EXECUTE format(
        'find %s -name "ecommerce_*.sql*" -type f -mtime +%s -delete',
        backup_dir || 'monthly/',
        monthly_retention_months * 30
    );
    
    -- Log retention management
    INSERT INTO maintenance_log (operation, details)
    VALUES (
        'retention',
        format(
            'Managed backup retention: Daily=%s days, Weekly=%s weeks, Monthly=%s months',
            daily_retention_days, weekly_retention_weeks, monthly_retention_months
        )
    );
END;
$$ LANGUAGE plpgsql;

-- Create notification function
CREATE OR REPLACE FUNCTION notify_backup_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Implementation would depend on notification system (email, Slack, etc.)
    IF NEW.status = 'error' THEN
        -- Send error notification
        RAISE NOTICE 'Backup operation failed: %', NEW.error_details;
    ELSIF NEW.status = 'success' THEN
        -- Send success notification
        RAISE NOTICE 'Backup completed successfully: %', NEW.details;
    END IF;
    
    NEW.notification_sent := true;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create notification trigger
CREATE TRIGGER backup_notification_trigger
AFTER INSERT OR UPDATE ON maintenance_log
FOR EACH ROW
WHEN (NEW.notification_sent = false)
EXECUTE
EXECUTE FUNCTION notify_backup_status();

-- Documentation and usage examples
COMMENT ON FUNCTION create_backup(INT, BOOLEAN, INT) IS 'Creates a compressed and optionally encrypted backup with parallel processing';
COMMENT ON FUNCTION validate_backup(TEXT) IS 'Validates backup file integrity and format';
COMMENT ON FUNCTION restore_from_backup(TEXT, TIMESTAMP, INT) IS 'Restores database from backup with optional point-in-time recovery';
COMMENT ON FUNCTION backup_selected_tables(TEXT[], TEXT) IS 'Creates selective backups of specified tables';
COMMENT ON FUNCTION cleanup_incomplete_backups() IS 'Removes failed or incomplete backup files';
COMMENT ON FUNCTION manage_backup_retention(INT, INT, INT) IS 'Manages backup retention based on configurable periods';
COMMENT ON FUNCTION notify_backup_status() IS 'Sends notifications for backup operations status';

/*
Backup and Recovery Instructions:

1. Regular Backup Creation:
   - Full backup with encryption:
     SELECT create_backup(9, true, 4);
   
   - Backup without encryption:
     SELECT create_backup(9, false, 4);

2. Backup Validation:
   - Validate backup integrity:
     SELECT validate_backup('/path/to/backup/file');

3. Database Restoration:
   - Full restore:
     SELECT restore_from_backup('/path/to/backup/file');
   
   - Point-in-time recovery:
     SELECT restore_from_backup('/path/to/backup/file', '2025-07-31 12:00:00');

4. Selective Operations:
   - Backup specific tables:
     SELECT backup_selected_tables(ARRAY['orders', 'customers']);
   
   - Estimate backup size:
     SELECT * FROM estimate_backup_size();

5. Maintenance:
   - Clean up old backups:
     SELECT manage_backup_retention(7, 4, 12);
   
   - Remove incomplete backups:
     SELECT cleanup_incomplete_backups();

6. Monitoring:
   - Check backup history:
     SELECT * FROM maintenance_log ORDER BY created_at DESC;
   
   - Monitor backup sizes:
     SELECT operation, size_bytes, compression_ratio 
     FROM maintenance_log 
     WHERE operation = 'backup'
     ORDER BY created_at DESC;

Best Practices:
1. Regularly validate backup integrity
2. Maintain multiple backup copies
3. Test restoration procedures periodically
4. Monitor backup sizes and completion times
5. Configure appropriate retention periods
6. Enable notifications for backup status
7. Use encryption for sensitive data
8. Optimize parallel workers based on system resources

Emergency Recovery:
1. Stop application services
2. Verify backup file integrity
3. Restore using appropriate procedure
4. Validate restored data
5. Restart application services
*/