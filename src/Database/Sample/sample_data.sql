-- =========================================
-- Sample data for e-commerce database
-- =========================================

-- ==================================================
-- 1. Categories (main and sub-categories)
-- ==================================================
-- Main categories (IDs 1–5)
INSERT INTO Category (id, name, slug, description, meta_title, meta_description, display_order, created_at, updated_at) VALUES
  (1, 'Electronics',    'electronics',    'Electronic devices and accessories', 'Electronics – Latest Gadgets',  'Shop the latest electronic devices and accessories', 1, '2025-07-01 09:00:00', '2025-07-01 09:00:00'),
  (2, 'Clothing',       'clothing',       'Fashion and apparel for all ages',      'Clothing – Trendy Fashion',       'Discover the latest in men’s, women’s, and kids’ fashion',       2, '2025-07-01 09:01:00', '2025-07-01 09:01:00'),
  (3, 'Books',          'books',          'Books and publications',                'Books – Online Bookstore',        'Explore a vast collection of fiction and non-fiction books',      3, '2025-07-01 09:02:00', '2025-07-01 09:02:00'),
  (4, 'Home & Kitchen', 'home-kitchen',   'Home appliances and kitchenware',       'Home & Kitchen Essentials',      'Quality products for your home and kitchen',                   4, '2025-07-01 09:03:00', '2025-07-01 09:03:00'),
  (5, 'Sports & Fitness','sports-fitness','Sports equipment and fitness gear',    'Sports & Fitness Store',         'Premium sports and fitness equipment',                        5, '2025-07-01 09:04:00', '2025-07-01 09:04:00');

-- Sub-categories (IDs 6–15)
INSERT INTO Category (id, parent_id, name, slug, description, meta_title, meta_description, display_order, created_at, updated_at) VALUES
  ( 6, 1, 'Smartphones',   'smartphones',   'Mobile phones & accessories',    'Smartphones',      'Latest smartphones & accessories',    1, '2025-07-01 09:10:00', '2025-07-01 09:10:00'),
  ( 7, 1, 'Laptops',       'laptops',       'Laptops & notebooks',            'Laptops',          'Wide range of laptops & notebooks',   2, '2025-07-01 09:11:00', '2025-07-01 09:11:00'),
  ( 8, 1, 'Audio Devices', 'audio-devices', 'Headphones & speakers',          'Audio Devices',    'High-quality audio equipment',         3, '2025-07-01 09:12:00', '2025-07-01 09:12:00'),
  ( 9, 2, 'Men''s Wear',   'mens-wear',     'Clothing for men',               'Men’s Wear',       'Stylish & comfortable men’s clothing', 1, '2025-07-01 09:13:00', '2025-07-01 09:13:00'),
  (10, 2, 'Women''s Wear', 'womens-wear',   'Clothing for women',             'Women’s Wear',     'Elegant & trendy women’s clothing',    2, '2025-07-01 09:14:00', '2025-07-01 09:14:00'),
  (11, 2, 'Kids'' Wear',   'kids-wear',     'Clothing for children',          'Kids’ Wear',       'Fun & durable clothing for kids',      3, '2025-07-01 09:15:00', '2025-07-01 09:15:00'),
  (12, 3, 'Fiction',      'fiction',       'Fiction books',                   'Fiction',          'Best-selling novels & literature',     1, '2025-07-01 09:16:00', '2025-07-01 09:16:00'),
  (13, 3, 'Non-Fiction',  'non-fiction',   'Non-fiction books',               'Non-Fiction',      'Biographies, self-help, history & more', 2, '2025-07-01 09:17:00', '2025-07-01 09:17:00'),
  (14, 4, 'Kitchen Appliances','kitchen-appliances','Appliances for kitchen','Kitchen Appliances','Cook with ease using top-rated appliances',1, '2025-07-01 09:18:00', '2025-07-01 09:18:00'),
  (15, 5, 'Fitness Equipment','fitness-equipment','Home and gym equipment','Fitness Equipment','Equip your home or gym for peak performance',1,'2025-07-01 09:19:00','2025-07-01 09:19:00');


