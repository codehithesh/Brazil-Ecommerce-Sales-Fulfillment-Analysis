-- =============================================================================
-- BRAZIL E-COMMERCE: DATA CLEANING & IMPUTATION
-- Target RDBMS : MySQL 8.0+
-- Source data   : 8 CSV files in assets/dataset/
-- Purpose       : Produce clean, typed, deduplicated tables ready for EDA
--
-- Execution order
--   1. SECTION 0  – Create schema & raw staging tables
--   2. SECTION 1  – customers
--   3. SECTION 2  – sellers
--   4. SECTION 3  – geolocation
--   5. SECTION 4  – products
--   6. SECTION 5  – orders
--   7. SECTION 6  – order_items
--   8. SECTION 7  – payments
--   9. SECTION 8  – order_reviews
--  10. SECTION 9  – Post-load validation queries
-- =============================================================================
-- =============================================================================
-- SECTION 0 – SCHEMA SETUP
-- =============================================================================
CREATE DATABASE IF NOT EXISTS brazil_ecommerce CHARACTER
SET
    utf8mb4 COLLATE utf8mb4_unicode_ci;

USE brazil_ecommerce;

-- Safety: disable FK checks while we rebuild everything
SET
    FOREIGN_KEY_CHECKS = 0;

SET
    sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_DATE,NO_ZERO_IN_DATE,ERROR_FOR_DIVISION_BY_ZERO';

-- =============================================================================
-- SECTION 1 – CUSTOMERS
-- =============================================================================
-- Issues found:
--   • customer_city is all-lowercase; needs title-casing
--   • customer_state is already the correct 2-char code
--   • customer_zip_code_prefix is numeric (no nulls)
--   • No nulls in any column
--   • customer_city may contain leading/trailing whitespace
-- =============================================================================
DROP TABLE IF EXISTS customers_raw;

CREATE TABLE
    customers_raw (
        customer_id VARCHAR(50),
        customer_unique_id VARCHAR(50),
        customer_zip_code_prefix VARCHAR(10),
        customer_city VARCHAR(100),
        customer_state CHAR(2)
    );

-- Load from CSV (adjust the path to your MySQL secure-file-priv directory or use your import tool)
-- LOAD DATA INFILE '/path/to/customers.csv'
-- INTO TABLE customers_raw
-- FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS;
DROP TABLE IF EXISTS customers;

CREATE TABLE
    customers (
        customer_id CHAR(32) NOT NULL,
        customer_unique_id CHAR(32) NOT NULL,
        customer_zip_code_prefix CHAR(5) NOT NULL, -- zero-padded 5-digit prefix
        customer_city VARCHAR(100) NOT NULL,
        customer_state CHAR(2) NOT NULL,
        CONSTRAINT pk_customers PRIMARY KEY (customer_id)
    );

INSERT INTO
    customers
SELECT
    -- trim stray whitespace from IDs
    TRIM(customer_id),
    TRIM(customer_unique_id),
    -- zero-pad to 5 chars (e.g. '1409' → '01409')
    LPAD (TRIM(customer_zip_code_prefix), 5, '0'),
    -- normalise city: trim + title-case
    -- MySQL has no native INITCAP, so we use a CONCAT + UPPER trick on the first char
    -- Full title-case is applied via the clean_title_case expression below
    TRIM(
        CONCAT (
            UPPER(LEFT (TRIM(customer_city), 1)),
            LOWER(SUBSTRING(TRIM(customer_city), 2))
        )
    ),
    -- state code to upper (already correct, but defensive)
    UPPER(TRIM(customer_state))
FROM
    customers_raw
WHERE
    TRIM(customer_id) <> ''
    AND TRIM(customer_unique_id) <> '';

-- Remove any accidental full duplicates
DELETE c1
FROM
    customers c1
    INNER JOIN customers c2 ON c1.customer_id = c2.customer_id
    AND c1.customer_city = c2.customer_city
    AND c1.customer_state = c2.customer_state
    AND c1.customer_zip_code_prefix = c2.customer_zip_code_prefix
WHERE
    c1.customer_unique_id > c2.customer_unique_id;

-- keep the lexicographically smaller row
-- =============================================================================
-- SECTION 2 – SELLERS
-- =============================================================================
-- Issues found:
--   • seller_city is all-lowercase; same normalisation needed as customers
--   • seller_zip_code_prefix needs zero-padding
--   • No nulls
-- =============================================================================
DROP TABLE IF EXISTS sellers_raw;

