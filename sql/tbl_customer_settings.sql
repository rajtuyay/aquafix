CREATE TABLE IF NOT EXISTS tbl_customer_settings (
    setting_id INT AUTO_INCREMENT PRIMARY KEY,
    setting_name VARCHAR(64) NOT NULL,
    setting_value VARCHAR(16) NOT NULL,
    customer_id VARCHAR(64) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES tbl_customers(customer_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    UNIQUE KEY unique_setting (customer_id, setting_name)
);