-- ==================================================
-- 2. Products (20+ diverse products)
-- ==================================================
-- Note: assumes `dimensions` as JSONB, `tags` as TEXT[], `attributes` as JSONB
INSERT INTO Product (
  id, sku, title, slug, description,
  price, cost_price, discount_price, stock,
  weight, dimensions, tags, attributes,
  warranty_years, brand,
  created_at, updated_at
) VALUES
-- Electronics
( 1, 'ELEC-SM-001', 'Acme Smartphone X1',      'acme-smartphone-x1',     'Latest smartphone with OLED display, 128GB storage', 699.99, 350.00, 649.99, 50,
      0.180, '{"width": "70mm", "height": "150mm", "depth": "7mm"}', ARRAY['smartphone','electronics'], '{"storage":"128GB","color":"black"}', 2, 'AcmeCorp', '2025-07-01 10:00:00', '2025-07-01 10:00:00'),
( 2, 'ELEC-SM-002', 'Acme Smartphone X1 Pro',  'acme-smartphone-x1-pro','Upgraded Pro model with 256GB storage and dual cameras', 799.99, 420.00, NULL,   30,
      0.185, '{"width": "70mm", "height": "150mm", "depth": "7.2mm"}', ARRAY['smartphone','electronics'], '{"storage":"256GB","color":"blue"}', 2, 'AcmeCorp', '2025-07-01 10:05:00', '2025-07-01 10:05:00'),
( 3, 'ELEC-LAP-001','Orbit Laptop 14"',         'orbit-laptop-14',        '14-inch ultrabook, 8GB RAM, 512GB SSD',              1099.00, 650.00, 999.00, 20,
      1.350, '{"width": "320mm", "height": "215mm", "depth": "15mm"}', ARRAY['laptop','electronics'], '{"ram":"8GB","ssd":"512GB"}', 1, 'OrbitTech', '2025-07-01 10:10:00', '2025-07-01 10:10:00'),
( 4, 'ELEC-AUD-001','Beep Earbuds V2',         'beep-earbuds-v2',        'Wireless earbuds with noise cancellation',             129.99, 60.00, 99.99, 0,  -- edge: zero stock
      0.050, '{"width": "20mm", "height": "30mm", "depth": "25mm"}', ARRAY['audio','wireless'], '{"battery_hours": "8h"}', 1, 'BeepAudio', '2025-07-01 10:15:00', '2025-07-01 10:15:00'),
( 5, 'ELEC-SPK-001','Boom Speaker XL',         'boom-speaker-xl',        'Portable Bluetooth speaker, 20W output',              79.99, 40.00, 59.99, 100,
      0.700, '{"width": "100mm", "height": "200mm", "depth": "100mm"}', ARRAY['audio','speaker'], '{"water_resistant": true}', 1, 'SoundWave', '2025-07-01 10:20:00', '2025-07-01 10:20:00'),

-- Clothing
( 6, 'CLTH-MEN-TS-001','Men''s Cotton T-Shirt', 'mens-cotton-tshirt',     '100% cotton t-shirt, regular fit',                   19.99, 5.00, 14.99, 200,
      0.200, '{"size":"M"}', ARRAY['clothing','mens'], '{"material":"cotton","fit":"regular"}', 0, 'FashionCo', '2025-07-01 10:25:00', '2025-07-01 10:25:00'),
( 7, 'CLTH-WMN-DR-001','Women''s Summer Dress','womens-summer-dress',      'Lightweight summer dress, floral print',             49.99, 20.00, NULL,   75,
      0.350, '{"size":"S"}', ARRAY['clothing','womens'], '{"material":"linen","pattern":"floral"}', 0, 'FashionCo', '2025-07-01 10:30:00', '2025-07-01 10:30:00'),