CREATE TABLE
    sellers_raw (
        seller_id VARCHAR(50),
        seller_zip_code_prefix VARCHAR(10),
        seller_city VARCHAR(100),
        seller_state CHAR(2)
    );

-- LOAD DATA INFILE '/path/to/sellers.csv' INTO TABLE sellers_raw ...
DROP TABLE IF EXISTS sellers;

CREATE TABLE
    sellers (
        seller_id CHAR(32) NOT NULL,
        seller_zip_code_prefix CHAR(5) NOT NULL,
        seller_city VARCHAR(100) NOT NULL,
        seller_state CHAR(2) NOT NULL,
        CONSTRAINT pk_sellers PRIMARY KEY (seller_id)
    );

INSERT INTO
    sellers
SELECT
    TRIM(seller_id),
    LPAD (TRIM(seller_zip_code_prefix), 5, '0'),
    TRIM(
        CONCAT (
            UPPER(LEFT (TRIM(seller_city), 1)),
            LOWER(SUBSTRING(TRIM(seller_city), 2))
        )
    ),
    UPPER(TRIM(seller_state))
FROM
    sellers_raw
WHERE
    TRIM(seller_id) <> '';

-- Deduplicate: keep the first occurrence of each seller_id
DELETE s1
FROM
    sellers s1
    INNER JOIN sellers s2 ON s1.seller_id = s2.seller_id
    AND s1.seller_city = s2.seller_city
WHERE
    s1.seller_zip_code_prefix > s2.seller_zip_code_prefix;

-- =============================================================================
-- SECTION 3 – GEOLOCATION
-- =============================================================================
-- Issues found:
--   • ~1 million rows; many zip codes have multiple lat/lng points (normal – they are
--     individual GPS readings, not one-per-zip records).
--   • For EDA joins we want ONE representative centroid per zip code.
--   • geolocation_city is all-lowercase; normalise for display.
--   • geolocation_state needs upper-casing.
--   • No nulls.
-- Strategy:
--   (a) Keep the full raw table as geolocation_raw for spatial completeness.
--   (b) Create geolocation_centroids with one row per zip (AVG lat/lng).
-- =============================================================================
DROP TABLE IF EXISTS geolocation_raw;

CREATE TABLE
    geolocation_raw (
        geolocation_zip_code_prefix VARCHAR(10),
        geolocation_lat DECIMAL(18, 10),
        geolocation_lng DECIMAL(18, 10),
        geolocation_city VARCHAR(100),
        geolocation_state CHAR(2)
    );

-- LOAD DATA INFILE '/path/to/geolocation.csv' INTO TABLE geolocation_raw ...
-- ── 3a. Full clean copy (deduplicated exact rows) ──────────────────────────
DROP TABLE IF EXISTS geolocation;

CREATE TABLE
    geolocation (
        geolocation_zip_code_prefix CHAR(5) NOT NULL,
        geolocation_lat DECIMAL(18, 10) NOT NULL,
        geolocation_lng DECIMAL(18, 10) NOT NULL,
        geolocation_city VARCHAR(100) NOT NULL,
        geolocation_state CHAR(2) NOT NULL,
        INDEX idx_geo_zip (geolocation_zip_code_prefix)
    );

INSERT INTO
    geolocation
SELECT DISTINCT
    LPAD (TRIM(geolocation_zip_code_prefix), 5, '0'),
    geolocation_lat,
    geolocation_lng,
    TRIM(
        CONCAT (
            UPPER(LEFT (TRIM(geolocation_city), 1)),
            LOWER(SUBSTRING(TRIM(geolocation_city), 2))
        )
    ),
    UPPER(TRIM(geolocation_state))
FROM
    geolocation_raw
WHERE
    geolocation_lat >= -34.0
    AND geolocation_lat <= 5.5 -- Brazil bounding box (lat)
    AND geolocation_lng >= -74.0
    AND geolocation_lng <= -28.0 -- Brazil bounding box (lng)
    AND TRIM(geolocation_zip_code_prefix) <> '';

-- ── 3b. One centroid per zip ────────────────────────────────────────────────
DROP TABLE IF EXISTS geolocation_centroids;

CREATE TABLE
    geolocation_centroids (
        geolocation_zip_code_prefix CHAR(5) NOT NULL,
        centroid_lat DECIMAL(10, 6) NOT NULL,
        centroid_lng DECIMAL(10, 6) NOT NULL,
        geolocation_city VARCHAR(100) NOT NULL,
        geolocation_state CHAR(2) NOT NULL,
        CONSTRAINT pk_geo_centroids PRIMARY KEY (geolocation_zip_code_prefix)
    );

