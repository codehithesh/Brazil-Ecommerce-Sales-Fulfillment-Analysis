![alt text](https://github.com/codehithesh/Brazil-Ecommerce-Sales-Fulfillment-Analysis/blob/main/assets/banner.jpg)

# Brazilian E-commerce Sales and Fulfillment Analysis, 2016-2018: Growth, Seasonality, Delivery vs. Estimates
BigQuery, SQL analysis on retail transactions. CTEs, Date Time functions, Window functions

## Executive Summary



## Watch Video Presentation

<a href="https://www.youtube.com/watch?v=c316uVDjDFY" target="_blank">
  <img src="https://img.youtube.com/vi/c316uVDjDFY/hqdefault.jpg" alt="Watch Video on YouTube" width="400" />
</a>


## About Business
Target is a globally renowned brand and a prominent retailer in the United States. Target makes it easy, shop-worthy, and inspiring, offering a store-hug feeling, e-commerce site, and apps for seamless and spent experience that's standard for modern retail.

## Problem Statement
Do exploratory data analysis, standardizing custom data processing, Target's operations in Brazil, customer experience, seller performance, logistics, freight cost, order processing, delivery speed, and overall performance, offering comprehensive insights into customer characteristics, product attributes, and customer behavior.

## Data Schema (ERD)
* Tables:
    * customers.csv
    * geolocation.csv
    * order_items.csv
    * order_payments.csv
    * order_reviews.csv
    * orders.csv
    * products.csv
    * sellers.csv
* Total Records: 100k

![alt text](https://github.com/codehithesh/Brazil-Ecommerce-Sales-Fulfillment-Analysis/blob/main/assets/erd/erd.png)


## Metrics

**Primary metrics**
* **Monthly order count** (`COUNT(DISTINCT order_id)` by `order_purchase_timestamp` month): answers "is it growing?"
* **Delivery vs. estimate gap**: `order_estimated_delivery_date - order_delivered_customer_date`, in days, delivered orders only. Positive means early, negative means late. Answers "are orders arriving on time?"

**Supporting metrics**
* On-time delivery rate: share of delivered orders with gap >= 0
* Average delivery time (purchase to delivery, in days) by state
* Order value: total and average `price` per order
* Freight value: total and average `freight_value` per order, plus freight as a % of price
* Payment mix: order count by `payment_type`, by month and year
* Average `payment_installments` by payment type
* Order count by customer state and by day of week / hour

**Guardrail metrics**
* Order status mix: share of `delivered` vs. cancelled/unavailable. Delivery metrics use only delivered orders, so this shows how much is excluded.
* Missing delivery dates: count of delivered orders with null `order_delivered_customer_date`
* Orders per month, flagged for sparse 2016 and incomplete late 2018 months, so growth isn't overstated
* Median alongside mean for delivery time, price, and freight (all are right-skewed)


## Insights

#### Spend by Gender
|  |  |
| ------------- | ------------- |
| ![Chart 1](https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/assets/charts/chart_1.jpg) | ![Chart Age Counts](https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/assets/charts/chart_Age_counts.jpg) |
* Men average ₹9,437 per transaction vs ₹8,735 for women (95% CI [₹9,411, ₹9,463] vs [₹8,694, ₹8,776]), a gap of ~8%.
* Men are ~75% of transactions and ~76% of revenue, so volume matters as much as spend per order.
* If prioritizing segments, men carry more revenue because there are more of them and they spend slightly more. Whether women are under-reached or simply buy less needs an incrementality test, which this dataset can't run.

#### Spend by Age
|  |  |
| ------------- | ------------- |
| ![Chart Gender Counts](https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/assets/charts/chart_Gender_counts.jpg) | ![Chart Aov](https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/assets/charts/chart_aov.jpg) |
* Ages 26-35 (~40%) and 36-45 (~20%) together contribute ~60% of transactions.
* AOV is nearly flat across age groups, from ₹8,900 to ₹9,500. Age drives volume, not order value.
* If prioritizing segments, target by reach (26-45), not by expected basket size.

#### Spend by City Category
|  |  |
| ------------- | ------------- |
| ![Chart Heatmap](https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/assets/charts/chart_heatmap.jpg) | ![Chart Purchase By Age](https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/assets/charts/chart_purchase_by_Age.jpg) |
* City B accounts for ~42% of transactions, ahead of C (~31%) and A (~27%).
* Median spend is similar across cities, ₹8,050 to ₹8,150.
* If prioritizing segments, City B offers the largest audience, but per-order value won't differ by city.

#### Spend by Marital Status
|  |
| ------------- |
| ![Chart Purchase By Gender](https://github.com/codehithesh/Black-Friday-Customer-Spend-Analysis/blob/main/assets/charts/chart_purchase_by_Gender.jpg) |
* Unmarried customers make ~59% of transactions.
* Spend per transaction differs by less than 1% between groups (₹9,266 vs ₹9,261).
* Marital status isn't a useful targeting lever on this data.

## Recommendations

1. **Focus on High-Growth Regions:**
* Concentrate fulfillment assets in high-volume hubs (**SP, RJ, MG**). Adding micro-fulfillment centers in these locations will lower shipping times and reduce freight expenses.

2. **Optimize Carrier Networks in High-Freight States:**
* Remote regions (Ex: **RR, AP**) show higher freight costs and longer delivery times. Partnering with regional logistics providers or standardizing parcel size limits can help lower shipping fees.

3. **Refine Delivery Estimation Models:**
* Several states receive packages 15–20 days ahead of the estimated date. Adjusting estimation algorithms to reflect realistic timelines will improve conversion rates without sacrificing customer satisfaction.

4. **Leverage Payment Preferences:**
* Offer flexible installment options and exclusive credit card cash-back promotions during peak sales hours (**13:00 to 22:00**) to drive basket sizes and conversion rates.



## Limitations
* **Transactions aren't independent.** Rows are line items, and the same customer appears many times. The CIs treat them as independent, so they are narrower than they should be. Aggregating to User_ID would widen them.
* **Significance isn't importance.** With 550K rows, almost any gap becomes statistically significant. The ~8% gender gap is reported with effect size for that reason, and practical impact depends on margin, which isn't available.
* **Single event, single year.** The data covers one Black Friday sample. Patterns may not hold in other periods, and I can't say whether the sample is representative of all Walmart customers.
* **No cost, margin, or response data.** Recommendations are conditional prioritization, not ROI estimates. Budget changes need an incrementality test first.
* **Anonymized segments.** City_Category (A/B/C) and Occupation are coded labels, so findings can't be tied to real regions or job types.
* **Public case-study dataset.** The 50M male / 50M female assumption in the brief extrapolates mean spend per customer, not the sample's ~75/25 gender mix.


## Tech Stack
* BigQuery
* SQL


## How to run
* Import `black_friday_customer_spend_analysis.ipynb` into Jupyter notebook. 
* Then from the menu `Run` -> `Run All Cells` (OR) Copy each SQL queries and run them in MySQL server where data is loaded. Check dataset in `assets/dataset`.