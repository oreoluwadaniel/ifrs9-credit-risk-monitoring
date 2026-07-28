/*===========================================================
IFRS 9 CREDIT DETERIORATION, STAGING &
EXPECTED LOSS MONITORING

## RISK MANAGEMENT CONTEXT

A loan portfolio can look healthy at headline level while risk
is quietly building underneath.

Loans move from performing accounts into early delinquency,
then into more serious credit deterioration and eventual
default.

For Credit Risk and Finance teams, the key issue is not only
how many loans have already defaulted.

They need to understand:

How much exposure remains performing?

How much has started deteriorating?

How much has reached default?

How quickly are loans moving between risk stages?

And what level of expected credit loss is associated with
the portfolio?

This analysis creates a SQL based monitoring layer for
tracking credit deterioration, stage migration, exposure,
and expected loss across the loan portfolio.

-----------------------------------------------------------
REVIEWER'S NOTE (corrections applied in this version)

Two issues were found and fixed while reviewing the original
script:

1. The vintage query grouped by "origination_date" directly.
   That column stores a full timestamp down to the fraction
   of a second, so almost every loan ends up in its own
   "vintage" and the group-by never actually groups anything.
   Fixed by truncating origination_date to a calendar month
   before grouping.

2. The original "USE" statement pointed at a database name
   with a space in it ("credit risk"), quoted with double
   quotes. That mixes syntax from different SQL engines and
   will fail on several of them. Fixed by using a database
   name without a space, and added a DROP VIEW IF EXISTS line
   so the script can be re-run without manually dropping the
   view first.

Everything else in the logic (staging rule, migration matrix,
expected loss formula, risk band and vintage groupings) was
reviewed and left as-is because it holds up.
===========================================================*/

USE credit_risk;

/*-----------------------------------------------------------
REBUILD THE CREDIT STAGING LAYER

Create a consistent analytical base containing loan
performance, credit risk estimates, exposure, origination
information, and customer characteristics.

Because the source data does not provide a reliable staging
field, stage is derived from days past due using the
simplified delinquency rules applied in this analysis:

Stage 1:
Less than 30 days past due.

Stage 2:
30 to 89 days past due.

Stage 3:
90 or more days past due.

This creates a consistent stage classification that can be
tracked across monthly loan observations.
-----------------------------------------------------------*/

DROP VIEW IF EXISTS v_ifrs9_base;

CREATE VIEW v_ifrs9_base AS
SELECT
    lp.loan_id,
    lp.month_end,
    lp.days_past_due,
    lp.pd_estimate,
    lp.lgd_estimate,
    l.loan_amount,
    l.origination_date,
    c.credit_score,
    c.country,
    CASE
        WHEN lp.days_past_due >= 90 THEN 3
        WHEN lp.days_past_due >= 30 THEN 2
        ELSE 1
    END AS stage
FROM loan_panel lp
JOIN loans l
    ON lp.loan_id = l.loan_id
JOIN customers c
    ON l.customer_id = c.customer_id;

/*-----------------------------------------------------------
WHERE DOES THE PORTFOLIO CURRENTLY SIT?

Track the number of loan observations within each stage over
time.

This provides the first view of portfolio credit quality and
shows whether the concentration of loans is shifting toward
higher risk stages.
-----------------------------------------------------------*/

SELECT
    month_end,
    stage,
    COUNT(*) AS loan_count
FROM v_ifrs9_base
GROUP BY month_end, stage
ORDER BY month_end, stage;

/*-----------------------------------------------------------
HOW MUCH EXPOSURE IS AT RISK?

Loan counts alone do not show the financial significance of
credit deterioration.

Aggregate loan amounts by stage to measure how much portfolio
exposure sits within performing, deteriorating, and defaulted
categories at each reporting date.

A small number of Stage 3 loans can still represent material
risk if those loans carry large exposures.
-----------------------------------------------------------*/

SELECT
    month_end,
    stage,
    SUM(loan_amount) AS exposure
FROM v_ifrs9_base
GROUP BY month_end, stage
ORDER BY month_end;

/*-----------------------------------------------------------
FOLLOW THE MOVEMENT OF RISK

Track each loan from its previous stage to its current stage.

This creates a migration view showing how credit quality
changes between monthly observations.

Examples include:

Stage 1 to Stage 1
Loan remains performing.

Stage 1 to Stage 2
Credit deterioration is emerging.

Stage 2 to Stage 3
Deterioration has progressed into default.

Stage 2 to Stage 1
Loan performance has improved under the staging rules.

Stage migration gives management more information than a
static default rate because it shows the direction in which
portfolio risk is moving.
-----------------------------------------------------------*/

WITH stage_transitions AS (
    SELECT
        loan_id,
        month_end,
        stage,
        LAG(stage) OVER (
            PARTITION BY loan_id
            ORDER BY month_end
        ) AS previous_stage
    FROM v_ifrs9_base
)
SELECT
    previous_stage,
    stage AS current_stage,
    COUNT(*) AS migration_count
FROM stage_transitions
WHERE previous_stage IS NOT NULL
GROUP BY previous_stage, stage
ORDER BY previous_stage;

