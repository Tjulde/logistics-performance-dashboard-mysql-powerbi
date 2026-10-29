# Data dictionary

9 tables plus a date table. **Dimensions** describe things (who, what, where). **Facts** record events (what happened and when).

## Dimensions
| Table | One row is… | Key columns |
|---|---|---|
| `locations` | a city we ship from or to | `location_id` (1 Lagos, 2 Lapai, 3 Minna, 4 Abuja), `city`, `state`, `role` |
| `customers` | a customer | `customer_id`, `customer_name`, `customer_type` (Student Association / Department / Faculty / Individual), `location_id` |
| `suppliers` | a material supplier | `supplier_id`, `supplier_name`, `city`, `category`, `sourcing_channel`, `onboarded_date`, `vetting_decision_date`, `status` (Trusted / Rejected), `trust_score` |
| `carriers` | a delivery company | `carrier_id`, `carrier_name`, `carrier_type`, `active_from`, `active_to` |
| `products` | a raw material | `product_id`, `product_name`, `supplier_category`, `unit`, `unit_cost_ngn`, `reorder_level`, `weight_kg_per_unit` |
| `dim_date` | a calendar day (2024–2026) | `date_key`, `year_num`, `quarter_num`, `month_start`, `is_complete_month`, `period_label` (Baseline / Current / Transition) |

## Facts
| Table | One row is… | Key columns |
|---|---|---|
| `orders` | a customer order | `order_id`, `customer_id`, `project_type`, `product_id`, `qty`, `order_value_ngn`, `order_ts`, `promised_ts`, `materials_ready_ts`, `production_start_ts`, `production_end_ts`, `delivered_ts`, `destination_id`, `material_wait_hours`, `queue_hours`, `delay_reason`, `status` |
| `purchase_orders` | an order placed with a supplier | `po_id`, `supplier_id`, `product_id`, `po_date`, `qty_requested`, `qty_received`, `supplier_promised_ts`, `supplier_dispatch_ts`, `vetted_at_order`, `status` |
| `shipments` | one trip of goods | `shipment_id`, `shipment_type` (Inbound materials / Outbound finished orders), `order_id` or `po_id`, `carrier_id`, `origin_id`, `destination_id`, `dispatch_ts`, `arrival_ts`, `weight_kg`, `freight_cost_ngn`, `handling_cost_ngn`, `scheduled_to_production_slot`, `status` |
| `inventory_snapshots` | a product's stock at a month end | `month_end`, `product_id`, `opening_qty`, `received_qty`, `demand_qty`, `consumed_qty`, `closing_qty`, `stockout_days`, `reorder_level`, `below_reorder` |

## Rules worth knowing
- `delay_reason` is filled **only** for orders delivered late, and only with: *Material delay, Carrier delay, Production backlog, Customer change*.
- An order that is not yet delivered has no `delivered_ts` and no `delay_reason`.
- `scheduled_to_production_slot` is set for inbound shipments only: `1` means the shipment was timed to a production slot.
- Money is in Nigerian naira (₦). Times are local.
