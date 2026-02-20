-- 1. CLEANUP
DROP TABLE IF EXISTS predictions CASCADE;
DROP TABLE IF EXISTS inventory_logs CASCADE;
DROP TABLE IF EXISTS products CASCADE;

-- 2. CORE TABLES
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    sku VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100),
    category VARCHAR(50),
    stock_qty INT DEFAULT 0,
    reorder_level INT DEFAULT 10, -- Alert threshold
    unit_price DECIMAL(10, 2)
);

CREATE TABLE inventory_logs (
    log_id BIGSERIAL PRIMARY KEY,
    product_id INT REFERENCES products(product_id),
    change_amount INT, -- Positive for Restock, Negative for Picking
    reason VARCHAR(50), -- 'Sale', 'Restock', 'Damage'
    log_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE predictions (
    pred_id SERIAL PRIMARY KEY,
    product_id INT REFERENCES products(product_id),
    predicted_stock_next_week INT,
    risk_level VARCHAR(20), -- 'High', 'Medium', 'Low'
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. ADVANCED: REAL-TIME NOTIFICATION TRIGGER
-- If stock drops below reorder_level, Postgres sends a signal to the Kotlin App.
CREATE OR REPLACE FUNCTION check_stock_level()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stock_qty < NEW.reorder_level THEN
        -- Payload format: "SKU:CurrentQty"
        PERFORM pg_notify('stock_alert', NEW.sku || ':' || NEW.stock_qty);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_alert
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION check_stock_level();

-- 4. AUTOMATIC AUDIT LOGGING
-- Whenever stock changes, log it automatically.
CREATE OR REPLACE FUNCTION log_stock_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.stock_qty != NEW.stock_qty THEN
        INSERT INTO inventory_logs (product_id, change_amount, reason)
        VALUES (NEW.product_id, NEW.stock_qty - OLD.stock_qty, 'Manual Update');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_log
AFTER UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION log_stock_change();

-- 5. STORED PROCEDURE: BULK PROCESSING
CREATE OR REPLACE PROCEDURE process_shipment(p_sku VARCHAR, p_qty INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_id INT;
BEGIN
    SELECT product_id INTO v_id FROM products WHERE sku = p_sku;
    
    IF v_id IS NULL THEN
        RAISE NOTICE 'Product not found';
    ELSE
        UPDATE products SET stock_qty = stock_qty + p_qty WHERE product_id = v_id;
        -- Log specific reason
        INSERT INTO inventory_logs (product_id, change_amount, reason) 
        VALUES (v_id, p_qty, 'Bulk Shipment Received');
    END IF;
END;
$$;

-- 6. DATA SEEDING (Manual Creation)
INSERT INTO products (sku, name, category, stock_qty, reorder_level, unit_price) VALUES
('ELEC-001', 'Wireless Mouse', 'Electronics', 150, 20, 25.00),
('ELEC-002', 'Mechanical Keyboard', 'Electronics', 45, 10, 85.00),
('ELEC-003', 'USB-C Cable', 'Accessories', 200, 30, 9.99),
('HOME-001', 'Desk Lamp', 'Home', 12, 15, 45.50), -- Low stock!
('HOME-002', 'Ergonomic Chair', 'Furniture', 5, 8, 250.00); -- Critical!

-- Generate history for ML training
INSERT INTO inventory_logs (product_id, change_amount, reason, log_timestamp)
SELECT 
    1, 
    floor(random() * -5 - 1), 
    'Sale', 
    NOW() - (i || ' days')::interval
FROM generate_series(1, 60) i; -- 60 days of sales history for Mouse