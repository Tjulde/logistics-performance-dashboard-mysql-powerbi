# 🔧 Stage 6: Maintenance. Keep the dashboard fresh

A building needs upkeep. This is the routine for adding new data.

1. **Add data** with [`04_update_new_data.sql`](04_update_new_data.sql). Edit the example values, then run **one numbered step at a time**, in the same query tab.
   - Step 2: a customer order, from received to delivered
   - Step 3: a supplier purchase order, from placed to received
   - Step 4: a month-end inventory snapshot
   - Step 5: housekeeping (extends the date table, flags complete months)
2. **Run Step 7 (data-quality checks).** Every query must return **zero rows**. The checks catch things like a late order with no reason, a shipment that arrives before it leaves, or a delay reason on an order not yet delivered.
3. **Refresh Power BI:** *Home > Refresh*.
4. **Sanity-check the cards:** 26.0 h → 18.0 h, 64% → 82%, ₦5,244 → ₦4,981, 73.6% → 96.6%. New rows dated after Sep 2026 appear in trend charts but do not change the cards, because the cards compare two fixed windows.

## Common slips
| Symptom | Likely cause |
|---|---|
| "Field 'carrier_id' doesn't have a default value" | Run Step 0B once (adds AUTO_INCREMENT to lookup tables) |
| A late order is missing from the delay chart | `delay_reason` was left empty. Step 7 will flag it |
| Quarters appear in the wrong order | Sort `Quarter Label` by `Quarter Sort` (see `04-roof/measures.dax`) |
| KPI card shows a different baseline | The baseline window should contain **11** orders. Count them |
