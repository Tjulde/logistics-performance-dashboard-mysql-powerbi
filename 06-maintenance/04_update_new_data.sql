-- =====================================================================
-- Khass Logistics | 04_update_new_data.sql  -  ADD / UPDATE YOUR OWN DATA
-- Database: khass_logistics_mini (MySQL 8.0+)
--
-- HOW TO USE
--  * The values below are EXAMPLES. Edit them, then run ONE numbered step at a time
--    (select the statements in MySQL Workbench and press Ctrl+Enter). Do not run the whole file.
--  * Keep every step in the SAME query tab/connection: steps use @oid / @poid variables.
--  * IDs are AUTO_INCREMENT: leave the ID column out of INSERTs and MySQL assigns the next one.
--    If you built the database BEFORE this fix, run STEP 0B once (carriers, products and locations were missing it).
--  * Allowed values (spelled exactly):
--      orders.status ........ 'In Production' | 'In Transit' | 'Delivered'
--      shipments.status ..... 'In Transit' | 'Delivered'          shipment_type: 'Inbound' | 'Outbound'
--      purchase_orders.status 'In Transit' | 'Received'
--      customer_type ........ 'Student Association' | 'Department' | 'Faculty' | 'Individual'
--      delay_reason ......... 'Material delay' | 'Carrier delay' | 'Production backlog' | 'Customer change'
--      project_type ......... 'Posters & Banners' | 'Magic cups' | 'Shirt branding' | 'Flyers' | 'Business cards' |
--                             'Invitation cards' | 'Gift boxes' | 'Paper bags' | 'Jotters' | 'Screen printing' | 'General printing'
--  * After updating, run STEP 7 (checks), then refresh Power BI (see the bottom of this file).
-- =====================================================================
USE khass_logistics_mini;

-- ---------------------------------------------------------------------
-- STEP 0. Look up IDs you need for the INSERTs below
-- ---------------------------------------------------------------------
SELECT location_id, city FROM locations;                               -- 1 Lagos, 2 Lapai, 3 Minna, 4 Abuja
SELECT carrier_id, carrier_name FROM carriers;
SELECT product_id, product_name, unit, reorder_level FROM products;
SELECT supplier_id, supplier_name, city, category, status FROM suppliers;
SELECT customer_id, customer_name, customer_type FROM customers;
SELECT 'orders' AS tbl, COALESCE(MAX(order_id), 0) + 1 AS next_id FROM orders
UNION ALL SELECT 'purchase_orders', COALESCE(MAX(po_id), 0) + 1 FROM purchase_orders
UNION ALL SELECT 'shipments',       COALESCE(MAX(shipment_id), 0) + 1 FROM shipments;

-- ---------------------------------------------------------------------
-- STEP 0B. ONE-TIME FIX (skip if you created the database with the latest 01_mini_schema.sql)
--          Lets you INSERT into carriers / products / locations without typing an ID.
--          If MySQL refuses the ALTER, skip it and give the ID yourself instead, e.g.
--          INSERT INTO carriers (carrier_id, carrier_name, ...) VALUES (7, 'Example Freight Co', ...);
-- ---------------------------------------------------------------------
ALTER TABLE carriers  MODIFY carrier_id  TINYINT NOT NULL AUTO_INCREMENT;
ALTER TABLE products  MODIFY product_id  TINYINT NOT NULL AUTO_INCREMENT;
ALTER TABLE locations MODIFY location_id TINYINT NOT NULL AUTO_INCREMENT;

-- ---------------------------------------------------------------------
-- STEP 1. Add a new customer / supplier / carrier / product (only when needed)
-- ---------------------------------------------------------------------
INSERT INTO customers (customer_name, customer_type, location_id)
VALUES ('Dept. of Physics', 'Department', 2);

INSERT INTO suppliers (supplier_name, city, location_id, category, sourcing_channel,
                       onboarded_date, vetting_decision_date, status, trust_score)
VALUES ('Ikoyi Print Supplies', 'Lagos', 1, 'Paper & Card', 'Online marketplace',
        '2026-10-01', '2026-10-15', 'Trusted', 8.5);          -- status: 'Trusted' once vetted, 'Rejected' if not approved

