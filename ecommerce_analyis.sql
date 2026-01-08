with rfm_calc as(
select
c.customer_name,
c.customer_id,
count(distinct o.order_id) as order_frequency,
sum(o.total_amount) as total_revenue,
max(o.order_date) as last_order_date,
datediff(curdate(),max(o.order_date)) as recency
 FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status = 'Completed'
group by customer_id,customer_name),

rf_score as (
select
customer_name,order_frequency,recency,last_order_date,
customer_id,total_revenue,
CASE 
  WHEN recency is null then 0
  WHEN recency<=30 then 5 
   WHEN recency<=60 then 4
    WHEN recency<=90 then 3
     WHEN recency<=180 then 2
        else 1 end as recency_scoring,
CASE 
 WHEN order_frequency=0 then 0
 WHEN order_frequency=1 then 1
 WHEN order_frequency <=3 then 2
  WHEN order_frequency <=6 then 3
   WHEN order_frequency <=9 then 4
else 5 end as frequency_scoring,
CASE               
 WHEN total_revenue=0 or total_revenue is null then 0             
 WHEN total_revenue<500 then 1
WHEN total_revenue<1500 then 2                                    
WHEN total_revenue<3000 then 3
WHEN total_revenue<5000 then 4
 else 5 end as monetary_scoring
 from rfm_calc),
 
 customer_segments as (
 select 
 monetary_scoring,
 frequency_scoring,
 recency_scoring,
 customer_name,
 order_frequency,
 recency,
 last_order_date,
customer_id,
total_revenue,
 case  
 when recency_scoring>=4 and frequency_scoring>=4 and monetary_scoring>=4 then 'Champions'
 when frequency_scoring>=4 and monetary_scoring>=3 then 'Loyal' 
 when recency_scoring>=4 and frequency_scoring in(2,3) and monetary_scoring>=2 then 'Potential Loyalist'
 when recency_scoring>=4 and frequency_scoring=1 and monetary_scoring>=1 then 'New Customer'
 when recency_scoring>=3 and frequency_scoring<=2  and monetary_scoring>=2 then 'Promising'
 when recency_scoring in(2,3) and frequency_scoring>=3  and monetary_scoring>=3 then 'At Risk'
 when recency_scoring in(1,2) and frequency_scoring>=2  and monetary_scoring>=2 then 'Hibernating'
 when recency_scoring>=1 and frequency_scoring<=2  and monetary_scoring>=2 then 'Lost'
 when recency_scoring=0 and frequency_scoring=0 and monetary_scoring=0 then 'Never Purchased'
 else 'Other'
 end as segment
 from rf_score)
 select*from customer_segments  
 order by monetary_scoring DESC, frequency_scoring DESC, recency_scoring DESC;
 
 
  
 with customer_cohorts as (
 select
  customer_name,customer_id,signup_date,
  date_format(signup_date,'%Y-%m') as signup_month
  from customers),
  
  customer_order_cohorts as (
  select
  c.customer_name,
  c.customer_id,
  c.signup_month,
  o.order_date,
  o.order_id,
  o.total_amount,
  c.signup_date,
  timestampdiff(MONTH,c.signup_date,o.order_date) as months_since_signup
  from customer_cohorts c
  inner join orders o on c.customer_id=o.customer_id and o.order_status='Completed'
  ),
  
  cohort_metrics as (
  select 
c.signup_month,
  count(distinct c.customer_id) as total_customers,
   count(distinct o.customer_id) as customer_with_orders,
   SUM(case when o.order_count>=2 then 1 ELSE 0 end) as customers_with_2plus,
   SUM(case when o.order_count>=3 then 1 ELSE 0 end) as customers_with_3plus,
   SUM(o.order_count) AS total_orders,
        SUM(o.total_revenue) AS total_revenue
   from customer_cohorts c left join(
   select 
   customer_id,
   count(order_id) as order_count,
   sum(total_amount) as total_revenue
   from customer_order_cohorts
   group by customer_id) as o
   on c.customer_id=o.customer_id
   group by c.signup_month),
   
   cohort_retention_rates as(
   select*,
   round((customers_with_2plus / total_customers) * 100,2) retention_rate_2plus,
round((customers_with_3plus / total_customers) * 100,2) retention_rate_3plus,
  total_revenue / total_customers as avg_revenue_per_customer,
  total_orders / total_customers as avg_orders_per_customer
  from cohort_metrics),

customer_purchase_patterns as (
 select
 customer_id,
 customer_name,
 min(order_date) as first_order_date,
 max(order_date) as last_order_date,
 datediff(max(order_date),min(order_date)) as days_between_first_and_last,
 count(order_id) as total_orders ,
 case 
 when count(order_id)>1 then datediff(max(order_date),min(order_date))
 /(count(order_id)-1)
 else null end as avg_days_between_orders
 from customer_order_cohorts
 group by customer_id,customer_name),

customer_category_preference as (
select 
c.customer_id,
c.customer_name,
sum(case when o.category='Electronics' then o.quantity * o.unit_price end) as Electronics_revenue,
 sum(case when o.category='Accessories' then o.quantity * o.unit_price end) as Accessories_revenue,
 sum(case when o.category='Clothing' then o.quantity * o.unit_price end) as Clothing_revenue,
 sum(case when o.category='Home' then o.quantity * o.unit_price end) as Home_revenue,
 count(distinct o.category) as num_of_category
 from customer_order_cohorts c inner join order_items o on c.order_id=o.order_id
 group by customer_id,customer_name),
 
customer_lifetime_value AS (
    SELECT
        p.*,
        c.Electronics_revenue,
        c.Accessories_revenue,
        c.Clothing_revenue,
        c.Home_revenue,
        c.num_of_category,
        
        
        COALESCE(c.Electronics_revenue, 0) + 
        COALESCE(c.Accessories_revenue, 0) + 
        COALESCE(c.Clothing_revenue, 0) + 
        COALESCE(c.Home_revenue, 0) AS total_revenue,
        
        
        (COALESCE(c.Electronics_revenue, 0) + 
         COALESCE(c.Accessories_revenue, 0) + 
         COALESCE(c.Clothing_revenue, 0) + 
         COALESCE(c.Home_revenue, 0)) / p.total_orders AS avg_order_value,
        
        
        CASE 
            WHEN p.days_between_first_and_last > 0 
            THEN (p.total_orders * 30.0 / p.days_between_first_and_last)
            ELSE NULL 
        END AS orders_per_month,
        
        
        CASE 
            WHEN p.days_between_first_and_last > 0 
            THEN ((COALESCE(c.Electronics_revenue, 0) + 
                   COALESCE(c.Accessories_revenue, 0) + 
                   COALESCE(c.Clothing_revenue, 0) + 
                   COALESCE(c.Home_revenue, 0)) / p.total_orders) * 
                 (p.total_orders * 365.0 / p.days_between_first_and_last)
            ELSE NULL 
        END AS predicted_annual_value
        
    FROM customer_purchase_patterns p
    LEFT JOIN customer_category_preference c ON p.customer_id = c.customer_id
)
select * from customer_lifetime_value;