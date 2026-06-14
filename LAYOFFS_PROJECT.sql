-- ============================================
-- GLOBAL AI & TECH LAYOFFS ANALYSIS (2020-2026)
-- Dataset: Global AI & Tech Layoffs | Kaggle
-- Analyst: Tanya Ojha
-- Thesis: Did AI-driven layoffs create shareholder value?
-- ============================================


-- ============================================
-- SECTION 1: TABLE SETUP
-- ============================================

CREATE TABLE layoffs_raw (
    event_id TEXT,
    company TEXT,
    industry TEXT,
    hq_country TEXT,
    hq_city TEXT,
    continent TEXT,
    founded_year INTEGER,
    company_size_est INTEGER,
    company_status TEXT,
    date_announced DATE,
    year INTEGER,
    month INTEGER,
    quarter TEXT,
    number_laid_off INTEGER,
    percentage_of_workforce NUMERIC(5,2),
    departments_affected TEXT,
    primary_reason TEXT,
    impact_scope TEXT,
    severance_info TEXT,
    source TEXT,
    stock_price_change_1wk_pct NUMERIC(6,2),
    is_ai_related_layoff BOOLEAN
);

-- Create working table — all cleaning happens here, raw data stays untouched
CREATE TABLE layoffs_cleaned AS
SELECT *
FROM layoffs_raw;


-- ============================================
-- SECTION 2: DATA EXPLORATION
-- ============================================

-- Row count
SELECT COUNT(*) FROM layoffs_raw;
-- Result: 1850 rows

-- Inspect first 10 rows
SELECT *
FROM layoffs_cleaned
LIMIT 10;

-- Confirm schema and data types
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'layoffs_raw';

-- Check for duplicate events
SELECT COUNT(DISTINCT event_id)
FROM layoffs_cleaned;
-- Result: 1850 — no duplicates, event_id is unique

-- Check NULLs in stock price column
SELECT COUNT(*) AS rows_with_stock_data
FROM layoffs_cleaned
WHERE stock_price_change_1wk_pct IS NOT NULL;
-- Result: 1389 rows have stock price data (remainder are private companies)

-- Confirm NULLs belong exclusively to private companies
SELECT COUNT(*) AS private_null_count
FROM layoffs_cleaned
WHERE stock_price_change_1wk_pct IS NULL
AND company_status = 'Private';
-- Result: All NULLs confirmed as private companies — expected, not a data error

-- Inspect primary_reason distribution
SELECT primary_reason, COUNT(*) AS frequency
FROM layoffs_cleaned
GROUP BY primary_reason
ORDER BY frequency DESC;
-- Result: 17 distinct reasons, all clean labels, no spelling variants

-- Inspect hq_country
SELECT DISTINCT hq_country
FROM layoffs_cleaned;
-- Result: 18 distinct countries, appears standardized

-- Inspect company_status
SELECT DISTINCT company_status
FROM layoffs_cleaned;
-- Result: Public and Private only — clean

-- Inspect departments_affected
SELECT DISTINCT departments_affected
FROM layoffs_cleaned;
-- Result: Multi-valued field (semicolon-separated e.g. "HR / People; Legal; Product")
-- Every combination is unique, making DISTINCT unhelpful for analysis
-- Decision: deferred — not needed for core thesis questions

-- Inspect industry
SELECT industry, COUNT(*) AS frequency
FROM layoffs_cleaned
GROUP BY industry
ORDER BY frequency DESC;
-- Result: 49 distinct values including compound industries (e.g. "Ride-Hailing / Fintech")
-- Note: Compound industries assigned to primary sector — see cleaning section

-- Check for NULLs in is_ai_related_layoff
SELECT COUNT(*)
FROM layoffs_cleaned
WHERE is_ai_related_layoff IS NULL;
-- Result: 0 — every row is classified