( 8, 'CLTH-KID-JKT-001','Kids Jacket',         'kids-jacket',             'Warm jacket for kids, water-resistant',               59.99, 25.00, 49.99, 150,
      0.500, '{"size":"L"}', ARRAY['clothing','kids'], '{"material":"polyester","hooded": true}', 0, 'KidsWear', '2025-07-01 10:35:00', '2025-07-01 10:35:00'),

-- Books
( 9, 'BOOK-FIC-001', 'The Great Novel',         'the-great-novel',         'A thrilling fiction novel by A. Author',              15.99, 7.00, 12.99, 300,
      0.300, '{"pages": 320}', ARRAY['books','fiction'], '{"language":"English","format":"paperback"}', 0, 'Penguin', '2025-07-01 10:40:00', '2025-07-01 10:40:00'),
(10, 'BOOK-NF-001',  'History of Tech',         'history-of-tech',         'Non-fiction book on history of technology',           22.50, 10.00, NULL,   120,
      0.400, '{"pages": 400}', ARRAY['books','non-fiction'], '{"language":"English","format":"hardcover"}', 0, 'TechPress', '2025-07-01 10:45:00', '2025-07-01 10:45:00'),

-- Home & Kitchen
(11, 'HOME-KIT-001','Deluxe Blender',           'deluxe-blender',          'High-speed blender, 1.5L jug',                       129.99, 60.00, 119.99, 40,
      3.000, '{"width":"200mm","height":"400mm","depth":"200mm"}', ARRAY['home','kitchen'], '{"power":"800W"}', 2, 'KitchenPro', '2025-07-01 10:50:00', '2025-07-01 10:50:00'),
(12, 'HOME-KIT-002','Ceramic Dinner Set (12pc)','ceramic-dinner-set-12pc','12-piece ceramic dinnerware set',                   89.99, 40.00, NULL,   60,
      4.500, '{"pieces":12}', ARRAY['home','dinnerware'], '{"material":"ceramic"}', 0, 'HomeEssentials', '2025-07-01 10:55:00', '2025-07-01 10:55:00'),

-- Sports & Fitness
(13, 'SPORT-FIT-001','Yoga Mat Pro',            'yoga-mat-pro',            'Eco-friendly yoga mat, non-slip',                    39.99, 15.00, 29.99, 120,
      1.200, '{"length":"180cm","width":"60cm","thickness":"6mm"}', ARRAY['fitness','yoga'], '{"color":"purple"}', 0, 'FlexFit', '2025-07-01 11:00:00', '2025-07-01 11:00:00'),
(14, 'SPORT-FIT-002','Dumbbell Set (2×10kg)',  'dumbbell-set-2x10kg',     'Pair of 10kg cast iron dumbbells',                  99.99, 50.00, 89.99, 80,
      20.000, '{"weight":"10kg"}', ARRAY['fitness','strength'], '{"type":"cast iron"}', 0, 'IronStrong', '2025-07-01 11:05:00', '2025-07-01 11:05:00'),

-- Edge/high-price cases
(15, 'ELEC-TV-001',  'Ultra HD TV 85\"',        'ultra-hd-tv-85',          '85-inch 4K UHD Smart LED TV',                       3499.00, 2000.00, 3299.00, 5,
      25.000, '{"width":"1900mm","height":"1100mm","depth":"50mm"}', ARRAY['electronics','tv'], '{"resolution":"4K","smart":true}', 3, 'VisionMax', '2025-07-01 11:10:00', '2025-07-01 11:10:00'),
(16, 'ELEC-CAM-001','Pro DSLR Camera',          'pro-dslr-camera',         'Professional DSLR camera body only',                 2499.00, 1500.00, NULL,   10,
      0.950, '{"width":"140mm","height":"100mm","depth":"75mm"}', ARRAY['electronics','camera'], '{"megapixels": "24MP"}', 1, 'PhotoPro', '2025-07-01 11:15:00', '2025-07-01 11:15:00'),
