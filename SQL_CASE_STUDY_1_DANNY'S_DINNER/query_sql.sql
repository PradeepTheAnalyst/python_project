------------------------------------------------------ OUESTIONS -------------------------------------------------------------------------
 -- 1.What is the total amount each customer spent at the restaurant?
 
select 
	d.customer_id as customers,
    sum(m.price) as total_spent 
from 
	dines d join menu m on 
    d.product_id = m.product_id
group by 
	customer_id;

-- 2.How many days has each customer visited the restaurant?

select
    customer_id,
    count(distinct order_date) as visited_days
from 
	dines
group by 
	customer_id;
    
-- 3.What was the first item from the menu purchased by each customer?
with first_item as
(select
	dines.customer_id,
    menu.product_name,
    row_number() over (partition by customer_id order by dines.order_date,dines.product_id) as item_order
from dines 
join menu 
on dines.product_id = menu.product_id
)
select 
	* 
from first_item
where item_order=1;

-- 4.What is the most purchased item on the menu and how many times was it purchased by all customers?
select 
	d.product_id,
    m.product_name,
    count(d.product_id) as count 
from dines d join menu m
on d.product_id = m.product_id
group by d.product_id,m.product_name 
order by d.product_id desc 
limit 1;

-- 5.Which item was the most popular for each customer?
with most_popular as
(select
	max_cnt.customer_id,
    max_cnt.product_id,
    max_cnt.product_name,
    max_cnt.cnt,
    rank() over (partition by max_cnt.customer_id order by max_cnt.cnt desc) as rnk 
from
	(select
		dines.customer_id,
		dines.product_id,
		menu.product_name,
		count(dines.product_id) as cnt
	from dines 
	join menu 
	on dines.product_id = menu.product_id
	group by dines.product_id,dines.customer_id,menu.product_name
	) max_cnt
)
select
	most_popular.customer_id,
    most_popular.product_name,
    most_popular.product_id,
    most_popular.cnt as item_count
from 
	most_popular
where 
	rnk = 1;

-- ---------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS membership_validation;
CREATE temporary TABLE membership_validation AS
SELECT
   dines.customer_id,
   dines.order_date,
   menu.product_name,
   menu.price,
   members.join_date,
   CASE WHEN dines.order_date >= members.join_date
     THEN 'X'
     ELSE ''
     END AS membership
FROM dines
 INNER JOIN menu
   ON dines.product_id = menu.product_id
 LEFT JOIN members
   ON dines.customer_id = members.customer_id
-- using the WHERE clause on the join_date column to exclude customers who haven't joined the membership program (don't have a join date = not joining the program)
  WHERE join_date IS NOT NULL
  ORDER BY 
    customer_id,
    order_date;

select * from membership_validation;
-- -------------------------------------------------------------------------------------------------------------------------------------

-- 6.Which item was purchased first by the customer after they became a member?
with first_item as 
(select
	*,
    row_number() over (partition by customer_id order by order_date) as rn
from
	membership_validation
where membership = 'X')
select customer_id,product_name,order_date,rn as purchased_item from first_item where rn=1;

-- 7. Which item was purchased just before the customer became a member?
with before_item as
(select
    *,
    rank() over (partition by customer_id order by order_date desc) as rnk
from membership_validation
where membership = '')
select
	customer_id,
    product_name,
    order_date,
    rnk as purchased_item
from before_item where rnk = 1;

-- 8.What is the total items and amount spent for each member before they became a member?
select 
	customer_id,
    sum(price) as total_amnt,
    count(*) as total_cnt 
from 
	membership_validation 
where 
	membership='' 
group by 
	customer_id;
    
-- 9.If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
with points as 
(select 
    customer_id,
    product_name,
    case
		when product_name = 'sushi' then sum(price * 20)
        else sum(price * 10)
	end as price_list
from 
	membership_validation
group by
	product_name,
    customer_id
)
select 
	points.customer_id,
    sum(price_list) as total_points
from 
	points 
group by 
	points.customer_id;
    
-- 10.In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
-- how many points do customer A and B have at the end of January?

CREATE temporary TABLE membership_first_week_validation AS 
with cte_valid as
(select 
	customer_id,
    order_date,
    product_name,
    price,
    count(*) as order_count,
    case
		when order_date between join_date and (join_date+6) then 'X'
        else ''
	end as within_1st_week
from membership_validation
group by customer_id,order_date,product_name,price,join_date
order by customer_id,order_date
)
select
	*
from cte_valid
where order_date < '2021-02-01';

select * from membership_first_week_validation;

-- condition 1
drop table if exists membership_condition1;
create temporary table membership_condition1 as
with cte_2 as
(select
	customer_id,
    case
		when within_1st_week = 'X' then (price * order_count * 20)
        else ''
	end as tot_points
from membership_first_week_validation
)
select
	customer_id,
    sum(tot_points) as total_points
from cte_2
group by customer_id;

select * from membership_condition1;

-- condition 2
drop table if exists membership_condition_2;
create temporary table membership_condition_2 as
with cte_3 as
(select
	customer_id,
    case
		when within_1st_week = '' and product_name = 'sushi' then (price * order_count * 20)
        when within_1st_week = ''then (price * order_count * 10)
        when within_1st_week = 'X' then ''
	end as tot_points
from membership_first_week_validation
)
select 
	customer_id,
    sum(tot_points) as total_points
from cte_3
group by customer_id;

select * from membership_condition_2;

-- final output
with cte_union as
(select * from membership_condition1
union 
select * from membership_condition_2
)
select
	customer_id,
    sum(total_points)
from cte_union
group by customer_id
order by customer_id;