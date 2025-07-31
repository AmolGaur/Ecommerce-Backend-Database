-- Trigger to update Order.total_price based on Order_Item entries
CREATE OR REPLACE FUNCTION update_order_total_price()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "Order"
    SET total_price = (
        SELECT SUM(quantity * price) FROM Order_Item WHERE order_id = NEW.order_id
    )
    WHERE order_id = NEW.order_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_total_price_update
AFTER INSERT OR UPDATE ON Order_Item
FOR EACH ROW
EXECUTE FUNCTION update_order_total_price();

-- Trigger to log inventory changes when a purchase is made
CREATE OR REPLACE FUNCTION log_inventory_change()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Product
    SET stock = stock - NEW.quantity
    WHERE product_id = NEW.product_id;

    INSERT INTO Inventory_Log (product_id, change)
    VALUES (NEW.product_id, -NEW.quantity);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER inventory_log_update
AFTER INSERT ON Order_Item
FOR EACH ROW
EXECUTE FUNCTION log_inventory_change();

-- Trigger to update Customer.total_spent when a new order is added
CREATE OR REPLACE FUNCTION update_customer_total_spent()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Customer
    SET total_spent = total_spent + NEW.total_price
    WHERE customer_id = NEW.customer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER customer_total_spent_update
AFTER INSERT ON "Order"
FOR EACH ROW
EXECUTE FUNCTION update_customer_total_spent();

-- Trigger to log low stock alerts
CREATE OR REPLACE FUNCTION low_stock_alert()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stock < 5 THEN
        INSERT INTO Alert_Log (product_id, alert_message)
        VALUES (NEW.product_id, 'Low stock alert: Stock is below threshold');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER low_stock_trigger
AFTER UPDATE ON Product
FOR EACH ROW
WHEN (NEW.stock < OLD.stock)
EXECUTE FUNCTION low_stock_alert();

-- Trigger function to update average rating for a product
CREATE OR REPLACE FUNCTION update_average_rating()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Product
    SET average_rating = (
        SELECT AVG(rating) FROM Review WHERE product_id = NEW.product_id
    )
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_rating_on_insert
AFTER INSERT OR UPDATE ON Review
FOR EACH ROW
EXECUTE FUNCTION update_average_rating();

CREATE TRIGGER update_rating_on_delete
AFTER DELETE ON Review
FOR EACH ROW
EXECUTE FUNCTION update_average_rating();

-- Trigger to prevent order placement for out-of-stock items
CREATE OR REPLACE FUNCTION check_stock_before_order()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT stock FROM Product WHERE product_id = NEW.product_id) < NEW.quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product ID %', NEW.product_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER stock_check_trigger
BEFORE INSERT ON Order_Item
FOR EACH ROW
EXECUTE FUNCTION check_stock_before_order();


-- Table to log audit information
CREATE TABLE IF NOT EXISTS Audit_Log (
    log_id SERIAL PRIMARY KEY,
    user_id INTEGER,
    action VARCHAR(50),
    table_name VARCHAR(50),
    record_id INTEGER,
    action_time TIMESTAMP DEFAULT NOW(),
    details TEXT
);