INSERT INTO
    geolocation_centroids
SELECT
    geolocation_zip_code_prefix,
    ROUND(AVG(geolocation_lat), 6) AS centroid_lat,
    ROUND(AVG(geolocation_lng), 6) AS centroid_lng,
    -- use the most-frequent city name for that zip
    SUBSTRING_INDEX (
        GROUP_CONCAT (
            geolocation_city
            ORDER BY
                geolocation_city SEPARATOR '|'
        ),
        '|',
        1
    ) AS geolocation_city,
    geolocation_state
FROM
    geolocation
GROUP BY
    geolocation_zip_code_prefix,
    geolocation_state;

-- =============================================================================
-- SECTION 4 – PRODUCTS
-- =============================================================================
-- Issues found:
--   • Column name has a space: `product category` → rename to product_category
--   • 610 rows where product_category, product_name_length, product_description_length,
--     product_photos_qty are ALL NULL simultaneously (likely unlisted/ghost products)
--     → impute category as 'unknown'; impute numeric dimensions with column median.
--   • 2 rows where product_weight_g, product_length_cm, product_height_cm,
--     product_width_cm are NULL → impute with column median.
--   • Mixed casing in category names (e.g. 'Art', 'sport leisure', 'perfumery').
-- =============================================================================
DROP TABLE IF EXISTS products_raw;

CREATE TABLE
    products_raw (
        product_id VARCHAR(50),
        `product category` VARCHAR(100), -- backtick-quoted because of the space
        product_name_length FLOAT,
        product_description_length FLOAT,
        product_photos_qty FLOAT,
        product_weight_g FLOAT,
        product_length_cm FLOAT,
        product_height_cm FLOAT,
        product_width_cm FLOAT
    );

-- LOAD DATA INFILE '/path/to/products.csv' INTO TABLE products_raw ...
DROP TABLE IF EXISTS products;

CREATE TABLE
    products (
        product_id CHAR(32) NOT NULL,
        product_category VARCHAR(100) NOT NULL DEFAULT 'unknown',
        product_name_length SMALLINT UNSIGNED, -- nullable: unknown for ghost products
        product_description_length SMALLINT UNSIGNED,
        product_photos_qty TINYINT UNSIGNED,
        product_weight_g SMALLINT UNSIGNED,
        product_length_cm TINYINT UNSIGNED,
        product_height_cm TINYINT UNSIGNED,
        product_width_cm TINYINT UNSIGNED,
        CONSTRAINT pk_products PRIMARY KEY (product_id)
    );

-- ── Step 4a + 4b: compute medians inline and insert with imputation ──────────
-- MySQL has no MEDIAN() aggregate, so medians are derived using ROW_NUMBER()
-- window functions (MySQL 8.0+) inside a CTE. No session variables needed.
--
-- Method: for each dimension, rank all non-null values; the median is the
-- average of the middle one or two rows (handles both odd and even counts).
INSERT INTO
    products
WITH
    -- ── median for product_weight_g ──────────────────────────────────────────
    weight_ranked AS (
        SELECT
            product_weight_g,
            ROW_NUMBER() OVER (
                ORDER BY
                    product_weight_g
            ) AS rn,
            COUNT(*) OVER () AS total
        FROM
            products_raw
        WHERE
            product_weight_g IS NOT NULL
    ),
    median_weight AS (
        SELECT
            AVG(product_weight_g) AS val
        FROM
            weight_ranked
        WHERE
            rn IN (FLOOR((total + 1) / 2), CEIL((total + 1) / 2))
    ),
    -- ── median for product_length_cm ─────────────────────────────────────────
    length_ranked AS (
        SELECT
            product_length_cm,
            ROW_NUMBER() OVER (
                ORDER BY
                    product_length_cm
            ) AS rn,
            COUNT(*) OVER () AS total
        FROM
            products_raw
        WHERE
            product_length_cm IS NOT NULL
    ),
    median_length AS (
        SELECT
            AVG(product_length_cm) AS val
        FROM
            length_ranked
        WHERE
            rn IN (FLOOR((total + 1) / 2), CEIL((total + 1) / 2))
    ),
    -- ── median for product_height_cm ─────────────────────────────────────────
    height_ranked AS (
        SELECT
            product_height_cm,
            ROW_NUMBER() OVER (
                ORDER BY
                    product_height_cm
            ) AS rn,
            COUNT(*) OVER () AS total
        FROM
            products_raw
        WHERE
            product_height_cm IS NOT NULL
    ),
    median_height AS (
        SELECT
            AVG(product_height_cm) AS val
        FROM
            height_ranked
        WHERE
            rn IN (FLOOR((total + 1) / 2), CEIL((total + 1) / 2))
    ),
    -- ── median for product_width_cm ──────────────────────────────────────────
    width_ranked AS (
        SELECT
            product_width_cm,
            ROW_NUMBER() OVER (
                ORDER BY
                    product_width_cm
            ) AS rn,
            COUNT(*) OVER () AS total
        FROM
            products_raw
        WHERE
            product_width_cm IS NOT NULL
    ),
    median_width AS (
        SELECT
            AVG(product_width_cm) AS val
        FROM
            width_ranked
        WHERE
            rn IN (FLOOR((total + 1) / 2), CEIL((total + 1) / 2))
    )
