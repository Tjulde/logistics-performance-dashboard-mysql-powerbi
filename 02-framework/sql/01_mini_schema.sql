-- =====================================================================
-- Khass Designs and Prints | Logistics Analytics Project (COMPACT DATASET)
-- 01_mini_schema.sql  -  creates database khass_logistics_mini (MySQL 8.0+)
-- NOTE: all data in this project is SIMULATED for portfolio purposes.
-- =====================================================================
DROP DATABASE IF EXISTS khass_logistics_mini;
CREATE DATABASE khass_logistics_mini CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE khass_logistics_mini;

-- ---------- dimensions ----------
CREATE TABLE locations (
    location_id  TINYINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    city         VARCHAR(30) NOT NULL,
    state        VARCHAR(30) NOT NULL,
    role         VARCHAR(40) NOT NULL
);

CREATE TABLE customers (
    customer_id    INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_name  VARCHAR(80) NOT NULL,
    customer_type  ENUM('Student Association','Department','Faculty','Individual') NOT NULL,
    location_id    TINYINT NOT NULL,
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

CREATE TABLE suppliers (
    supplier_id            INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    supplier_name          VARCHAR(80) NOT NULL,
    city                   VARCHAR(30) NOT NULL,
    location_id            TINYINT NOT NULL,
    category               VARCHAR(40) NOT NULL,
    sourcing_channel       VARCHAR(30) NOT NULL,      -- how the supplier was found
    onboarded_date         DATE NOT NULL,
    vetting_decision_date  DATE NOT NULL,             -- date supplier was approved or rejected
    status                 ENUM('Trusted','Rejected') NOT NULL,
    trust_score            DECIMAL(3,1) NOT NULL,
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
);

CREATE TABLE carriers (
    carrier_id    TINYINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    carrier_name  VARCHAR(60) NOT NULL,
    carrier_type  VARCHAR(30) NOT NULL,
    active_from   DATE NOT NULL,
    active_to     DATE NULL
);

CREATE TABLE products (
    product_id          TINYINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    product_name        VARCHAR(60) NOT NULL,
    supplier_category   VARCHAR(40) NOT NULL,
    unit                VARCHAR(10) NOT NULL,
    unit_cost_ngn       INT NOT NULL,
    reorder_level       INT NOT NULL,
    weight_kg_per_unit  DECIMAL(6,2) NOT NULL
);

-- ---------- facts ----------
CREATE TABLE orders (
    order_id             INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    customer_id          INT NOT NULL,
    project_type         VARCHAR(30) NOT NULL,
    product_id           TINYINT NOT NULL,
    qty                  INT NOT NULL,
    material_qty         DECIMAL(10,2) NOT NULL,
    order_value_ngn      INT NOT NULL,
    order_ts             DATETIME NOT NULL,
    promised_ts          DATETIME NOT NULL,
    materials_ready_ts   DATETIME NULL,
    production_start_ts  DATETIME NULL,
    production_end_ts    DATETIME NULL,
    delivered_ts         DATETIME NULL,
    destination_id       TINYINT NOT NULL,
    material_wait_hours  DECIMAL(6,1) NULL,   -- order confirmed -> materials available in Lapai
    queue_hours          DECIMAL(6,1) NULL,   -- materials available -> production start
    delay_reason         VARCHAR(30) NULL,
    status               ENUM('Delivered','In Transit','In Production') NOT NULL,
    FOREIGN KEY (customer_id)    REFERENCES customers(customer_id),
    FOREIGN KEY (product_id)     REFERENCES products(product_id),
    FOREIGN KEY (destination_id) REFERENCES locations(location_id),
    INDEX idx_orders_ts (order_ts)
);

CREATE TABLE purchase_orders (
    po_id                  INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    supplier_id            INT NOT NULL,
    product_id             TINYINT NOT NULL,
    po_date                DATE NOT NULL,
    qty_requested          DECIMAL(10,1) NOT NULL,
    qty_received           DECIMAL(10,1) NULL,
    unit_cost_ngn          INT NOT NULL,
    supplier_promised_ts   DATETIME NOT NULL,
    supplier_dispatch_ts   DATETIME NOT NULL,
    vetted_at_order        TINYINT NOT NULL,  -- 1 = supplier was already a vetted/trusted supplier
    status                 ENUM('Received','In Transit') NOT NULL,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id),
    FOREIGN KEY (product_id)  REFERENCES products(product_id),
    INDEX idx_po_date (po_date)
);

