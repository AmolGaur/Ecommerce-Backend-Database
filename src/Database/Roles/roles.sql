-- Create roles for access control
CREATE ROLE admin_role;
CREATE ROLE user_role;
CREATE ROLE guest_role;

-- Grant privileges to roles
-- Admin: Full access to all tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO admin_role;

-- User: Limited access to specific tables
GRANT SELECT, INSERT, UPDATE ON Customer, "Order", Order_Item, Cart, Wishlist TO user_role;
GRANT SELECT ON Product, Category TO user_role;

-- Guest: Read-only access to public data
GRANT SELECT ON Product, Category TO guest_role;