/*-----------------------------------------------------------
EARLY DETERIORATION SIGNAL

Measure the proportion of Stage 1 observations that migrate
into Stage 2.

This provides a focused early warning indicator of emerging
credit deterioration before loans reach default.

A rising Stage 1 to Stage 2 migration rate may indicate that
portfolio credit quality is weakening and deserves closer
risk investigation.
-----------------------------------------------------------*/

WITH stage_transitions AS (
    SELECT
        loan_id,
        stage,
        LAG(stage) OVER (
            PARTITION BY loan_id
            ORDER BY month_end
        ) AS previous_stage
    FROM v_ifrs9_base
)
SELECT
    COUNT(CASE WHEN previous_stage = 1 AND stage = 2 THEN 1 END) * 1.0
    / COUNT(CASE WHEN previous_stage = 1 THEN 1 END) AS stage1_to_2_rate
FROM stage_transitions;

/*-----------------------------------------------------------
EXPECTED LOSS EXPOSURE

Estimate credit loss using the available risk parameters:

Expected Loss = PD x LGD x Loan Amount

PD estimates the probability that the borrower defaults.

LGD estimates the proportion of exposure expected to be lost
if default occurs.

Loan Amount represents the exposure measure available in the
dataset.

Aggregating the result by month and stage shows where
expected losses are concentrated and how the estimated loss
burden changes as portfolio credit quality deteriorates.

This is a simplified expected loss calculation based on the
fields available in the dataset and should not be interpreted
as a complete IFRS 9 ECL implementation.
-----------------------------------------------------------*/

SELECT
    month_end,
    stage,
    SUM(pd_estimate * lgd_estimate * loan_amount) AS expected_loss
FROM v_ifrs9_base
GROUP BY month_end, stage
ORDER BY month_end;

/*-----------------------------------------------------------
WHO IS CARRYING THE RISK?

Segment the portfolio using borrower credit scores and compare
stage distribution and average probability of default across
risk bands.

Prime:
Credit score of 700 or higher.

Mid:
Credit score between 600 and 699.

Subprime:
Credit score below 600.

This helps identify whether deterioration is concentrated
among already weaker borrowers or spreading into stronger
credit segments.
-----------------------------------------------------------*/

SELECT
    CASE
        WHEN credit_score >= 700 THEN 'Prime'
        WHEN credit_score >= 600 THEN 'Mid'
        ELSE 'Subprime'
    END AS risk_band,
    stage,
    COUNT(*) AS loans,
    AVG(pd_estimate) AS avg_pd
FROM v_ifrs9_base
GROUP BY
    CASE
        WHEN credit_score >= 700 THEN 'Prime'
        WHEN credit_score >= 600 THEN 'Mid'
        ELSE 'Subprime'
    END,
    stage;

/*-----------------------------------------------------------
VINTAGE RISK REVIEW

Compare loans by origination month to understand how different
lending vintages are distributed across risk stages.

FIX: the original version grouped by the raw origination_date
timestamp (which includes hours, minutes, seconds and
fractional seconds), so every loan effectively formed its own
group and no real vintage grouping happened. This version
truncates origination_date down to the first day of its month
before grouping, which is what a "vintage" analysis needs.

Loan count shows the number of observations represented
within each origination month and stage combination.

Average PD provides an additional view of estimated credit
risk within each group.

This can help identify origination periods associated with
weaker subsequent credit performance and support deeper
reviews of historical lending quality.
-----------------------------------------------------------*/

SELECT
    DATE_TRUNC('month', origination_date) AS origination_month,
    stage,
    COUNT(*) AS loans,
    AVG(pd_estimate) AS avg_pd
FROM v_ifrs9_base
GROUP BY DATE_TRUNC('month', origination_date), stage
ORDER BY origination_month;

-- SQL Server equivalent, if DATE_TRUNC is not available:
-- SELECT
--     DATEFROMPARTS(YEAR(origination_date), MONTH(origination_date), 1) AS origination_month,
--     stage,
--     COUNT(*) AS loans,
--     AVG(pd_estimate) AS avg_pd
-- FROM v_ifrs9_base
-- GROUP BY DATEFROMPARTS(YEAR(origination_date), MONTH(origination_date), 1), stage
-- ORDER BY origination_month;

/*===========================================================
THE RISK STORY
--------------

A default report tells management what has already gone
wrong.

This analysis goes further by showing how risk is developing
before and after default.

STAGE DISTRIBUTION

Shows how the portfolio is split across performing,
deteriorating, and defaulted loan observations.

EXPOSURE

Shows the financial amount associated with each stage, not
just the number of loans.

MIGRATION

Shows whether individual loans are improving, remaining
stable, or moving toward higher risk stages.

DETERIORATION

Stage 1 to Stage 2 migration provides an early signal that
credit quality may be weakening.

EXPECTED LOSS

PD, LGD, and available loan exposure translate credit risk
into an estimated financial loss measure.

RISK SEGMENTS

Credit score bands reveal where deterioration and probability
of default are concentrated.

VINTAGES

Origination month analysis helps determine whether weaker
credit performance is concentrated among particular lending
periods.

Together, these measures give Credit Risk and Finance teams a
structured view of three critical questions:

Where is the risk today?

Where is the risk moving?

What financial loss is associated with that risk?

The result is a SQL based credit deterioration and expected
loss monitoring framework that supports portfolio oversight,
early warning analysis, and provisioning discussions.
===========================================================*/