CREATE TABLE shipments (
    shipment_id                   INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    shipment_type                 ENUM('Inbound','Outbound') NOT NULL,  -- Inbound = materials to Lapai, Outbound = finished orders
    order_id                      INT NULL,
    po_id                         INT NULL,
    carrier_id                    TINYINT NOT NULL,
    origin_id                     TINYINT NOT NULL,
    destination_id                TINYINT NOT NULL,
    dispatch_ts                   DATETIME NOT NULL,
    arrival_ts                    DATETIME NULL,
    weight_kg                     DECIMAL(10,1) NOT NULL,
    freight_cost_ngn              INT NOT NULL,
    handling_cost_ngn             INT NOT NULL,
    scheduled_to_production_slot  TINYINT NULL,   -- inbound only: 1 = shipment timed to a production slot
    status                        ENUM('Delivered','In Transit') NOT NULL,
    FOREIGN KEY (order_id)       REFERENCES orders(order_id),
    FOREIGN KEY (po_id)          REFERENCES purchase_orders(po_id),
    FOREIGN KEY (carrier_id)     REFERENCES carriers(carrier_id),
    FOREIGN KEY (origin_id)      REFERENCES locations(location_id),
    FOREIGN KEY (destination_id) REFERENCES locations(location_id),
    INDEX idx_ship_dispatch (dispatch_ts)
);

CREATE TABLE inventory_snapshots (
    snapshot_id    INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    month_end      DATE NOT NULL,
    product_id     TINYINT NOT NULL,
    opening_qty    DECIMAL(10,2) NOT NULL,
    received_qty   DECIMAL(10,2) NOT NULL,
    demand_qty     DECIMAL(10,2) NOT NULL,
    consumed_qty   DECIMAL(10,2) NOT NULL,
    closing_qty    DECIMAL(10,2) NOT NULL,
    stockout_days  TINYINT NOT NULL,
    reorder_level  INT NOT NULL,
    below_reorder  TINYINT NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    UNIQUE KEY uq_snapshot (month_end, product_id)
);

-- ---------- date dimension (Jan 2024 -> Dec 2026) ----------
CREATE TABLE dim_date (
    date_key           DATE PRIMARY KEY,
    year_num           SMALLINT NOT NULL,
    quarter_num        TINYINT  NOT NULL,
    month_num          TINYINT  NOT NULL,
    month_name         VARCHAR(10) NOT NULL,
    year_month_label   CHAR(7)  NOT NULL,          -- e.g. 2025-03
    month_start        DATE     NOT NULL,
    is_complete_month  TINYINT  NOT NULL,          -- 0 for October 2026 (data stops 15 Oct)
    period_label       VARCHAR(30) NOT NULL        -- Baseline / Current / Transition
);

SET SESSION cte_max_recursion_depth = 2000;   -- default 1000 is too low for ~1,100 days

INSERT INTO dim_date
WITH RECURSIVE d AS (
    SELECT DATE('2024-01-01') AS dt
    UNION ALL
    SELECT dt + INTERVAL 1 DAY FROM d WHERE dt < '2026-12-31'
)
SELECT dt,
       YEAR(dt), QUARTER(dt), MONTH(dt), MONTHNAME(dt),
       DATE_FORMAT(dt, '%Y-%m'),
       DATE_FORMAT(dt, '%Y-%m-01'),
       CASE WHEN dt >= '2026-10-01' THEN 0 ELSE 1 END,
       CASE WHEN dt <  '2024-07-01' THEN 'Baseline (Jan-Jun 2024)'
            WHEN dt >= '2026-04-01' AND dt < '2026-10-01' THEN 'Current (Apr-Sep 2026)'
            ELSE 'Transition' END
FROM d;
