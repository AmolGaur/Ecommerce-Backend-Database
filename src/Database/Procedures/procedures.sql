-- Enable pgcrypto extension if needed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Stored procedure to process an order, verifying stock and updating inventory
CREATE OR REPLACE FUNCTION process_order(
    p_customer_id INTEGER,
    p_order_items JSONB,
    p_shipping_address_id INTEGER,
    p_billing_address_id INTEGER DEFAULT NULL,
    p_shipping_method VARCHAR(50) DEFAULT 'standard'
) RETURNS INTEGER AS $$
DECLARE
    item RECORD;
    total_price DECIMAL(10, 2) := 0;
    retry_count INT := 0;
    max_retries INT := 3;
BEGIN
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    WHILE retry_count < max_retries LOOP
        BEGIN
            -- Iterate through the JSON array of order items
            FOR item IN SELECT * FROM jsonb_array_elements(order_items) LOOP
                -- Check stock availability
                IF (SELECT stock FROM Product WHERE product_id = item->>'product_id') < (item->>'quantity')::INTEGER THEN
                    RAISE EXCEPTION 'Insufficient stock for product ID %', item->>'product_id';
                END IF;

                -- Calculate total cost for the item
                total_price := total_price + ((item->>'quantity')::DECIMAL * (SELECT price FROM Product WHERE product_id = item->>'product_id'));

                -- Deduct stock
                UPDATE Product
                SET stock = stock - (item->>'quantity')::INTEGER
                WHERE product_id = item->>'product_id';

                -- Log inventory change
                INSERT INTO Inventory_Log (product_id, change)
                VALUES ((item->>'product_id')::INTEGER, -(item->>'quantity')::INTEGER);
            END LOOP;

            -- Insert new order
            INSERT INTO "Order" (customer_id, order_date, total_price)
            VALUES (customer_id, NOW(), total_price);

            COMMIT; -- Commit transaction if all operations succeed
            EXIT; -- Exit loop if transaction was successful

        EXCEPTION WHEN deadlock_detected THEN
            -- Handle deadlock: increment retry count, wait briefly, and retry
            retry_count := retry_count + 1;
            PERFORM pg_sleep(1); -- Wait before retrying
            ROLLBACK; -- Rollback transaction on deadlock
        WHEN OTHERS THEN
            ROLLBACK; -- Rollback transaction for any other error
            RAISE EXCEPTION 'Order processing failed: %', SQLERRM;
        END;
    END LOOP;

    -- If maximum retries are reached, raise an exception
    IF retry_count = max_retries THEN
        RAISE EXCEPTION 'Order processing failed after % attempts', max_retries;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- PROCESS PAYMENT
CREATE OR REPLACE FUNCTION process_payment(customer_id INTEGER, order_id INTEGER, payment_amount DECIMAL)
RETURNS VOID AS $$
DECLARE
    retry_count INT := 0;
    max_retries INT := 3;
BEGIN
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    WHILE retry_count < max_retries LOOP
        BEGIN
            -- Check if the payment amount matches the order total
            IF payment_amount <> (SELECT total_price FROM "Order" WHERE order_id = order_id) THEN
                RAISE EXCEPTION 'Payment amount does not match order total';
            END IF;

            -- Insert payment record
            INSERT INTO Payment (payment_date, payment_method, amount, customer_id)
            VALUES (NOW(), 'credit_card', payment_amount, customer_id);

            -- Update customer total spent
            UPDATE Customer
            SET total_spent = total_spent + payment_amount
            WHERE customer_id = customer_id;

            -- Mark order as paid (additional status column might be needed in Order table)
            UPDATE "Order"
            SET status = 'paid'
            WHERE order_id = order_id;

            COMMIT; -- Commit transaction if all operations succeed
            EXIT; -- Exit loop if transaction was successful

        EXCEPTION WHEN deadlock_detected THEN
            -- Handle deadlock: increment retry count, wait briefly, and retry
            retry_count := retry_count + 1;
            PERFORM pg_sleep(1); -- Wait before retrying
            ROLLBACK; -- Rollback transaction on deadlock
        WHEN OTHERS THEN
            ROLLBACK; -- Rollback transaction for any other error
            RAISE EXCEPTION 'Payment processing failed: %', SQLERRM;
        END;
    END LOOP;

    -- If maximum retries are reached, raise an exception
    IF retry_count = max_retries THEN
        RAISE EXCEPTION 'Payment processing failed after % attempts', max_retries;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Stored procedure to restock a product and log the restocking