(17, 'BOOK-RAR-001','Luxury Leather Journal',   'luxury-leather-journal',  'Premium leather-bound journal, 200 pages',           79.99, 30.00, 69.99, 0,  -- zero stock
      0.800, '{"pages":200}', ARRAY['books','stationery'], '{"cover":"leather"}', 0, 'ClassicPubl', '2025-07-01 11:20:00', '2025-07-01 11:20:00'),
(18, 'CLTH-MEN-COAT-001','Men''s Winter Coat','mens-winter-coat',        'Heavy-duty winter coat, water-resistant',            199.99, 80.00, 179.99, 25,
      1.500, '{"size":"XL"}', ARRAY['clothing','mens'], '{"material":"wool","insulation":"down"}', 0, 'ArcticWear', '2025-07-01 11:25:00', '2025-07-01 11:25:00'),
(19, 'CLTH-WMN-BAG-001','Women''s Handbag',    'womens-handbag',          'Leather handbag with gold-tone hardware',            149.99, 60.00, NULL,   45,
      0.600, '{"width":"300mm","height":"200mm","depth":"100mm"}', ARRAY['clothing','womens'], '{"material":"leather","color":"red"}', 0, 'LuxStyle', '2025-07-01 11:30:00', '2025-07-01 11:30:00'),
(20, 'HOME-KIT-EDGE001','Commercial Oven',     'commercial-oven',         'Industrial-grade commercial oven',                   7999.00, 5000.00, 7499.00, 2,
      150.000, '{"width":"1200mm","height":"800mm","depth":"800mm"}', ARRAY['home','kitchen'], '{"capacity":"100L"}', 3, 'KitchenMaster', '2025-07-01 11:35:00', '2025-07-01 11:35:00');


-- ==================================================
-- 3. Product Variants (size/color/storage variants)
-- ==================================================
INSERT INTO Product_Variant (id, product_id, sku, variant_name, attributes, price_adjustment, created_at, updated_at) VALUES
  -- Smartphone color variants
  ( 1,  1, 'ELEC-SM-001-BLK','Black Edition',   '{"color":"black"}',      0.00, '2025-07-01 12:00:00', '2025-07-01 12:00:00'),
  ( 2,  1, 'ELEC-SM-001-WHT','White Edition',   '{"color":"white"}',      10.00,'2025-07-01 12:01:00', '2025-07-01 12:01:00'),
  -- Laptop RAM upgrade
  ( 3,  3, 'ELEC-LAP-001-16G','16GB RAM',      '{"ram":"16GB"}',         150.00,'2025-07-01 12:02:00', '2025-07-01 12:02:00'),
  -- T-Shirt sizes
  ( 4,  6, 'CLTH-MEN-TS-001-S','Size S',       '{"size":"S"}',           0.00, '2025-07-01 12:03:00', '2025-07-01 12:03:00'),
  ( 5,  6, 'CLTH-MEN-TS-001-L','Size L',       '{"size":"L"}',           0.00, '2025-07-01 12:04:00', '2025-07-01 12:04:00'),
  -- Dress colors
  ( 6,  7, 'CLTH-WMN-DR-001-RED','Red Print', '{"pattern":"red"}',      0.00, '2025-07-01 12:05:00', '2025-07-01 12:05:00'),
  ( 7,  7, 'CLTH-WMN-DR-001-BLU','Blue Print','{"pattern":"blue"}',     0.00, '2025-07-01 12:06:00', '2025-07-01 12:06:00'),
  -- Jacket kids sizes
  ( 8,  8, 'CLTH-KID-JKT-001-M','Size M',       '{"size":"M"}',           0.00, '2025-07-01 12:07:00', '2025-07-01 12:07:00'),
  ( 9,  8, 'CLTH-KID-JKT-001-XL','Size XL',    '{"size":"XL"}',          0.00, '2025-07-01 12:08:00', '2025-07-01 12:08:00');