INSERT INTO carriers (carrier_name, carrier_type, active_from, active_to)
VALUES ('Example Freight Co', 'Road freight', '2026-10-01', NULL);

INSERT INTO products (product_name, supplier_category, unit, unit_cost_ngn, reorder_level, weight_kg_per_unit)
VALUES ('Sticker paper roll', 'Paper & Card', 'pack', 3500, 20, 0.60);

-- ---------------------------------------------------------------------
-- STEP 2. NEW CUSTOMER ORDER (follow stages A to F as the order progresses)
-- ---------------------------------------------------------------------
-- 2A. Order received. promised_ts = the delivery time you promised the customer.
INSERT INTO orders (customer_id, project_type, product_id, qty, material_qty, order_value_ngn,
                    order_ts, promised_ts, destination_id, status)
VALUES (3, 'Posters & Banners', 1, 40, 40.0, 100000,
        '2026-10-20 10:30:00', '2026-10-26 17:00:00', 4, 'In Production');
SET @oid = LAST_INSERT_ID();                                           -- remember this order's ID
SELECT @oid AS new_order_id;

-- 2B. Materials arrived in Lapai, and production started
UPDATE orders
SET materials_ready_ts = '2026-10-21 14:00:00',
    production_start_ts = '2026-10-22 08:00:00'
WHERE order_id = @oid;

-- 2C. Production finished
UPDATE orders SET production_end_ts = '2026-10-23 16:00:00' WHERE order_id = @oid;

-- 2D. Dispatched: add the OUTBOUND shipment and mark the order In Transit
--     (origin 2 = Lapai; destination 1 Lagos, 2 Lapai, 3 Minna, 4 Abuja)
INSERT INTO shipments (shipment_type, order_id, po_id, carrier_id, origin_id, destination_id,
                       dispatch_ts, arrival_ts, weight_kg, freight_cost_ngn, handling_cost_ngn,
                       scheduled_to_production_slot, status)
VALUES ('Outbound', @oid, NULL, 5, 2, 4,
        '2026-10-23 19:00:00', NULL, 18.4, 2400, 750, NULL, 'In Transit');
UPDATE orders SET status = 'In Transit' WHERE order_id = @oid;

-- 2E. Delivered: close the shipment and the order
UPDATE shipments SET arrival_ts = '2026-10-24 02:30:00', status = 'Delivered'
WHERE order_id = @oid AND shipment_type = 'Outbound';
UPDATE orders SET delivered_ts = '2026-10-24 02:30:00', status = 'Delivered' WHERE order_id = @oid;

-- 2F. Auto-calculate the bottleneck hours, and record a reason ONLY if the order was late
UPDATE orders
SET material_wait_hours = ROUND(TIMESTAMPDIFF(MINUTE, order_ts, materials_ready_ts) / 60, 1),
    queue_hours         = ROUND(TIMESTAMPDIFF(MINUTE, materials_ready_ts, production_start_ts) / 60, 1)
WHERE order_id = @oid AND materials_ready_ts IS NOT NULL AND production_start_ts IS NOT NULL;

UPDATE orders SET delay_reason = 'Carrier delay'                        -- pick the real cause
WHERE order_id = @oid AND delivered_ts > promised_ts;                   -- does nothing if it was on time

-- ---------------------------------------------------------------------
-- STEP 3. NEW SUPPLIER PURCHASE ORDER (inbound materials to Lapai)
-- ---------------------------------------------------------------------
-- 3A. Place the PO. qty_received stays NULL until the goods arrive.
INSERT INTO purchase_orders (supplier_id, product_id, po_date, qty_requested, qty_received, unit_cost_ngn,
                             supplier_promised_ts, supplier_dispatch_ts, vetted_at_order, status)
VALUES (1, 1, '2026-10-18', 300, NULL, 900,
        '2026-10-19 10:00:00', '2026-10-19 08:30:00', 1, 'In Transit');
SET @poid = LAST_INSERT_ID();

-- 3B. Let MySQL decide whether the supplier was already approved on the PO date (1 = trusted, 0 = not yet)
UPDATE purchase_orders p JOIN suppliers s ON s.supplier_id = p.supplier_id
SET p.vetted_at_order = (s.status = 'Trusted' AND s.vetting_decision_date <= p.po_date)
WHERE p.po_id = @poid;

