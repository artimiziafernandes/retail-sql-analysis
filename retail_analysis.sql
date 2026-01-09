CREATE TABLE customers(
customer_id int PRIMARY KEY,
first_name VARCHAR(50),
last_name VARCHAR(50),
email VARCHAR(100),
signup_date DATE,
city VARCHAR(50)
);

CREATE TABLE stores(
store_id int PRIMARY KEY,
store_name VARCHAR(50),
city VARCHAR(50),
opened_date DATE
);

CREATE TABLE products(
product_id int PRIMARY KEY,
product_name VARCHAR(50),
category VARCHAR(50),
price NUMERIC(10,2)
);

CREATE TABLE sales(
sale_id int PRIMARY KEY,
customer_id int,
product_id int,
store_id int,
quantity int,
unit_price NUMERIC(10,2),
sale_date DATE,
discount_applied NUMERIC(5,2),

FOREIGN KEY (customer_id) references customers(customer_id),
FOREIGN KEY (store_id) references stores(store_id),
FOREIGN KEY (product_id) references products(product_id)
);

CREATE TABLE returns (
    return_id        INT PRIMARY KEY,
    sale_id          INT NOT NULL,
    product_id       INT NOT NULL,
    store_id         INT NOT NULL,
    return_date      DATE NOT NULL,
    return_quantity  INT NOT NULL,
    return_reason    VARCHAR(100)
);

INSERT INTO returns (
    return_id,
    sale_id,
    product_id,
    store_id,
    return_date,
    return_quantity,
    return_reason
) VALUES
(1, 101, 201, 1, '2024-01-15', 1, 'Damaged item'),
(2, 102, 202, 1, '2024-01-18', 2, 'Wrong size'),
(3, 105, 203, 2, '2024-01-20', 1, 'Defective'),
(4, 110, 201, 2, '2024-02-02', 3, 'Customer changed mind'),
(5, 115, 204, 3, '2024-02-10', 1, 'Late delivery'),
(6, 118, 202, 3, '2024-02-12', 2, 'Wrong product'),
(7, 120, 205, 1, '2024-02-15', 1, 'Defective'),
(8, 125, 203, 2, '2024-03-01', 2, 'Damaged item'),
(9, 130, 204, 3, '2024-03-05', 1, 'Customer changed mind'),
(10, 135, 201, 1, '2024-03-08', 2, 'Defective');


SELECT * FROM customers;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM stores;
SELECT COUNT(*) FROM sales;

-- Task 1 — Total Revenue by Store

SELECT st.store_id,
       st.store_name,
       COALESCE(SUM(s.quantity * s.unit_price * (1 - s.discount_applied)), 0) AS total_revenue
FROM stores AS st
LEFT JOIN sales AS s ON s.store_id = st.store_id
GROUP BY st.store_id, st.store_name
ORDER BY total_revenue DESC;

-- Task 2 — Top 5 Best-Selling Products
WITH revenue AS (
    SELECT 
        s.product_id,
        p.product_name,
        SUM(s.quantity * s.unit_price * (1 - discount_applied)) AS total_revenue 
    FROM sales s
    LEFT JOIN products p ON s.product_id = p.product_id
    GROUP BY s.product_id, p.product_name
),

rank_products AS (
    SELECT 
        r.*, 
        RANK() OVER (ORDER BY total_revenue DESC) AS rnk
    FROM revenue r
)

SELECT *
FROM rank_products
WHERE rnk <= 5;

--Task 3 — Customer Lifetime Value
WITH customer_summary AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        MIN(s.sale_date) AS first_purchase,
        MAX(s.sale_date) AS last_purchase,
        SUM(s.quantity * s.unit_price * (1 - s.discount_applied)) AS total_spend,
        COUNT(DISTINCT s.sale_id) AS total_orders
    FROM customers c
    LEFT JOIN sales s ON c.customer_id = s.customer_id
    GROUP BY c.customer_id, customer_name
)

SELECT
    customer_id,
    customer_name,
    first_purchase,
    last_purchase,
    total_spend,
    CASE 
        WHEN total_orders = 0 THEN 0 
        ELSE total_spend / total_orders 
    END AS avg_order_value
FROM customer_summary
ORDER BY total_spend DESC NULLS LAST;

-- Task 4 -Monthly revenue trend

SELECT
    DATE_TRUNC('month', sale_date)::date AS month_start,
    SUM(quantity * unit_price * (1 - COALESCE(discount_applied, 0))) AS monthly_revenue
FROM sales
GROUP BY month_start
ORDER BY month_start;

-- Task 5 - Product category performance

SELECT  p.category,st.store_name,SUM(quantity * unit_price * (1 - COALESCE(discount_applied, 0))) AS revenue
FROM products as p
LEFT JOIN sales as s ON p.product_id = s.product_id
LEFT JOIN stores as st ON s.store_id = st.store_id
GROUP BY p.category,st.store_name
ORDER BY p.category,revenue desc LIMIT 10;

