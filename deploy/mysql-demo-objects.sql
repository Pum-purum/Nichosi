-- MySQL 8 demo objects. Run as administrator in the existing local container.
USE nichosi_lab;
CREATE TABLE IF NOT EXISTS nichosi_object_demo (id BIGINT PRIMARY KEY, label VARCHAR(100) NOT NULL, amount DECIMAL(12,2) NOT NULL DEFAULT 0, updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP);
INSERT INTO nichosi_object_demo VALUES (1,'Demo item',42.50,CURRENT_TIMESTAMP) ON DUPLICATE KEY UPDATE id=id;
CREATE OR REPLACE VIEW nichosi_demo_summary AS SELECT id,label,amount FROM nichosi_object_demo WHERE amount >= 0;
DROP TRIGGER IF EXISTS nichosi_demo_before_update;
CREATE TRIGGER nichosi_demo_before_update BEFORE UPDATE ON nichosi_object_demo FOR EACH ROW SET NEW.updated_at=CURRENT_TIMESTAMP;
DROP FUNCTION IF EXISTS nichosi_demo_gross_amount;
CREATE DEFINER='nichosi_lab'@'%' FUNCTION nichosi_demo_gross_amount(net DECIMAL(12,2)) RETURNS DECIMAL(12,2) DETERMINISTIC NO SQL RETURN ROUND(net*1.20,2);
DROP PROCEDURE IF EXISTS nichosi_demo_summary;
CREATE DEFINER='nichosi_lab'@'%' PROCEDURE nichosi_demo_summary() READS SQL DATA SELECT id,label,amount FROM nichosi_object_demo ORDER BY id LIMIT 100;
CREATE EVENT IF NOT EXISTS nichosi_demo_daily_refresh ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY DISABLE COMMENT 'Disabled demonstration event' DO UPDATE nichosi_object_demo SET updated_at=CURRENT_TIMESTAMP WHERE id=1;
CREATE ROLE IF NOT EXISTS 'nichosi_demo_reader'@'localhost', 'nichosi_demo_unassigned'@'localhost';
GRANT SELECT ON nichosi_lab.* TO 'nichosi_demo_reader'@'localhost';
-- Discard stdout when executing: MySQL returns the generated password.
CREATE USER IF NOT EXISTS 'nichosi_demo_user'@'localhost' IDENTIFIED BY RANDOM PASSWORD ACCOUNT LOCK;
GRANT 'nichosi_demo_reader'@'localhost' TO 'nichosi_demo_user'@'localhost';
-- Expose only non-secret account metadata through a dedicated read-only view.
-- The application does not receive direct access to mysql.user.
CREATE OR REPLACE SQL SECURITY DEFINER VIEW nichosi_account_metadata AS
 SELECT User AS account_name, Host AS account_host, account_locked,
 CASE WHEN account_locked='Y' AND authentication_string='' THEN 'role' ELSE 'user' END AS account_type
 FROM mysql.user;