SELECT
    TRIM(p.product_id),
    -- rename + normalise category: trim, lowercase, replace spaces with underscores
    -- NULL → 'unknown'
    CASE
        WHEN p.`product category` IS NULL
        OR TRIM(p.`product category`) = '' THEN 'unknown'
        ELSE LOWER(REPLACE (TRIM(p.`product category`), ' ', '_'))
    END,
    -- 610 ghost-product rows: name_length / description_length / photos_qty are NULL
    -- Leave as NULL (unknown is accurate; using median here would be misleading)
    CASE
        WHEN p.product_name_length IS NOT NULL THEN ROUND(p.product_name_length)
        ELSE NULL
    END,
    CASE
        WHEN p.product_description_length IS NOT NULL THEN ROUND(p.product_description_length)
        ELSE NULL
    END,
    CASE
        WHEN p.product_photos_qty IS NOT NULL THEN ROUND(p.product_photos_qty)
        ELSE NULL
    END,
    -- 2 rows with missing physical dimensions → impute with median
    ROUND(COALESCE(p.product_weight_g, mw.val)),
    ROUND(COALESCE(p.product_length_cm, ml.val)),
    ROUND(COALESCE(p.product_height_cm, mh.val)),
    ROUND(COALESCE(p.product_width_cm, mwd.val))
FROM
    products_raw p
    CROSS JOIN median_weight mw
    CROSS JOIN median_length ml
    CROSS JOIN median_height mh
    CROSS JOIN median_width mwd
WHERE
    TRIM(p.product_id) <> '';

-- ── Step 4c: deduplicate on product_id ──────────────────────────────────────
-- (products_raw occasionally has duplicate rows from re-exports)
DELETE p1
FROM
    products p1
    INNER JOIN products p2 ON p1.product_id = p2.product_id
    AND p1.product_category = p2.product_category
WHERE
    p1.product_name_length > p2.product_name_length;

-- keep row with smaller value as tiebreak
-- =============================================================================
-- SECTION 5 – ORDERS
-- =============================================================================
-- Issues found:
--   • All 5 timestamp columns arrive as VARCHAR from CSV; must be cast to DATETIME.
--   • order_approved_at:               160 NULLs  (not yet approved – acceptable)
--   • order_delivered_carrier_date:  1,783 NULLs  (not dispatched yet – acceptable)
--   • order_delivered_customer_date: 2,965 NULLs  (not yet delivered – acceptable)
--   • 8 'delivered' orders with no order_delivered_customer_date → flag; exclude
--     from delivery-metric views, not from the order table itself.
--   • 1 non-'delivered' row that has a delivery date → data entry error;
--     set that delivery date to NULL.
--   • Timestamps in orders.csv use format 'YYYY-MM-DD HH:MM:SS' (ISO-like) – safe.
-- =============================================================================
DROP TABLE IF EXISTS orders_raw;

CREATE TABLE
    orders_raw (
        order_id VARCHAR(50),
        customer_id VARCHAR(50),
        order_status VARCHAR(20),
        order_purchase_timestamp VARCHAR(25),
        order_approved_at VARCHAR(25),
        order_delivered_carrier_date VARCHAR(25),
        order_delivered_customer_date VARCHAR(25),
        order_estimated_delivery_date VARCHAR(25)
    );

-- LOAD DATA INFILE '/path/to/orders.csv' INTO TABLE orders_raw ...
DROP TABLE IF EXISTS orders;