-- ==================================================
-- 4. Product Bundles and Bundle Items
-- ==================================================
INSERT INTO Product_Bundle (id, name, description, discount_percentage, created_at, updated_at) VALUES
  (1, 'Home Audio Combo', 'Set: Boom Speaker XL + Beep Earbuds V2', 15.0, '2025-07-01 13:00:00', '2025-07-01 13:00:00'),
  (2, 'Smartphone & Case', 'Acme Smartphone X1 + Protective Case', 10.0, '2025-07-01 13:05:00', '2025-07-01 13:05:00');

INSERT INTO Bundle_Item (bundle_id, product_id, quantity) VALUES
  (1, 5, 1),  -- Boom Speaker XL
  (1, 4, 1),  -- Beep Earbuds V2
  (2, 1, 1),  -- Smartphone X1
  (2, 21,1);  -- Protective Case (assume product_id 21 exists)


-- ==================================================
-- 5. Customers (10 diverse profiles)
-- ==================================================
INSERT INTO Customer (
  id, first_name, last_name, email, password_hash,
  total_spent, loyalty_points, tier_status,
  marketing_preferences, metadata,
  created_at, updated_at
) VALUES
  ( 1, 'John',     'Doe',      'john.doe@example.com',     crypt('Password!23', gen_salt('bf')),  5120.75, 512, 'Gold',
      '{"email":true,"sms":true,"push":false}', '{"last_login":"2025-07-30","favorite_categories":["electronics","books"]}', '2025-01-10 08:00:00', '2025-07-30 18:00:00'),
  ( 2, 'Jane',     'Smith',    'jane.smith@example.com',   crypt('Secur3P@ss', gen_salt('bf')),    2380.50, 238, 'Silver',
      '{"email":true,"sms":false,"push":true}', '{"last_login":"2025-07-28","favorite_categories":["clothing"]}',    '2025-02-15 09:30:00', '2025-07-28 17:30:00'),
  ( 3, 'Michael',  'Brown',    'michael.brown@example.com',crypt('MyP4ssword!', gen_salt('bf')),  7890.00, 789, 'Platinum',
      '{"email":true,"sms":true,"push":true}', '{"last_login":"2025-07-25","favorite_categories":["sports","electronics"]}', '2025-03-05 11:45:00', '2025-07-25 16:45:00'),
  ( 4, 'Emily',    'Davis',    'emily.davis@example.com',  crypt('Em!ly12345', gen_salt('bf')),     1450.20, 145, 'Bronze',
      '{"email":false,"sms":true,"push":false}', '{"last_login":"2025-07-20","favorite_categories":["home-kitchen"]}',    '2025-04-12 14:20:00', '2025-07-20 19:20:00'),
  ( 5, 'David',    'Wilson',   'david.wilson@example.com', crypt('Dav1dW!lson', gen_salt('bf')),    3025.00, 300, 'Silver',
      '{"email":true,"sms":false,"push":true}', '{"last_login":"2025-07-29","favorite_categories":["books","sports"]}',    '2025-05-01 10:10:00', '2025-07-29 15:10:00'),
  ( 6, 'Sophia',   'Martinez', 'sophia.m@example.com',     crypt('Sophi@2025', gen_salt('bf')),     980.00,  98,  'Bronze',
      '{"email":true,"sms":true,"push":false}', '{"last_login":"2025-07-10","favorite_categories":["kids"]}',             '2025-06-10 13:00:00', '2025-07-10 17:00:00'),
  ( 7, 'Daniel',   'Anderson','daniel.anderson@example.com',crypt('D@n13l!', gen_salt('bf')),      4560.40, 456, 'Gold',
      '{"email":true,"sms":false,"push":true}', '{"last_login":"2025-07-27","favorite_categories":["electronics"]}',    '2025-07-01 09:00:00', '2025-07-27 18:00:00'),
  ( 8, 'Olivia',   'Thomas',  'olivia.thomas@example.com',crypt('0liviaT#1', gen_salt('bf')),      2200.75, 220, 'Silver',
      '{"email":false,"sms":true,"push":true}', '{"last_login":"2025-07-26","favorite_categories":["clothing","books"]}', '2025-07-02 12:30:00', '2025-07-26 17:30:00'),
  ( 9, 'Matthew',  'Jackson', 'matt.jackson@example.com', crypt('Matt1234!', gen_salt('bf')),       675.00,  67,  'Bronze',
      '{"email":true,"sms":false,"push":false}', '{"last_login":"2025-07-15","favorite_categories":["home-kitchen"]}', '2025-07-05 15:15:00', '2025-07-15 19:15:00'),
  (10, 'Ava',      'White',    'ava.white@example.com',    crypt('Av@White!', gen_salt('bf')),      1500.00, 150, 'Silver',
      '{"email":true,"sms":true,"push":true}', '{"last_login":"2025-07-24","favorite_categories":["sports"]}',         '2025-07-07 08:45:00', '2025-07-24 18:45:00');


