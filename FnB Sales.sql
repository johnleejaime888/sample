# Create Staging table
use sales_portfolio;

CREATE TABLE cleaned
like sales_staging4;

ALTER TABLE cleaned
ADD COLUMN match_status TEXT;

INSERT INTO cleaned
SELECT *,
	CASE
		WHEN total_amount = correct_total_amount THEN 'MATCHED'
		ELSE 'NOT MATCHED'
	END AS match_status
FROM sales_staging4;

# Store Missing Values and Duplicates

CREATE TABLE missing_v_d
LIKE sales_staging2;

INSERT INTO missing_v_d
SELECT * FROM sales_staging2 where row_num > 1;

INSERT INTO missing_v_d
SELECT * FROM sales_staging2 where branch = '';

INSERT INTO missing_v_d
SELECT * FROM sales_staging2 where payment_method = '';

SELECT *,
ROW_NUMBER () OVER (PARTITION BY transaction_id) AS row_num1
FROM missing_v_d;

SELECT * FROM missing_v_d WHERE transaction_id IN ('TXN000907','TXN009716');

SELECT 
	COUNT(*) as total_row,
    SUM(CASE WHEN branch = '' THEN 1 ELSE 0 END) AS total_missing_branch,
    SUM(CASE WHEN payment_method = '' THEN 1 ELSE 0 END) AS total_missing_branch,
    SUM(CASE WHEN payment_method <> '' AND branch <> '' THEN 1 ELSE 0 END) AS total_duplicates
FROM missing_v_d;

# Remove Duplicate

SELECT *,
ROW_NUMBER() OVER(PARTITION BY transaction_id) as row_num
FROM sales_staging;

WITH duplicateCTE AS (
SELECT *,
ROW_NUMBER() OVER(PARTITION BY transaction_id) as row_num
FROM sales_staging
)
SELECT * FROM duplicateCTE where row_num > 1;

CREATE TABLE sales_staging2
like sales_staging;

ALTER TABLE sales_staging2
ADD COLUMN row_num int;

INSERT INTO sales_staging2
SELECT *,
ROW_NUMBER() OVER(PARTITION BY transaction_id) as row_num
FROM sales_staging;

SELECT * FROM sales_staging2 where row_num > 1;

DELETE FROM sales_staging2 where row_num > 1;

SELECT * FROM sales_staging2;


# Standardizing Data

SELECT DISTINCT(transaction_date) FROM sales_staging2 ORDER BY transaction_date;

SELECT DISTINCT(branch) FROM sales_staging2 ORDER BY branch;

SELECT branch, TRIM(branch) FROM sales_staging2;

UPDATE sales_staging2 SET branch = TRIM(branch);

SELECT DISTINCT(product) FROM sales_staging2 ORDER BY product;

SELECT DISTINCT(category) FROM sales_staging2 ORDER BY category;

SELECT DISTINCT product, category FROM sales_staging2 ORDER BY product;

SELECT product, MAX(category) AS category FROM sales_staging2 WHERE category <> '' AND category IS NOT NULL GROUP BY product;

UPDATE sales_staging2 t1
JOIN (
	SELECT product, category FROM sales_staging2 where category <> '' or category IS NULL
) t2 ON t1.product = t2.product SET t1.category = t2.category WHERE t1.category = '' OR t1.category IS NULL;

SELECT DISTINCT(payment_method) FROM sales_staging2 ORDER BY payment_method;

SELECT payment_method, TRIM(payment_method) FROM sales_staging2;

UPDATE sales_staging2 SET payment_method = TRIM(payment_method);

SELECT * FROM sales_staging2 WHERE payment_method LIKE 'G%';

UPDATE sales_staging2 SET payment_method = 'GCash' WHERE payment_method LIKE 'G%';


# Validate Quantity, Unit Price, Total Amount

SELECT * FROM sales_staging2 where quantity < 1;

WITH correct_qty AS (
SELECT *,
ROUND(total_amount / (unit_price * (1 - discount))) AS correct_quantity
FROM sales_staging2
)
SELECT * FROM correct_qty where quantity < 1;