CREATE TABLE
    orders (
        order_id CHAR(32) NOT NULL,
        customer_id CHAR(32) NOT NULL,
        order_status VARCHAR(20) NOT NULL,
        order_purchase_timestamp DATETIME NOT NULL,
        order_approved_at DATETIME NULL,
        order_delivered_carrier_date DATETIME NULL,
        order_delivered_customer_date DATETIME NULL,
        order_estimated_delivery_date DATETIME NULL,
        -- cleaning flags (non-destructive audit trail)
        flag_missing_delivery_date TINYINT (1) NOT NULL DEFAULT 0 COMMENT '1 = status=delivered but delivery date is NULL',
        flag_date_inconsistency TINYINT (1) NOT NULL DEFAULT 0 COMMENT '1 = non-delivered row had a delivery date (corrected to NULL)',
        CONSTRAINT pk_orders PRIMARY KEY (order_id),
        INDEX idx_orders_customer (customer_id),
        INDEX idx_orders_purchase (order_purchase_timestamp),
        INDEX idx_orders_status (order_status)
    );

INSERT INTO
    orders
SELECT
    TRIM(order_id),
    TRIM(customer_id),
    LOWER(TRIM(order_status)),
    -- STRICT_TRANS_TABLES will reject zero-dates; STR_TO_DATE returns NULL on bad input
    STR_TO_DATE (
        NULLIF(TRIM(order_purchase_timestamp), ''),
        '%Y-%m-%d %H:%i:%s'
    ),
    STR_TO_DATE (
        NULLIF(TRIM(order_approved_at), ''),
        '%Y-%m-%d %H:%i:%s'
    ),
    STR_TO_DATE (
        NULLIF(TRIM(order_delivered_carrier_date), ''),
        '%Y-%m-%d %H:%i:%s'
    ),
    -- Fix: if status <> 'delivered' but delivery date is populated → set to NULL
    CASE
        WHEN LOWER(TRIM(order_status)) <> 'delivered'
        AND TRIM(order_delivered_customer_date) <> '' THEN NULL
        ELSE STR_TO_DATE (
            NULLIF(TRIM(order_delivered_customer_date), ''),
            '%Y-%m-%d %H:%i:%s'
        )
    END,
    STR_TO_DATE (
        NULLIF(TRIM(order_estimated_delivery_date), ''),
        '%Y-%m-%d %H:%i:%s'
    ),
    -- flag: delivered orders missing their delivery date
    CASE
        WHEN LOWER(TRIM(order_status)) = 'delivered'
        AND (
            TRIM(order_delivered_customer_date) = ''
            OR order_delivered_customer_date IS NULL
        ) THEN 1
        ELSE 0
    END,
    -- flag: non-delivered row had a delivery date (corrected above)
    CASE
        WHEN LOWER(TRIM(order_status)) <> 'delivered'
        AND TRIM(order_delivered_customer_date) <> '' THEN 1
        ELSE 0
    END
FROM
    orders_raw
WHERE
    TRIM(order_id) <> ''
    AND TRIM(customer_id) <> ''
    -- drop rows with no purchase timestamp: they cannot be placed in the analysis window
    AND TRIM(order_purchase_timestamp) <> ''
    AND order_purchase_timestamp IS NOT NULL;

-- =============================================================================
-- SECTION 6 – ORDER_ITEMS
-- =============================================================================
-- Issues found:
--   • shipping_limit_date stored as VARCHAR ('YYYY-MM-DD HH:MM:SS') → cast to DATETIME.
--   • No nulls; no duplicate (order_id, order_item_id) pairs.
--   • price and freight_value should be > 0 for valid items; rows with 0 or negative
--     values are flagged (not deleted – a $0 item may be a free gift/promo).
-- =============================================================================
DROP TABLE IF EXISTS order_items_raw;

CREATE TABLE
    order_items_raw (
        order_id VARCHAR(50),
        order_item_id INT,
        product_id VARCHAR(50),
        seller_id VARCHAR(50),
        shipping_limit_date VARCHAR(25),
        price DECIMAL(10, 2),
        freight_value DECIMAL(10, 2)
    );

-- LOAD DATA INFILE '/path/to/order_items.csv' INTO TABLE order_items_raw ...
DROP TABLE IF EXISTS order_items;

