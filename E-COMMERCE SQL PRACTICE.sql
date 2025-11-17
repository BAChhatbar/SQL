use ecommerce;

---#--- BASICS ---
---#1. List all customers from India.

SELECT *
FROM customers
WHERE country = 'india';

/*2. Show all products with price greater than 100.*/

SELECT *
FROM products
WHERE price > 100;

/*3. Get all orders placed after '2023-02-01'.*/

SELECT *
FROM orders
WHERE order_date > "2023-02-01";

/*4. Display all distinct payment methods used.*/

SELECT DISTINCT method
FROM payments;

/*5. Find the total number of customers.*/

SELECT count(1)
FROM customers;

/*--- AGGREGATIONS ---*/
/*6. Count total number of orders per customer.*/

SELECT customer_id
	,count(order_id) AS OrderCount
FROM orders
GROUP BY customer_id;

---# 7. Find the average product price per category.

SELECT category
	,avg(price) AveragePrice
FROM products
GROUP BY category;

---# 8. Calculate total sales amount per country. 

SELECT c.country
	,sum(total_amount) TotalSalesAmount
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.country;

---# 9. Find the maximum order amount placed.

SELECT max(total_amount) MaximumAmount
FROM orders;

---# 10. Get the number of successful vs failed payments. 

SELECT count(CASE 
			WHEN STATUS = 'success'
				THEN 1
			END) SuccessPayment
	,count(CASE 
			WHEN STATUS = 'failed'
				THEN 1
			END) FailedPayment
FROM payments;

---#--- JOINS ---
---#11. List all orders with customer names.

SELECT c.name
	,group_concat(order_id separator ', ') OrderList
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.name;

---# 12. Show product details for each order item. 

SELECT oi.order_item_id
	,oi.order_id
	,oi.quantity OrderQuantity
	,p.name
	,p.category
	,p.price
	,p.stock ProductStock
FROM orderitems oi
INNER JOIN products p ON oi.product_id = p.product_id;

---# 13. Get all payments with order and customer info.

SELECT c.name
	,c.email
	,c.country
	,c.signup_date
    ,o.order_id
	,p.method
	,p.STATUS
	,p.payment_date
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN payments p ON o.order_id = p.order_id;

---# 14. Find customers who bought Laptop. 

SELECT c.name
	,p.name
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN orderitems oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
WHERE p.name = "Laptop";

---# 15. List customers and the products they purchased. 

SELECT c.name CustomerName
	,group_concat(p.name separator ', ') ProductName
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN orderitems oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
GROUP BY c.name;

---# --- SUBQUERIES ---
---# 16. Find customers who have never placed an order. 

SELECT *
FROM customers c
WHERE NOT EXISTS (
		SELECT 1
		FROM orders
		WHERE customer_id = c.customer_id
		);

---# 17. List products more expensive than the average product price. 

SELECT *
FROM products
WHERE price > (
		SELECT avg(price)
		FROM products
		);

---# 18. Get customers who spent more than the average spending of all customers.

SELECT DISTINCT c.name
	,c.email
	,c.country
	,c.signup_date
	,sum(o.total_amount) OVER (
		PARTITION BY c.name ORDER BY c.name
		) TotalSpending
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.total_amount > (
		SELECT avg(total_amount)
		FROM orders
		);

---# 19. Find the order(s) with the highest total amount. 

SELECT *
FROM orders
WHERE total_amount = (
		SELECT max(total_amount)
		FROM orders
		);

---# 20. List products that were never ordered. 

SELECT *
FROM products
WHERE product_id NOT IN (
		SELECT product_id
		FROM orderitems
		);

---# --- SET OPERATIONS  ---
---# 21. Get all unique IDs of people who appear as customer_id in Orders or as payment order_id in Payments.

SELECT customer_id uniqueIDs
FROM orders

UNION

SELECT order_id
FROM payments;

---# 22. Find customers who placed orders but don’t have successful payments. 

SELECT DISTINCT c.*
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE NOT EXISTS (
		SELECT 1
		FROM payments p
		WHERE p.order_id = o.order_id
			AND p.STATUS = 'success'
		);

---# --- WINDOW FUNCTIONS  ---
---# 23. Rank customers by their total spending (highest first). 

