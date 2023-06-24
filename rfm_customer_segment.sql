/* 
    DROPPING CURRENT TABLES 
*/
drop table if exists segmentation;
drop table if exists rfm_customer_analysis;
drop table if exists rfm_country_analysis;

/* 
    CREATING SEGMENTATION TABLE BASED ON THE SCORES OF RECENCY, FREQUENCY AND MONETARY
    FOR DEMONSTRATION, EACH SCORE WILL RANG FROM VALUE 1 TO 3 REPRESENTING FROM WORSE TO BEST 
*/

create table segmentation (
    segment nvarchar(20),
    segment_desc nvarchar(100),
    recency_f int, recency_t int,
    frequency_f int, frequency_t int,
    monetary_f int, monetary_t int
    );

insert into segmentation values ('Champion','Purchased most recently, often and spend most',3,3,2,3,2,3),
                                ('Loyal Customer','Not always spend the most, frequently but always come back',2,2,3,3,2,3),
                                ('Potential Loyalist','Not purchase often but biggest spenders',1,2,1,2,3,3),
                                ('New Customers','Bought more recently, but not often',3,3,1,1,1,3),
                                ('Promising','Made recent purchases, but not much',2,2,1,2,1,2),
                                ('At Risk', 'Spent big money, purchased often but long time ago',1,1,1,3,2,2),
                                ('Lost Customers','Lowest recency, frequency & monetary scores',1,1,1,1,1,1);

/*
    CREATING RFM SCORE TO SEGMENT DATA BY CUSTOMERS 

        Frequency: how many times has the customer purchased in the store
        Recency: how many days ago was their last purchase
        Monetary: how much has this customer spent in total 

*/

/* Valuation date can be changed up your business */
declare @valuation_date as DATE
set @valuation_date = '1998-05-10';

/* Getting customer with lastest purchase date compared to valuation date, how many orders made and totla sales */
with rfm_customer (custid, recency, frequency, monetary) 
as                (
                       select c.customerid as custid,
                              DATEDIFF(day,cast(MAX(o1.orderDate) as Date), @valuation_date) as recency,
                              COUNT(distinct o1.orderid) as frequency,
                              SUM(o2.unitprice * o2.quantity) as moneytary
                       from customers c
                       join orders o1 on c.customerid = o1.customerid
                       join [order details] o2 on o1.orderid = o2.orderid 
                       group by c.customerid
                   ),

/* Creating rfm score table using ntile method (or it can be quartile, quintile or percentile) */
rfm_scores (custid, recency, frequency, monetary, r_score, f_score, m_score) 
as (  
    select custid, recency, frequency, monetary,
            r_score  = NTILE(3) over (order by recency DESC),
            f_score  = NTILE(3) over (order by frequency ASC),
            m_score  = NTILE(3) over (order by monetary ASC)
from rfm_customer
),

/* Linking rfm score with the segmentation */
rfm_final 
as (
    select *, (r_score * 100 + f_score * 10 + m_score) as rfm_score from rfm_scores)


/* Main query */
select t1.*, ISNULL(t2.segment,'Others') as 'segment'
into rfm_customer_analysis
from rfm_final as t1 left join segmentation as t2 
on  (t1.r_score between t2.recency_f and t2.recency_t) AND
    (t1.f_score between t2.frequency_f and t2.frequency_t) AND
    (t1.m_score between t2.monetary_f and t2.monetary_t);

/*
    CREATING RFM SCORE TO SEGMENT DATA BY COUNTRY
*/

with rfm_country (country, recency, frequency, monetary) 
as                (
                       select c.country,
                              DATEDIFF(day,cast(MAX(o1.orderdate) as Date), @valuation_date) as recency,
                              COUNT(distinct o1.orderid) as frequency,
                              SUM(o2.unitprice * o2.quantity) as monetary
                       from customers c
                       join orders o1 on c.customerid = o1.customerid
                       join [order details] o2 on o1.orderid = o2.orderid 
                       group by c.country
                   ),

/* Creating rfm score table using ntile method (or it can be quartile, quintile or percentile) */
rfm_scores (country, recency, frequency, monetary, r_score, f_score, m_score) 
as (  
    select country, recency, frequency, monetary,
            r_score  = NTILE(3) over (order by recency DESC),
            f_score  = NTILE(3) over (order by frequency ASC),
            m_score  = NTILE(3) over (order by monetary ASC)
from rfm_country
),

/* Linking rfm score with the segment */
rfm_final 
as (
    select *, (r_score * 100 + f_score * 10 + m_score)  as rfm_score from rfm_scores)

/* Main query */
select t1.*, ISNULL(t2.segment,'Others') as 'segment'
into rfm_country_analysis
from rfm_final as t1 left join segmentation as t2
on (t1.r_score between t2.recency_f and t2.recency_t) AND
   (t1.f_score between t2.frequency_f and t2.frequency_t) AND
   (t1.m_score between t2.monetary_f and t2.monetary_t);

select * from rfm_customer_analysis;
select * from rfm_country_analysis;