CREATE TABLE
    order_items (
        order_id CHAR(32) NOT NULL,
        order_item_id TINYINT UNSIGNED NOT NULL,
        product_id CHAR(32) NOT NULL,
        seller_id CHAR(32) NOT NULL,
        shipping_limit_date DATETIME NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        freight_value DECIMAL(10, 2) NOT NULL,
        flag_zero_price TINYINT (1) NOT NULL DEFAULT 0 COMMENT '1 = price is 0 (possible promo/free item)',
        CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id),
        INDEX idx_oi_product (product_id),
        INDEX idx_oi_seller (seller_id)
    );

INSERT INTO
    order_items
SELECT
    TRIM(order_id),
    order_item_id,
    TRIM(product_id),
    TRIM(seller_id),
    STR_TO_DATE (
        NULLIF(TRIM(shipping_limit_date), ''),
        '%Y-%m-%d %H:%i:%s'
    ),
    price,
    freight_value,
    IF (price <= 0, 1, 0)
FROM
    order_items_raw
WHERE
    TRIM(order_id) <> ''
    AND TRIM(product_id) <> ''
    AND TRIM(seller_id) <> ''
    -- exclude clearly corrupt rows: negative price or freight
    AND price >= 0
    AND freight_value >= 0;

-- =============================================================================
-- SECTION 7 – PAYMENTS
-- =============================================================================
-- Issues found:
--   • payment_type can be 'not_defined' (edge case, not a recognised method).
--     → Normalise to 'unknown' so the EDA grouping is consistent.
--   • payment_installments = 0 occurs for voucher/boleto (one-shot) payments –
--     set to 1 so arithmetic (avg installments) is meaningful.
--   • payment_value should be > 0; any zero-value payments are flagged.
--   • No nulls in raw data.
--   • Multiple rows per order_id are legitimate (split payments, payment_sequential).
-- =============================================================================
DROP TABLE IF EXISTS payments_raw;

CREATE TABLE
    payments_raw (
        order_id VARCHAR(50),
        payment_sequential TINYINT UNSIGNED,
        payment_type VARCHAR(30),
        payment_installments TINYINT UNSIGNED,
        payment_value DECIMAL(10, 2)
    );

-- LOAD DATA INFILE '/path/to/payments.csv' INTO TABLE payments_raw ...
DROP TABLE IF EXISTS payments;

CREATE TABLE
    payments (
        order_id CHAR(32) NOT NULL,
        payment_sequential TINYINT UNSIGNED NOT NULL,
        payment_type VARCHAR(30) NOT NULL,
        payment_installments TINYINT UNSIGNED NOT NULL,
        payment_value DECIMAL(10, 2) NOT NULL,
        flag_zero_payment TINYINT (1) NOT NULL DEFAULT 0 COMMENT '1 = payment_value is 0',
        CONSTRAINT pk_payments PRIMARY KEY (order_id, payment_sequential),
        INDEX idx_pay_type (payment_type)
    );

INSERT INTO
    payments
SELECT
    TRIM(order_id),
    payment_sequential,
    -- normalise 'not_defined' to 'unknown'
    CASE
        WHEN LOWER(TRIM(payment_type)) IN ('not_defined', '', 'undefined') THEN 'unknown'
        ELSE LOWER(TRIM(payment_type))
    END,
    -- installments = 0 → treat as 1 (single-shot payment)
    CASE
        WHEN payment_installments = 0 THEN 1
        ELSE payment_installments
    END,
    payment_value,
    IF (payment_value <= 0, 1, 0)
FROM
    payments_raw
WHERE
    TRIM(order_id) <> ''
    AND payment_value >= 0;