SELECT rank() OVER (
		ORDER BY TotalSpending DESC
		) RankByTotalSpending
	,name
	,email
	,country
	,signup_date
	,TotalSpending
FROM (
	SELECT DISTINCT c.name
		,c.email
		,c.country
		,c.signup_date
		,sum(o.total_amount) OVER (
			PARTITION BY c.name ORDER BY c.name
			) TotalSpending
	FROM customers c
	INNER JOIN orders o ON c.customer_id = o.customer_id
	) a;

---# 24. Show running total of sales amount by date. 

SELECT DISTINCT date_format(order_date, '%M %Y') AS OrderDate
	,sum(total_amount) OVER (PARTITION BY date_format(order_date, '%M %Y')) AS TotalSalesAmount
FROM orders;

---# 25. Find the top 2 most expensive products in each category. 

SELECT Category
	,group_concat(Name separator ', ') Top2MostExpensiveProduct
FROM (
	SELECT name
		,category
		,price
		,row_number() OVER (
			PARTITION BY category ORDER BY price DESC
			) rw
	FROM products
	) a
WHERE rw IN (
		1
		,2
		)
GROUP BY Category;

SELECT category
	,name
	,price
FROM (
	SELECT category
		,name
		,price
		,row_number() OVER (
			PARTITION BY category ORDER BY price DESC
			) rw
	FROM products
	) a
WHERE rw = 1
ORDER BY price DESC limit 2;

---# 26. Show dense rank of orders by amount. 

SELECT dense_rank() OVER (
		ORDER BY total_amount DESC
		) Rnk
	,order_id
	,total_amount
FROM orders;

---# --- ADVANCED  ---
---# 27. Create a view that shows customer_id, name, and total amount spent. 

CREATE VIEW Summary
AS
SELECT c.customer_id
	,Name
	,total_amount
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id;

SELECT *
FROM Summary;

---# 28. Write a stored procedure to insert a new order with order items.

DELIMITER $$
CREATE PROCEDURE Insert_OrderDetails (
	IN p_customer_id INT
	,IN p_product_id INT
	,IN p_quantity INT
	,IN p_unit_price DECIMAL(10, 2)
	)

BEGIN
	DECLARE v_order_id INT;
	DECLARE v_total DECIMAL(10, 2);

	INSERT INTO orders (
		customer_id
		,order_date
		,total_amount
		)
	VALUES (
		p_customer_id
		,NOW()
		,0.00
		);

	SET v_order_id = LAST_INSERT_ID();

	INSERT INTO orderitems (
		order_id
		,product_id
		,quantity
		,price
		)
	VALUES (
		v_order_id
		,p_product_id
		,p_quantity
		,p_unit_price
		);

	SET v_total = p_quantity * p_unit_price;

	UPDATE orders
	SET total_amount = v_total
	WHERE order_id = v_order_id;

	SELECT v_order_id AS NewOrderID
		,v_total AS TotalAmount;
        
END$$

DELIMITER ;

CALL Insert_OrderDetails(2, 1, 1, 800.00);

---# 29. Use a CTE to find customers who bought more than 3 different product categories.

WITH cte
AS (
	SELECT c.Name
		,oi.product_id
	FROM customers c
	INNER JOIN orders o ON c.customer_id = o.customer_id
	INNER JOIN orderitems oi ON o.order_id = oi.order_id
	)
SELECT c.Name
	,group_concat(p.Category separator ', ') CategoryList
FROM cte c
INNER JOIN products p ON c.product_id = p.product_id
GROUP BY c.name
HAVING count(DISTINCT p.category) > 3;

---# 30. Simulate a transaction: deduct stock when an order is placed. 

DELIMITER $$

CREATE PROCEDURE Deduct_Stock (IN p_order_id INT)

BEGIN
	UPDATE products p
	JOIN (
		SELECT product_id
			,SUM(quantity) AS total_qty
		FROM orderitems
		WHERE order_id = p_order_id
		GROUP BY product_id
		) t ON p.product_id = t.product_id

	SET p.stock = p.stock - t.total_qty;

	SELECT CONCAT (
			'Stock deducted for order_id = '
			,p_order_id
			) AS Message;
END$$

DELIMITER ;

CALL Deduct_Stock(110);


