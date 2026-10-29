create database if not exists brazil_ecommerce;

use brazil_ecommerce;

-- =============================================================================
-- Part 1: PROFILING
-- =============================================================================
-- 1. Row counts and key uniqueness
select
	"customers" as `tbl`,
	count(*) as n_rows,
	count(distinct customer_id) as `n_distinct_ids`
from
	customers
union all
select
	"sellers",
	count(*),
	count(distinct seller_id)
from
	sellers
union all
select
	"products",
	count(*),
	count(distinct product_id)
from
	products
union all
select
	"orders",
	count(*),
	count(distinct order_id)
from
	orders
union all
select
	"reviews (by review_id)",
	count(*),
	count(distinct review_id)
from
	order_reviews
union all
select
	"reviews (by order_id)",
	count(*),
	count(distinct order_id)
from
	order_reviews
union all
select
	"payments",
	count(*),
	count(distinct order_id)
from
	payments
union all
select
	"order_items (by order_id)",
	count(*),
	count(distinct order_id)
from
	order_items
union all
select
	"order_items (by product_id)",
	count(*),
	count(distinct product_id)
from
	order_items;
	
	
-- =============================================================================
-- 2. Blank/NULL counts in orders
select
	sum(
		nullif(trim(order_purchase_timestamp), "") is null
	) as `missing_purchase`,
	sum(
		nullif(trim(order_approved_at), "") is null
	) as `missing_approved`,
	sum(
		nullif(trim(order_delivered_carrier_date), "") is null
	) as `missing_carrier`,
	sum(
		nullif(trim(order_delivered_customer_date), "") is null
	) as `missing_delivered`,
	sum(
		nullif(trim(order_estimated_delivery_date), "") is null
	) as `missing_estimated`
from
	orders;
	

-- =============================================================================
-- 3. Categorical columns: look for odd or inconsistent values
	
select
	order_status,
	count(*) as `n`
from
	orders
group by
	order_status
order by
	n desc;
	
select
	payment_type,
	count(*) as `n`
from
	payments
group by
	payment_type
order by
	n desc;

select
	review_score,
	count(*) as `n`
from
	order_reviews
group by
	review_score
order by
	review_score;
	
-- =============================================================================
-- 4. Numeric sanity: price/freight/payment ranges

select
	min(cast(price as decimal(10, 2))) as `min_price`,
	max(cast(price as decimal(10, 2))) as `max_price`,
	min(cast(freight_value as decimal(10, 2))) as `min_freight`
from
	order_items;

select
	sum(cast(payment_installments as signed) = 0) as `zero_installments`,
	sum(cast(payment_value as decimal(10, 2)) <= 0) as `zero_or_neg_payments`
from
	payments;
	
-- =============================================================================
-- 5. Products: how many rows are missing which fields?

select
	sum(nullif(trim(`product category`), "") is null) as `missing_category`,
	sum(nullif(trim(product_weight_g), "") is null) as `missing_weight`,
	sum(nullif(trim(product_photos_qty), "") is null) as `missing_photos`
from
	products;

-- =============================================================================
-- 6. Check date formats

select
	order_purchase_timestamp
from
	orders
limit
	3;

select
	review_creation_date,
	review_answer_timestamp
from
	order_reviews
limit
	3;

describe orders;
describe order_reviews;


-- =============================================================================
-- Part 2: GENERATE CLEAN VIEWS (without touching original tables)
-- =============================================================================

/*
 * customers_view
 * 
 * trim IDs
 * zero-pad zip
 * consistent case for GROUP BY ops
 * one row per customer_id
 * */

create or replace view customers_view as 
with cte1 as (
    select
        trim(customer_id) as `customer_id`,
        trim(customer_unique_id) as `customer_unique_id`,
        lpad(trim(customer_zip_code_prefix), 5, "0") as `customer_zip_code_prefix`,
        lower(trim(customer_city)) as `customer_city`,
        upper(trim(customer_state)) as `customer_state`,
        lower(trim(bsn.`State name`)) as `customer_state_name`,
        row_number() over(partition by trim(customer_id) order by customer_unique_id) as `rn`
    from
        customers as c left join brazil_state_names as bsn
        on c.customer_state = bsn.`State code`
    where
        nullif(trim(customer_id), "") is not null
)
select
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,   
    customer_state,
    customer_state_name
from
    cte1
where 
    rn = 1;

/*
 * sellers_view
 * 
 * one row per seller_id
 * */

