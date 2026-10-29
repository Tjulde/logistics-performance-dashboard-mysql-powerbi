-- =====================================================================
-- 02a_mini_insert_dimensions.sql  -  DIMENSION tables
-- Plain INSERT statements (no LOAD DATA / local_infile needed). SIMULATED data.
-- Run 01_schema.sql first.
-- =====================================================================
USE khass_logistics_mini;
START TRANSACTION;

-- locations: 4 rows
INSERT INTO locations (location_id, city, state, role) VALUES
  (1, 'Lagos', 'Lagos', 'Sourcing hub'),
  (2, 'Lapai', 'Niger', 'Production base'),
  (3, 'Minna', 'Niger', 'Delivery point'),
  (4, 'Abuja', 'FCT', 'Supply and delivery point');

-- customers: 12 rows
INSERT INTO customers (customer_id, customer_name, customer_type, location_id) VALUES
  (1, 'History Students'' Association', 'Student Association', 4),
  (2, 'Microbiology Students'' Association', 'Student Association', 2),
  (3, 'Chemistry Students'' Association', 'Student Association', 3),
  (4, 'Public Administration Students'' Association', 'Student Association', 4),
  (5, 'Dept. of Computer Science', 'Department', 2),
  (6, 'Dept. of Mass Communication', 'Department', 3),
  (7, 'Dept. of Physics', 'Department', 2),
  (8, 'Dept. of Chemistry', 'Department', 4),
  (9, 'Dept. of Geography', 'Department', 3),
  (10, 'Faculty of Management Sciences', 'Faculty', 4),
  (11, 'Faculty of Agriculture', 'Faculty', 2),
  (12, 'Individual Client 05', 'Individual', 3);

-- suppliers: 14 rows
INSERT INTO suppliers (supplier_id, supplier_name, city, location_id, category, sourcing_channel, onboarded_date, vetting_decision_date, status, trust_score) VALUES
  (1, 'Lagos Flex & Media Hub', 'Lagos', 1, 'Flex & Banner Media', 'Online marketplace', '2024-01-05', '2024-02-10', 'Trusted', 9.1),
  (2, 'Ikeja Paper & Card Mart', 'Lagos', 1, 'Paper & Card', 'Online marketplace', '2024-01-05', '2024-03-01', 'Trusted', 8.8),
  (3, 'Island Blank Apparel Co', 'Lagos', 1, 'Blank Apparel', 'Online marketplace', '2024-01-08', '2024-04-15', 'Trusted', 8.7),
  (4, 'GiftPack Lagos', 'Lagos', 1, 'Gift & Packaging', 'WhatsApp catalogue', '2024-01-10', '2024-06-20', 'Trusted', 8.5),
  (5, 'Surulere Stationery Depot', 'Lagos', 1, 'Stationery & School Kits', 'Online marketplace', '2024-01-12', '2024-05-10', 'Trusted', 8.9),
  (6, 'InkWorks Lagos', 'Lagos', 1, 'Inks & Consumables', 'Online marketplace', '2024-01-12', '2024-07-01', 'Trusted', 8.6),
  (7, 'QuickFlex Online', 'Lagos', 1, 'Flex & Banner Media', 'WhatsApp catalogue', '2024-02-20', '2024-04-30', 'Rejected', 4.2),
  (8, 'MegaPaper Express', 'Lagos', 1, 'Paper & Card', 'WhatsApp catalogue', '2024-03-05', '2024-06-01', 'Rejected', 4.8),
  (9, 'CupCraft Wholesale', 'Lagos', 1, 'Gift & Packaging', 'Online marketplace', '2024-05-15', '2024-09-01', 'Trusted', 8.4),
  (10, 'Campus Kits Lagos', 'Lagos', 1, 'Stationery & School Kits', 'Online marketplace', '2024-09-10', '2024-12-01', 'Trusted', 8.8),
  (11, 'ThreadLine Apparel', 'Lagos', 1, 'Blank Apparel', 'Direct referral', '2024-11-01', '2025-02-15', 'Trusted', 8.6),
  (12, 'Banner Pro Lagos', 'Lagos', 1, 'Flex & Banner Media', 'Online marketplace', '2025-01-15', '2025-04-01', 'Trusted', 9.0),
  (13, 'Abuja Ink & Consumables', 'Abuja', 4, 'Inks & Consumables', 'Online marketplace', '2024-06-10', '2024-10-01', 'Trusted', 8.3),
  (14, 'Capital Paper Depot', 'Abuja', 4, 'Paper & Card', 'Online marketplace', '2024-08-01', '2025-01-10', 'Trusted', 8.5);

-- carriers: 6 rows
INSERT INTO carriers (carrier_id, carrier_name, carrier_type, active_from, active_to) VALUES
  (1, 'Lagos Park Parcel Service', 'Bus-park parcel', '2024-01-01', '2024-11-30'),
  (2, 'NorthLink Freight', 'Road freight', '2024-01-01', NULL),
  (3, 'Capital Express Cargo', 'Road freight', '2024-07-01', NULL),
  (4, 'SwiftRoute Logistics', 'Scheduled road freight', '2025-02-01', NULL),
  (5, 'Savanna Dispatch', 'Regional courier', '2024-01-01', NULL),
  (6, 'Khass In-House Delivery', 'In-house rider', '2024-01-01', NULL);

-- products: 9 rows
INSERT INTO products (product_id, product_name, supplier_category, unit, unit_cost_ngn, reorder_level, weight_kg_per_unit) VALUES
  (1, 'Flex roll (banner media)', 'Flex & Banner Media', 'm2', 900, 55, 0.4),
  (2, 'Magic cup blanks', 'Gift & Packaging', 'pcs', 1400, 73, 0.14),
  (3, 'T-shirt blanks', 'Blank Apparel', 'pcs', 2100, 106, 0.22),
  (4, 'A4 art paper', 'Paper & Card', 'ream', 4200, 6, 2.4),
  (5, 'Card stock (100 sheets)', 'Paper & Card', 'pack', 3800, 7, 0.8),
  (6, 'Gift box blanks', 'Gift & Packaging', 'pcs', 450, 70, 0.09),
  (7, 'Kraft paper bags', 'Gift & Packaging', 'pcs', 90, 196, 0.03),
  (8, 'School kit & jotter packs', 'Stationery & School Kits', 'pack', 520, 213, 0.45),
  (9, 'Screen printing ink', 'Inks & Consumables', 'litre', 6500, 3, 1.1);

COMMIT;

-- Row-count check
SELECT 'locations' AS table_name, COUNT(*) AS row_count, 4 AS expected FROM locations UNION ALL
SELECT 'customers' AS table_name, COUNT(*) AS row_count, 12 AS expected FROM customers UNION ALL
SELECT 'suppliers' AS table_name, COUNT(*) AS row_count, 14 AS expected FROM suppliers UNION ALL
SELECT 'carriers' AS table_name, COUNT(*) AS row_count, 6 AS expected FROM carriers UNION ALL
SELECT 'products' AS table_name, COUNT(*) AS row_count, 9 AS expected FROM products;
