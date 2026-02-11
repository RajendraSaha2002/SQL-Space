-- 1. CLEANUP
DROP TABLE IF EXISTS inventory_alerts CASCADE;
DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;

-- 2. SCHEMA DEFINITION

CREATE TABLE warehouses (
    warehouse_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    location_code VARCHAR(10), -- e.g., 'US-EAST-1'
    capacity INT,
    manager_name VARCHAR(100)
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    sku VARCHAR(50) UNIQUE,
    name VARCHAR(100),
    category VARCHAR(50),
    unit_cost DECIMAL(10, 2),
    selling_price DECIMAL(10, 2),
    reorder_point INT, -- Min stock level before alert
    reorder_qty INT -- How much to order
);

CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    warehouse_id INT REFERENCES warehouses(warehouse_id),
    product_id INT REFERENCES products(product_id),
    quantity_on_hand INT,
    last_restock_date TIMESTAMP,
    UNIQUE(warehouse_id, product_id)
);

CREATE TABLE stock_movements (
    movement_id BIGSERIAL PRIMARY KEY,
    product_id INT,
    warehouse_id INT,
    movement_type VARCHAR(20), -- 'INBOUND', 'OUTBOUND', 'RETURN'
    quantity INT,
    movement_date TIMESTAMP DEFAULT NOW()
);

CREATE TABLE inventory_alerts (
    alert_id SERIAL PRIMARY KEY,
    warehouse_id INT,
    product_id INT,
    alert_type VARCHAR(50), -- 'LOW_STOCK', 'OVERSTOCK'
    message TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 3. INDEXING (For speed on millions of rows)
CREATE INDEX idx_inv_wh_prod ON inventory(warehouse_id, product_id);
CREATE INDEX idx_movements_date ON stock_movements(movement_date);

-- 4. INTELLIGENT TRIGGER: AUTO-REORDER SYSTEM
-- Triggers when stock drops below 'reorder_point'
CREATE OR REPLACE FUNCTION check_stock_levels()
RETURNS TRIGGER AS $$
DECLARE
    min_level INT;
    prod_sku VARCHAR;
BEGIN
    -- Get product reorder settings
    SELECT reorder_point, sku INTO min_level, prod_sku 
    FROM products WHERE product_id = NEW.product_id;

    -- Check if we are in danger zone
    IF NEW.quantity_on_hand < min_level THEN
        INSERT INTO inventory_alerts (warehouse_id, product_id, alert_type, message)
        VALUES (NEW.warehouse_id, NEW.product_id, 'CRITICAL_LOW', 
                'SKU ' || prod_sku || ' is below threshold. Current: ' || NEW.quantity_on_hand);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_check
AFTER UPDATE ON inventory
FOR EACH ROW
EXECUTE FUNCTION check_stock_levels();

-- 5. ANALYTIC VIEW: INVENTORY TURNOVER & DEMAND
-- Calculates how fast items are moving (Velocity)
CREATE OR REPLACE VIEW v_stock_velocity AS
SELECT 
    p.name as product_name,
    w.location_code,
    i.quantity_on_hand,
    -- Calculate Sales Velocity (Outbound items in last 30 days)
    COALESCE(SUM(CASE WHEN sm.movement_type = 'OUTBOUND' THEN sm.quantity ELSE 0 END), 0) as monthly_sales,
    -- Days Inventory Outstanding (DIO) Logic
    CASE 
        WHEN COALESCE(SUM(CASE WHEN sm.movement_type = 'OUTBOUND' THEN sm.quantity ELSE 0 END), 0) = 0 THEN 999 
        ELSE (i.quantity_on_hand / NULLIF(SUM(CASE WHEN sm.movement_type = 'OUTBOUND' THEN sm.quantity ELSE 0 END), 0)) * 30
    END as days_of_supply
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN warehouses w ON i.warehouse_id = w.warehouse_id
LEFT JOIN stock_movements sm ON i.product_id = sm.product_id 
    AND i.warehouse_id = sm.warehouse_id 
    AND sm.movement_date > NOW() - INTERVAL '30 days'
GROUP BY p.name, w.location_code, i.quantity_on_hand
ORDER BY monthly_sales DESC;