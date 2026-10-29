// =====================================================================
// Khass Logistics | Power BI <-> MySQL connection (Power Query M)
// HOW TO USE
//  1. Install MySQL Connector/NET 8.x, restart Power BI Desktop.
//  2. Home > Transform data > Manage Parameters > New: create two Text parameters
//        ServerName    = localhost:3306      (or your host:port)
//        DatabaseName  = khass_logistics
//  3. For each block below: Home > New Source > Blank Query > Advanced Editor,
//     paste the code between the markers, click Done, then rename the query
//     to the name in the "QUERY NAME" line.
//  4. Close & Apply, then follow PowerBI_Report_Guide.md (relationships, DAX).
//  Login prompt: choose the "Database" tab and enter your MySQL user/password.
// =====================================================================


// ---------- QUERY NAME: fact_orders ----------
let
    Source  = MySQL.Database(ServerName, DatabaseName),
    Tbl     = Source{[Schema = DatabaseName, Item = "vw_fact_orders"]}[Data],
    Typed   = Table.TransformColumnTypes(Tbl, {
        {"order_date", type date}, {"order_ts", type datetime}, {"promised_ts", type datetime},
        {"delivered_ts", type datetime}, {"material_wait_hours", type number},
        {"queue_hours", type number}, {"bottleneck_hours", type number},
        {"on_time_flag", Int64.Type}, {"order_value_ngn", Int64.Type}})
in
    Typed


// ---------- QUERY NAME: fact_shipments ----------
let
    Source  = MySQL.Database(ServerName, DatabaseName),
    Tbl     = Source{[Schema = DatabaseName, Item = "vw_fact_shipments"]}[Data],
    Typed   = Table.TransformColumnTypes(Tbl, {
        {"dispatch_date", type date}, {"dispatch_ts", type datetime}, {"arrival_ts", type datetime},
        {"transit_hours", type number}, {"weight_kg", type number},
        {"total_logistics_cost_ngn", Int64.Type}, {"scheduled_to_production_slot", Int64.Type}})
in
    Typed


// ---------- QUERY NAME: fact_purchase_orders ----------
let
    Source  = MySQL.Database(ServerName, DatabaseName),
    Tbl     = Source{[Schema = DatabaseName, Item = "vw_fact_purchase_orders"]}[Data],
    Typed   = Table.TransformColumnTypes(Tbl, {
        {"po_date", type date}, {"qty_requested", type number}, {"qty_received", type number},
        {"fill_rate", type number}, {"trusted_supplier_flag", Int64.Type},
        {"supplier_on_time_flag", Int64.Type}, {"supplier_delay_hours", type number}})
in
    Typed


// ---------- QUERY NAME: fact_inventory ----------
let
    Source  = MySQL.Database(ServerName, DatabaseName),
    Tbl     = Source{[Schema = DatabaseName, Item = "vw_fact_inventory"]}[Data],
    Typed   = Table.TransformColumnTypes(Tbl, {
        {"month_end", type date}, {"closing_qty", type number}, {"demand_qty", type number},
        {"consumed_qty", type number}, {"stockout_days", Int64.Type}, {"below_reorder", Int64.Type}})
in
    Typed


// ---------- QUERY NAME: dim_date ----------
let
    Source  = MySQL.Database(ServerName, DatabaseName),
    Tbl     = Source{[Schema = DatabaseName, Item = "dim_date"]}[Data],
    Typed   = Table.TransformColumnTypes(Tbl, {{"date_key", type date}, {"month_start", type date}})
in
    Typed


// ---------- OPTIONAL: custom SQL query (Bullet 1 as a hand-written MySQL query) ----------
// QUERY NAME: kpi_transit_by_period
// Shows how to send your own SQL from Power BI. Needs only the same connection.
let
    Source = MySQL.Database(ServerName, DatabaseName, [Query =
        "SELECT CASE WHEN dispatch_ts < '2024-07-01' THEN 'Baseline (Jan-Jun 2024)'
                     ELSE 'Current (Apr-Sep 2026)' END AS period,
                COUNT(*) AS shipments,
                ROUND(AVG(transit_hours), 1) AS avg_lagos_lapai_hours
         FROM vw_fact_shipments
         WHERE shipment_type = 'Inbound' AND lane = 'Lagos -> Lapai' AND transit_hours IS NOT NULL
           AND ((dispatch_ts >= '2024-01-01' AND dispatch_ts < '2024-07-01')
             OR (dispatch_ts >= '2026-04-01' AND dispatch_ts < '2026-10-01'))
         GROUP BY period"])
in
    Source


// ---------- OPTIONAL: monthly KPI roll-up straight from the view ----------
// QUERY NAME: monthly_kpis   (handy for quick cards and as a cross-check of your DAX)
let
    Source = MySQL.Database(ServerName, DatabaseName),
    Tbl    = Source{[Schema = DatabaseName, Item = "vw_monthly_kpis"]}[Data]
in
    Tbl