create or replace view sellers_view as 
with cte1 as (
    select
        trim(seller_id) as `seller_id`,
        lpad(trim(seller_zip_code_prefix), 5, "0") as `seller_zip_code_prefix`,
        lower(trim(seller_city)) as `seller_city`,
        upper(trim(seller_state)) as `seller_state`,
        row_number() over(partition by trim(seller_id) order by seller_zip_code_prefix) as `rn`
    from
        sellers
    where
        nullif(trim(seller_id), "") is not null
)
select
    seller_id,
    seller_zip_code_prefix,
    seller_city,   
    seller_state  
from
    cte1
where 
    rn = 1;

/*
 * geolocation_view
 * 
 * zero-pad zip
 * */

create or replace view geolocation_view as
select
    round(avg(geolocation_lat), 6) as centroid_lat,
    round(avg(geolocation_lng), 6) as centroid_lng,
    lpad(trim(geolocation_zip_code_prefix), 5, "0") as `geolocation_zip_code_prefix`,
    max(lower(trim(geolocation_city))) as `geolocation_city`,
    max(upper(trim(geolocation_state))) as `geolocation_state`,
    count(*) as `n_readings`
from
    geolocation
group by
	lpad(trim(geolocation_zip_code_prefix), 5, "0");



/*
 * products_view
 * 
 * rename col with space
 * normalise categroy text
 * cast to numbers
 * missing category -> "unknown"
 * */

create or replace view products_view as 
with cte1 as (
    select
        trim(product_id) as `product_id`,
        coalesce(
        	lower(
        		replace(
        			NULLIF(TRIM(`product category`), ""), 
        			" ", "_"
        		)
        	),
        	"unknown"
        ) as `product_category`,
        cast(
        	nullif(trim(product_name_length), "") as decimal(10, 0)
        ) as `product_name_length`,
        cast(
        	nullif(trim(product_description_length), "") as decimal(10, 0)
        ) as `product_description_length`,
        cast(
        	nullif(trim(product_photos_qty), "") as decimal(10, 0)
        ) as `product_photos_qty`,
        cast(
        	nullif(trim(product_weight_g), "") as decimal(10, 0)
        ) as `product_weight_g`,
        cast(
        	nullif(trim(product_length_cm), "") as decimal(10, 0)
        ) as `product_length_cm`,
        cast(
        	nullif(trim(product_height_cm), "") as decimal(10, 0)
        ) as `product_height_cm`,
        cast(
        	nullif(trim(product_width_cm), "") as decimal(10, 0)
        ) as `product_width_cm`,
        row_number() over(partition by trim(product_id) order by product_id) as `rn`
    from
        products
    where
        nullif(trim(product_id), "") is not null
)
select
    product_id,
    product_category,
    product_name_length,
    product_description_length,   
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
from
    cte1
where 
    rn = 1;



/*
 * orders_view
 * 
 * text-> datetime
 * lowercase status
 * delivery date on a non-delivered order
 * order set to null
 * create delivery metrics most analysed
 * */

create or replace view orders_view as 
with cte1 as (
    select
        trim(order_id) as `order_id`,
        trim(customer_id) as `customer_id`,
        lower(trim(order_status)) as `order_status`,
        str_to_date(
        	nullif(trim(order_purchase_timestamp), ""),
        	"%Y-%m-%d %H:%i:%s"
        ) as `order_purchase_timestamp`,
        str_to_date(
        	nullif(trim(order_approved_at), ""),
        	"%Y-%m-%d %H:%i:%s"
        ) as `order_approved_at`,
        str_to_date(
        	nullif(trim(order_delivered_carrier_date), ""),
        	"%Y-%m-%d %H:%i:%s"
        ) as `order_delivered_carrier_date`,
        str_to_date(
        	nullif(trim(order_delivered_customer_date), ""),
        	"%Y-%m-%d %H:%i:%s"
        ) as `order_delivered_customer_date`,
        str_to_date(
        	nullif(trim(order_estimated_delivery_date), ""),
        	"%Y-%m-%d %H:%i:%s"
        ) as `order_estimated_delivery_date`
    from
        orders
    where
        nullif(trim(order_id), "") is not null
),
cte2 as (
	select
		order_id,
		customer_id,
		order_status,
		order_purchase_timestamp,
		order_approved_at,
		order_delivered_carrier_date,
		order_estimated_delivery_date,
		case
			when order_status = "delivered" then order_delivered_customer_date
			else null
		end as `order_delivered_customer_date`,
		(
			order_status = "delivered" 
			and order_delivered_customer_date is null
		) as `flag_missing_delivery_date`,
		(
			order_status != "delivered"
			and order_delivered_customer_date is not null
		) as `flag_delivery_date_on_undelivered`
	from
		cte1
	where
		order_purchase_timestamp is not null and
        order_purchase_timestamp between "2017-01-01 00:00:00" and "2018-09-01 00:00:00"
)
select
    *,
    datediff(
    	order_delivered_customer_date, 
    	order_purchase_timestamp
    ) as `delivery_days`,
    datediff(
    	order_estimated_delivery_date, 
    	order_delivered_customer_date
    ) as `days_vs_estimate`, -- +ve is early
    case 
    	when order_delivered_customer_date is null then null
    	when date(order_delivered_customer_date) > date(order_estimated_delivery_date) then 1
    	else 0
    end as `is_late`