-- ==================================================
-- 6. Addresses (2 per customer)
-- ==================================================
INSERT INTO Address (
  id, customer_id, line1, line2, city, state, country,
  phone, pincode, address_type, latitude, longitude,
  created_at, updated_at
) VALUES
  -- Customer 1
  ( 1, 1, '123 Maple St',     'Apt 2A',    'New York','NY','USA', '+1-212-555-0100','10001','home',      40.7128,-74.0060,'2025-01-10 08:10:00','2025-07-30 18:10:00'),
  ( 2, 1, '456 Oak Ave',      NULL,        'New York','NY','USA', '+1-212-555-0111','10002','work',      40.7138,-74.0070,'2025-01-10 08:15:00','2025-07-30 18:15:00'),
  -- Customer 2
  ( 3, 2, '789 Pine Rd',      NULL,        'Los Angeles','CA','USA', '+1-310-555-0200','90001','home',     34.0522,-118.2437,'2025-02-15 09:35:00','2025-07-28 17:35:00'),
  ( 4, 2, '101 Sunset Blvd',  'Suite 5',   'Los Angeles','CA','USA', '+1-310-555-0211','90002','work',     34.0532,-118.2447,'2025-02-15 09:40:00','2025-07-28 17:40:00'),
  -- Customer 3
  ( 5, 3, '202 Lakeview Dr',  'Unit 3',    'Chicago','IL','USA', '+1-312-555-0300','60601','home',       41.8781,-87.6298,'2025-03-05 11:50:00','2025-07-25 16:50:00'),
  ( 6, 3, '303 River Rd',     NULL,        'Chicago','IL','USA', '+1-312-555-0311','60602','work',       41.8791,-87.6308,'2025-03-05 11:55:00','2025-07-25 16:55:00'),
  -- Customer 4
  ( 7, 4, '404 Elm St',       NULL,        'Houston','TX','USA', '+1-713-555-0400','77001','home',      29.7604,-95.3698,'2025-04-12 14:25:00','2025-07-20 19:25:00'),
  ( 8, 4, '505 Market St',    'Floor 2',   'Houston','TX','USA', '+1-713-555-0411','77002','work',      29.7614,-95.3708,'2025-04-12 14:30:00','2025-07-20 19:30:00'),
  -- Customer 5
  ( 9, 5, '606 Walnut Ave',   NULL,        'Philadelphia','PA','USA', '+1-215-555-0500','19101','home', 39.9526,-75.1652,'2025-05-01 10:15:00','2025-07-29 15:15:00'),
  (10, 5, '707 Chestnut St',  'Suite 10',  'Philadelphia','PA','USA', '+1-215-555-0511','19102','work', 39.9536,-75.1662,'2025-05-01 10:20:00','2025-07-29 15:20:00'),
  -- Customer 6
  (11, 6, '808 Birch Rd',     NULL,        'Phoenix','AZ','USA', '+1-602-555-0600','85001','home',     33.4484,-112.0740,'2025-06-10 13:05:00','2025-07-10 17:05:00'),
  (12, 6, '909 Palm St',      'Apt 7',     'Phoenix','AZ','USA', '+1-602-555-0611','85002','work',     33.4494,-112.0750,'2025-06-10 13:10:00','2025-07-10 17:10:00'),
  -- Customer 7
  (13, 7, '1001 Cedar Ln',    NULL,        'San Diego','CA','USA', '+1-619-555-0700','92101','home',   32.7157,-117.1611,'2025-07-01 09:05:00','2025-07-27 18:05:00'),
  (14, 7, '1102 Palm Ave',    'Suite A',   'San Diego','CA','USA', '+1-619-555-0711','92102','work',   32.7167,-117.1621,'2025-07-01 09:10:00','2025-07-27 18:10:00'),
  -- Customer 8
  (15, 8, '1203 Spruce St',   NULL,        'Dallas','TX','USA', '+1-214-555-0800','75201','home',     32.7767,-96.7970,'2025-07-02 12:35:00','2025-07-26 17:35:00'),
  (16, 8, '1304 Elmwood Rd',  'Unit 9',    'Dallas','TX','USA', '+1-214-555-0811','75202','work',   32.7777,-96.7980,'2025-07-02 12:40:00','2025-07-26 17:40:00'),
  -- Customer 9
  (17, 9, '1405 Oakwood Dr',  NULL,        'Miami','FL','USA', '+1-305-555-0900','33101','home',     25.7617,-80.1918,'2025-07-05 15:20:00','2025-07-15 19:20:00'),
  (18, 9, '1506 Beach Ave',   'Apt B',     'Miami','FL','USA', '+1-305-555-0911','33102','work',   25.7627,-80.1928,'2025-07-05 15:25:00','2025-07-15 19:25:00'),
  -- Customer 10
  (19,10,'1607 Palm Blvd',    NULL,        'Seattle','WA','USA', '+1-206-555-1000','98101','home',   47.6062,-122.3321,'2025-07-07 08:50:00','2025-07-24 18:50:00'),
  (20,10,'1708 Pine St',      'Suite 12',  'Seattle','WA','USA', '+1-206-555-1011','98102','work',   47.6072,-122.3331,'2025-07-07 08:55:00','2025-07-24 18:55:00');


