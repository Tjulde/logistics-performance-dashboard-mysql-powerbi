# KPI definitions

Every number in this project is calculated the same way in SQL and in Power BI. If a definition changes, change it in both places.

**Comparison windows:** *Baseline* = Jan–Jun 2024 · *Current* = Apr–Sep 2026. Six full months each, so a few unusual days don't swing the result.

| KPI | Definition | Baseline | Current | SQL | Power BI measure |
|---|---|---|---|---|---|
| **Lagos → Lapai delivery time** | Hours from dispatch to arrival, inbound shipments on the Lagos → Lapai lane, by dispatch date | 26.0 h | 18.0 h | `05_mini_analysis_queries.sql`, Bullet 1 | `Avg Transit Hrs` |
| **On-time delivery** | Share of delivered orders where `delivered_ts <= promised_ts`, by order date | 64% (7 of 11) | 82% (9 of 11) | Bullet 2 | `On-Time %` |
| **Logistics cost per order** | Total freight + handling of shipments (by dispatch date) ÷ orders (by order date) | ₦5,244 | ₦4,981 | Bullet 3 | `Cost per Order` |
| **Supplier fill rate** | Quantity received ÷ quantity requested, received purchase orders only, by PO date | 73.6% | 96.6% | Bullet 4 | `Supplier Fill Rate` |

## Why these choices
- **Cost per order, not total cost.** More orders means more trips and a higher total, which would hide real savings. Dividing by orders compares like with like.
- **Six-month windows, not single months.** With few orders a month, one late order moves a monthly rate a lot.
- **Percentage points, not percent.** On-time rose from 64% to 82%: that is **+18 percentage points** (not +18%).
