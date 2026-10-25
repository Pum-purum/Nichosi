-- Bitrix-style schema: relations exist by naming convention only, no FOREIGN KEYs.
CREATE TABLE b_user (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  LOGIN VARCHAR(50) NOT NULL,
  NAME VARCHAR(100)
) ENGINE=InnoDB;

CREATE TABLE b_iblock (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  NAME VARCHAR(255) NOT NULL,
  CODE VARCHAR(50)
) ENGINE=InnoDB;

CREATE TABLE b_iblock_element (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  NAME VARCHAR(255) NOT NULL,
  IBLOCK_ID INT NOT NULL,
  ACTIVE CHAR(1) NOT NULL DEFAULT 'Y',
  SORT INT NULL,
  DATE_CREATE DATETIME NOT NULL,
  CREATED_BY INT NULL,
  KEY ix_iblock (IBLOCK_ID)
) ENGINE=InnoDB;

CREATE TABLE b_iblock_element_property (
  ID INT AUTO_INCREMENT PRIMARY KEY,
  IBLOCK_ELEMENT_ID INT NOT NULL,
  VALUE VARCHAR(255)
) ENGINE=InnoDB;

INSERT INTO b_user (LOGIN, NAME) VALUES ('admin', 'Administrator'), ('editor', 'Editor');
INSERT INTO b_iblock (NAME, CODE) VALUES ('Catalog', 'catalog'), ('News', 'news');
INSERT INTO b_iblock_element (NAME, IBLOCK_ID, ACTIVE, SORT, DATE_CREATE, CREATED_BY) VALUES
  ('Catalog A', 1, 'Y', 100, NOW(), 1),
  ('Catalog B', 1, 'Y', 200, NOW(), 2),
  ('Service',   1, 'N', NULL, NOW(), 1),
  ('Delivery',  1, 'Y', 300, NOW(), 99),  -- orphan: user 99 does not exist
  ('Press',     2, 'Y', 100, NOW(), 2);
INSERT INTO b_iblock_element_property (IBLOCK_ELEMENT_ID, VALUE) VALUES
  (1, 'red'), (1, 'large'), (2, 'blue'), (5, 'headline');
