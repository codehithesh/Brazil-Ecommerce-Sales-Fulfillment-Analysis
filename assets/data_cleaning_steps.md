# Data Cleaning Steps

**customers & sellers**
- IDs trimmed of whitespace
- `customer_zip_code_prefix` / `seller_zip_code_prefix` zero-padded to 5 chars (`1409` → `01409`)
- City names title-cased (MySQL has no `INITCAP`, done via `UPPER(LEFT(...)) + LOWER(SUBSTRING(...))`)
- State codes uppercased defensively

**geolocation**
- Out-of-Brazil coordinates filtered (bounding box: lat `[-34, 5.5]`, lng `[-74, -28]`)
- Exact duplicate rows removed with `DISTINCT`
- A separate `geolocation_centroids` table created (one row per zip using `AVG(lat/lng)`) for clean joins in EDA

**products**
- Column renamed: `` `product category` `` → `product_category`; normalised to `lower_snake_case`
- 610 ghost-product rows: category imputed as `'unknown'`; name/description/photos left `NULL` (imputing those would invent data)
- 2 rows with missing physical dimensions: imputed with **column median** (computed via `ROW_NUMBER()` window function CTEs — MySQL 8.0+, no session variables)

**orders**
- All 5 timestamp columns cast from `VARCHAR` to `DATETIME` via `STR_TO_DATE`
- Unparseable values → `NULL` (safe for the 160 `order_approved_at` NULLs)
- 1 non-delivered row with a delivery date: **corrected to `NULL`**, flagged via `flag_date_inconsistency`
- 8 delivered rows with no delivery date: **preserved but flagged** via `flag_missing_delivery_date` (so EDA can filter them cleanly)

**order_items**
- `shipping_limit_date` cast from `VARCHAR` to `DATETIME`
- Rows with negative price/freight dropped; `price = 0` flagged (could be promos)

**payments**
- `payment_type = 'not_defined'` normalised to `'unknown'`
- `payment_installments = 0` corrected to `1` (single-shot payment)

**order_reviews**
- `review_creation_date` / `review_answer_timestamp` converted from `DD/MM/YY H:MM` format to `DATETIME`
- 87,675 empty `review_comment_title` values: empty strings → `NULL` (consistent `IS NULL` semantics)
- Scores outside 1–5 clamped to `NULL` and flagged
- Duplicate reviews per `order_id` flagged; a `order_reviews_deduped` view keeps only the most-recent review per order for EDA

**Validation (Section 9)** — 12 queries cover row counts, NULL coverage, flag counts, score ranges, date bounds, orphan FK rows, and bounding-box checks.