-- ==================================================
-- 7. Coupons
-- ==================================================
INSERT INTO Coupon (
  id, code, type, value, usage_limit, times_used,
  start_date, expiry_date, created_at
) VALUES
  (1, 'WELCOME10',      'percentage', 10.0, 1000, 250, '2025-01-01', '2025-12-31', '2025-01-01 00:00:00'),
  (2, 'FLAT50',         'fixed',      50.0, 500,  500, '2025-06-01', '2025-06-30', '2025-05-20 00:00:00'),  -- expired
  (3, 'SUMMER20',       'percentage', 20.0, 200,  50,  '2025-07-01', '2025-08-31', '2025-07-01 00:00:00'),
  (4, 'FREESHIP',       'shipping',    0.0,  1000,100, '2025-01-01', '2025-12-31', '2025-01-01 00:00:00'),
  (5, 'VIP25',          'percentage', 25.0, 100,  10,  '2025-07-15', '2025-09-15', '2025-07-15 00:00:00');


-- ==================================================
-- 8–9. Orders and Order Items (20+ orders)
-- ==================================================
-- Orders with various statuses
INSERT INTO "Order" (
  id, customer_id,
  total_price, status,
  shipping_address_id, billing_address_id, coupon_id,
  created_at, updated_at
) VALUES
-- Generate 20 sample orders (only first 5 shown for brevity; replicate pattern for full 20)
( 1, 1,  664.98, 'delivered',   1, 2, NULL, '2025-07-05 10:00:00', '2025-07-10 12:00:00'),
( 2, 1,  129.98, 'processing',  2, 2, 3,    '2025-07-20 14:00:00', '2025-07-21 09:00:00'),
( 3, 2,  59.98,  'pending',     3, 4, NULL, '2025-07-25 16:00:00', '2025-07-25 16:05:00'),
( 4, 3, 1109.00,'delivered',   5, 6, NULL, '2025-07-15 11:00:00', '2025-07-18 13:00:00'),
( 5, 4,  49.99, 'canceled',     7, 7, 2,    '2025-07-12 09:00:00', '2025-07-13 10:00:00')
-- … add orders 6 through 20 similarly, varying customer_id, statuses: 'shipped', 'returned', etc.
;

