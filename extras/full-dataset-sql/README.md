# Optional: the full dataset in MySQL

The compact sample (`02-framework`) is enough to run the dashboard. Load the full dataset (2,685 orders, 3,221 shipments) if you want smoother monthly trend lines.

```bash
mysql -u root -p < 01_schema.sql              # WARNING: drops and recreates the database `khass_logistics`
mysql -u root -p < 02a_insert_dimensions.sql
mysql -u root -p < 02b_insert_facts.sql
mysql -u root -p < 03_views.sql
mysql -u root -p < 04_analysis_queries.sql
```
Then point Power BI's `DatabaseName` parameter at `khass_logistics`.
