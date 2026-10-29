![alt text](https://github.com/codehithesh/Brazil-Ecommerce-Sales-Fulfillment-Analysis/blob/main/assets/banner.jpg)

# Brazilian E-commerce Sales and Fulfillment Analysis, 2016-2018: Growth, Seasonality, Delivery vs. Estimates
BigQuery + SQL analysis of Target Brazil retail transactions using order, customer, payment, and fulfillment data.

## Executive Summary
The dataset has roughly 100k orders placed between September 2016 and October 2018, spread across 4,119 cities and 27 Brazilian states. Most of the business sits in the Southeast. Sao Paulo, Rio de Janeiro, and Minas Gerais together make up about 68% of all orders. In other words, a handful of big regional markets drive the business, so decisions about fulfillment, staffing, and merchandising should lean toward those areas.

Orders grew a lot from 2017 to 2018, and demand clearly follows seasons, with most purchases happening during the day and in certain peak months. In Brazil it isn't really one big Black Friday moment. It's a steady growth trend with demand spikes that keep coming back. Customers also lean heavily on credit cards, which cover roughly 74% of transactions, and UPI comes second at about 19%. That's worth keeping in mind when designing checkout and installment promotions.

Delivery works well overall, but not evenly everywhere. A delivered order takes about 12.1 days on average to reach the customer, and 92% show up on or before the estimated date. The trouble is in remote, harder-to-reach states like RR, AP, AM, and AL, where deliveries take much longer and shipping costs a lot more. That points to freight inefficiency and last-mile bottlenecks. So the best opportunity isn't to chase every state equally. It's to get the most out of the Southeast-heavy demand base while rethinking carrier and fulfillment plans for the slower remote states.

## About Business
Target is a well-known global retail brand and one of the biggest retailers in the United States. It runs physical stores, an e-commerce website, and apps built to make shopping easy. In this project, we look at Target's Brazilian operations using public transaction data, so we can see how orders have grown, where customers are, what freight costs, and how deliveries perform.

## Problem Statement
The goal here is to explore Target Brazil's e-commerce data and turn it into insights the business can act on. We look at where customers are, how many orders come in, how people pay, how sellers and fulfillment perform, what freight costs, how fast deliveries are, and when orders happen. All of this feeds into operational planning and performance management.

## Data Schema (ERD)
- Tables:
- customers.csv
- geolocation.csv
- order_items.csv
- payments.csv
- order_reviews.csv
- orders.csv
- products.csv
- sellers.csv
- Approximate total records: 100k orders across the public dataset

![alt text](https://github.com/codehithesh/Brazil-Ecommerce-Sales-Fulfillment-Analysis/blob/main/assets/erd/erd.png)

## Metrics

**Primary metrics**
- Monthly order count by `order_purchase_timestamp` month, to see whether demand is growing over time.
- Delivery gap, calculated as `order_estimated_delivery_date - order_delivered_customer_date` in days, for delivered orders only. A positive number means the order came early and a negative number means it came late.

**Supporting metrics**
- On-time or early delivery rate, meaning the share of delivered orders with a gap >= 0
- Average purchase-to-delivery time by state
- Total and average order value (`price` per order) and freight (`freight_value` per order)
- Payment mix by `payment_type`, month, and year
- Average `payment_installments` by payment type
- Order volume by state and by time of day

**Guardrail metrics**
- Order status mix, comparing delivered orders against shipped, canceled, unavailable, and other non-delivered states
- Non-delivered orders are left out of the delivery performance analysis
- Monthly counts are flagged where 2016 coverage is partial and late-2018 coverage is incomplete
- Median and mean are reported together wherever the data is skewed

## Insights

### Growth and seasonality
|  |  |
| --- | --- |
| ![Orders by year](assets/charts/chart_2_1.jpg) | ![Monthly seasonality](assets/charts/chart_2_2.jpg) |

- Orders went up from 2017 to 2018, which tells us e-commerce here is growing steadily and not just having one short spike.
- Ordering follows the seasons. Several months across the year are busy, and a lot of the activity lands in the middle and later parts of the year.
- Most purchases happen in the afternoon and evening, so the busiest window looks like 12:00-22:00.

### Regional demand concentration
|  |  |
| --- | --- |
| ![Top states by order evolution](assets/charts/chart_3_1.jpg) | ![Top states by unique customers](assets/charts/chart_3_2.jpg) |

- A few states carry most of the demand. São Paulo alone accounts for about 42% of all orders, with Rio de Janeiro and Minas Gerais following at roughly 13% and 12%.
- The top five states cover most of the e-commerce activity, which makes a good case for building the network around the Southeast and the high-volume hubs nearby.
- So when planning expansion and space, it makes more sense to build up fulfillment density in the strongest markets than to spread assets evenly across every region.

### Payment behavior and order economics
|  |  |
| --- | --- |
| ![Payment growth](assets/charts/chart_4_1.jpg) | ![Average order item price by state](assets/charts/chart_4_2.jpg) |

- Credit cards are by far the most used payment method, at about 74% of transactions. UPI comes second at roughly 19%, and voucher and debit card play smaller roles.
- The average order value is around R$137.75, and average freight is about R$22.82 per order. That puts freight at around 16.6% of the average order value. It's a real cost, but not big enough to cancel out the benefit of growing volume.
- People don't pay the same way in every state, which matters when building local promotions, installment offers, and checkout flows.

### Delivery performance and logistics risk
|  |  |
| --- | --- |
| ![Delivery performance variance](assets/charts/chart_5_1.jpg) | ![Fastest vs. slowest states](assets/charts/chart_5_3.jpg) |

- A delivered order takes 12.1 days on average to reach the customer, with a median of 10 days. So the typical experience is good, and a small group of very slow deliveries is pulling the average up.
- Orders arrive about +10.9 days ahead of the estimate on average, so most of them come earlier than promised. About 92% of delivered orders arrive on or before the estimated date.
- The real challenge is how different the states are from each other. Remote states like RR, AP, AM, and AL see much slower transit and much higher freight costs, while SP and its neighbors stay fairly efficient.

## Recommendations
**Put fulfillment capacity where the Southeast demand is**
   * Keep or grow fulfillment, inventory, and last-mile capacity in **SP, RJ, and MG**, since that's where most customers are.
   * A hub-and-spoke setup around the Southeast will work better than trying to cover the whole country evenly.

**Rethink logistics in high-freight states**
   * States like **RR, AP, AM, AL, and PA** have both high freight costs and slow deliveries. That could mean carriers aren't performing well, routes are very long, or the network is thin there.
   * Regional carriers, cross-docking, or consolidated routing could help bring shipping costs down in these states.

**Make delivery promises more accurate**
   * Many orders arrive earlier than estimated, so the current estimates look too cautious. Shortening the promised lead times could make customers happier without hurting trust, as long as the model still allows for the variation in remote states.

**Match payment offers to how people actually pay**
   * Since most people pay by credit card, installment offers and cashback promotions are still good levers. In regions where voucher or UPI use is high, local payment messaging could also help conversion.

## Limitations
- **The time coverage is uneven.** The data covers only part of 2016 and runs only through October 2018, so the years aren't fully comparable across 2016-2018.
- **Delivery metrics only use delivered orders.** Canceled, unavailable, and other non-delivered orders are left out of the speed and variance analysis.
- **State-level reads are approximate.** Customer state shows where the order was placed or delivered, but the shipment may have started somewhere else.
- **There's no margin or profit data.** We can measure volume, shipping cost, and delivery behavior, but not unit economics or profitability by product, seller, or region.
- **It's a public dataset.** It may not capture everything about Target Brazil's real operating conditions, seasonality, or network limits.

## Tech Stack
- SQL (CTEs, Joins, Date)
- Python and Pandas
- Matplotlib and Seaborn
- BigQuery

## How to run
- Open `retail_sales_and_fulfillment_analysis.ipynb` in Jupyter or VS Code.
- Run all the cells in order to reproduce the EDA and generate the charts under `assets/charts`.
- If you'd rather stick to SQL, load the CSV files from `assets/dataset` into a database and run the queries in the notebook.