-- Outlier check: percentage_of_workforce
SELECT
    MIN(percentage_of_workforce) AS min_pct,
    MAX(percentage_of_workforce) AS max_pct,
    ROUND(AVG(percentage_of_workforce), 2) AS avg_pct,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY percentage_of_workforce) AS p25,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY percentage_of_workforce) AS p75
FROM layoffs_cleaned
WHERE percentage_of_workforce IS NOT NULL;
-- Result: MIN 0.30, MAX 25.50, AVG 6.05, P25 2.8, P75 8.2
-- No suspicious outliers — MAX of 25.5% is aggressive but realistic

-- Outlier check: number_laid_off
SELECT
    MIN(number_laid_off) AS min_n,
    MAX(number_laid_off) AS max_n,
    ROUND(AVG(number_laid_off), 2) AS avg_n,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY number_laid_off) AS p25,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY number_laid_off) AS p75
FROM layoffs_cleaned
WHERE number_laid_off IS NOT NULL;
-- Result: MIN 10, MAX 205254, AVG 4452, P25 197, P75 3862
-- MAX of 205,254 is real (large-scale events e.g. Amazon, Meta)
-- Average pulled above P75 due to skew from large events
-- Decision: retain all rows, note skew in findings

/*
DATA EXPLORATION SUMMARY
1. event_id is unique — no duplicates
2. Stock price NULLs belong exclusively to private companies — expected
3. hq_country appears standardized — no cleaning needed
4. company_status is clean — Public and Private only
5. departments_affected is multi-valued — deferred, not needed for core analysis
6. industry contains 49 values including compound categories — bucketed in cleaning
7. primary_reason has 17 clean distinct labels — bucketed in cleaning
8. is_ai_related_layoff has no NULLs — clean
9. number_laid_off is right-skewed due to large-scale events — retained, flagged
*/


-- ============================================
-- SECTION 3: DATA CLEANING & ENRICHMENT
-- ============================================

-- --------------------------------------------
-- Step 1: Add reason_category column
-- Groups 17 primary reasons into 5 analytical buckets
-- Methodology: business-driven grouping aligned to thesis
-- --------------------------------------------

ALTER TABLE layoffs_cleaned
ADD COLUMN reason_category TEXT;

UPDATE layoffs_cleaned
SET reason_category = CASE
    WHEN primary_reason IN (
        'AI Automation Replacing Roles',
        'Shift to AI-First Strategy'
    ) THEN 'AI-Driven'

    WHEN primary_reason IN (
        'Failed Expansion',
        'Market Downturn',
        'Investor Pressure',
        'Economic Uncertainty',
        'Declining Revenue',
        'Post-Pandemic Overhiring Correction',
        'Profitability Push'
    ) THEN 'Financial Pressure'

    WHEN primary_reason IN (
        'Duplicate Roles After Merger',
        'Merger / Acquisition'
    ) THEN 'Structural / M&A'

    WHEN primary_reason IN (
        'Regulatory Pressure',
        'Product Shutdown'
    ) THEN 'Market / External Forces'

    ELSE 'Strategic Realignment'
END;

-- Verify distribution
SELECT reason_category, COUNT(*) AS count
FROM layoffs_cleaned
GROUP BY reason_category
ORDER BY count DESC;
/*
Financial Pressure     651
Strategic Realignment  428
AI-Driven              380
Market/External Forces 199
Structural / M&A       192
*/

-- --------------------------------------------
-- Step 2: Add industry_category column
-- Groups 49 industries into 7 broader sectors
-- Methodology: compound industries assigned to primary sector
-- (first-listed industry = primary business)
-- Limitation: ~15% of rows are compound-industry companies
-- with potential minor misclassification
-- --------------------------------------------

ALTER TABLE layoffs_cleaned
ADD COLUMN industry_category TEXT;

