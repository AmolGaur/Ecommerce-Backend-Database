-- Backup and Recovery Procedures for E-commerce Database

-- Create backup user with necessary privileges
CREATE ROLE backup_user WITH LOGIN PASSWORD 'secure_backup_password';
GRANT CONNECT ON DATABASE ecommerce TO backup_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;

-- Function to create timestamped backups
CREATE OR REPLACE FUNCTION create_backup()
RETURNS void AS $$
DECLARE
    backup_path TEXT;
    timestamp_str TEXT;
BEGIN
    -- Generate timestamp string
    SELECT to_char(current_timestamp, 'YYYY_MM_DD_HH24_MI_SS') INTO timestamp_str;
    backup_path := '/var/lib/postgresql/backups/ecommerce_' || timestamp_str || '.sql';
    
    -- Create backup directory if it doesn't exist
    PERFORM pg_advisory_lock(1);
    EXECUTE 'CREATE DIRECTORY IF NOT EXISTS ''/var/lib/postgresql/backups''';
    
    -- Create full database backup
    EXECUTE 'pg_dump -Fc -f ' || backup_path || ' -d ecommerce';
    
    -- Log backup creation
    INSERT INTO maintenance_log (operation, details)
    VALUES ('backup', 'Created backup: ' || backup_path);
    
    PERFORM pg_advisory_unlock(1);
EXCEPTION WHEN OTHERS THEN
    -- Log error and release lock
    INSERT INTO maintenance_log (operation, details, status)
    VALUES ('backup', 'Backup failed: ' || SQLERRM, 'error');
    PERFORM pg_advisory_unlock(1);
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Function to restore from backup
CREATE OR REPLACE FUNCTION restore_from_backup(backup_file TEXT)
RETURNS void AS $$
BEGIN
    -- Acquire exclusive lock
    PERFORM pg_advisory_lock(2);
    
    -- Terminate all other connections
    EXECUTE '
        SELECT pg_terminate_backend(pid) 
        FROM pg_stat_activity 
        WHERE pid <> pg_backend_pid() 
        AND datname = current_database()
    ';
    
    -- Restore from backup
    EXECUTE 'pg_restore -c -d ecommerce ' || backup_file;
    
    -- Log restoration
    INSERT INTO maintenance_log (operation, details)
    VALUES ('restore', 'Restored from backup: ' || backup_file);
    
    PERFORM pg_advisory_unlock(2);
EXCEPTION WHEN OTHERS THEN
    -- Log error and release lock
    INSERT INTO maintenance_log (operation, details, status)
    VALUES ('restore', 'Restore failed: ' || SQLERRM, 'error');
    PERFORM pg_advisory_unlock(2);
    RAISE;
END;
$$ LANGUAGE plpgsql;

-- Create maintenance log table
CREATE TABLE IF NOT EXISTS maintenance_log (
    log_id SERIAL PRIMARY KEY,
    operation VARCHAR(50) NOT NULL,
    details TEXT,
    status VARCHAR(20) DEFAULT 'success',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create backup schedule
CREATE OR REPLACE FUNCTION schedule_backups()
RETURNS void AS $$
BEGIN
    -- Schedule daily backups at 2 AM
    EXECUTE 'CREATE EVENT IF NOT EXISTS daily_backup
        ON SCHEDULE EVERY 1 DAY
        STARTS CURRENT_DATE + INTERVAL ''2 hours''
        DO
        BEGIN
            CALL create_backup();
        END;';
        
    -- Schedule weekly full backups on Sunday at 3 AM
    EXECUTE 'CREATE EVENT IF NOT EXISTS weekly_backup
        ON SCHEDULE EVERY 1 WEEK
        STARTS DATE_ADD(DATE(NOW()), INTERVAL (7 - WEEKDAY(NOW())) DAY) + INTERVAL ''3 hours''
        DO
        BEGIN
            CALL create_backup();
        END;';
END;
$$ LANGUAGE plpgsql;

-- Backup retention policy
CREATE OR REPLACE FUNCTION cleanup_old_backups()
RETURNS void AS $$
DECLARE
    backup_retention_days INTEGER := 30;
    backup_dir TEXT := '/var/lib/postgresql/backups/';
BEGIN
    -- Remove backups older than retention period
    EXECUTE 'find ' || backup_dir || ' -name "ecommerce_*.sql" -mtime +' || 
            backup_retention_days || ' -delete';
            
    -- Log cleanup
    INSERT INTO maintenance_log (operation, details)
    VALUES ('cleanup', 'Removed backups older than ' || backup_retention_days || ' days');
END;
$$ LANGUAGE plpgsql;

-- Documentation
COMMENT ON FUNCTION create_backup() IS 'Creates a timestamped backup of the database';
COMMENT ON FUNCTION restore_from_backup(TEXT) IS 'Restores database from specified backup file';
COMMENT ON FUNCTION schedule_backups() IS 'Sets up automated backup schedule';
COMMENT ON FUNCTION cleanup_old_backups() IS 'Removes backups older than retention period';

-- Recovery Instructions
/*
To perform a manual backup:
SELECT create_backup();

To restore from a backup:
SELECT restore_from_backup('/path/to/backup/file.sql');

To schedule automated backups:
SELECT schedule_backups();

To clean up old backups:
SELECT cleanup_old_backups();

Emergency Recovery Steps:
1. Stop the application
2. Connect to database as superuser
3. Run: SELECT restore_from_backup('/path/to/latest/backup.sql');
4. Verify data integrity
5. Restart the application

Monitoring:
- Check maintenance_log table for backup/restore history
- Monitor available disk space for backups
- Verify backup files are being created as scheduled
*/