CREATE OR REPLACE FUNCTION restock_product(product_id INTEGER, quantity INTEGER)
RETURNS VOID AS $$
BEGIN
    UPDATE Product
    SET stock = stock + quantity
    WHERE product_id = product_id;

    INSERT INTO Inventory_Log (product_id, change)
    VALUES (product_id, quantity);
END;
$$ LANGUAGE plpgsql;

-- Stored procedure to generate a daily revenue report
CREATE OR REPLACE FUNCTION get_daily_revenue_report(report_date DATE)
RETURNS TABLE(total_revenue DECIMAL(10, 2)) AS $$
BEGIN
    RETURN QUERY
    SELECT SUM(total_price) AS total_revenue
    FROM "Order"
    WHERE DATE(order_date) = report_date;
END;
$$ LANGUAGE plpgsql;

-- Stored procedure to generate a monthly sales report
CREATE OR REPLACE FUNCTION generate_monthly_sales_report(report_month DATE)
RETURNS TABLE(total_revenue DECIMAL(10, 2), total_orders INT, top_product INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        SUM(total_price) AS total_revenue,
        COUNT(order_id) AS total_orders,
        (SELECT product_id FROM Order_Item GROUP BY product_id ORDER BY SUM(quantity) DESC LIMIT 1) AS top_product
    FROM "Order"
    WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', report_month);
END;
$$ LANGUAGE plpgsql;

-- Procedure to calculate revenue over time (monthly or daily)
CREATE OR REPLACE FUNCTION calculate_revenue_over_time(interval_type VARCHAR)
RETURNS TABLE(time_period DATE, total_revenue DECIMAL(10, 2)) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE 
            WHEN interval_type = 'daily' THEN DATE_TRUNC('day', order_date)
            WHEN interval_type = 'monthly' THEN DATE_TRUNC('month', order_date)
        END AS time_period,
        SUM(total_price) AS total_revenue
    FROM "Order"
    GROUP BY time_period
    ORDER BY time_period;
END;
$$ LANGUAGE plpgsql;

-- Procedure to perform cohort analysis based on first purchase month
CREATE OR REPLACE FUNCTION cohort_analysis()
RETURNS TABLE(cohort_month DATE, customer_count INT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE_TRUNC('month', MIN(order_date)) AS cohort_month,
        COUNT(DISTINCT customer_id) AS customer_count
    FROM "Order"
    GROUP BY cohort_month
    ORDER BY cohort_month;
END;
$$ LANGUAGE plpgsql;

-- Procedure to get top-selling products over a specified period
CREATE OR REPLACE FUNCTION top_selling_products(start_date DATE, end_date DATE)
RETURNS TABLE(product_id INTEGER, total_quantity_sold INT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        product_id,
        SUM(quantity) AS total_quantity_sold
    FROM Order_Item
    JOIN "Order" ON Order_Item.order_id = "Order".order_id
    WHERE order_date BETWEEN start_date AND end_date
    GROUP BY product_id
    ORDER BY total_quantity_sold DESC;
END;
$$ LANGUAGE plpgsql;

-- Procedure to find frequently bundled products
CREATE OR REPLACE FUNCTION frequently_bundled_products()
RETURNS TABLE(product_1 INTEGER, product_2 INTEGER, bundle_count INT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        oi1.product_id AS product_1,
        oi2.product_id AS product_2,
        COUNT(*) AS bundle_count
    FROM Order_Item oi1
    JOIN Order_Item oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id < oi2.product_id
    GROUP BY product_1, product_2
    HAVING COUNT(*) > 1
    ORDER BY bundle_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Procedure to manage product variants
CREATE OR REPLACE FUNCTION manage_product_variant(
    p_product_id INTEGER,
    p_variant_name VARCHAR(255),
    p_attributes JSONB,
    p_price_adjustment DECIMAL(10, 2),
    p_stock INTEGER,
    p_action VARCHAR(10)
) RETURNS INTEGER AS $$
DECLARE
    v_variant_id INTEGER;
BEGIN
    CASE p_action
        WHEN 'create' THEN
            INSERT INTO Product_Variant (
                product_id,
                variant_name,
                attributes,
                price_adjustment,
                stock
            ) VALUES (
                p_product_id,
                p_variant_name,
                p_attributes,
                p_price_adjustment,
                p_stock
            ) RETURNING variant_id INTO v_variant_id;
            
            RETURN v_variant_id;
            
        WHEN 'update' THEN
            UPDATE Product_Variant
            SET
                variant_name = p_variant_name,
                attributes = p_attributes,
                price_adjustment = p_price_adjustment,
                stock = p_stock,
                updated_at = CURRENT_TIMESTAMP
            WHERE product_id = p_product_id AND variant_name = p_variant_name
            RETURNING variant_id INTO v_variant_id;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Variant not found';
            END IF;
            
            RETURN v_variant_id;
            
        ELSE
            RAISE EXCEPTION 'Invalid action';
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Procedure to manage product bundles
CREATE OR REPLACE FUNCTION manage_product_bundle(
    p_name VARCHAR(255),
    p_description TEXT,
    p_discount_percentage DECIMAL(5, 2),
    p_products JSONB,
    p_action VARCHAR(10)
) RETURNS INTEGER AS $$
DECLARE
    v_bundle_id INTEGER;
    v_product RECORD;
BEGIN
    CASE p_action
        WHEN 'create' THEN
            -- Create bundle
            INSERT INTO Product_Bundle (
                name,
                description,
                discount_percentage,
                is_active,
                valid_from,
                valid_until
            ) VALUES (
                p_name,
                p_description,
                p_discount_percentage,
                true,
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP + INTERVAL '1 year'
            ) RETURNING bundle_id INTO v_bundle_id;
            
            -- Add products to bundle
            FOR v_product IN SELECT * FROM jsonb_array_elements(p_products) LOOP
                INSERT INTO Bundle_Item (
                    bundle_id,
                    product_id,
                    quantity
                ) VALUES (
                    v_bundle_id,
                    (v_product->>'product_id')::INTEGER,
                    COALESCE((v_product->>'quantity')::INTEGER, 1)
                );
            END LOOP;
            
            RETURN v_bundle_id;
            
        WHEN 'update' THEN
            -- Update bundle
            UPDATE Product_Bundle
            SET
                name = p_name,
                description = p_description,
                discount_percentage = p_discount_percentage,
                updated_at = CURRENT_TIMESTAMP
            WHERE name = p_name
            RETURNING bundle_id INTO v_bundle_id;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Bundle not found';
            END IF;
            
            -- Remove existing items
            DELETE FROM Bundle_Item WHERE bundle_id = v_bundle_id;
            
            -- Add updated products
            FOR v_product IN SELECT * FROM jsonb_array_elements(p_products) LOOP
                INSERT INTO Bundle_Item (
                    bundle_id,
                    product_id,
                    quantity
                ) VALUES (
                    v_bundle_id,
                    (v_product->>'product_id')::INTEGER,
                    COALESCE((v_product->>'quantity')::INTEGER, 1)
                );
            END LOOP;
            
            RETURN v_bundle_id;
            
        ELSE
            RAISE EXCEPTION 'Invalid action';
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Procedure to validate and apply coupon
CREATE OR REPLACE FUNCTION apply_coupon(
    p_order_id INTEGER,
    p_coupon_code VARCHAR(50)
) RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_coupon RECORD;
    v_order_total DECIMAL(10, 2);
    v_discount_amount DECIMAL(10, 2) := 0;
BEGIN
    -- Get coupon details
    SELECT * INTO v_coupon
    FROM Coupon
    WHERE code = p_coupon_code
    AND is_active = true
    AND valid_from <= CURRENT_TIMESTAMP
    AND valid_until >= CURRENT_TIMESTAMP
    AND (usage_limit IS NULL OR used_count < usage_limit);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired coupon code';
    END IF;

    -- Get order total
    SELECT total_price INTO v_order_total
    FROM "Order"
    WHERE order_id = p_order_id;

    -- Validate minimum purchase amount
    IF v_coupon.min_purchase_amount IS NOT NULL AND v_order_total < v_coupon.min_purchase_amount THEN
        RAISE EXCEPTION 'Order total does not meet minimum purchase requirement';
    END IF;

    -- Calculate discount
    CASE v_coupon.type
        WHEN 'percentage' THEN
            v_discount_amount := v_order_total * (v_coupon.value / 100);
        WHEN 'fixed' THEN
            v_discount_amount := v_coupon.value;
        WHEN 'buy_x_get_y' THEN
            -- Implementation for buy X get Y logic
            v_discount_amount := calculate_buy_x_get_y_discount(p_order_id, v_coupon.applies_to);
        WHEN 'free_shipping' THEN
            SELECT shipping_cost INTO v_discount_amount
            FROM "Order"
            WHERE order_id = p_order_id;
    END CASE;

    -- Apply maximum discount limit if exists
    IF v_coupon.max_discount_amount IS NOT NULL THEN
        v_discount_amount := LEAST(v_discount_amount, v_coupon.max_discount_amount);
    END IF;

    -- Update order with discount
    UPDATE "Order"
    SET
        discount_amount = v_discount_amount,
        coupon_code = p_coupon_code,
        total_price = v_order_total - v_discount_amount
    WHERE order_id = p_order_id;

    -- Update coupon usage count
    UPDATE Coupon
    SET used_count = used_count + 1
    WHERE code = p_coupon_code;

    RETURN v_discount_amount;
END;
$$ LANGUAGE plpgsql;

-- Helper function to calculate buy X get Y discount
CREATE OR REPLACE FUNCTION calculate_buy_x_get_y_discount(
    p_order_id INTEGER,
    p_applies_to JSONB
) RETURNS DECIMAL(10, 2) AS $$
DECLARE
    v_discount DECIMAL(10, 2) := 0;
    v_item RECORD;
BEGIN
    -- Implementation depends on the structure of applies_to JSONB
    -- Example: {"buy": 2, "get": 1, "discount_percent": 100, "category_id": 1}
    -- This is a placeholder for the actual implementation
    RETURN v_discount;
END;
$$ LANGUAGE plpgsql;

-- Procedure to manage loyalty points
CREATE OR REPLACE FUNCTION manage_loyalty_points(
    p_customer_id INTEGER,
    p_action VARCHAR(10),
    p_points INTEGER,
    p_order_id INTEGER DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_current_points INTEGER;
    v_new_points INTEGER;
    v_tier_status VARCHAR(20);
BEGIN
    -- Get current points
    SELECT loyalty_points INTO v_current_points
    FROM Customer
    WHERE customer_id = p_customer_id;

    -- Calculate new points based on action
    CASE p_action
        WHEN 'earn' THEN
            v_new_points := v_current_points + p_points;
        WHEN 'redeem' THEN
            IF v_current_points < p_points THEN
                RAISE EXCEPTION 'Insufficient loyalty points';
            END IF;
            v_new_points := v_current_points - p_points;
        ELSE
            RAISE EXCEPTION 'Invalid action';
    END CASE;

    -- Determine new tier status
    v_tier_status := CASE
        WHEN v_new_points >= 5000 THEN 'platinum'
        WHEN v_new_points >= 2000 THEN 'gold'
        WHEN v_new_points >= 1000 THEN 'silver'
        ELSE 'bronze'
    END;

    -- Update customer points and tier
    UPDATE Customer
    SET
        loyalty_points = v_new_points,
        tier_status = v_tier_status
    WHERE customer_id = p_customer_id;

    -- Log points transaction if order_id provided
    IF p_order_id IS NOT NULL THEN
        INSERT INTO Loyalty_Transaction (
            customer_id,
            order_id,
            points,
            action,
            transaction_date
        ) VALUES (
            p_customer_id,
            p_order_id,
            p_points,
            p_action,
            CURRENT_TIMESTAMP
        );
    END IF;

    RETURN v_new_points;
END;
$$ LANGUAGE plpgsql;

-- Procedure to process product returns and refunds
CREATE OR REPLACE FUNCTION process_return(
    p_order_id INTEGER,
    p_customer_id INTEGER,
    p_items JSONB,
    p_reason TEXT
) RETURNS INTEGER AS $$
DECLARE
    v_return_id INTEGER;
    v_refund_amount DECIMAL(10, 2) := 0;
    v_item RECORD;
BEGIN
    -- Create return record
    INSERT INTO Return (order_id, customer_id, reason, status)
    VALUES (p_order_id, p_customer_id, p_reason, 'requested')
    RETURNING return_id INTO v_return_id;

    -- Process each return item
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        -- Calculate refund amount
        SELECT (oi.unit_price * (v_item->>'quantity')::INTEGER)
        INTO v_refund_amount
        FROM Order_Item oi
        WHERE oi.order_id = p_order_id
        AND oi.product_id = (v_item->>'product_id')::INTEGER;

        -- Insert return items
        INSERT INTO Return_Item (
            return_id,
            product_id,
            quantity,
            reason
        ) VALUES (
            v_return_id,
            (v_item->>'product_id')::INTEGER,
            (v_item->>'quantity')::INTEGER,
            (v_item->>'reason')::TEXT
        );
    END LOOP;

    -- Update return record with refund amount
    UPDATE Return
    SET refund_amount = v_refund_amount
    WHERE return_id = v_return_id;

    RETURN v_return_id;
END;
$$ LANGUAGE plpgsql;