-- 3C. Add the INBOUND shipment (origin = supplier city: 1 Lagos or 4 Abuja; destination 2 = Lapai)
--     scheduled_to_production_slot: 1 if the delivery was timed to a production slot, else 0
INSERT INTO shipments (shipment_type, order_id, po_id, carrier_id, origin_id, destination_id,
                       dispatch_ts, arrival_ts, weight_kg, freight_cost_ngn, handling_cost_ngn,
                       scheduled_to_production_slot, status)
VALUES ('Inbound', NULL, @poid, 4, 1, 2,
        '2026-10-19 09:00:00', NULL, 105.0, 16200, 1300, 1, 'In Transit');

-- 3D. Goods arrived: record arrival time and the quantity actually received
UPDATE shipments SET arrival_ts = '2026-10-20 03:00:00', status = 'Delivered' WHERE po_id = @poid;
UPDATE purchase_orders SET qty_received = 285, status = 'Received' WHERE po_id = @poid;

-- ---------------------------------------------------------------------
-- STEP 4. MONTH-END INVENTORY SNAPSHOT (consumed, closing, stock-out days and the reorder flag are calculated)
--         Fill in one SELECT per product; join them with UNION ALL.
-- ---------------------------------------------------------------------
INSERT INTO inventory_snapshots (month_end, product_id, opening_qty, received_qty, demand_qty,
                                 consumed_qty, closing_qty, stockout_days, reorder_level, below_reorder)
SELECT x.month_end, x.product_id, x.opening_qty, x.received_qty, x.demand_qty,
       LEAST(x.opening_qty + x.received_qty, x.demand_qty),
       x.opening_qty + x.received_qty - LEAST(x.opening_qty + x.received_qty, x.demand_qty),
       COALESCE(ROUND(28 * (1 - LEAST(x.opening_qty + x.received_qty, x.demand_qty) / NULLIF(x.demand_qty, 0))), 0),
       p.reorder_level,
       (x.opening_qty + x.received_qty - LEAST(x.opening_qty + x.received_qty, x.demand_qty)) < p.reorder_level
FROM (
      SELECT '2026-09-30' AS month_end, 1 AS product_id, 120.0 AS opening_qty, 300.0 AS received_qty, 380.0 AS demand_qty
      UNION ALL
      SELECT '2026-09-30', 8, 60.0, 250.0, 280.0
     ) x
JOIN products p ON p.product_id = x.product_id;

-- ---------------------------------------------------------------------
-- STEP 5. HOUSEKEEPING AFTER ADDING DATA (needed so Power BI date filters work)
-- ---------------------------------------------------------------------
-- 5A. Extend the date table if your new data goes past 31 Dec 2026 (change the end date as needed).
--     Run it ONCE per extension (it continues from the last date already in the table).
SET SESSION cte_max_recursion_depth = 5000;
INSERT INTO dim_date (date_key, year_num, quarter_num, month_num, month_name, year_month_label,
                      month_start, is_complete_month, period_label)
WITH RECURSIVE d AS (
    SELECT DATE_ADD((SELECT MAX(date_key) FROM dim_date), INTERVAL 1 DAY) AS dt
    UNION ALL
    SELECT dt + INTERVAL 1 DAY FROM d WHERE dt < '2027-12-31'
)
SELECT dt, YEAR(dt), QUARTER(dt), MONTH(dt), MONTHNAME(dt), DATE_FORMAT(dt, '%Y-%m'),
       DATE_FORMAT(dt, '%Y-%m-01'), 0, 'Transition'
FROM d;

-- 5B. Refresh the "complete month" flag: every month BEFORE the latest order month counts as complete
UPDATE dim_date
SET is_complete_month = CASE
        WHEN month_start < (SELECT DATE_SUB(DATE(MAX(order_ts)), INTERVAL DAYOFMONTH(MAX(order_ts)) - 1 DAY) FROM orders)
        THEN 1 ELSE 0 END;