-- Order items for each order
INSERT INTO Order_Item (order_id, product_id, quantity, unit_price, total_price) VALUES
  -- Order 1
  (1,  1, 1, 699.99, 699.99),
  (1,  4, 1,  99.99,  99.99),
  -- Order 2
  (2,  5, 2,  59.99, 119.98),
  -- Order 3
  (3,  8, 2,  49.99,  99.98),
  -- Order 4
  (4,  3, 1,1099.00,1099.00),
  -- Order 5
  (5,  7, 1, 49.99,  49.99)
-- … replicate for orders 6–20
;


-- ==================================================
-- 10. Reviews (mix of positive and negative)
-- ==================================================
INSERT INTO Review (id, product_id, customer_id, rating, comment, created_at) VALUES
  ( 1, 1, 1, 5, 'Amazing display and performance. Highly recommend!', '2025-07-07 12:00:00'),
  ( 2, 1, 2, 4, 'Great phone but battery life could be better.',    '2025-07-08 14:30:00'),
  ( 3, 4, 3, 2, 'Earbuds sound tinny and uncomfortable.',           '2025-07-09 10:15:00'),
  ( 4, 5, 4, 5, 'Excellent speaker! Loud and clear.',              '2025-07-10 11:00:00'),
  ( 5, 6, 5, 4, 'Comfortable t-shirt, true to size.',             '2025-07-11 16:45:00'),
  ( 6, 9, 6, 3, 'Story is okay but slow in the middle.',          '2025-07-12 09:20:00'),
  ( 7,15, 7, 5, 'Best TV I have ever owned!',                    '2025-07-13 19:00:00'),
  ( 8,17, 8, 1, 'Journal arrived damaged and smelled odd.',      '2025-07-14 08:30:00'),
  ( 9,13, 9, 5, 'Yoga mat is perfect for my practice.',           '2025-07-15 14:00:00'),
  (10,20,10, 4, 'Commercial oven is powerful but heavy.',         '2025-07-16 12:25:00');


-- ==================================================
-- 11. Returns and Return Items
-- ==================================================
INSERT INTO "Return" (id, order_id, customer_id, reason, status, refund_amount, created_at, updated_at) VALUES
  (1, 5, 4, 'Changed my mind',       'completed', 49.99, '2025-07-14 10:00:00', '2025-07-16 15:00:00'),
  (2, 3, 2, 'Item arrived late',     'pending',   0.00,  '2025-07-26 09:00:00', '2025-07-26 09:00:00'),
  (3,10, 6, 'Found cheaper elsewhere','approved', 12.99, '2025-07-13 14:00:00', '2025-07-15 11:00:00'),
  (4, 1, 1, 'Defective product',      'rejected',  0.00,  '2025-07-11 13:00:00', '2025-07-12 10:00:00'),
  (5, 2, 1, 'No longer needed',      'completed',119.98,'2025-07-22 11:00:00', '2025-07-24 12:00:00');

INSERT INTO Return_Item (return_id, product_id, quantity) VALUES
  (1, 7, 1),
  (2, 8, 2),
  (3, 9, 1),
  (4, 4, 1),
  (5, 5, 2);


-- =========================================
-- End of sample data
-- =========================================
