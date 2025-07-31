-- Enable row level security
ALTER TABLE Customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Order" ENABLE ROW LEVEL SECURITY;
ALTER TABLE Order_Item ENABLE ROW LEVEL SECURITY;
ALTER TABLE Payment ENABLE ROW LEVEL SECURITY;
ALTER TABLE Cart ENABLE ROW LEVEL SECURITY;
ALTER TABLE Wishlist ENABLE ROW LEVEL SECURITY;

-- Create application roles with hierarchy
CREATE ROLE super_admin;
CREATE ROLE admin_role;
CREATE ROLE manager_role;
CREATE ROLE customer_service_role;
CREATE ROLE user_role;
CREATE ROLE guest_role;

-- Grant role hierarchy
GRANT guest_role TO user_role;
GRANT user_role TO customer_service_role;
GRANT customer_service_role TO manager_role;
GRANT manager_role TO admin_role;
GRANT admin_role TO super_admin;

-- Super Admin: Full access to all tables and system functions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO super_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO super_admin;

-- Admin: Full access to all business tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO admin_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO admin_role;

-- Manager: Access to manage products, inventory, and view analytics
GRANT SELECT, INSERT, UPDATE ON Product, Category, Inventory_Log TO manager_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO manager_role;
GRANT EXECUTE ON FUNCTION get_daily_revenue_report TO manager_role;
GRANT EXECUTE ON FUNCTION generate_monthly_sales_report TO manager_role;

-- Customer Service: Handle orders and customer data
GRANT SELECT, UPDATE ON Customer, "Order", Order_Item TO customer_service_role;
GRANT SELECT ON Product, Category, Inventory_Log TO customer_service_role;
GRANT INSERT ON Alert_Log TO customer_service_role;

-- User: Access to their own data and product browsing
GRANT SELECT, INSERT, UPDATE ON Customer TO user_role;
GRANT SELECT, INSERT ON "Order", Order_Item, Review TO user_role;
GRANT SELECT, INSERT, DELETE ON Cart, Wishlist TO user_role;
GRANT SELECT ON Product, Category TO user_role;

-- Guest: Read-only access to public data
GRANT SELECT ON Product, Category TO guest_role;

-- Row Level Security Policies

-- Customer table policies
CREATE POLICY customer_self_access ON Customer
    FOR ALL
    TO user_role
    USING (current_user = email);

CREATE POLICY customer_service_access ON Customer
    FOR SELECT
    TO customer_service_role
    USING (true);

-- Order policies
CREATE POLICY order_self_access ON "Order"
    FOR ALL
    TO user_role
    USING (customer_id = (SELECT customer_id FROM Customer WHERE email = current_user));

CREATE POLICY order_service_access ON "Order"
    FOR SELECT
    TO customer_service_role
    USING (true);

-- Cart policies
CREATE POLICY cart_self_access ON Cart
    FOR ALL
    TO user_role
    USING (customer_id = (SELECT customer_id FROM Customer WHERE email = current_user));

-- Wishlist policies
CREATE POLICY wishlist_self_access ON Wishlist
    FOR ALL
    TO user_role
    USING (customer_id = (SELECT customer_id FROM Customer WHERE email = current_user));

-- Payment policies
CREATE POLICY payment_self_access ON Payment
    FOR SELECT
    TO user_role
    USING (customer_id = (SELECT customer_id FROM Customer WHERE email = current_user));

-- Review policies
CREATE POLICY review_self_access ON Review
    FOR ALL
    TO user_role
    USING (customer_id = (SELECT customer_id FROM Customer WHERE email = current_user));

-- Create security functions
CREATE OR REPLACE FUNCTION check_user_access()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT (SELECT EXISTS (
        SELECT 1 FROM Customer 
        WHERE customer_id = NEW.customer_id 
        AND email = current_user
    )) THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add security triggers
CREATE TRIGGER ensure_order_access
    BEFORE INSERT OR UPDATE ON "Order"
    FOR EACH ROW
    EXECUTE FUNCTION check_user_access();

CREATE TRIGGER ensure_cart_access
    BEFORE INSERT OR UPDATE ON Cart
    FOR EACH ROW
    EXECUTE FUNCTION check_user_access();

-- Add session context functions
CREATE OR REPLACE FUNCTION set_user_context()
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_id', 
        (SELECT customer_id::text FROM Customer WHERE email = current_user),
        false);
END;
$$ LANGUAGE plpgsql;

-- Create audit logging function
CREATE OR REPLACE FUNCTION audit_log_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Audit_Log (
        user_id,
        action,
        table_name,
        record_id,
        details
    ) VALUES (
        (SELECT customer_id FROM Customer WHERE email = current_user),
        TG_OP,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id 
            ELSE NEW.id 
        END,
        jsonb_build_object(
            'old_data', to_jsonb(OLD),
            'new_data', to_jsonb(NEW),
            'timestamp', current_timestamp,
            'user_context', current_setting('app.current_user_id', true)
        )
    );
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit logging to sensitive tables
CREATE TRIGGER audit_customer_changes
    AFTER INSERT OR UPDATE OR DELETE ON Customer
    FOR EACH ROW EXECUTE FUNCTION audit_log_changes();

CREATE TRIGGER audit_order_changes
    AFTER INSERT OR UPDATE OR DELETE ON "Order"
    FOR EACH ROW EXECUTE FUNCTION audit_log_changes();

CREATE TRIGGER audit_payment_changes
    AFTER INSERT OR UPDATE OR DELETE ON Payment
    FOR EACH ROW EXECUTE FUNCTION audit_log_changes();

-- Comments for documentation
COMMENT ON ROLE super_admin IS 'Highest level administrative access with full system control';
COMMENT ON ROLE admin_role IS 'Administrative access for business operations';
COMMENT ON ROLE manager_role IS 'Management access for inventory and analytics';
COMMENT ON ROLE customer_service_role IS 'Customer service representatives';
COMMENT ON ROLE user_role IS 'Authenticated customers';
COMMENT ON ROLE guest_role IS 'Unauthenticated public access';

COMMENT ON FUNCTION check_user_access() IS 'Ensures users can only access their own data';
COMMENT ON FUNCTION set_user_context() IS 'Sets user context for the current session';
COMMENT ON FUNCTION audit_log_changes() IS 'Logs all changes to sensitive tables';
