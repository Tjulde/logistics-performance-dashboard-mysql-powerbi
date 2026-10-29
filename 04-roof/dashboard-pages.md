# 🏠 Stage 4: The Roof. The 5-page Power BI dashboard

Each page answers one business question. Numbers below are what the compact sample data shows.

| Page | Question it answers | Visuals | What to notice |
|---|---|---|---|
| **1. Executive Overview** | Are we winning? | 4 KPI cards, mini trend charts, baseline-vs-current columns | 26.0 h → 18.0 h · 64% → 82% · ₦5,244 → ₦4,981 · 73.6% → 96.6% |
| **2. Delivery Time and Carriers** | Why did deliveries get faster? | Transit trend with 26 h and 18 h reference lines, carrier comparison, quarterly speed, scheduling vs transit | SwiftRoute 17.4 h · NorthLink 22.9 h · Lagos Park Parcel 27.9 h. Shipments timed to production days went from 0% to 100%. |
| **3. Order Bottleneck and On-Time Delivery** | Where do orders get stuck? | On-time by quarter, wait-time breakdown, late reasons, on-time by project type, top late orders | Waiting for materials fell from about 52 h to about 21 h. |
| **4. Supply-Chain Operation: Lagos, Niger, Abuja** | What does the network cost and move? | Cost by quarter, lane matrix, map of deliveries, stock-heat matrix, stock-out days | 30 shipments, 1,692 kg, ₦276,487 across all lanes. |
| **5. Sourcing and Suppliers** | Can we trust our suppliers? | Fill rate vs trusted share, supplier scorecard, fill rate by product, flex and school-kit supply | Trusted-supplier orders: 25% → 100%. |

## Design choices (and why)
- **One date table for all four fact tables.** A Year or Month slicer filters every chart.
- **KPI cards ignore the slicers on purpose** (`REMOVEFILTERS ( dim_date )`), so the headline always compares the same two six-month windows.
- **Baseline-vs-current columns** replace monthly lines for on-time and cost, because with few orders a month the monthly line jumps around.
- **Quarter axis sorted by `Quarter Sort`**, so "Q4 2025" does not appear after "Q3 2026".
- **Interpolation set to Linear**, so a smooth curve doesn't invent values between real data points.

## Re-create it
1. Connect: [`connect-to-mysql.md`](connect-to-mysql.md) and [`Khass_MySQL_Connection.pq`](Khass_MySQL_Connection.pq).
2. Paste the measures from [`measures.dax`](measures.dax).
3. Apply the theme [`khass_theme.json`](khass_theme.json) (View > Themes > Browse for themes).
4. Build the pages above. Commit your `.pbix` to this folder if you want others to open it.