WITH rev as (
SELECT
  st.store_id,
  st.store_name,
  p.category,
  SUM(s.quantity * s.unit_price * (1 - COALESCE(s.discount_applied,0))) AS revenue
FROM sales s
JOIN products p ON s.product_id = p.product_id
JOIN stores st ON s.store_id = st.store_id
GROUP BY st.store_id, st.store_name, p.category),
rank_category as (
SELECT r.*, RANK() OVER (PARTITION BY store_id ORDER BY revenue desc) as rnk
FROM rev as r
)

SELECT * FROM rank_category
WHERE rnk = 1
ORDER BY revenue desc;

--Task 6 - Repeat Customer Rate
WITH customer_orders AS (
    SELECT customer_id, COUNT(DISTINCT sale_id) AS num_orders
    FROM sales
    GROUP BY customer_id
)
SELECT
    SUM(CASE WHEN num_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    COUNT(*) AS total_customers_with_orders,
    ROUND(100.0 * SUM(CASE WHEN num_orders > 1 THEN 1 ELSE 0 END) 
          / COUNT(*), 2) AS repeat_rate_pct
FROM customer_orders;


--TASK 7 - Store with highest YoY growth

WITH yearly_revenue AS (
    SELECT
        s.store_id,
        DATE_TRUNC('year', s.sale_date)::date AS year,
        SUM(s.quantity * s.unit_price * (1 - COALESCE(s.discount_applied, 0))) AS revenue
    FROM sales s
    GROUP BY s.store_id, year
),

yoy_calc AS (
    SELECT
        store_id,
        year,
        revenue,
        LAG(revenue) OVER (
            PARTITION BY store_id
            ORDER BY year
        ) AS prev_year_revenue
    FROM yearly_revenue
),

yoy_growth AS (
    SELECT
        store_id,
        year,
        revenue,
        prev_year_revenue,
        revenue - prev_year_revenue AS yoy_growth,
        ROUND(
            (revenue - prev_year_revenue)
            / NULLIF(prev_year_revenue, 0) * 100,
            2
        ) AS yoy_growth_pct
    FROM yoy_calc
)

SELECT *
FROM yoy_growth
WHERE prev_year_revenue IS NOT NULL
ORDER BY yoy_growth_pct DESC;


--Task 8 - Identify each store’s top 3 customers
WITH pr as 
(SELECT c.customer_id,st.store_id,
SUM(s.quantity *s.unit_price * (1-COALESCE(s.discount_applied,0))) as rev
FROM sales as s
JOIN customers as c ON s.customer_id = c.customer_id
JOIN stores as st ON s.store_id = st.store_id
GROUP BY  c.customer_id,st.store_id),
tp_cus as ( SELECT p.*, RANK() OVER(PARTITION BY store_id ORDER BY rev DESC) as rn
FROM pr as p)
SELECT * FROM tp_cus
WHERE rn <4;

--Task 9 - MoM revenue growth per store

WITH monthly AS (
  SELECT
    s.store_id,
    st.store_name,
    DATE_TRUNC('month', sale_date)::date AS month_start,
    SUM(quantity * unit_price * (1 - COALESCE(discount_applied,0))) AS monthly_revenue
  FROM sales s
  JOIN stores st ON s.store_id = st.store_id
  GROUP BY s.store_id, st.store_name, month_start
),
mom AS (
  SELECT
    store_id,
    store_name,
    month_start,
    monthly_revenue,
    LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month_start) AS prev_month_revenue,
    ROUND(
      ((monthly_revenue - LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month_start))
       / NULLIF(LAG(monthly_revenue) OVER (PARTITION BY store_id ORDER BY month_start),0)
      ) * 100, 2) AS mom_pct
  FROM monthly
)
SELECT *
FROM mom
WHERE prev_month_revenue IS NOT NULL
ORDER BY store_id, month_start;

-- TASK 10 - Which product has the highest return rate?
WITH sales_qty AS (
  SELECT product_id, SUM(quantity) AS sold_qty
  FROM sales
  GROUP BY product_id
),
returns_qty AS (
  SELECT product_id, SUM(return_quantity) AS returned_qty
  FROM returns
  GROUP BY product_id
),
rates AS (
  SELECT
    p.product_id,
    p.product_name,
    COALESCE(r.returned_qty,0) AS returned_qty,
    COALESCE(s.sold_qty,0) AS sold_qty,
    CASE WHEN COALESCE(s.sold_qty,0)=0 THEN NULL
         ELSE ROUND(100.0 * COALESCE(r.returned_qty,0) / s.sold_qty,2)
    END AS return_rate_pct
  FROM products p
  LEFT JOIN returns_qty r ON p.product_id = r.product_id
  LEFT JOIN sales_qty s ON p.product_id = s.product_id
)
SELECT *
FROM rates
ORDER BY return_rate_pct DESC NULLS LAST
LIMIT 10;

