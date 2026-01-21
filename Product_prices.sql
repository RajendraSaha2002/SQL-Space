CREATE DATABASE shopdb;
USE shopdb;

CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(50),
    price INT
);

CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    quantity INT,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO products (product_name, price) VALUES
('Laptop', 60000),
('Mouse', 500),
('Keyboard', 1500);

INSERT INTO orders (product_id, quantity) VALUES
(1, 2),
(2, 5),
(3, 1);

-- Join output
SELECT o.order_id, p.product_name, p.price, o.quantity,
       (p.price * o.quantity) AS total_price
FROM orders o
JOIN products p ON o.product_id = p.product_id;
