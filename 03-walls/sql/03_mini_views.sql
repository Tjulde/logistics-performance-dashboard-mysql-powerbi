-- =====================================================================
-- 03_views.sql  -  clean, analysis-ready views (these are what Power BI imports)
-- =====================================================================
USE khass_logistics_mini;

-- ---------- FACT: orders ----------
CREATE OR REPLACE VIEW vw_fact_orders AS
SELECT  o.order_id,
        o.customer_id,
        c.customer_name,
        c.customer_type,
        o.project_type,
        o.product_id,
        o.qty,
        o.order_value_ngn,
        DATE(o.order_ts)                                   AS order_date,
        o.order_ts,
        o.promised_ts,
        o.delivered_ts,
        o.destination_id,
        o.status,
        o.material_wait_hours,
        o.queue_hours,
        o.material_wait_hours + o.queue_hours              AS bottleneck_hours,
        o.delay_reason,
        CASE WHEN o.delivered_ts IS NULL THEN NULL
             WHEN o.delivered_ts <= o.promised_ts THEN 1
             ELSE 0 END                                    AS on_time_flag,
        CASE WHEN o.delivered_ts IS NULL THEN NULL
             ELSE ROUND(TIMESTAMPDIFF(MINUTE, o.order_ts, o.delivered_ts) / 60, 1) END
                                                           AS order_cycle_hours
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id;

-- ---------- FACT: shipments (transit hours, lane, cost) ----------
CREATE OR REPLACE VIEW vw_fact_shipments AS
SELECT  s.shipment_id,
        s.shipment_type,
        s.order_id,
        s.po_id,
        s.carrier_id,
        ca.carrier_name,
        s.origin_id,
        s.destination_id,
        lo.city                                            AS origin_city,
        ld.city                                            AS destination_city,
        CONCAT(lo.city, ' -> ', ld.city)                   AS lane,
        DATE(s.dispatch_ts)                                AS dispatch_date,
        s.dispatch_ts,
        s.arrival_ts,
        CASE WHEN s.arrival_ts IS NULL THEN NULL
             ELSE ROUND(TIMESTAMPDIFF(MINUTE, s.dispatch_ts, s.arrival_ts) / 60, 2) END
                                                           AS transit_hours,
        s.weight_kg,
        s.freight_cost_ngn,
        s.handling_cost_ngn,
        s.freight_cost_ngn + s.handling_cost_ngn           AS total_logistics_cost_ngn,
        s.scheduled_to_production_slot,
        s.status
FROM shipments s
JOIN locations lo ON lo.location_id = s.origin_id
JOIN locations ld ON ld.location_id = s.destination_id
JOIN carriers  ca ON ca.carrier_id  = s.carrier_id;

-- ---------- FACT: purchase orders (sourcing performance) ----------
CREATE OR REPLACE VIEW vw_fact_purchase_orders AS
SELECT  p.po_id,
        p.supplier_id,
        s.supplier_name,
        s.city                                             AS supplier_city,
        s.category                                         AS supplier_category,
        s.sourcing_channel,
        p.product_id,
        pr.product_name,
        p.po_date,
        p.qty_requested,
        p.qty_received,
        CASE WHEN p.qty_received IS NULL THEN NULL
             ELSE ROUND(p.qty_received / p.qty_requested, 4) END      AS fill_rate,
        p.unit_cost_ngn,
        p.vetted_at_order                                  AS trusted_supplier_flag,
        CASE WHEN p.supplier_dispatch_ts <= p.supplier_promised_ts THEN 1 ELSE 0 END
                                                           AS supplier_on_time_flag,
        ROUND(TIMESTAMPDIFF(MINUTE, p.supplier_promised_ts, p.supplier_dispatch_ts) / 60, 1)
                                                           AS supplier_delay_hours,
        p.status
FROM purchase_orders p
JOIN suppliers s ON s.supplier_id = p.supplier_id
JOIN products pr ON pr.product_id = p.product_id;

-- ---------- FACT: month-end inventory ----------
CREATE OR REPLACE VIEW vw_fact_inventory AS
SELECT  i.snapshot_id, i.month_end, i.product_id, pr.product_name,
        i.opening_qty, i.received_qty, i.demand_qty, i.consumed_qty, i.closing_qty,
        i.stockout_days, i.reorder_level, i.below_reorder,
        ROUND(i.consumed_qty / NULLIF(i.demand_qty, 0), 4) AS demand_fulfilment_rate
FROM inventory_snapshots i
JOIN products pr ON pr.product_id = i.product_id;

-- ---------- Monthly KPI roll-up (quick sanity check + handy for Power BI cards) ----------
CREATE OR REPLACE VIEW vw_monthly_kpis AS
WITH ord AS (
    SELECT DATE_SUB(DATE(order_ts), INTERVAL DAYOFMONTH(order_ts) - 1 DAY) AS month_start,
           COUNT(*)                                                AS orders,
           ROUND(100 * AVG(on_time_flag), 1)                       AS on_time_pct,
           ROUND(AVG(material_wait_hours), 1)                      AS avg_material_wait_hrs,
           ROUND(AVG(bottleneck_hours), 1)                         AS avg_bottleneck_hrs
    FROM vw_fact_orders GROUP BY 1
), shp AS (
    SELECT DATE_SUB(DATE(dispatch_ts), INTERVAL DAYOFMONTH(dispatch_ts) - 1 DAY) AS month_start,
           SUM(total_logistics_cost_ngn)                           AS logistics_cost_ngn,
           ROUND(AVG(CASE WHEN shipment_type = 'Inbound' AND lane = 'Lagos -> Lapai'
                          THEN transit_hours END), 1)              AS lagos_lapai_transit_hrs
    FROM vw_fact_shipments GROUP BY 1
), po AS (
    SELECT DATE_SUB(po_date, INTERVAL DAYOFMONTH(po_date) - 1 DAY) AS month_start,
           ROUND(100 * SUM(qty_received) / SUM(CASE WHEN qty_received IS NOT NULL THEN qty_requested END), 1)
                                                                   AS supplier_fill_rate_pct,
           ROUND(100 * AVG(trusted_supplier_flag), 0)              AS trusted_supplier_po_pct
    FROM vw_fact_purchase_orders GROUP BY 1
)
SELECT  ord.month_start, ord.orders, shp.lagos_lapai_transit_hrs, ord.on_time_pct,
        ROUND(shp.logistics_cost_ngn / ord.orders, 0)              AS logistics_cost_per_order_ngn,
        po.supplier_fill_rate_pct, po.trusted_supplier_po_pct,
        ord.avg_material_wait_hrs, ord.avg_bottleneck_hrs
FROM ord
LEFT JOIN shp ON shp.month_start = ord.month_start
LEFT JOIN po  ON po.month_start  = ord.month_start
ORDER BY ord.month_start;
