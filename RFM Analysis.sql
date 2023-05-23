CREATE database RFM;

--Inspecting data

SELECT *
FROM rfm_sales_analysis;

--Checking unique values
SELECT DISTINCT status
FROM rfm_sales_analysis;

SELECT DISTINCT
    year_id
FROM
    rfm_sales_analysis;

SELECT DISTINCT
    productline
FROM
    rfm_sales_analysis;

SELECT DISTINCT
    country
FROM
    rfm_sales_analysis;

SELECT DISTINCT
    dealsize
FROM
    rfm_sales_analysis;

SELECT DISTINCT
    territory
FROM
    rfm_sales_analysis;

--Analysis
--Grouping sum of sales by productline to see which product sold the most
SELECT PRODUCTLINE, SUM(SALES) AS REVENUE
FROM rfm_sales_analysis
GROUP BY PRODUCTLINE
ORDER BY REVENUE DESC;

--Checking to see what year the company made the most sales
SELECT YEAR_ID, SUM(SALES) AS REVENUE
FROM rfm_sales_analysis
GROUP BY YEAR_ID
ORDER BY REVENUE DESC;

--2005 had the least revenue generated, lets find out if they operated the entire year in 2005
SELECT DISTINCT MONTH_ID
FROM rfm_sales_analysis
WHERE YEAR_ID = 2005;
--they operated for just five months in 2005

SELECT DISTINCT MONTH_ID
FROM rfm_sales_analysis
WHERE YEAR_ID = 2004;

SELECT DISTINCT
    MONTH_ID
FROM
    rfm_sales_analysis
WHERE
    YEAR_ID = 2003;

--They operated a full year in 2003, 2004, and operated for 5 months in 2005. That explains why 
the revenue was really low on that year

--Grouping sum of sales by dealsize to see which sold the most
SELECT DEALSIZE, SUM(SALES) AS REVENUE
FROM rfm_sales_analysis
GROUP BY DEALSIZE
ORDER BY REVENUE DESC;
--The medium dealsize generated the most revenue, so the company can focus on that or
improve marketing strategies for other dealsizes.

--To see what month had the most sales in a particular year
SELECT MONTH_ID, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS FREQUENCY
FROM rfm_sales_analysis
WHERE YEAR_ID=2004
GROUP BY MONTH_ID
ORDER BY REVENUE DESC;
--They had the highest revenue and number of orders in November

SELECT MONTH_ID, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS FREQUENCY
FROM rfm_sales_analysis
WHERE YEAR_ID=2003
GROUP BY MONTH_ID
ORDER BY REVENUE DESC;
--Again, Novemebr is the month the highest revenue was generated, we wont check for 2003 since
they only operated for half a year and the analysis would not be a true reflection of the 
yearly sales.

--Since Novemebr is the best month for both years, lets see what product sold the most in
November
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS FREQUENCY
FROM rfm_sales_analysis
WHERE YEAR_ID=2004 AND MONTH_ID=11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY REVENUE DESC;

November
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS FREQUENCY
FROM rfm_sales_analysis
WHERE YEAR_ID=2003 AND MONTH_ID=11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY REVENUE DESC;

--In 2003 and 2004, classic cars were sold the most in Novemeber.

--Lets see who our best customer is using an RFM(Recency-Frequency-Monetary) analysis
It is an indexing technique that uses past purchase behaviour to segment customers and know
whether he/she is a high value customer, or a customer that is slipping away. RFM report segments
customers into three key metrics:Recency(how long ago was their last purchase), frequency(how
often do they purchase), monetary value(how much have they spent).

UPDATE rfm_sales_analysis
SET ORDERDATE = STR_TO_DATE(ORDERDATE, '%m/%d/%Y %H:%i');

