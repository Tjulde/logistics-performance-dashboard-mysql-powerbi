-- =====================================================================
-- 04_analysis_queries.sql  -  one query per CV bullet, plus supporting analysis
-- Reporting windows:  Baseline = Jan-Jun 2024   |   Current = Apr-Sep 2026
-- Expected results are shown in the comment above each query.
-- =====================================================================
USE khass_logistics_mini;

-- Reusable period definitions are repeated as a CTE in each query for clarity.

-- ---------------------------------------------------------------------
-- BULLET 1: "Cut Lagos-to-Niger delivery time from 26 hours to 18 hours by
--            coordinating carrier arrangements and scheduling shipments
--            around production needs."
-- Expected:  Baseline 26.0 h  |  Current 18.0 h
-- ---------------------------------------------------------------------
WITH periods AS (
    SELECT 'Baseline (Jan-Jun 2024)' AS period, DATE('2024-01-01') AS start_d, DATE('2024-07-01') AS end_d
    UNION ALL
    SELECT 'Current (Apr-Sep 2026)',            DATE('2026-04-01'),            DATE('2026-10-01')
)
SELECT  p.period,
        COUNT(*)                                   AS inbound_shipments,
        ROUND(AVG(s.transit_hours), 1)             AS avg_lagos_to_lapai_hours
FROM periods p
JOIN vw_fact_shipments s
  ON s.dispatch_ts >= p.start_d AND s.dispatch_ts < p.end_d
WHERE s.shipment_type = 'Inbound'
  AND s.lane = 'Lagos -> Lapai'
  AND s.transit_hours IS NOT NULL
GROUP BY p.period
ORDER BY p.start_d;

-- 1b. WHY it improved: carrier mix (transit hours by carrier)
SELECT  carrier_name,
        COUNT(*)                         AS shipments,
        ROUND(AVG(transit_hours), 1)     AS avg_transit_hours
FROM vw_fact_shipments
WHERE shipment_type = 'Inbound' AND lane = 'Lagos -> Lapai' AND transit_hours IS NOT NULL
GROUP BY carrier_name
ORDER BY avg_transit_hours;

-- 1c. WHY it improved: shipments timed to production slots vs not (2025 onward)
SELECT  CASE scheduled_to_production_slot WHEN 1 THEN 'Scheduled to production slot' ELSE 'Ad hoc dispatch' END AS dispatch_mode,
        COUNT(*)                         AS shipments,
        ROUND(AVG(transit_hours), 1)     AS avg_transit_hours
FROM vw_fact_shipments
WHERE shipment_type = 'Inbound' AND lane = 'Lagos -> Lapai' AND transit_hours IS NOT NULL
  AND dispatch_ts >= '2025-01-01'
GROUP BY scheduled_to_production_slot;

-- 1d. Share of inbound shipments scheduled to production slots, by quarter
SELECT  CONCAT(YEAR(dispatch_ts), '-Q', QUARTER(dispatch_ts))              AS quarter,
        ROUND(100 * AVG(scheduled_to_production_slot), 0)                  AS pct_scheduled,
        ROUND(AVG(CASE WHEN lane = 'Lagos -> Lapai' THEN transit_hours END), 1) AS lagos_lapai_hours
FROM vw_fact_shipments
WHERE shipment_type = 'Inbound'
GROUP BY quarter
ORDER BY quarter;

-- ---------------------------------------------------------------------
-- BULLET 2: "Coordinate inbound materials and outbound finished orders ...
--            reducing bottlenecks and improving on-time delivery by 18%."
-- Expected:  Baseline 64.0%  |  Current 82.0%  |  +18.0 percentage points
-- ---------------------------------------------------------------------
WITH periods AS (
    SELECT 'Baseline (Jan-Jun 2024)' AS period, DATE('2024-01-01') AS start_d, DATE('2024-07-01') AS end_d
    UNION ALL
    SELECT 'Current (Apr-Sep 2026)',            DATE('2026-04-01'),            DATE('2026-10-01')
)
SELECT  p.period,
        COUNT(*)                                        AS orders,
        ROUND(100 * AVG(o.on_time_flag), 1)             AS on_time_delivery_pct,
        ROUND(AVG(o.material_wait_hours), 1)            AS avg_material_wait_hrs,
        ROUND(AVG(o.queue_hours), 1)                    AS avg_queue_hrs,
        ROUND(AVG(o.bottleneck_hours), 1)               AS avg_bottleneck_hrs