from
    cte2;


/*
 * order_values_view
 * */

CREATE OR REPLACE VIEW order_values_view AS
SELECT
    o.order_id,
    c.customer_state,
    bsn.`State name` as customer_state_name,
    YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    SUM(oi.price) AS order_price,
    SUM(oi.freight_value) AS order_freight
FROM orders_view o
JOIN customers_view c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN brazil_state_names bsn ON c.customer_state = bsn.`State code`
GROUP BY 
    o.order_id,
    c.customer_state,
    bsn.`State name`,
    order_year,
    order_month;

/*
 * delivery_metrics_view
 * */

CREATE OR REPLACE VIEW delivery_metrics_view AS
SELECT
    o.order_id,
    c.customer_state,
    -- Fractional delivery days calculated from seconds
    TIMESTAMPDIFF(SECOND, o.order_purchase_timestamp, o.order_delivered_customer_date) / (24 * 60 * 60) AS time_to_deliver_days,
    -- Promised delivery window in days
    DATEDIFF(DATE(o.order_estimated_delivery_date), DATE(o.order_purchase_timestamp)) AS promised_days,
    -- Difference between estimated and actual delivery dates
    DATEDIFF(DATE(o.order_estimated_delivery_date), DATE(o.order_delivered_customer_date)) AS diff_estimated_delivery
FROM orders_view o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_delivered_customer_date >= o.order_purchase_timestamp;

/*
 * order_items_view
 * 
 * zero/-ve prices flagged. 0 price can be a promo item
 * */

create or replace view order_items_view as 
select
    trim(order_id) as `order_id`,
    cast(order_item_id as unsigned) as `order_item_id`,
    trim(product_id) as `product_id`,
    trim(seller_id) as `seller_id`,
    str_to_date(
    	nullif(trim(shipping_limit_date), ""),
    	"%Y-%m-%d %H:%i:%s"
    ) as `shipping_limit_date`,
    cast(price as decimal(10, 2)) as `price`,
    cast(freight_value as decimal(10, 2)) as `freight_value`,
    (cast(price as decimal(10, 2)) <= 0) AS `flag_nonpositive_price`
from
    order_items
where
    nullif(trim(order_id), "") is not null;


/*
 * payments_view
 * 
 * 'not_defined' -> 'unknown'; installments of 0 -> 1 (one-shot payment) so
 * average-installments maths is meaningful. Several rows per order are normal
 * (split payments), so aggregate to order level before joining to orders.
 * */

create or replace view payments_view as 
select
    trim(order_id) as `order_id`,
    cast(payment_sequential as unsigned) as `payment_sequential`,
    case
    	when lower(trim(payment_type)) in ("not_defined", "", "undefined") then "unknown"
    	else lower(trim(payment_type))
    end as `payment_type`,
    case
    	when cast(payment_installments as signed) = 0 then 1
    	else cast(payment_installments as signed)
    end as `payment_installments`,
    cast(payment_value as decimal(10, 2)) as `payment_value`,
    (cast(payment_value as decimal(10, 2)) <= 0) as `flag_nonpositive_payment`
from
    payments
where
    nullif(trim(order_id), "") is not null;


-- Order-level payment totals, ready to join to orders_clean
create or replace view payments_by_order_view as 
select
	order_id,
	sum(payment_value) as `total_paid`,
	max(payment_installments) as `max_installments`,
	count(*) as `n_payments`
from
	payments_view
group by
	order_id;


-- ── order_reviews: one row per order ────────────────────────────────────────
-- Fixes: score outside 1-5 -> NULL (flagged), blank title -> NULL, dates parsed,
-- and where an order has several reviews, keep only the most recent. This also
-- sidesteps any duplicated review_id values.
-- Date format 


