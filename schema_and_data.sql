-- 1. CLEANUP
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS daily_revenue_summary CASCADE;

-- 2. SCHEMA DEFINITION

-- Dimension: Customers
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    segment VARCHAR(50), -- e.g., Enterprise, SMB, Consumer
    region VARCHAR(50),
    joined_date DATE DEFAULT CURRENT_DATE
);

-- Dimension: Products
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    category VARCHAR(50),
    cost_price DECIMAL(10, 2),
    selling_price DECIMAL(10, 2)
);

-- Fact: Orders
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    order_date DATE,
    status VARCHAR(20) -- Completed, Returned
);

-- Fact: Order Items (The detailed transaction log)
CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(order_id),
    product_id INT REFERENCES products(product_id),
    quantity INT,
    total_price DECIMAL(10, 2)
);

-- Table for Trigger Target: Pre-calculated revenue table
CREATE TABLE daily_revenue_summary (
    summary_date DATE PRIMARY KEY,
    total_revenue DECIMAL(15, 2) DEFAULT 0.00,
    order_count INT DEFAULT 0
);

-- 3. INDEXING (For Performance on large datasets)
CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_items_product ON order_items(product_id);

-- 4. ADVANCED: DATABASE TRIGGER
-- Automate revenue updates. When an order item is added, update the daily summary.
CREATE OR REPLACE FUNCTION update_daily_revenue()
RETURNS TRIGGER AS $$
DECLARE
    ord_date DATE;
BEGIN
    -- Get the date of the order
    SELECT order_date INTO ord_date FROM orders WHERE order_id = NEW.order_id;
    
    -- Upsert (Insert or Update) logic
    INSERT INTO daily_revenue_summary (summary_date, total_revenue, order_count)
    VALUES (ord_date, NEW.total_price, 1)
    ON CONFLICT (summary_date) 
    DO UPDATE SET 
        total_revenue = daily_revenue_summary.total_revenue + EXCLUDED.total_revenue,
        order_count = daily_revenue_summary.order_count + 1;
        
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_revenue
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION update_daily_revenue();

-- 5. ANALYTICAL VIEW (KPIs)
CREATE OR REPLACE VIEW v_monthly_kpis AS
SELECT 
    TO_CHAR(o.order_date, 'YYYY-MM') as month,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(oi.total_price) as gross_revenue,
    SUM(oi.total_price - (p.cost_price * oi.quantity)) as gross_profit,
    ROUND((SUM(oi.total_price - (p.cost_price * oi.quantity)) / SUM(oi.total_price) * 100), 2) as margin_percentage
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY TO_CHAR(o.order_date, 'YYYY-MM')
ORDER BY month;

-- 6. DATA GENERATION (Mocking Data)
-- Insert Products
INSERT INTO products (name, category, cost_price, selling_price) VALUES
('ERP License (Annual)', 'Software', 2000, 5000),
('Cloud Storage 1TB', 'Services', 50, 120),
('Analytics Plugin', 'Software', 100, 500),
('Consulting Hour', 'Services', 80, 200),
('Dedicated Server', 'Hardware', 1500, 2200);

-- Insert Customers (Generating 50 random customers)
INSERT INTO customers (name, segment, region, joined_date)
SELECT 
    'Customer ' || generate_series,
    (ARRAY['Enterprise', 'SMB', 'Startup'])[floor(random() * 3 + 1)],
    (ARRAY['NA', 'EMEA', 'APAC'])[floor(random() * 3 + 1)],
    CURRENT_DATE - (floor(random() * 365) || ' days')::interval
FROM generate_series(1, 50);

-- Insert Orders & Items (Generating 500 orders)
DO $$
DECLARE
    o_id INT;
    c_id INT;
    p_id INT;
    qty INT;
    price DECIMAL;
BEGIN
    FOR i IN 1..500 LOOP
        -- Create Order
        INSERT INTO orders (customer_id, order_date, status)
        VALUES (
            floor(random() * 50 + 1),
            CURRENT_DATE - (floor(random() * 365) || ' days')::interval,
            'Completed'
        ) RETURNING order_id INTO o_id;

        -- Create Order Item (Trigger will fire here automatically)
        p_id := floor(random() * 5 + 1);
        qty := floor(random() * 5 + 1);
        SELECT selling_price * qty INTO price FROM products WHERE product_id = p_id;
        
        INSERT INTO order_items (order_id, product_id, quantity, total_price)
        VALUES (o_id, p_id, qty, price);
    END LOOP;
END $$;