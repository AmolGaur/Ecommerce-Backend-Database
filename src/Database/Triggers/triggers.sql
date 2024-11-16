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




