create database Electricity;
use electricity;
show tables;

describe billing_info;
select * from billing_info;

SET SQL_SAFE_UPDATES = 0;

/*Project Task 1: Update 
the payment_status in the billing_info table based on the cost_usd value. Use CASE...END logic.
•	Hint:
Cost_usd > 200 set “high”
Cost_usd >  100 and 200  set “medium”
Else “Low”
Use the UPDATE statement along with CASE to set values conditionally.*/

update billing_info
set
payment_status = case 
when cost_usd >200 then 'high'
when cost_usd between  100 and 200 then 'medium'
else 'pending'
end;
select * from billing_info;

/*Project Task 2: (Using Group by) For each household, show the monthly electricity usage, 
rank of usage within each year, and classify usage level.
•	Hint: Use SUM, MONTHNAME, Date_format, RANK() OVER, and CASE.
•	Hint2: update Usage level criteria using total Kwh
Sum(total kwh > 500 then “High”
Else “Low”
Here is the query for analyzing and ranking monthly electricity usage
This query helps in identifying peak consumption months for each household.*/

SELECT household_id,year,month,SUM(total_kwh) AS monthly_usage,
RANK() OVER (PARTITION BY household_id, year 
ORDER BY SUM(total_kwh) DESC) AS usage_rank,
CASE
    WHEN SUM(total_kwh) > 500 THEN 'High'
    ELSE 'Low'
    END AS usage_level
FROM billing_info
GROUP BY household_id, year, month
ORDER BY household_id, year, month;

/*Project Task 3:
Create a monthly usage pivot table showing usage for January, February, and March.
•	Hint: Use conditional aggregation using Pivot concept with CASE WHEN.*/
select * from billing_info;

select household_id,
sum(
case
when month='jan' then total_kwh else 0
end) as january,
sum(
case
when month='feb' then total_kwh else 0
end) as february,
sum(
case
when month='mar' then total_kwh else 0
end) as March
from billing_info
group by household_id;

/*Project Task 4: Show average monthly usage per household with city name.
•	Hint: Use a subquery grouped by household and month.*/
SELECT
    hi.household_id,
    hi.city,
    monthly_avg.avg_monthly_kwh
FROM
    household_info hi
JOIN
    (SELECT
        household_id,
        AVG(total_kwh) AS avg_monthly_kwh
    FROM
        billing_info
    GROUP BY
        household_id) AS monthly_avg
ON
    hi.household_id = monthly_avg.household_id
ORDER BY
    hi.city, avg_monthly_kwh DESC;

/*Project Task 5: Retrieve AC usage and outdoor temperature for households where AC usage is high.
•	Hint: Use a subquery to filter AC usage above 100.(High)*/

SELECT
    au.household_id,
    au.kwh_usage_AC,
    ed.avg_outdoor_temp
FROM
    appliance_usage au
JOIN
    environmental_data ed ON au.household_id = ed.household_id
WHERE
    au.household_id IN (SELECT household_id FROM appliance_usage WHERE kwh_usage_AC > 100);

/*Project Task 6: Create a procedure to return billing info for a given region.
•	Hint: Use IN parameter in a CREATE PROCEDURE.*/

DELIMITER //
CREATE PROCEDURE GetBillingInfoByRegion(IN region_name VARCHAR(50))
BEGIN
    SELECT
        bi.*
    FROM
        billing_info bi
    JOIN
        household_info hi ON bi.household_id = hi.household_id
    WHERE
        hi.region = region_name;
END //
DELIMITER ;

-- To call the procedure:
CALL GetBillingInfoByRegion('East');

/*Project Task 7: Create a procedure to calculate total usage for a household and return it.
•	Hint: Use INOUT parameter and assign with SELECT INTO.*/

DELIMITER //
CREATE PROCEDURE GetTotalUsage(INOUT household_id_param VARCHAR(10))
BEGIN
    SELECT
        SUM(total_kwh) INTO household_id_param
    FROM
        billing_info
    WHERE
        household_id = household_id_param;
END //
DELIMITER ;

-- To call the procedure:
SET @household = 'H0002';
CALL GetTotalUsage(@household);
SELECT @household;

/*Project Task 8: Automatically calculate cost_usd before inserting into billing_info.
•	Hint: Use BEFORE INSERT trigger and assign NEW.cost_usd.*/
DELIMITER //
CREATE TRIGGER before_billing_insert
BEFORE INSERT ON billing_info
FOR EACH ROW
BEGIN
    SET NEW.cost_usd = NEW.total_kwh * NEW.rate_per_kwh;
END //
DELIMITER ;


/*Project Task 9 : After a new billing entry, insert calculated metrics into calculated_metrics.
•	Hint1: Use AFTER INSERT trigger and NEW keyword.
•	Hint 2:  Calculations(metrics)
House hold_id = new.house_hold_id
KWG per_occupant = total_kwh /Num_occupants
Usage category = total_kwh > 600 set “High” else “Moderate”*/

DELIMITER //
CREATE TRIGGER after_billing_insert
AFTER INSERT ON billing_info
FOR EACH ROW
BEGIN
    DECLARE occupants INT;
    DECLARE sqft INT;

    SELECT num_occupants, floor_area_sqft INTO occupants, sqft
    FROM household_info
    WHERE household_id = NEW.household_id;

    INSERT INTO calculated_metrics (household_id, kwh_per_occupant, kwh_per_sqft, usage_category)
    VALUES (
        NEW.household_id,
        NEW.total_kwh / occupants,
        NEW.total_kwh / sqft,
        CASE
            WHEN NEW.total_kwh > 600 THEN 'High'
            ELSE 'Moderate'
        END
    );
END //
DELIMITER ;
