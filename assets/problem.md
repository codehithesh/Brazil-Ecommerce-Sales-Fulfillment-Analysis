# Brazil E-Commerce EDA

### About Business

Target is a globally renowned brand and a prominent retailer in the United States. Target makes it easy, shop-worthy, and inspiring, offering a store-hug feeling, e-commerce site, and apps for seamless and spent experience that's standard for modern retail.

This particular dataset includes 100k orders made on Target in Brazil and provides insights and operations of 100k orders placed between 2016 and 2018. The dataset allows an exploration of various dimensions, including order status, price, payment and freight performance, customer location, product attributes, and customer reviews.

Data analysis on the dataset is paramount, standardizing custom data processing, Target's operations in Brazil, customer experience, seller performance, logistics, freight cost, order processing, delivery speed, and overall performance, offering comprehensive insights into customer characteristics, product attributes, and customer behavior.

**Dataset link:** 
`https://d3ilbtxij3a859.cloudfront.net/31a47b850d18086aed15d03a1d95.zip`

Dataset is available in 8 csv files:

1. `customers.csv`
2. `geolocation.csv`
3. `order_items.csv`
4. `order_payments.csv`
5. `order_reviews.csv`
6. `orders.csv`
7. `products.csv`
8. `sellers.csv`

---

### Schema Description

The **`customers.csv`** has the following features:

| Feature | Description |
| --- | --- |
| `customer_id` | Key to the customer who made the purchase |
| `customer_unique_id` | Unique ID of the customer |
| `customer_zip_code_prefix` | First 5 digits of customer zip code |
| `customer_city` | Name of the city where customer lives |
| `customer_state` | State code where order was delivered (e.g., SP) |

The **`sellers.csv`** contains the following features:

| Feature | Description |
| --- | --- |
| `seller_id` | Seller unique ID |
| `seller_zip_code_prefix` | First 5 digits of seller zip code |
| `seller_city` | Name of the city of the seller |
| `seller_state` | State code (e.g., SP) |

The **`orders.csv`** contains the following features:

| Feature | Description |
| --- | --- |
| `order_id` | Unique ID of an order placed by the customer |
| `order_status` | Status of the order (e.g., delivered, shipped, cancelled) |
| `order_purchase_timestamp` | Timestamp when order was placed by customer |
| `order_approved_at` | Timestamp when payment was approved |
| `order_delivered_carrier_date` | Date when the order was handed over to the carrier |
| `order_delivered_customer_date` | Date when order was delivered to customer |
| `order_estimated_delivery_date` | Estimated delivery date given to customer at purchase time |

The **`geolocation.csv`** contains the following features:

| Feature | Description |
| --- | --- |
| `geolocation_zip_code_prefix` | First 5 digits of zip code |
| `geolocation_lat` | Latitude |
| `geolocation_lng` | Longitude |
| `geolocation_city` | City |
| `geolocation_state` | State |

The **`order_payments.csv`** contains the following features:

| Feature | Description |
| --- | --- |
| `order_id` | Unique ID of an order placed by customer |
| `payment_sequential` | Sequence of the payment methods used |
| `payment_type` | Payment method used (e.g., Credit Card) |
| `payment_installments` | Number of installments chosen for EMI payment |
| `payment_value` | Total amount paid for the order sequence |

The **`order_items.csv`** contains the following features:

| Feature | Description |
| --- | --- |
| `order_id` | Unique ID of an order placed by customer |
| `order_item_id` | ID of the item within order sequence |
| `product_id` | Unique ID of product purchased |
| `seller_id` | Unique ID of seller who sold the product |
| `shipping_limit_date` | Date limit for seller to ship the order |
| `price` | Price of the item purchased |
| `freight_value` | Freight cost of shipping the item |

The **`order_reviews.csv`** contains the following features:

| Feature | Description |
| --- | --- |
| `review_id` | Unique ID of review written by customer |
| `order_id` | Unique ID of order purchased |
| `review_score` | Rating score given by customer on scale of 1-5 |
| `review_comment_title` | Title of the review |
| `review_comment_message` | Detailed comment message left by customer |
| `review_creation_date` | Date review survey was sent to customer |
| `review_answer_timestamp` | Date review response was received |

The **`products.csv`** contains the following features:

| Feature | Description |
| --- | --- |
| `product_id` | Unique ID for product |
| `product_category_name` | Category of product |
| `product_name_lenght` | Length of product name |
| `product_description_lenght` | Length of product description |
| `product_photos_qty` | Number of product photos published |
| `product_weight_g` | Weight of product in grams |
| `product_length_cm` | Length of product in centimeters |
| `product_height_cm` | Height of product in centimeters |
| `product_width_cm` | Width of product in centimeters |

---

### Problem Statement

In this project, as a data analyst working at Target, you have been assigned to conduct an exploratory data analysis on the given dataset to extract meaningful insights and present them to the higher management.

1. Visual Appeal & Organization (Data structure & exploration) 
2. In-depth Exploration
3. Evolution of E-commerce in Brazil region
4. Impact on Economy
5. Analysis based on Delivery
6. Analysis based on Payments

---

1. **Import the dataset and do usual exploratory analysis steps like checking the structure & characteristics of the dataset:**
    1. Data type of all columns in the 8 tables.
    2. Get the time range for which the data is provided (e.g., 2016-10 to 2018-09).
    3. Check the count of Cities & States of customers who ordered stuff.


2. **In-depth Exploration:**
    1. Is there a growing trend in the number of orders placed over time?
    2. How do order volumes vary across months, days of week, and hours?
    3. Moving on to seasonality, do we see a trend in seasonal ordering, peak times, time of year, or day of week?
        * Split by Year
        * Split by Month
        * Split by Hour


4. Evolution of E-commerce orders in the Brazil region:
    * Get the number of orders placed per month/year.
    * How are order counts distributed across states?


3. **Impact on Economy:** Analyze the money movement/order value so far and impact on the process, freight, and seller.
    1. Get the percentual change of the cost of order placed from 2017 to 2018 (Aug 2017 to Aug 2018).
    2. Get total & average order price and total & average freight value per order.
    3. Analysis on payment methods (Credit Card, Boleto, etc.).
    4. Analysis on payment installments (number of installments).


4. **Analysis based on Sales, Freight & Delivery:**
    1. Calculate delivery performance metrics for orders:
        * How fast orders were delivered (difference between estimated delivery date and delivery date)?
        * Calculate the time difference between delivery date and estimated date.
        * `diff_estimated_delivery_date` = `estimated_delivery_date` - `delivered_customer_date`


    2. Find the top 5 states with highest delivery time/freight price.
    3. Find the top 5 states with lowest delivery time/freight price.
    4. Find the top 5 states where the order delivery date is fast compared to estimated delivery.
    5. Do we observe differences in delivery times across states? Compare top/bottom states with average delivery time per state.


5. **Analysis based on the payments:**
    1. Find the month-on-month count of orders placed for each payment type.
    2. Find the total number of orders placed per year for each payment method.