UPDATE layoffs_cleaned
SET industry_category = CASE
    WHEN industry IN (
        'Fintech', 'Cryptocurrency', 'Investment / Tech',
        'Ride-Hailing / Fintech', 'E-Signature'
    ) THEN 'Fintech & Crypto'

    WHEN industry IN (
        'E-Commerce', 'Food Delivery', 'Delivery',
        'Grocery Delivery', 'Ride-Hailing', 'Ride-Hailing / Delivery',
        'Super App', 'E-Commerce / Cloud', 'E-Commerce / Gaming'
    ) THEN 'E-Commerce & Delivery'

    WHEN industry IN (
        'Social Media', 'Social Platform', 'Streaming',
        'Music Streaming', 'Gaming / Social Media', 'Video Communications',
        'Design Software', 'Creative Software', 'Travel Tech',
        'Social Media / AI'
    ) THEN 'Entertainment & Media'

    WHEN industry IN (
        'Semiconductors', 'Consumer Electronics', 'Industrial Tech',
        'Networking', 'Cloud Communications', 'Telecommunications',
        'Semiconductors / AI', 'Electric Vehicles / AI'
    ) THEN 'Hardware & Infrastructure'

    WHEN industry IN (
        'Health Tech', 'Biotech / AI'
    ) THEN 'Health Tech'

    WHEN industry IN (
        'Real Estate Tech'
    ) THEN 'Real Estate Tech'

    ELSE 'AI & Data'
END;

-- Verify no rows fell through
SELECT COUNT(*)
FROM layoffs_cleaned
WHERE industry_category = 'Uncategorized';
-- Result: 0 — all industries mapped

-- Verify distribution
SELECT industry_category, COUNT(*) AS count
FROM layoffs_cleaned
GROUP BY industry_category
ORDER BY count DESC;
/*
AI & Data                459
Entertainment & Media    396
E-Commerce & Delivery    390
Hardware & Infrastructure 272
Fintech & Crypto         255
Health Tech               49
Real Estate Tech          29
*/


-- ============================================
-- SECTION 4: ANALYSIS
-- ============================================

-- --------------------------------------------
-- Q1: Do AI-related layoffs receive better
--     stock market reactions than non-AI layoffs?
-- Skills: CASE WHEN, GROUP BY, AVG, ROUND, WHERE
-- --------------------------------------------

SELECT
    CASE WHEN is_ai_related_layoff = true
         THEN 'AI Layoff'
         ELSE 'Non-AI Layoff'
    END AS layoff_type,
    ROUND(AVG(stock_price_change_1wk_pct), 2) AS avg_stock_chg_pct
FROM layoffs_cleaned
WHERE stock_price_change_1wk_pct IS NOT NULL
GROUP BY is_ai_related_layoff
ORDER BY avg_stock_chg_pct DESC;

/*
FINDING:
Non-AI Layoff   -1.87%
AI Layoff       -2.48%

Contrary to expectations, markets penalize AI-driven layoffs more harshly
than non-AI layoffs in the short term. Both categories produce negative
average reactions, suggesting markets do not universally reward workforce
reductions regardless of stated reason.

Hypothesis: Early AI skepticism (2022-2023) may be driving the negative
reaction as investors were not yet convinced AI efficiency gains would
materialize. Worth testing: does the AI layoff reaction improve year over year?
*/


-- --------------------------------------------
-- Q2: Which layoff reason categories generate
--     the strongest stock market reactions?
-- Skills: GROUP BY, AVG, ROUND, WHERE, ORDER BY
-- --------------------------------------------

SELECT
    reason_category,
    ROUND(AVG(stock_price_change_1wk_pct), 2) AS avg_stock_chg_pct
FROM layoffs_cleaned
WHERE stock_price_change_1wk_pct IS NOT NULL
GROUP BY reason_category
ORDER BY avg_stock_chg_pct DESC;