-- 5C. OPTIONAL: move the "Current" comparison window. The dashboard KPI cards compare the two windows labelled
--     'Baseline (Jan-Jun 2024)' and 'Current (Apr-Sep 2026)'. If you change the dates here, also update the label
--     text in the Power BI measures (search the DAX for "Current (Apr-Sep 2026)"), or the cards will go blank.
-- UPDATE dim_date SET period_label = 'Transition' WHERE period_label = 'Current (Apr-Sep 2026)';
-- UPDATE dim_date SET period_label = 'Current (Apr-Sep 2026)' WHERE date_key >= '2026-04-01' AND date_key < '2026-10-01';

-- ---------------------------------------------------------------------
-- STEP 6. CORRECTIONS
-- ---------------------------------------------------------------------
-- Fix a value:
-- UPDATE orders SET promised_ts = '2026-10-27 17:00:00' WHERE order_id = 29;
-- Delete a wrong ORDER: remove its shipment first (shipments point at orders)
-- DELETE FROM shipments WHERE order_id = 29;
-- DELETE FROM orders    WHERE order_id = 29;
-- Delete a wrong PURCHASE ORDER: remove its shipment first
-- DELETE FROM shipments       WHERE po_id = 11;
-- DELETE FROM purchase_orders WHERE po_id = 11;

-- ---------------------------------------------------------------------
-- STEP 7. DATA-QUALITY CHECKS. Run after every update: every query should return ZERO rows.
-- ---------------------------------------------------------------------
SELECT 'late order without a delay_reason' AS problem, order_id FROM orders
 WHERE delivered_ts > promised_ts AND delay_reason IS NULL
UNION ALL SELECT 'on-time order with a delay_reason', order_id FROM orders
 WHERE delivered_ts <= promised_ts AND delay_reason IS NOT NULL
UNION ALL SELECT 'delay_reason set on an order that is not delivered yet', order_id FROM orders
 WHERE delivered_ts IS NULL AND delay_reason IS NOT NULL
UNION ALL SELECT 'delivered_ts missing but status Delivered', order_id FROM orders
 WHERE status = 'Delivered' AND delivered_ts IS NULL
UNION ALL SELECT 'delivered_ts filled but status not Delivered', order_id FROM orders
 WHERE delivered_ts IS NOT NULL AND status <> 'Delivered'
UNION ALL SELECT 'timestamps out of order', order_id FROM orders
 WHERE materials_ready_ts < order_ts OR production_start_ts < materials_ready_ts
    OR production_end_ts < production_start_ts OR delivered_ts < production_end_ts
UNION ALL SELECT 'bottleneck hours not calculated', order_id FROM orders
 WHERE materials_ready_ts IS NOT NULL AND production_start_ts IS NOT NULL
   AND (material_wait_hours IS NULL OR queue_hours IS NULL)
UNION ALL SELECT 'shipment arrives before it leaves', shipment_id FROM shipments
 WHERE arrival_ts < dispatch_ts
UNION ALL SELECT 'shipment status does not match arrival_ts', shipment_id FROM shipments
 WHERE (arrival_ts IS NULL AND status = 'Delivered') OR (arrival_ts IS NOT NULL AND status = 'In Transit')
UNION ALL SELECT 'outbound shipment without order_id, or inbound without po_id', shipment_id FROM shipments
 WHERE (shipment_type = 'Outbound' AND order_id IS NULL) OR (shipment_type = 'Inbound' AND po_id IS NULL)
UNION ALL SELECT 'PO received but qty_received missing (or over-delivered)', po_id FROM purchase_orders
 WHERE (status = 'Received' AND qty_received IS NULL) OR qty_received > qty_requested
UNION ALL SELECT 'order date not covered by dim_date (run STEP 5A)', order_id FROM orders
 WHERE DATE(order_ts) > (SELECT MAX(date_key) FROM dim_date);

-- ---------------------------------------------------------------------
-- STEP 8. QUICK RESULT CHECK: these should match the KPI cards after a Power BI refresh
-- ---------------------------------------------------------------------
SELECT * FROM vw_monthly_kpis ORDER BY month_start DESC LIMIT 6;   -- latest months
-- Full headline comparison (26.0 h -> 18.0 h, 64% -> 82%, -5%, 73.6% -> 96.6%): run 05_mini_analysis_queries.sql

-- ---------------------------------------------------------------------
-- STEP 9. REFRESH POWER BI
--   Power BI Desktop: Home > Refresh.  Nothing else changes: the dashboard reads these same views.
-- ---------------------------------------------------------------------