SELECT * FROM sales_staging3;

SELECT * FROM sales_staging3 WHERE quantity < 1;

UPDATE sales_staging3 SET quantity = correct_quantity where quantity < 1;

SELECT DISTINCT product, unit_price FROM sales_staging3 ORDER BY product;

SELECT product, MAX(unit_price) AS max_unit_price FROM sales_staging3 GROUP BY product ORDER BY product ASC;

SELECT * FROM sales_staging3 where unit_price <= 0 ;

UPDATE sales_staging3 t1
JOIN (
SELECT product, MAX(unit_price)AS max_unit_price FROM sales_staging3 WHERE unit_price > 0 GROUP BY product
) t2 ON t1.product = t2.product SET t1.unit_price = t2.max_unit_price where t1.unit_price <= 0 ;


SELECT *,
ROUND(quantity * (unit_price * (1 - discount)), 2) AS correct_total_amount
FROM sales_staging3;

WITH remarks AS (
SELECT *,
	CASE
		WHEN total_amount = correct_total_amount THEN 'MATCHED'
		ELSE 'NOT MATCHED'
	END AS match_status
FROM sales_staging4
)
SELECT * FROM remarks where match_status = 'NOT MATCHED';

SELECT * FROM CLEANED WHERE match_status = 'NOT MATCHED';

UPDATE cleaned SET total_amount = correct_total_amount, match_status = 'MATCHED' where match_status = 'NOT MATCHED';

SELECT * FROM cleaned;


# What is total revenue by month?

SELECT MONTHNAME(transaction_date) AS month_name, SUM(total_amount) AS total_revenue_per_month
FROM cleaned GROUP BY MONTH(transaction_date), MONTHNAME(transaction_date) ORDER BY MONTH(transaction_date) asc;

# Which branch generates the most revenue?

SELECT branch, SUM(total_amount) AS total_revenue FROM cleaned GROUP by branch;

# What are the top 10 products by units sold and revenue?

SELECT product, count(quantity) AS unit_sold, sum(total_amount) AS Revenue FROM cleaned GROUP BY product ORDER BY unit_sold DESC limit 10;

# Which category performs best?

SELECT category, count(category) AS total_order FROM cleaned GROUP BY category ORDER BY total_order desc;

# What is average transaction value?

WITH avg_transaction_value AS (
SELECT payment_method, COUNT(*) AS total_transactions
FROM cleaned
GROUP BY payment_method
)
SELECT  AVG(total_transactions) AS avg_transaction_value FROM avg_transaction_value
ORDER BY avg_transaction_value DESC;

WITH avg_transaction_value AS (
SELECT payment_method, transaction_date ,COUNT(*) AS total_transactions
FROM cleaned
GROUP BY payment_method, transaction_date
)
SELECT payment_method, AVG(total_transactions) AS avg_transaction_value FROM avg_transaction_value
GROUP BY payment_method ORDER BY avg_transaction_value DESC;

# Which payment method is most frequently used?

SELECT payment_method, count(payment_method) as total_transactions FROM cleaned GROUP BY payment_method ORDER BY total_transactions DESC;

# How does revenue vary by customer type?

SELECT customer_type, sum(total_amount), AVG() as Revenue FROM cleaned GROUP BY customer_type ORDER BY Revenue DESC;

WITH revenue_vary AS (
SELECT customer_type, SUM(quantity) AS total_qty, count(customer_type)AS total_transaction,
SUM(total_amount) AS total_revenue FROM cleaned GROUP BY customer_type
)
SELECT customer_type,SUM(total_transaction), SUM(total_qty), SUM(total_revenue) FROM revenue_vary GROUP BY customer_type ORDER BY total_revenue DESC;

# Which branches have the highest transaction counts?

SELECT branch, COUNT(branch) total_transaction_count FROM cleaned GROUP BY branch ORDER BY total_transaction_count DESC;

select distinct branch, payment_method from cleaned;

update cleaned set branch = "Other" where payment_method = '';

select * from cleaned where payment_method = '';

ALTER TABLE cleaned
DROP COLUMN match_status;

select * from clean