/*
FINDING:
Market / External Forces   -1.64%
Strategic Realignment      -1.75%
Structural / M&A           -1.84%
Financial Pressure         -2.03%
AI-Driven                  -2.48%

All reason categories produce negative average stock reactions.
AI-Driven layoffs receive the harshest market penalty across all categories.
Market/External Forces layoffs receive the mildest reaction — possibly because
investors view externally-forced cuts as necessary and beyond management control.
*/


/*Q3: Within each industry, which layoff events 
were the most severe?*/

WITH ranked_layoffs AS (
    SELECT
		company,
		industry_category,
		percentage_of_workforce,
		DENSE_RANK () OVER (
			PARTITION BY industry_category
			ORDER BY percentage_of_workforce DESC
		) AS severity_rank
	FROM layoffs_cleaned
	WHERE percentage_of_workforce IS NOT NULL
)
SELECT *
FROM ranked_layoffs
WHERE severity_rank = 1;

/*
FINDING:
Most severe single layoff event per industry by workforce percentage:
AI & Data              → HubSpot      22.80%
E-Commerce & Delivery  → Rappi        21.40%
Entertainment & Media  → ByteDance    25.50%
Hardware & Infra       → Cisco        21.30%
Fintech & Crypto       → SoftBank     20.70%
Health Tech            → BioNTech     20.60%
Real Estate Tech       → Zillow       18.00%

ByteDance leads all industries cutting 25.5% of its workforce in a single event.
All top events fall in the 18-26% range suggesting a natural ceiling
on how aggressively even the most severe layoffs cut workforce.
*/

/*Q4: Do companies receive diminishing stock
market rewards after repeated layoffs?*/

WITH stock_reaction AS(
	SELECT
		company,
		date_announced,
		stock_price_change_1wk_pct,
		LAG (stock_price_change_1wk_pct,1) OVER(
			PARTITION BY company
			ORDER BY date_announced
		) AS prev_stock_reaction,
		stock_price_change_1wk_pct - LAG (stock_price_change_1wk_pct,1)OVER(
			PARTITION BY company
			ORDER BY date_announced
		) AS reaction_change,
		ROW_NUMBER () OVER(
			PARTITION BY company
			ORDER BY date_announced
		) AS layoff_sequence
	FROM layoffs_cleaned
	WHERE stock_price_change_1wk_pct IS NOT NULL
)
SELECT
	layoff_sequence,
	AVG(stock_price_change_1wk_pct) AS avg_stock_reaction,
	COUNT(*) AS sample_size
FROM stock_reaction
WHERE layoff_sequence > 1
GROUP BY layoff_sequence
ORDER BY layoff_sequence;

/* FINDING Q4:
Markets do not systematically punish companies for repeat layoffs.
Average stock reaction for sequences 2-14 (n=55 companies each) 
hovers between -1.17% and -2.47% with no clear trend of worsening.
The "diminishing sympathy" hypothesis is not supported by this data.

Note: Sequences 15+ have declining sample sizes and should be 
interpreted with caution. Sequences 30+ (n<10) are statistically 
unreliable.

Limitation: This analysis treats all companies equally regardless 
of industry or layoff reason. A more granular analysis could 
segment by AI vs non-AI layoffs.
*/

/*Q5: Are investors rewarding AI efficiency 
or workforce destruction? */

SELECT
	CASE WHEN is_ai_related_layoff = true
         THEN 'AI Layoff'
         ELSE 'Non-AI Layoff'
    END AS layoff_type, 
	CASE 
    WHEN percentage_of_workforce >= 0 AND percentage_of_workforce < 5 THEN '0-5%'
    WHEN percentage_of_workforce >= 5 AND percentage_of_workforce < 10 THEN '5-10%'
	WHEN percentage_of_workforce >= 10 AND percentage_of_workforce < 20 THEN '10-20%'
	WHEN percentage_of_workforce >= 20 AND percentage_of_workforce < 40 THEN '20-40%'
	WHEN percentage_of_workforce >= 40 THEN '40%+'
	ELSE 'NOT DESIGNATED'
	END AS bucket,
	ROUND(AVG(stock_price_change_1wk_pct),2) AS avg_stock_reaction
