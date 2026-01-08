# E-commerce Customer Strategy & Lifetime Value Analysis
**Tools Used:** SQL (MySQL/PostgreSQL), Data Modeling, RFM Analysis

## 1. Project Overview
I developed a comprehensive SQL-driven analytics engine to help an e-commerce business understand customer health. Instead of looking at raw sales, I built a system that segments customers by loyalty and predicts future value.

## 2. Key Business Questions Answered
* **Customer Segmentation:** Who are our 'Champions' vs. those 'At Risk' of churning? (RFM Model)
* **Retention:** Are new signups staying with us? (Cohort Analysis)
* **Predictive LTV:** What is the expected annual value of a customer based on their current purchase frequency?

## 3. Technical Highlights
* **Complex CTEs:** Layered logic to transform raw order data into behavioral metrics.
* **Data Cleaning:** Implemented `COALESCE` and `CASE` logic to handle null values in revenue reporting.
* **Feature Engineering:** Calculated "Average Days Between Orders" and "Orders Per Month" to forecast growth.

## 4. Key Insight Example
By identifying the 'Potential Loyalist' segment (High recency, medium frequency), the business can target them with specific 'Buy 1 Get 1' offers to convert them into 'Champions.'