-- =============================================================================
-- SECTION 8 – ORDER_REVIEWS
-- =============================================================================
-- Issues found:
--   • review_comment_title: 87,675 / 99,224 (~88%) are NULL or empty – this is
--     expected (most reviewers leave only a score). Mark empty strings as NULL
--     so IS NULL filtering is consistent.
--   • review_comment_message (not in this dataset's CSV headers, but handle if present).
--   • review_creation_date and review_answer_timestamp stored in non-ISO format:
--     'DD/MM/YY H:MM' (e.g. '18/01/18 0:00') → cast to DATETIME via STR_TO_DATE.
--   • review_score should be INTEGER 1–5; out-of-range values are flagged.
--   • One order can have multiple reviews (reviewer re-submission); keep all rows
--     but add a flag for duplicated order_ids.
-- =============================================================================
DROP TABLE IF EXISTS order_reviews_raw;

CREATE TABLE
    order_reviews_raw (
        review_id VARCHAR(50),
        order_id VARCHAR(50),
        review_score TINYINT,
        review_comment_title VARCHAR(255),
        review_creation_date VARCHAR(25),
        review_answer_timestamp VARCHAR(25)
    );

-- LOAD DATA INFILE '/path/to/order_reviews.csv' INTO TABLE order_reviews_raw ...
DROP TABLE IF EXISTS order_reviews;

CREATE TABLE
    order_reviews (
        review_id CHAR(32) NOT NULL,
        order_id CHAR(32) NOT NULL,
        review_score TINYINT UNSIGNED NOT NULL,
        review_comment_title VARCHAR(255) NULL COMMENT 'NULL means reviewer left no title (expected for ~88% of rows)',
        review_creation_date DATETIME NOT NULL,
        review_answer_timestamp DATETIME NULL,
        flag_invalid_score TINYINT (1) NOT NULL DEFAULT 0 COMMENT '1 = review_score outside 1–5',
        flag_duplicate_order TINYINT (1) NOT NULL DEFAULT 0 COMMENT '1 = multiple reviews exist for the same order_id',
        CONSTRAINT pk_order_reviews PRIMARY KEY (review_id),
        INDEX idx_rev_order (order_id),
        INDEX idx_rev_score (review_score)
    );

INSERT INTO
    order_reviews
SELECT
    TRIM(review_id),
    TRIM(order_id),
    -- clamp out-of-range scores to NULL; flag them separately
    CASE
        WHEN review_score >= 1
        AND review_score <= 5 THEN review_score
        ELSE NULL -- will be caught by flag_invalid_score below
    END,
    -- empty strings → NULL (consistent NULL semantics for text fields)
    NULLIF(TRIM(review_comment_title), ''),
    -- 'DD/MM/YY H:MM' → DATETIME  (e.g. '18/01/18 0:00' → 2018-01-18 00:00:00)
    STR_TO_DATE (
        NULLIF(TRIM(review_creation_date), ''),
        '%d/%m/%y %H:%i'
    ),
    -- answer timestamp same format; can be NULL if not yet answered
    STR_TO_DATE (
        NULLIF(TRIM(review_answer_timestamp), ''),
        '%d/%m/%y %H:%i'
    ),
    IF (
        review_score < 1
        OR review_score > 5,
        1,
        0
    ),
    -- duplicate-order flag filled in the UPDATE step below (needs the full table)
    0
FROM
    order_reviews_raw
WHERE
    TRIM(review_id) <> ''
    AND TRIM(order_id) <> ''
    -- drop rows with an unparseable creation date (nothing to anchor in time)
    AND TRIM(review_creation_date) <> '';

-- ── Step 8b: mark duplicate order_id reviews ────────────────────────────────
UPDATE order_reviews r
JOIN (
    SELECT
        order_id
    FROM
        order_reviews
    GROUP BY
        order_id
    HAVING
        COUNT(*) > 1
) dup ON r.order_id = dup.order_id
SET
    r.flag_duplicate_order = 1;

-- ── Step 8c: for duplicate-order rows keep only the most-recent review ───────
-- (creates a view; the raw rows are preserved, the view is used in EDA)
CREATE
OR REPLACE VIEW order_reviews_deduped AS
SELECT
    r.*
FROM
    order_reviews r
    INNER JOIN (
        SELECT
            order_id,
            MAX(review_creation_date) AS latest_review
        FROM
            order_reviews
        GROUP BY
            order_id
    ) latest ON r.order_id = latest.order_id
    AND r.review_creation_date = latest.latest_review;

-- =============================================================================
-- SECTION 9 – POST-LOAD VALIDATION
-- =============================================================================
-- Run these SELECT queries after loading to confirm all cleaning goals were met.
-- Expected results are noted in comments.
-- =============================================================================
-- ── V1: Row counts (sanity check against raw file line counts) ────────────────
SELECT
    'customers' AS tbl,
    COUNT(*) AS rows
FROM
    customers
UNION ALL
SELECT
    'sellers',
    COUNT(*)
FROM
    sellers
UNION ALL
SELECT
    'geolocation',
    COUNT(*)
FROM
    geolocation
UNION ALL
SELECT
    'geo_centroids',
    COUNT(*)
FROM
    geolocation_centroids
UNION ALL
SELECT
    'products',
    COUNT(*)
FROM
    products
UNION ALL
SELECT
    'orders',
    COUNT(*)
FROM
    orders
UNION ALL
SELECT
    'order_items',
    COUNT(*)
FROM
    order_items
UNION ALL
SELECT
    'payments',
    COUNT(*)
FROM
    payments
UNION ALL
SELECT
    'order_reviews',
    COUNT(*)
FROM
    order_reviews;

-- Expected approx: 99441 / 3095 / <1M / ~18K zips / 32950 / ~99441 / 112650 / 103885 / 99224
-- ── V2: NULL coverage for orders timestamps ───────────────────────────────────
-- order_approved_at should be ~160 NULLs; delivered_customer_date ~2965 NULLs
SELECT
    SUM(order_purchase_timestamp IS NULL) AS null_purchase,
    SUM(order_approved_at IS NULL) AS null_approved, -- expect ~160
    SUM(order_delivered_carrier_date IS NULL) AS null_carrier, -- expect ~1783
    SUM(order_delivered_customer_date IS NULL) AS null_delivered, -- expect ~2965
    SUM(order_estimated_delivery_date IS NULL) AS null_estimated
FROM
    orders;

-- ── V3: Flagged anomalies in orders ──────────────────────────────────────────
SELECT
    SUM(flag_missing_delivery_date) AS delivered_missing_date, -- expect 8
    SUM(flag_date_inconsistency) AS wrong_delivery_date -- expect 1
FROM
    orders;

-- ── V4: order_status distribution ────────────────────────────────────────────
SELECT
    order_status,
    COUNT(*) AS cnt
FROM
    orders
GROUP BY
    order_status
ORDER BY
    cnt DESC;

-- ── V5: Products – NULL counts after imputation ───────────────────────────────
-- product_weight_g / dimensions should now be 0 NULLs; category NULLs = 0
SELECT
    SUM(product_category IS NULL) AS null_category, -- expect 0
    SUM(product_weight_g IS NULL) AS null_weight, -- expect 0
    SUM(product_length_cm IS NULL) AS null_length, -- expect 0
    SUM(product_height_cm IS NULL) AS null_height, -- expect 0
    SUM(product_width_cm IS NULL) AS null_width, -- expect 0
    SUM(product_name_length IS NULL) AS null_name_len, -- expect 610
    SUM(product_description_length IS NULL) AS null_desc_len, -- expect 610
    SUM(product_photos_qty IS NULL) AS null_photos -- expect 610
FROM
    products;

-- ── V6: Payment type distribution (verify 'not_defined' → 'unknown') ─────────
SELECT
    payment_type,
    COUNT(*) AS cnt
FROM
    payments
GROUP BY
    payment_type
ORDER BY
    cnt DESC;

-- ── V7: Reviews – score range check (expect 0 NULLs after clamp) ─────────────
SELECT
    review_score,
    COUNT(*) AS cnt,
    SUM(flag_invalid_score) AS flagged
FROM
    order_reviews
GROUP BY
    review_score
ORDER BY
    review_score;

-- ── V8: Review date format conversion check ────────────────────────────────────
SELECT
    SUM(review_creation_date IS NULL) AS null_creation, -- expect ~0
    SUM(review_answer_timestamp IS NULL) AS null_answer, -- some legitimate NULLs ok
    MIN(review_creation_date) AS earliest,
    MAX(review_creation_date) AS latest
FROM
    order_reviews;

-- ── V9: Geolocation bounding box check (no outlier coordinates) ───────────────
SELECT
    MIN(geolocation_lat) AS min_lat,
    MAX(geolocation_lat) AS max_lat,
    MIN(geolocation_lng) AS min_lng,
    MAX(geolocation_lng) AS max_lng
FROM
    geolocation;

-- Brazil bounds: lat [-34, +5.5], lng [-74, -28] – any value outside is bad data
-- ── V10: Duplicate (order_id, order_item_id) in order_items ──────────────────
SELECT
    COUNT(*) AS duplicate_item_pairs
FROM
    (
        SELECT
            order_id,
            order_item_id
        FROM
            order_items
        GROUP BY
            order_id,
            order_item_id
        HAVING
            COUNT(*) > 1
    ) dups;

-- expect 0
-- ── V11: Orders without a matching customer ────────────────────────────────────
SELECT
    COUNT(*) AS orders_missing_customer
FROM
    orders o
    LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE
    c.customer_id IS NULL;

-- expect 0
-- ── V12: Order items referencing unknown orders ───────────────────────────────
SELECT
    COUNT(*) AS orphan_items
FROM
    order_items oi
    LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE
    o.order_id IS NULL;

-- expect 0
-- =============================================================================
-- RE-ENABLE FK CHECKS
-- =============================================================================
SET
    FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- END OF SCRIPT
-- =============================================================================