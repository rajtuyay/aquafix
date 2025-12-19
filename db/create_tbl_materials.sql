-- Create table
CREATE TABLE tbl_materials (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    material_name VARCHAR(64) NOT NULL,
    size VARCHAR(32) NOT NULL,
    price INT NOT NULL
);

-- Insert values
INSERT INTO tbl_materials (material_name, size, price) VALUES
('Female Elbow', '3/4', 15),
('Female Elbow', '1/2', 12),
('Female Elbow', '1', 20),

('Union Coupling', '3/4', 18),
('Union Coupling', '1/2', 15),
('Union Coupling', '1', 25),

('Nipple', '2 3/4', 20),
('Nipple', '3 3/4', 25),
('Nipple', '6 3/4', 35),
('Nipple', '12 3/4', 50),

('Ball Valve', '3/4', 70),
('Ball Valve', '1/2', 60),
('Ball Valve', '1', 90),

('Water Meter', '1/2', 350),
('Water Meter', '3/4', 450),
('Water Meter', '1', 500),

('Elbow GI', '3/4', 30),
('Elbow GI', '1/2', 25),
('Elbow GI', '1', 40),

('Straight Elbow', 'N/A', 28),

('Elbow Reducer', 'N/A', 28),

('Bushing', '3/4 x 1/2', 25),
('Bushing', '1 x 3/4', 30),

('Brass Corpo', '1/2', 45),
('Brass Corpo', '3/4', 55),
('Brass Corpo', '1', 65),

('Saddle Clamp', '2 x 3/4', 55),
('Saddle Clamp', '2 x 1', 65),
('Saddle Clamp', '3 x 3/4', 60),
('Saddle Clamp', '3 x 1', 70),
('Saddle Clamp', '4 x 3/4', 75),
('Saddle Clamp', '4 x 1', 80),

('Sleeve Type Coupling', '2', 50),
('Sleeve Type Coupling', '3', 60),
('Sleeve Type Coupling', '4', 75),

('PE Pipe', '1/2', 20),
('PE Pipe', '3/4', 25),
('PE Pipe', '1', 35),

('Teflon', '1/2', 10);
