-- Enable pgcrypto extension if needed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Stored procedure to process an order, verifying stock and updating inventory
CREATE OR REPLACE FUNCTION process_order(customer_id INTEGER, order_items JSONB)
RETURNS VOID AS $$
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
