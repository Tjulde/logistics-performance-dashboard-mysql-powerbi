# Connect Power BI to MySQL

## 1. Build the database (once)
Run these in order (MySQL Workbench or the command line):

| Order | File | What it does |
|---|---|---|
| 1 | `02-framework/sql/01_mini_schema.sql` | Creates database `khass_logistics_mini`, tables and the date table |
| 2 | `02-framework/sql/02a_mini_insert_dimensions.sql` | Loads locations, customers, suppliers, carriers, products |
| 3 | `02-framework/sql/02b_mini_insert_facts.sql` | Loads orders, purchase orders, shipments, inventory snapshots |
| 4 | `03-walls/sql/03_mini_views.sql` | Creates the `vw_*` views Power BI reads |
| 5 | `03-walls/sql/05_mini_analysis_queries.sql` | Optional: prints the headline numbers |

## 2. Connect
1. Install **MySQL Connector/NET 8.x** and restart Power BI Desktop.
2. In Power Query, create two Text parameters: `ServerName` (for example `localhost:3306`) and `DatabaseName` (`khass_logistics_mini`).
3. Paste each query from [`Khass_MySQL_Connection.pq`](Khass_MySQL_Connection.pq) into **New Source > Blank Query > Advanced Editor**, and name them `fact_orders`, `fact_shipments`, `fact_purchase_orders`, `fact_inventory`, `dim_date`.
4. **Close & Apply.** Choose the **Database** tab at the login prompt.

If **Edit parameters** is greyed out, your report has no parameters. Use **Transform data > Data source settings > Change Source**, or edit the database name inside each query's **Advanced Editor**. Spell it exactly `khass_logistics_mini`.

## 3. No MySQL? Use the CSVs
`04-roof/powerbi_csv_compact/` holds the same five tables as CSV files (**Get data > Text/CSV**).

## 4. Check
With the Year slicer on *All*, the cards should show 26.0 h → 18.0 h, 64% → 82%, ₦5,244 → ₦4,981 and 73.6% → 96.6%. If a card is off, count the baseline orders first (it should be **11**).
