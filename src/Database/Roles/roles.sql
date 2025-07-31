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
CREATE ROLE inventory_manager_role;
CREATE ROLE returns_manager_role;
CREATE ROLE marketing_manager_role;
CREATE ROLE analytics_viewer_role;

-- Grant role hierarchy
GRANT guest_role TO user_role;
GRANT user_role TO customer_service_role;
GRANT customer_service_role TO manager_role;
GRANT manager_role TO admin_role;
GRANT admin_role TO super_admin;
GRANT analytics_viewer_role TO manager_role;
GRANT analytics_viewer_role TO marketing_manager_role;
GRANT inventory_manager_role TO manager_role;
GRANT returns_manager_role TO customer_service_role;

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

-- Inventory Manager: Specialized access for inventory management
GRANT SELECT, INSERT, UPDATE ON Product, Product_Variant, Inventory_Log TO inventory_manager_role;
GRANT SELECT, INSERT ON Alert_Log TO inventory_manager_role;
GRANT SELECT ON Order_Item TO inventory_manager_role;
GRANT EXECUTE ON FUNCTION restock_product TO inventory_manager_role;
GRANT EXECUTE ON FUNCTION manage_variant_stock TO inventory_manager_role;

-- Returns Manager: Handle product returns and refunds
GRANT SELECT, UPDATE ON Return, Return_Item TO returns_manager_role;
GRANT SELECT ON "Order", Order_Item TO returns_manager_role;
GRANT SELECT ON Customer TO returns_manager_role;
GRANT EXECUTE ON FUNCTION process_return TO returns_manager_role;

-- Marketing Manager: Handle promotions and customer engagement
GRANT SELECT, INSERT, UPDATE ON Coupon, Product_Bundle TO marketing_manager_role;
GRANT SELECT ON Customer, "Order" TO marketing_manager_role;
GRANT SELECT ON customer_analytics TO marketing_manager_role;
GRANT SELECT ON sales_analytics TO marketing_manager_role;

-- Analytics Viewer: Read-only access to analytics
GRANT SELECT ON customer_analytics TO analytics_viewer_role;
GRANT SELECT ON sales_analytics TO analytics_viewer_role;
GRANT SELECT ON product_analytics TO analytics_viewer_role;
GRANT SELECT ON returns_analytics TO analytics_viewer_role;
GRANT SELECT ON inventory_analytics TO analytics_viewer_role;
GRANT SELECT ON variant_analytics TO analytics_viewer_role;
GRANT SELECT ON bundle_analytics TO analytics_viewer_role;

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

-- Return policies
CREATE POLICY return_self_access ON Return
    FOR ALL
    TO user_role
    USING (customer_id = (SELECT customer_id FROM Customer WHERE email = current_user));

CREATE POLICY return_service_access ON Return
    FOR ALL
    TO returns_manager_role
    USING (true);

-- Product Variant policies
CREATE POLICY variant_inventory_access ON Product_Variant
    FOR ALL
    TO inventory_manager_role
    USING (true);

-- Bundle policies
CREATE POLICY bundle_marketing_access ON Product_Bundle
    FOR ALL
    TO marketing_manager_role
    USING (true);

-- Coupon policies
CREATE POLICY coupon_marketing_access ON Coupon
    FOR ALL
    TO marketing_manager_role
    USING (true);

-- Analytics view policies
CREATE POLICY analytics_view_access ON customer_analytics
    FOR SELECT
    TO analytics_viewer_role
    USING (true);

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

-- Additional role documentation
COMMENT ON ROLE inventory_manager_role IS 'Specialized role for inventory and stock management';
COMMENT ON ROLE returns_manager_role IS 'Handles product returns and refund processing';
COMMENT ON ROLE marketing_manager_role IS 'Manages promotions, bundles, and customer engagement';
COMMENT ON ROLE analytics_viewer_role IS 'Read-only access to business analytics and reporting';

-- Enable RLS on new tables
ALTER TABLE Product_Variant ENABLE ROW LEVEL SECURITY;
ALTER TABLE Product_Bundle ENABLE ROW LEVEL SECURITY;
ALTER TABLE Bundle_Item ENABLE ROW LEVEL SECURITY;
ALTER TABLE Coupon ENABLE ROW LEVEL SECURITY;
ALTER TABLE Return ENABLE ROW LEVEL SECURITY;
ALTER TABLE Return_Item ENABLE ROW LEVEL SECURITY;
ALTER TABLE Loyalty_Transaction ENABLE ROW LEVEL SECURITY;

-- Add audit logging for new sensitive tables
CREATE TRIGGER audit_variant_changes
    AFTER INSERT OR UPDATE OR DELETE ON Product_Variant
    FOR EACH ROW EXECUTE FUNCTION audit_log_changes();

CREATE TRIGGER audit_bundle_changes
    AFTER INSERT OR UPDATE OR DELETE ON Product_Bundle
    FOR EACH ROW EXECUTE FUNCTION audit_log_changes();

CREATE TRIGGER audit_coupon_changes
    AFTER INSERT OR UPDATE OR DELETE ON Coupon
    FOR EACH ROW EXECUTE FUNCTION audit_log_changes();

CREATE TRIGGER audit_return_changes
    AFTER INSERT OR UPDATE OR DELETE ON Return
    FOR EACH ROW EXECUTE FUNCTION audit_log_changes();