---TASK 11 - Weighted performance scoring for stores

WITH rev_month as (
SELECT DATE_TRUNC('month',s.sale_date)::date as start_month,
SUM(s.quantity * s.unit_price *(COALESCE(1-s.discount_applied,0))) as revenue_month,st.store_id
FROM sales as s
LEFT JOIN stores as st ON s.store_id = st.store_id
GROUP BY st.store_id,start_month),
mom_growth as(
SELECT *,(revenue_month-  LAG(revenue_month) OVER(PARTITION BY store_id ORDER BY start_month)) as mom_change,ROUND((revenue_month-  LAG(revenue_month) OVER(PARTITION BY store_id ORDER BY start_month))/NULLIF(LAG(revenue_month) OVER(PARTITION BY store_id ORDER BY start_month),0) *100,2) as mom_pct
FROM rev_month),
rev_year as (
SELECT DATE_TRUNC('year',s.sale_date)::date as start_year,
SUM(s.quantity * s.unit_price *(COALESCE(1-s.discount_applied,0))) as revenue_year,st.store_id
FROM sales as s
LEFT JOIN stores as st ON s.store_id = st.store_id
GROUP BY st.store_id,start_year),
yoy_growth as (
SELECT *,(revenue_year- LAG(revenue_year) OVER(PARTITION BY store_id ORDER BY start_year)) as yoy_change,
ROUND((revenue_year- LAG(revenue_year) OVER(PARTITION BY store_id ORDER BY start_year))/NULLIF(LAG(revenue_year) OVER(PARTITION BY store_id ORDER BY start_year),0) *100,2) as yoy_pct
FROM rev_year),
customer_spend as (
SELECT s.customer_id,SUM(s.quantity * s.unit_price *(COALESCE(1-s.discount_applied,0))) as total_spend,s.store_id
FROM sales as s
GROUP BY s.customer_id,s.store_id
),
customer_rank as (
SELECT *, NTILE(5) OVER(PARTITION BY store_id ORDER BY total_spend DESC) as spend_bucket
FROM customer_spend
),
high_value_cus as (
SELECT store_id, COUNT(*) FILTER( WHERE spend_bucket=1)::decimal / COUNT(*) as high_value_customer
FROM customer_rank
GROUP BY store_id
),
basket_bucket as (
SELECT store_id,SUM(s.quantity * s.unit_price *(COALESCE(1-s.discount_applied,0))) / COUNT(DISTINCT s.sale_id) as avg_basket_value
FROM sales as s
GROUP BY store_id
),
final_score as (
SELECT
 st.store_id, AVG(mg.mom_pct) as avg_mom_pct, MAX(yg.yoy_pct) as yoy_pct,hvc.high_value_customer,bb.avg_basket_value,
 ROUND((0.35*COALESCE(MAX(yg.yoy_pct),0)+(0.25*COALESCE(AVG(mg.mom_pct),0))
 +(0.20*(COALESCE(hvc.high_value_customer,0)*100))
 +(0.20*COALESCE(bb.avg_basket_value,0)))) as performance_scores
 FROM stores as st
 LEFT JOIN mom_growth as mg ON st.store_id =mg.store_id
 LEFT JOIN yoy_growth as yg ON st.store_id =yg.store_id
 LEFT JOIN high_value_cus as hvc ON st.store_id =hvc.store_id
 LEFT JOIN basket_bucket as bb ON st.store_id =bb.store_id
 GROUP BY st.store_id,hvc.high_value_customer,bb.avg_basket_value
)
SELECT *, RANK() OVER(ORDER BY performance_scores DESC) as store_Rank
FROM final_score
ORDER BY store_Rank;

---Task 12 -Customer segmentation (RFM)

with cus_metrics as (
SELECT s.customer_id, MAX(s.sale_date) as last_purchase, 
COUNT(DISTINCT s.sale_id) as freq_order, 
SUM(s.quantity * s.unit_price *(COALESCE(1-s.discount_applied,0))) as customer_spend
FROM sales as s
GROUP BY s.customer_id),
score_cus as(
SELECT *, NTILE(3) OVER(ORDER BY (CURRENT_DATE - last_purchase)ASC) as r_score,
NTILE(3) OVER(ORDER BY freq_order DESC) as f_score,
NTILE(3) OVER(ORDER BY customer_spend DESC) as m_score
FROM cus_metrics
),
rfm_score as(
SELECT *,(r_score +f_score+m_score) as RFM,
CASE
WHEN (r_score +f_score + m_score) <=3 THEN 'GOLD' 
WHEN (r_score +f_score + m_score) BETWEEN 4 AND 6 THEN 'SILVER'
ELSE 'BRONZE'
END as segment
FROM score_cus)
SELECT customer_id,last_purchase,freq_order,customer_spend,r_score,f_score,m_score,segment
FROM rfm_score
ORDER BY segment,customer_spend desc;