FROM periods p
JOIN vw_fact_orders o ON o.order_ts >= p.start_d AND o.order_ts < p.end_d
WHERE o.on_time_flag IS NOT NULL
GROUP BY p.period
ORDER BY p.start_d;

-- 2b. Improvement in percentage points, in one row
SELECT  ROUND(100 * AVG(CASE WHEN order_ts <  '2024-07-01' THEN on_time_flag END), 1) AS baseline_on_time_pct,
        ROUND(100 * AVG(CASE WHEN order_ts >= '2026-04-01' AND order_ts < '2026-10-01' THEN on_time_flag END), 1) AS current_on_time_pct,
        ROUND(100 * AVG(CASE WHEN order_ts >= '2026-04-01' AND order_ts < '2026-10-01' THEN on_time_flag END)
            - 100 * AVG(CASE WHEN order_ts <  '2024-07-01' THEN on_time_flag END), 1) AS improvement_pct_points
FROM vw_fact_orders;

-- 2c. What causes late orders, and how the mix shifted
SELECT  YEAR(order_ts) AS yr,
        delay_reason,
        COUNT(*)                                                           AS late_orders,
        ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY YEAR(order_ts)), 1) AS pct_of_late_orders
FROM vw_fact_orders
WHERE on_time_flag = 0
GROUP BY YEAR(order_ts), delay_reason
ORDER BY yr, late_orders DESC;

-- ---------------------------------------------------------------------
-- BULLET 3: "Manage supply-chain operations across Lagos, Niger, and Abuja,
--            monitoring inventory and carrier arrangements to reduce logistics
--            costs by 5% while meeting print deadlines."
-- Logistics cost per order = total shipment cost (by dispatch month) / orders (by order month)
-- Expected:  current window is 5.0% lower than baseline window
-- ---------------------------------------------------------------------
WITH periods AS (
    SELECT 'Baseline (Jan-Jun 2024)' AS period, DATE('2024-01-01') AS start_d, DATE('2024-07-01') AS end_d
    UNION ALL
    SELECT 'Current (Apr-Sep 2026)',            DATE('2026-04-01'),            DATE('2026-10-01')
), cost AS (
    SELECT p.period, SUM(s.total_logistics_cost_ngn) AS total_cost
    FROM periods p JOIN vw_fact_shipments s ON s.dispatch_ts >= p.start_d AND s.dispatch_ts < p.end_d
    GROUP BY p.period
), ord AS (
    SELECT p.period, COUNT(*) AS orders
    FROM periods p JOIN orders o ON o.order_ts >= p.start_d AND o.order_ts < p.end_d
    GROUP BY p.period
)
SELECT  c.period,
        c.total_cost                              AS logistics_cost_ngn,
        o.orders,
        ROUND(c.total_cost / o.orders, 0)         AS cost_per_order_ngn
FROM cost c JOIN ord o ON o.period = c.period
ORDER BY c.period DESC;

-- 3b. Percentage change in one row
WITH base AS (
    SELECT (SELECT SUM(total_logistics_cost_ngn) FROM vw_fact_shipments WHERE dispatch_ts >= '2024-01-01' AND dispatch_ts < '2024-07-01')
         / (SELECT COUNT(*) FROM orders WHERE order_ts >= '2024-01-01' AND order_ts < '2024-07-01') AS cpo
), cur AS (
    SELECT (SELECT SUM(total_logistics_cost_ngn) FROM vw_fact_shipments WHERE dispatch_ts >= '2026-04-01' AND dispatch_ts < '2026-10-01')
         / (SELECT COUNT(*) FROM orders WHERE order_ts >= '2026-04-01' AND order_ts < '2026-10-01') AS cpo
)
SELECT ROUND(base.cpo, 0) AS baseline_cost_per_order, ROUND(cur.cpo, 0) AS current_cost_per_order,
       ROUND(100 * (cur.cpo / base.cpo - 1), 1) AS pct_change
FROM base, cur;

-- 3c. Operations by corridor (Lagos, Niger, Abuja)
SELECT  lane, shipment_type,
        COUNT(*)                                   AS shipments,
        ROUND(SUM(weight_kg), 0)                   AS kg_moved,
        ROUND(AVG(transit_hours), 1)               AS avg_transit_hrs,
        SUM(total_logistics_cost_ngn)              AS logistics_cost_ngn,
        ROUND(SUM(total_logistics_cost_ngn) / SUM(weight_kg), 0) AS cost_per_kg_ngn
