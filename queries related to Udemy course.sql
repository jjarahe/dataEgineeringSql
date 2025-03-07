select o.order_date
	,oi.order_item_product_id
	, round(SUM(oi.order_item_subtotal)::numeric, 2) as order_revenue
from orders AS o
inner join order_items AS oi
on o.order_id = oi.order_item_order_id
and o.order_status in ('COMPLETE','CLOSED')
group by o.order_date,oi.order_item_product_id
order by 1, 3 desc;

CREATE OR REPLACE VIEW v_order_details
AS
select o.*
	,oi.order_item_product_id
	,oi.order_item_subtotal
	,oi.order_item_id
from orders AS o
inner join order_items AS oi
on o.order_id = oi.order_item_order_id;

select * from v_order_details;


--CTE is Common Table Expression
--Views are consisten in the DB, but CTE is just in memory it does not persist in the DB.
WITH order_details_cte AS
(select o.*
	,oi.order_item_product_id
	,oi.order_item_subtotal
	,oi.order_item_id
from orders AS o
inner join order_items AS oi
on o.order_id = oi.order_item_order_id)
select * from order_details_cte
where order_id = 2;


select *
FROM products p 
LEFT JOIN v_order_details od
ON p.product_id = od.order_item_product_id
WHERE od.order_item_product_id is NULL

--Statement, get all products not sold on JAN 2014
--Wrong statement
select *
FROM products p 
LEFT JOIN v_order_details od
ON p.product_id = od.order_item_product_id
WHERE to_char(od.order_date::timestamp, 'yyyy-MM') = '2014-01'
AND od.order_item_product_id is NULL


--Correct statement
select *
FROM products p 
LEFT JOIN v_order_details od
ON p.product_id = od.order_item_product_id
AND to_char(od.order_date::timestamp, 'yyyy-MM') = '2014-01'
WHERE od.order_item_product_id is NULL


--CTAS (Create table AS)

CREATE TABLE order_count_by_status
AS
SELECT order_status, count(1) AS order_count
FROM orders
GROUP BY 1;

select * from order_count_by_status;

--CTAS with just structure of the table without data
CREATE TABLE order_stg
AS
SELECT * FROM orders where 1=2;

select * from order_stg;



CREATE TABLE daily_revenue
AS
SELECT o.order_date,
    round(sum(oi.order_item_subtotal)::numeric, 2) AS order_revenue
FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_item_order_id
WHERE o.order_status IN ('COMPLETE', 'CLOSED')
GROUP BY 1;

SELECT * FROM daily_revenue
ORDER BY order_date;

CREATE TABLE daily_product_revenue
AS
SELECT o.order_date,
    oi.order_item_product_id,
    round(sum(oi.order_item_subtotal)::numeric, 2) AS order_revenue
FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_item_order_id
WHERE o.order_status IN ('COMPLETE', 'CLOSED')
GROUP BY 1,2;

SELECT * FROM daily_product_revenue
ORDER BY 1, 3 DESC;



--This query shows error becuase you cannot compute in this way.
SELECT dr.*
	,SUM(order_revenue)
FROM daily_revenue dr
ORDER BY 1;

--To fix this should be defines as below
SELECT to_char(dr.order_date::timestamp,'yyyy-MM') AS order_month
	,dr.order_date
	,dr.order_revenue 
	,SUM(order_revenue) OVER(PARTITION BY to_char(dr.order_date::timestamp,'yyyy-MM')) AS monthly_order_revenue
FROM daily_revenue dr
ORDER BY 20;


select sum(order_revenue) from daily_revenue; --15,012,982.48

select dr.*,
		sum(order_revenue) OVER (PARTITION BY 1) AS total_order_revenue
from daily_revenue AS dr
ORDER BY 1;


--Overview of Rankingg in SQL

select count(*) from daily_product_revenue;

select * from daily_product_revenue
order by order_date, order_revenue DESC;

--rank() OVER ()
--dense_rank() OVER ()

--GLOBAL RANKING rank() OVER (ORDER BY col1 DESC)
--Ranking based on key or partition  rank() OVER (PARTITION BY col2 ORDER BY DESC)


--GLOBAL RANKING
select *
from daily_product_revenue
where order_date = '2014-01-01 00:00:00.0'
order by order_revenue DESC;

select order_date,
		order_item_product_id,
		order_revenue,
		rank() OVER (ORDER BY order_revenue DESC) as rnk,
		dense_rank() OVER (ORDER BY order_revenue DESC) as drnk
from daily_product_revenue
where order_date = '2014-01-01 00:00:00.0'
order by order_revenue DESC;


--FOR a giving month 2014 JAN order revenue for each day


select order_date,
		order_item_product_id,
		order_revenue,
		rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as rnk,
		dense_rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as drnk
from daily_product_revenue
where to_char(order_date::date, 'yyyy-MM') = '2014-01'
order by order_date, order_revenue DESC;

--it will trough an error
select order_date,
		order_item_product_id,
		order_revenue,
		rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as rnk,
		dense_rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as drnk
from daily_product_revenue
where to_char(order_date::date, 'yyyy-MM') = '2014-01'
and rnk = 5
order by order_date, order_revenue DESC;


--Filtering based on GLOBAL Ranks using Nested Queries and CTEs in SQL
select * from (
				select order_date,
						order_item_product_id,
						order_revenue,
						rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as rnk,
						dense_rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as drnk
				from daily_product_revenue
				where order_date::date = '2014-01-01'
) AS q
where rnk <= 5
order by order_revenue DESC;


--CTE table
WITH daily_product_revenue_ranks AS (
select order_date,
						order_item_product_id,
						order_revenue,
						rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as rnk,
						dense_rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as drnk
				from daily_product_revenue
				where order_date::date = '2014-01-01'
) select * from daily_product_revenue_ranks
where drnk <=5
order by order_revenue DESC;
				



--61.Filtering based on Ranks per Partitioning using Nested Queries and CTEs in SQL
select * from (
				select order_date,
						order_item_product_id,
						order_revenue,
						rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as rnk,
						dense_rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as drnk
				from daily_product_revenue
				where to_char(order_date::date, 'yyyy-MM') = '2014-01'
) AS q
where drnk <= 5
order by order_date, order_revenue DESC;


WITH daily_product_revenue_ranks AS (
				select order_date,
						order_item_product_id,
						order_revenue,
						rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as rnk,
						dense_rank() OVER (PARTITION BY order_date ORDER BY order_revenue DESC) as drnk
				from daily_product_revenue
				where to_char(order_date::date, 'yyyy-MM') = '2014-01'
) select * from daily_product_revenue_ranks
where  drnk <= 5
order by order_date, order_revenue DESC;




--62.Create Students table with Data for ranking using SQL

CREATE TABLE student_scores (
    student_id INT PRIMARY KEY,
    student_score INT
);

INSERT INTO student_scores VALUES
(1, 980),
(2, 960),
(3, 960),
(4, 990),
(5, 920),
(6, 960),
(7, 980),
(8, 960),
(9, 940),
(10, 940);

SELECT * FROM student_scores
ORDER BY student_score DESC;

SELECT student_id,
    student_score,
    rank() OVER (ORDER BY student_score DESC) AS student_rank,
    dense_rank() OVER (ORDER BY student_score DESC) AS student_drank
FROM student_scores
ORDER BY student_score DESC;