CREATE TEMPORARY TABLE r_f_m
WITH rfm AS (
   SELECT 
          CUSTOMERNAME, 
		  SUM(SALES) AS MONETARYVALUE, 
		  AVG(SALES) AS AVGMONETARYVALUE,
		  COUNT(ORDERNUMBER) AS FREQUENCY, 
		  MAX(ORDERDATE) AS LAST_ORDER_DATE,
		  (SELECT MAX(ORDERDATE) FROM rfm_sales_analysis) AS MAX_ORDER_DATE,
          DATEDIFF((SELECT MAX(ORDERDATE) FROM rfm_sales_analysis), MAX(ORDERDATE)) AS RECENCY
  FROM rfm_sales_analysis
  GROUP BY CUSTOMERNAME
),
rfm_calc AS(

	SELECT r.*,
			  NTILE(4) OVER (ORDER BY RECENCY DESC) AS RFM_RECENCY,
			  NTILE(4) OVER (ORDER BY FREQUENCY) AS RFM_FREQUENCY,
			  NTILE(4) OVER (ORDER BY MONETARYVALUE) AS RFM_MONETARY
	FROM rfm AS R
)
SELECT c.*, RFM_RECENCY+ RFM_FREQUENCY+ RFM_MONETARY AS RFM_CELL,
CONCAT(CAST(RFM_RECENCY AS CHAR), CAST(RFM_FREQUENCY AS CHAR), CAST(RFM_MONETARY AS CHAR)) AS RFM_CELL_STRING
FROM rfm_calc AS c;

-- Now we segment the customers using the case statement
SELECT 
    CUSTOMERNAME,
    RFM_RECENCY,
    RFM_FREQUENCY,
    RFM_MONETARY,
    CASE
        WHEN
            rfm_cell_string IN (111 , 112,
                121,
                122,
                123,
                132,
                211,
                212,
                114,
                141)
        THEN
            'lost_customers'
        WHEN rfm_cell_string IN (133 , 134, 143, 244, 334, 343, 344, 144) THEN 'slipping away, cannot lose'
        WHEN rfm_cell_string IN (311 , 411, 331) THEN 'new customers'
        WHEN rfm_cell_string IN (222 , 223, 233, 322) THEN 'potential churners'
        WHEN rfm_cell_string IN (323 , 333, 321, 422, 332, 432) THEN 'active'
        WHEN rfm_cell_string IN (433 , 434, 443, 444) THEN 'loyal'
    END AS RFM_SEGMENT
FROM
    r_f_m

--What products are often sold together
--SELECT * FROM rfm_sales_analysis WHERE ORDERNUMBER= 10411;
-- Some orders have multiple items, so we'll see all the product codes(items) in a particular
-- order. 
    
SELECT DISTINCT
    s1.ORDERNUMBER,
    GROUP_CONCAT(s2.PRODUCTCODE SEPARATOR ',') AS PRODUCTCODES
FROM
    rfm_sales_analysis s1
INNER JOIN
    rfm_sales_analysis s2 ON s1.ORDERNUMBER = s2.ORDERNUMBER
INNER JOIN (
    SELECT
        ORDERNUMBER,
        COUNT(*) AS rn
    FROM
        rfm_sales_analysis
    WHERE
        STATUS = 'Shipped'
    GROUP BY
        ORDERNUMBER
) m ON s1.ORDERNUMBER = m.ORDERNUMBER
WHERE
    m.rn = 3
GROUP BY
    s1.ORDERNUMBER;

-- Further more, we want to see what two products were sold together, so we'll our result
-- to order numbers with just two product codes.

SELECT 
    s1.ORDERNUMBER,
    GROUP_CONCAT(s1.PRODUCTCODE
        SEPARATOR ',') AS PRODUCTCODES
FROM
    rfm_sales_analysis s1
        INNER JOIN
    (SELECT 
        ORDERNUMBER, COUNT(DISTINCT PRODUCTCODE) AS product_count
    FROM
        rfm_sales_analysis
    WHERE
        STATUS = 'Shipped'
    GROUP BY ORDERNUMBER
    HAVING product_count = 2) s2 ON s1.ORDERNUMBER = s2.ORDERNUMBER
GROUP BY s1.ORDERNUMBER
ORDER BY s1.ORDERNUMBER DESC;
  
-- What city has the highest number of sales in a specific country
SELECT 
    CITY, SUM(SALES) AS REVENUE
FROM
    rfm_sales_analysis
WHERE
    COUNTRY = 'UK'
GROUP BY CITY
ORDER BY 2 DESC;

-- What is the best product in the United States?
SELECT 
    COUNTRY, YEAR_ID, PRODUCTLINE, SUM(SALES) AS REVENUE
FROM
    rfm_sales_analysis
WHERE
    COUNTRY = 'USA'
GROUP BY COUNTRY , YEAR_ID , PRODUCTLINE
ORDER BY 4 DESC;
