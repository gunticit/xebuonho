-- Seed real data for Xebuonho (Users, Drivers, Merchants, Menu Items)

-- 1. Insert/Update Merchants (Restaurants & Supermarkets in TP.HCM)
INSERT INTO merchants (
    id, name, description, category, phone, location, address,
    rating, total_orders, is_active, is_verified, operating_hours
) VALUES
(
    'a1111111-1111-1111-1111-111111111111',
    'Cơm Tấm Phúc Lộc Thọ - Bến Nghé',
    'Chuỗi cơm tấm truyền thống đậm đà phong vị Sài Gòn xưa. Sườn nướng than hoa thơm lừng.',
    'food',
    '02873001234',
    ST_SetSRID(ST_MakePoint(106.7025, 10.7760), 4326)::geography,
    '32 Lê Thánh Tôn, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    4.9, 1250, true, true,
    '{"mon-sun": "06:00-23:00"}'::jsonb
),
(
    'a2222222-2222-2222-2222-222222222222',
    'Phúc Long Coffee & Tea - Ngô Đức Kế',
    'Trà và Cà phê đậm vị từ cao nguyên Bảo Lộc. Thức uống tươi ngon mỗi ngày.',
    'drink',
    '02838228333',
    ST_SetSRID(ST_MakePoint(106.7042, 10.7735), 4326)::geography,
    '42 Ngô Đức Kế, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    4.8, 2890, true, true,
    '{"mon-sun": "07:00-22:30"}'::jsonb
),
(
    'a3333333-3333-3333-3333-333333333333',
    'Phở 24 - Đồng Khởi',
    'Nước dùng ninh từ xương bò 24 giờ với 24 loại gia vị thảo mộc thiên nhiên.',
    'food',
    '02838242424',
    ST_SetSRID(ST_MakePoint(106.7031, 10.7752), 4326)::geography,
    '71 Đồng Khởi, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    4.7, 980, true, true,
    '{"mon-sun": "06:00-22:00"}'::jsonb
),
(
    'a4444444-4444-4444-4444-444444444444',
    'Bún Chả Hà Nội 1982',
    'Chả nướng kẹp que tre thơm nức mũi, nước chấm gia truyền nóng hổi kèm nem cua bể giòn rụm.',
    'food',
    '0908123982',
    ST_SetSRID(ST_MakePoint(106.6980, 10.7785), 4326)::geography,
    '15 Lý Tự Trọng, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    4.85, 1420, true, true,
    '{"mon-sun": "09:00-21:30"}'::jsonb
),
(
    'a5555555-5555-5555-5555-555555555555',
    'WinMart+ Tiện Lợi - Hai Bà Trưng',
    'Rau củ quả tươi sạch MEATDeli, thực phẩm nhập khẩu, đồ dùng gia đình hàng ngày.',
    'grocery',
    '02871088888',
    ST_SetSRID(ST_MakePoint(106.6965, 10.7812), 4326)::geography,
    '128 Hai Bà Trưng, Phường Đa Kao, Quận 1, TP. Hồ Chí Minh',
    4.92, 3100, true, true,
    '{"mon-sun": "06:00-22:00"}'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    address = EXCLUDED.address,
    location = EXCLUDED.location;

-- 2. Insert Menu Items for each Merchant
DELETE FROM menu_items WHERE merchant_id IN (
    'a1111111-1111-1111-1111-111111111111',
    'a2222222-2222-2222-2222-222222222222',
    'a3333333-3333-3333-3333-333333333333',
    'a4444444-4444-4444-4444-444444444444',
    'a5555555-5555-5555-5555-555555555555'
);

INSERT INTO menu_items (merchant_id, category_name, name, description, price, is_available) VALUES
-- Cơm Tấm Phúc Lộc Thọ
('a1111111-1111-1111-1111-111111111111', 'Món chính', 'Cơm Tấm Sườn Nướng Đặc Biệt', 'Sườn cốt lết dày thịt ướp sốt độc quyền nướng than hoa', 45000, true),
('a1111111-1111-1111-1111-111111111111', 'Món chính', 'Cơm Tấm Sườn Bì Chả Trứng', 'Đầy đủ sườn nướng, bì heo giòn, chả trứng hấp, trứng ốp la', 62000, true),
('a1111111-1111-1111-1111-111111111111', 'Canh & Rau', 'Canh Rong Biển Thịt Bằm', 'Canh rong biển nấu thanh mát giải nhiệt', 15000, true),

-- Phúc Long Coffee & Tea
('a2222222-2222-2222-2222-222222222222', 'Trà sữa', 'Trà Sữa Phúc Long (Size L)', 'Hương vị trà đen đậm đà hòa quyện cùng sữa béo thơm', 55000, true),
('a2222222-2222-2222-2222-222222222222', 'Trà trái cây', 'Trà Đào Cam Sả (Size L)', 'Vị chua ngọt thanh mát với đào miếng giòn và sả tươi', 60000, true),
('a2222222-2222-2222-2222-222222222222', 'Cà phê', 'Cà Phê Sữa Đá Sài Gòn', 'Cà phê pha phin truyền thống thơm nồng', 38000, true),

-- Phở 24
('a3333333-3333-3333-3333-333333333333', 'Phở bò', 'Phở Bò Tái Nạm Gầu', 'Thịt bò tươi mềm ngọt nước dùng xương bò đậm đà', 69000, true),
('a3333333-3333-3333-3333-333333333333', 'Món thêm', 'Quẩy Giòn Sài Gòn (3 chiếc)', 'Quẩy nóng vàng giòn tan chấm nước dùng', 10000, true),

-- Bún Chả 1982
('a4444444-4444-4444-4444-444444444444', 'Bún chả', 'Suất Bún Chả Đặc Biệt', 'Chả miếng, chả viên nướng que tre, bún tươi, rau sống và nước chấm', 65000, true),
('a4444444-4444-4444-4444-444444444444', 'Khai vị', 'Nem Cua Bể Hải Phòng (2 chiếc)', 'Nem cua bể vàng ươm ngập thịt cua và nấm hương', 35000, true),

-- WinMart+ (Đi chợ hộ)
('a5555555-5555-5555-5555-555555555555', 'Thực phẩm tươi sống', 'Thịt Heo MEATDeli Nạc Dăm (400g)', 'Thịt heo sạch công nghệ Oxy-Fresh chuẩn châu Âu', 78000, true),
('a5555555-5555-5555-5555-555555555555', 'Trứng & Sữa', 'Trứng Gà Ba Huân Hộp 10 Quả', 'Trứng gà tươi sạch tiệt trùng giàu dinh dưỡng', 34000, true),
('a5555555-5555-5555-5555-555555555555', 'Trái cây', 'Táo Envy New Zealand (1kg)', 'Táo giòn ngọt đậm đà nhập khẩu trực tiếp', 129000, true);

-- 3. Capability for Driver
INSERT INTO driver_capabilities (driver_id, can_ride, can_food, can_grocery, can_designated, transmission_type)
VALUES ('93623b04-ecc7-4654-8846-e05f72ab8069', true, true, true, true, 'BOTH')
ON CONFLICT (driver_id) DO NOTHING;