-- Audit logging function to record user actions
CREATE OR REPLACE FUNCTION log_audit_action()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Audit_Log (user_id, action, table_name, record_id, details)
    VALUES (
        NEW.customer_id,     -- Adjust based on your schema's primary key field
        TG_OP,               -- Trigger operation (INSERT, UPDATE, DELETE)
        TG_TABLE_NAME,       -- Table name
        NEW.customer_id,     -- Record ID (change as appropriate)
        row_to_json(NEW)::TEXT -- Details as JSON (change NEW to OLD for DELETE operations)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Trigger for Customer table (records inserts, updates, and deletions)
CREATE TRIGGER customer_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON Customer
FOR EACH ROW
EXECUTE FUNCTION log_audit_action();

-- Trigger for Payment table (records inserts, updates, and deletions)
CREATE TRIGGER payment_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON Payment
FOR EACH ROW
EXECUTE FUNCTION log_audit_action();

-- Trigger for Order table (records inserts, updates, and deletions)
CREATE TRIGGER order_audit_trigger
AFTER INSERT OR UPDATE OR DELETE ON "Order"
FOR EACH ROW
EXECUTE FUNCTION log_audit_action();

-- Trigger to manage product variant stock
CREATE OR REPLACE FUNCTION manage_variant_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.variant_id IS NOT NULL THEN
        UPDATE Product_Variant
        SET stock = stock - NEW.quantity
        WHERE variant_id = NEW.variant_id;

        IF (SELECT stock FROM Product_Variant WHERE variant_id = NEW.variant_id) < 5 THEN
            INSERT INTO Alert_Log (product_id, alert_message)
            VALUES (
                (SELECT product_id FROM Product_Variant WHERE variant_id = NEW.variant_id),
                'Low stock alert: Variant ' || NEW.variant_id || ' is below threshold'
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER variant_stock_update
AFTER INSERT ON Order_Item
FOR EACH ROW
WHEN (NEW.variant_id IS NOT NULL)
EXECUTE FUNCTION manage_variant_stock();

-- Trigger to manage bundle inventory
CREATE OR REPLACE FUNCTION manage_bundle_inventory()
RETURNS TRIGGER AS $$
DECLARE
    v_item RECORD;
BEGIN
    -- Check and update stock for each product in the bundle
    FOR v_item IN 
        SELECT product_id, quantity 
        FROM Bundle_Item 
        WHERE bundle_id = NEW.bundle_id
    LOOP
        -- Check stock availability
        IF (SELECT stock FROM Product WHERE product_id = v_item.product_id) < (v_item.quantity * NEW.quantity) THEN
            RAISE EXCEPTION 'Insufficient stock for product ID % in bundle', v_item.product_id;
        END IF;

        -- Update stock
        UPDATE Product
        SET stock = stock - (v_item.quantity * NEW.quantity)
        WHERE product_id = v_item.product_id;

        -- Log inventory change
        INSERT INTO Inventory_Log (product_id, change)
        VALUES (v_item.product_id, -(v_item.quantity * NEW.quantity));
    END LOOP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bundle_inventory_update
AFTER INSERT ON Order_Item
FOR EACH ROW
WHEN (NEW.bundle_id IS NOT NULL)
EXECUTE FUNCTION manage_bundle_inventory();

-- Trigger to manage loyalty points
CREATE OR REPLACE FUNCTION manage_loyalty_points()
RETURNS TRIGGER AS $$
DECLARE
    v_points INTEGER;
BEGIN
    -- Calculate points (1 point per $10 spent)
    v_points := FLOOR(NEW.total_price / 10);
    
    -- Update customer loyalty points
    UPDATE Customer
    SET 
        loyalty_points = loyalty_points + v_points,
        tier_status = CASE 
            WHEN loyalty_points + v_points >= 5000 THEN 'platinum'
            WHEN loyalty_points + v_points >= 2000 THEN 'gold'
            WHEN loyalty_points + v_points >= 1000 THEN 'silver'
            ELSE 'bronze'
        END
    WHERE customer_id = NEW.customer_id;

    -- Log points transaction
    INSERT INTO Loyalty_Transaction (
        customer_id,
        order_id,
        points,
        action,
        transaction_date
    ) VALUES (
        NEW.customer_id,
        NEW.order_id,
        v_points,

-- Trigger to track coupon usage
CREATE OR REPLACE FUNCTION track_coupon_usage()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.coupon_code IS NOT NULL THEN
        UPDATE Coupon
        SET 
            used_count = used_count + 1,
            is_active = CASE 
                WHEN usage_limit IS NOT NULL AND used_count + 1 >= usage_limit THEN false
                WHEN valid_until < CURRENT_TIMESTAMP THEN false
                ELSE is_active
            END
        WHERE code = NEW.coupon_code;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER coupon_usage_track
AFTER INSERT ON "Order"
FOR EACH ROW
WHEN (NEW.coupon_code IS NOT NULL)
EXECUTE FUNCTION track_coupon_usage();

-- Trigger to handle return status changes
CREATE OR REPLACE FUNCTION handle_return_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'approved' THEN
        NEW.approved_at = CURRENT_TIMESTAMP;
    ELSIF NEW.status = 'received' THEN
        NEW.received_at = CURRENT_TIMESTAMP;
        
        -- Return items to inventory
        UPDATE Product p
        SET stock = stock + ri.quantity
        FROM Return_Item ri
        WHERE ri.return_id = NEW.return_id 
        AND ri.product_id = p.product_id;
        
    ELSIF NEW.status = 'refunded' THEN
        NEW.refunded_at = CURRENT_TIMESTAMP;
        
        -- Update customer's total spent
        UPDATE Customer
        SET total_spent = total_spent - NEW.refund_amount
        WHERE customer_id = NEW.customer_id;
        
        -- Deduct loyalty points
        WITH point_deduction AS (
            SELECT FLOOR(NEW.refund_amount / 10) as points_to_deduct
        )
        UPDATE Customer
        SET 
            loyalty_points = loyalty_points - (SELECT points_to_deduct FROM point_deduction),
            tier_status = CASE 
                WHEN loyalty_points - (SELECT points_to_deduct FROM point_deduction) >= 5000 THEN 'platinum'
                WHEN loyalty_points - (SELECT points_to_deduct FROM point_deduction) >= 2000 THEN 'gold'
                WHEN loyalty_points - (SELECT points_to_deduct FROM point_deduction) >= 1000 THEN 'silver'
                ELSE 'bronze'
            END
        WHERE customer_id = NEW.customer_id;
        
        -- Log points deduction
        INSERT INTO Loyalty_Transaction (
            customer_id,
            points,
            action,
            transaction_date,
            reference_id
        ) VALUES (
            NEW.customer_id,
            -(SELECT FLOOR(NEW.refund_amount / 10)),
            'deduct_return',
            CURRENT_TIMESTAMP,
            NEW.return_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER return_status_change
BEFORE UPDATE ON Return
FOR EACH ROW
WHEN (NEW.status IS DISTINCT FROM OLD.status)
EXECUTE FUNCTION handle_return_status_change();

-- Enhanced audit logging for sensitive operations
CREATE OR REPLACE FUNCTION enhanced_audit_log()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Audit_Log (
        user_id,
        action,
        table_name,
        record_id,
        action_time,
        details
    ) VALUES (
        COALESCE(current_setting('app.current_user_id', true), NULL)::INTEGER,
        TG_OP,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id 
            ELSE NEW.id 
        END,
        CURRENT_TIMESTAMP,
        jsonb_build_object(
            'old_data', to_jsonb(OLD),
            'new_data', to_jsonb(NEW),
            'user_ip', current_setting('app.client_ip', true),
            'user_agent', current_setting('app.user_agent', true),
            'changes', CASE
                WHEN TG_OP = 'UPDATE' THEN (
                    SELECT jsonb_object_agg(key, value)
                    FROM jsonb_each(to_jsonb(NEW))
                    WHERE COALESCE(to_jsonb(NEW)->>key, '') != COALESCE(to_jsonb(OLD)->>key, '')
                )
                ELSE NULL
            END
        )
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply enhanced audit logging to sensitive tables
CREATE TRIGGER enhanced_audit_product_changes
AFTER INSERT OR UPDATE OR DELETE ON Product
FOR EACH ROW EXECUTE FUNCTION enhanced_audit_log();

CREATE TRIGGER enhanced_audit_price_changes
AFTER UPDATE ON Product
FOR EACH ROW
WHEN (NEW.price IS DISTINCT FROM OLD.price)
EXECUTE FUNCTION enhanced_audit_log();

CREATE TRIGGER enhanced_audit_coupon_changes
AFTER INSERT OR UPDATE OR DELETE ON Coupon
FOR EACH ROW EXECUTE FUNCTION enhanced_audit_log();

CREATE TRIGGER enhanced_audit_return_changes
AFTER INSERT OR UPDATE OR DELETE ON Return
FOR EACH ROW EXECUTE FUNCTION enhanced_audit_log();

COMMENT ON FUNCTION manage_variant_stock() IS 'Manages stock levels for product variants and creates alerts';
COMMENT ON FUNCTION manage_bundle_inventory() IS 'Handles inventory updates when bundles are purchased';
COMMENT ON FUNCTION manage_loyalty_points() IS 'Manages customer loyalty points and tier status';
COMMENT ON FUNCTION track_coupon_usage() IS 'Tracks coupon usage and updates coupon status';
COMMENT ON FUNCTION handle_return_status_change() IS 'Manages the return process workflow';
COMMENT ON FUNCTION enhanced_audit_log() IS 'Provides detailed audit logging for sensitive operations';
        'earn',
        CURRENT_TIMESTAMP
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER loyalty_points_update
AFTER INSERT ON "Order"
FOR EACH ROW
WHEN (NEW.status = 'completed')
EXECUTE FUNCTION manage_loyalty_points();




