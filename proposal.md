# Project Proposal: AI Layoff Market Penalty Analysis

**Analyst:** Tanya Ojha | MS Analytics, Northeastern University
**Tools:** PostgreSQL, Power BI
**Dataset:** Global AI & Tech Layoffs 2020-2026 (Kaggle)

---

## The Business Problem

Every time a tech company announces layoffs and credits AI, the press release follows a familiar script: we are becoming more efficient, more focused, more competitive. The implication is that investors should be pleased.

This project tests whether that narrative actually holds up in the market data.

Using 1,850 layoff events from 2020 to 2026, I analyzed whether companies framing cuts as AI-driven received better or worse short-term stock reactions than companies citing other reasons. The answer has direct implications for how companies communicate restructuring decisions and how investors should interpret them.

---

## The Hypothesis

Markets will react more negatively to AI-driven layoffs than to non-AI layoffs. Investors in this period were uncertain whether stated AI efficiency gains would materialize, and may have viewed AI-framed cuts as premature, reputationally risky, or a signal of deeper strategic confusion.

---

## The Dataset

**Source:** Global AI & Tech Layoffs 2020-2026, Kaggle

**Size:** 1,850 layoff events | 18 countries | 49 industries

**Key variables:**
- `stock_price_change_1wk_pct`: 1-week post-announcement stock reaction
- `is_ai_related_layoff`: boolean flag for AI-driven vs non-AI layoffs
- `primary_reason`: 17 distinct layoff reasons
- `percentage_of_workforce`: cut severity as share of total workforce
- `hq_country`, `industry`, `company_status`

Stock data is available for 1,389 of 1,850 rows. The remaining 461 are private companies with no public stock data. All stock reaction analysis is scoped to the 1,389 public company rows.

---

## The Questions

1. Do AI layoffs get better or worse stock reactions than non-AI layoffs?
2. Which layoff reason categories generate the strongest market penalties?
3. Within each industry, which single events were the most severe by workforce percentage?
4. Do companies get punished more harshly for repeated layoffs?
5. Does the size of the cut change the AI penalty?
6. Which countries have the highest AI layoff concentration, and does geography affect market reaction?
7. Are the most extreme workforce cuts more likely to be AI-driven?

---

## The Approach

**PostgreSQL** for all data work: exploration, cleaning, and analysis. Raw data stays untouched in `layoffs_raw`. All cleaning happens in `layoffs_cleaned`. Two enrichment columns added: `reason_category` (bucketing 17 reasons into 5 groups) and `industry_category` (bucketing 49 industries into 7 sectors).

SQL techniques used: GROUP BY aggregations, CASE WHEN bucketing, window functions (DENSE_RANK, LAG, ROW_NUMBER, PERCENT_RANK), and CTEs for multi-step comparisons.

**Power BI** for the dashboard: two-page interactive report on a custom dark navy canvas. Page 1 covers the headline findings. Page 2 drills into what actually drives the market penalty.

---

## Deliverables

- Fully documented SQL file with 7 analytical questions, findings, and methodology notes
- Two-page interactive Power BI dashboard
- This proposal and a full findings report

---

*Tanya Ojha | MS Analytics, Northeastern University | linkedin.com/in/tanyaojha2412*