FROM vw_fact_shipments
GROUP BY lane, shipment_type
ORDER BY logistics_cost_ngn DESC;

-- 3d. Inventory health: stock-out days and months below reorder level, by year
SELECT  YEAR(month_end)                              AS yr,
        ROUND(AVG(stockout_days), 2)                 AS avg_stockout_days_per_product_month,
        ROUND(100 * AVG(below_reorder), 1)           AS pct_product_months_below_reorder,
        ROUND(100 * SUM(consumed_qty) / SUM(demand_qty), 1) AS demand_fulfilled_pct
FROM vw_fact_inventory
GROUP BY YEAR(month_end)
ORDER BY yr;

-- 3e. Products currently at risk (latest complete month below reorder level)
SELECT product_name, closing_qty, reorder_level, stockout_days
FROM vw_fact_inventory
WHERE month_end = (SELECT MAX(month_end) FROM inventory_snapshots)
  AND below_reorder = 1
ORDER BY closing_qty / reorder_level;

-- ---------------------------------------------------------------------
-- BULLET 4: "Source and secure trusted suppliers online for printing materials
--            such as flex and school kits, closing the supply gap between
--            Lagos and Lapai."
-- Supply gap = quantity requested but not delivered (fill rate < 100%)
-- ---------------------------------------------------------------------
WITH periods AS (
    SELECT 'Baseline (Jan-Jun 2024)' AS period, DATE('2024-01-01') AS start_d, DATE('2024-07-01') AS end_d
    UNION ALL
    SELECT 'Current (Apr-Sep 2026)',            DATE('2026-04-01'),            DATE('2026-10-01')
)
SELECT  p.period,
        COUNT(*)                                                         AS purchase_orders,
        ROUND(100 * SUM(po.qty_received) / SUM(po.qty_requested), 1)     AS supplier_fill_rate_pct,
        ROUND(100 * AVG(po.trusted_supplier_flag), 0)                    AS pct_pos_with_trusted_suppliers,
        ROUND(100 * AVG(po.supplier_on_time_flag), 1)                    AS supplier_on_time_dispatch_pct
FROM periods p
JOIN vw_fact_purchase_orders po ON po.po_date >= p.start_d AND po.po_date < p.end_d
WHERE po.qty_received IS NOT NULL
GROUP BY p.period
ORDER BY p.start_d;

-- 4b. Supplier scorecard (vetted vs rejected, fill rate, reliability)
SELECT  s.supplier_name, s.city, s.category, s.sourcing_channel, s.status,
        s.vetting_decision_date,
        COUNT(po.po_id)                                              AS purchase_orders,
        ROUND(100 * SUM(po.qty_received) / SUM(po.qty_requested), 1) AS fill_rate_pct,
        ROUND(100 * AVG(po.supplier_on_time_flag), 1)                AS on_time_dispatch_pct
FROM suppliers s
LEFT JOIN vw_fact_purchase_orders po ON po.supplier_id = s.supplier_id AND po.qty_received IS NOT NULL
GROUP BY s.supplier_id, s.supplier_name, s.city, s.category, s.sourcing_channel, s.status, s.vetting_decision_date
ORDER BY fill_rate_pct DESC;

-- 4c. Flex and school-kit supply, by half-year
SELECT  CONCAT(YEAR(po.po_date), '-H', CEILING(MONTH(po.po_date) / 6)) AS half_year,
        po.product_name,
        ROUND(100 * SUM(po.qty_received) / SUM(po.qty_requested), 1)   AS fill_rate_pct
FROM vw_fact_purchase_orders po
WHERE po.qty_received IS NOT NULL
  AND po.product_name IN ('Flex roll (banner media)', 'School kit & jotter packs')
GROUP BY half_year, po.product_name
ORDER BY half_year, po.product_name;

-- ---------------------------------------------------------------------
-- BULLET 5 (tools):  Query order, inventory and delivery data in MySQL and
--                    visualize trends in Power BI  ->  see vw_monthly_kpis
-- ---------------------------------------------------------------------
SELECT * FROM vw_monthly_kpis;