create or replace view reviews_view as 
with cte1 as (
    select
        trim(review_id) as `review_id`,
        trim(order_id) as `order_id`,
        case
        	when cast(review_score as signed) >= 1
        	and cast(review_score as signed) <= 5 then cast(review_score as signed)
        end as `review_score`,
        nullif(trim(review_comment_title), "") as `review_comment_title`,
        str_to_date(
        	nullif(trim(review_creation_date), ""),
        	"%Y-%m-%d %H:%i:%s"
        ) as `review_creation_date`,
        str_to_date(
        	nullif(trim(review_answer_timestamp), ""),
        	"%Y-%m-%d %H:%i:%s"
        ) as `review_answer_timestamp`,
        (
        	cast(review_score as signed) < 1
        	or cast(review_score as signed) > 5
        ) as `flag_invalid_score`,
        count(*) over(partition by trim(order_id)) as `n_reviews_for_order`, 
        row_number() over(
        	partition by trim(order_id) 
        	order by str_to_date(
        		nullif(trim(review_creation_date), ""),
        		"%Y-%m-%d %H:%i:%s"
        	) desc,
        	review_id
        ) as `rn`
    from
        order_reviews
    where
        nullif(trim(order_id), "") is not null
)
select
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_creation_date,
    review_answer_timestamp,
    flag_invalid_score,
    n_reviews_for_order
from
    cte1
where 
    rn = 1;


-- =============================================================================
-- PART 3 - VALIDATION 
-- =============================================================================
-- 3a. Did we lose or gain rows unexpectedly? Compare raw vs clean.
SELECT
    'customers' AS tbl,
    (
        SELECT
            COUNT(*)
        FROM
            customers
    ) AS raw_rows,
    (
        SELECT
            COUNT(*)
        FROM
            customers_view
    ) AS clean_rows
UNION ALL
SELECT
    'sellers',
    (
        SELECT
            COUNT(*)
        FROM
            sellers
    ),
    (
        SELECT
            COUNT(*)
        FROM
            sellers_view
    )
UNION ALL
SELECT
    'products',
    (
        SELECT
            COUNT(*)
        FROM
            products
    ),
    (
        SELECT
            COUNT(*)
        FROM
            products_view
    )
UNION ALL
SELECT
    'orders',
    (
        SELECT
            COUNT(*)
        FROM
            orders
    ),
    (
        SELECT
            COUNT(*)
        FROM
            orders_view
    )
UNION ALL
SELECT
    'items',
    (
        SELECT
            COUNT(*)
        FROM
            order_items
    ),
    (
        SELECT
            COUNT(*)
        FROM
            order_items_view
    )
UNION ALL
SELECT
    'payments',
    (
        SELECT
            COUNT(*)
        FROM
            payments
    ),
    (
        SELECT
            COUNT(*)
        FROM
            payments_view
    )
UNION ALL
SELECT
    'reviews',
    (
        SELECT
            COUNT(*)
        FROM
            order_reviews
    ),
    (
        SELECT
            COUNT(*)
        FROM
            reviews_view
    );

-- Only reviews should differ (one row kept per order). Anything else: investigate.
-- 3b. Date parsing worked? Unparsed dates become NULL, so these should be ~0.
SELECT
    SUM(order_purchase_timestamp IS NULL) AS null_purchase
FROM
    orders_view;

SELECT
    SUM(review_creation_date IS NULL) AS null_review_date
FROM
    reviews_view;

-- 3c. Flagged anomalies (counts for your cleaning log)
SELECT
    SUM(flag_missing_delivery_date) AS delivered_but_no_date,
    SUM(flag_delivery_date_on_undelivered) AS date_on_undelivered
FROM
    orders_view;

SELECT
    SUM(flag_invalid_score) AS bad_scores
FROM
    reviews_view;


-- 3d. Referential integrity (all should be 0)
SELECT
    COUNT(*) AS orders_without_customer
FROM
    orders_view o
    LEFT JOIN customers_view c ON o.customer_id = c.customer_id
WHERE
    c.customer_id IS NULL;

SELECT
    COUNT(*) AS items_without_order
FROM
    order_items_view i
    LEFT JOIN orders_view o ON i.order_id = o.order_id
WHERE
    o.order_id IS NULL;

SELECT
    COUNT(*) AS items_without_product
FROM
    order_items_view i
    LEFT JOIN products_view p ON i.product_id = p.product_id
WHERE
    p.product_id IS NULL;

SELECT
    COUNT(*) AS items_without_seller
FROM
    order_items_view i
    LEFT JOIN sellers_view s ON i.seller_id = s.seller_id
WHERE
    s.seller_id IS NULL;

-- 3e. Do customer zips actually match the geolocation table after padding?
SELECT
    COUNT(*) AS customers_without_geo
FROM
    customers_view c
    LEFT JOIN geolocation_view g ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE
    g.geolocation_zip_code_prefix IS NULL;












	