FROM layoffs_cleaned
WHERE stock_price_change_1wk_pct IS NOT NULL
GROUP BY 1, 2
ORDER BY bucket

/*FINDING Q5:
Small AI layoffs (0-5%) receive only slightly worse reactions than 
non-AI layoffs (-2.62 vs -1.98). But large AI layoffs (20-40%) 
receive nearly 3x harsher reactions (-5.48 vs -1.97).

Markets appear to tolerate AI-driven efficiency cuts but 
severely punish large-scale AI-driven workforce destruction.
The threshold appears to be around the 20% workforce reduction mark.

Note: No data in 40%+ bucket, dataset max is 25.5% workforce cut.
*/

/*Q6: Which countries show the highest concentration of 
AI-related layoffs as a share of total layoffs, and how
does their average stock reaction compare to the global average?*/

WITH country_stats AS (
	SELECT 
		hq_country,
		SUM(CASE WHEN is_ai_related_layoff = true 
				THEN 1 ELSE 0 END) AS country_ai_share,
		ROUND(SUM(CASE WHEN is_ai_related_layoff = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS ai_share_pct,
		ROUND(AVG(stock_price_change_1wk_pct),2) AS avg_stock_reaction,
		COUNT(*) AS total_layoffs
	FROM layoffs_cleaned
	WHERE stock_price_change_1wk_pct IS NOT NULL
	GROUP BY hq_country
),
global_avg AS (
	SELECT AVG(stock_price_change_1wk_pct) AS global_avg_reaction
	FROM layoffs_cleaned
	WHERE stock_price_change_1wk_pct IS NOT NULL
)
SELECT
	hq_country,
	country_ai_share,
	ai_share_pct,
	avg_stock_reaction,
	total_layoffs,
	ROUND(global_avg_reaction,2),
	ROUND(avg_stock_reaction - global_avg_reaction, 2) AS diff_from_global
FROM country_stats, global_avg
ORDER BY ai_share_pct DESC;

/*FINDING Q6:
Germany leads AI layoff concentration at 32.88% of all layoffs,
followed by Brazil (30.43%) and Netherlands (27.42%).

However, most countries show stock reactions within ±0.5% of the 
global average (-1.99%), suggesting geography is not a significant 
driver of market reaction to layoffs.

Exception: Netherlands shows +1.26% better than global average
despite being the 3rd highest AI layoff concentration country.
This warrants further investigation.

Note: Small sample sizes for several countries (Brazil n=23, 
Australia n=21, Argentina n=23) limit statistical reliability.
*/

/*Q7: Within each industry, which layoff events
ranked in the top 10% by workforce percentage cut
and were those extreme events more likely to be AI-related?*/

WITH extreme_events AS (
SELECT 
	company, industry_category, percentage_of_workforce, is_ai_related_layoff,
	ROUND(PERCENT_RANK() OVER (
        PARTITION BY industry_category
		ORDER BY percentage_of_workforce DESC
	)::numeric, 2) AS top_ten
FROM layoffs_cleaned
WHERE percentage_of_workforce IS NOT NULL
)
SELECT company, top_ten, is_ai_related_layoff, industry_category, percentage_of_workforce
FROM extreme_events
WHERE top_ten >= 0.90;

/*FINDING Q7:
Among the top 10% most severe layoff events by workforce percentage
within each industry, the majority are non-AI related.

This suggests AI is not the primary driver of extreme workforce
reductions. Companies making the deepest cuts are predominantly
motivated by financial pressure, restructuring, or strategic pivots.

Combined with Q1 and Q5 findings: AI layoffs get harsher market
reactions but are not the most severe in scale. Markets may be
punishing the narrative of AI-driven cuts more than the actual
damage done.
*/
