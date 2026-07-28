# IFRS 9 Credit Risk Staging & Expected Loss Monitoring

**A SQL-based credit risk monitoring system for detecting portfolio deterioration, tracking stage migration, estimating expected loss, and identifying where credit risk is building before it becomes realized default.**

---

## Business Problem

Default is a late signal.

By the time a loan becomes seriously delinquent, the lender may already have spent months carrying increasing credit exposure without taking action.

The more useful questions are:

* How much of the portfolio is still performing?
* Which loans are beginning to deteriorate?
* How quickly are exposures migrating into higher-risk stages?
* Where is expected loss increasing?
* Which borrower segments or lending vintages are driving the change?

This project builds a SQL monitoring layer around those questions.

Using monthly loan-performance data, it classifies exposures into **Stage 1, Stage 2, and Stage 3**, tracks movement between those stages, estimates expected loss using PD and LGD, and segments deterioration by credit quality and origination vintage.

The goal is to move credit monitoring from:

> **"How many loans have already defaulted?"**

to:

> **"Where is risk building, how quickly is it deteriorating, and what could it cost us?"**

---

## Business Value

For a credit risk team, the value of staging is not simply knowing how many loans belong in each bucket.

The value is seeing **movement before the final loss occurs**.

A portfolio can maintain the same Stage 3 balance while its underlying risk profile becomes materially worse if large numbers of Stage 1 loans are migrating into Stage 2.

That makes migration a leading indicator.

```text
Performing
   |
   v
Stage 1
   |
   | Credit deterioration
   v
Stage 2
   |
   | Serious deterioration
   v
Stage 3
   |
   v
Default / Recovery
```

This project creates the analytical layer needed to monitor that progression over time.

---

## What the System Monitors

The analysis covers eight connected areas of portfolio risk:

### 1. Credit Risk Staging

Each monthly loan observation is classified into a simplified IFRS 9-style stage using delinquency:

| Stage       | Delinquency  | Interpretation        |
| ----------- | ------------ | --------------------- |
| **Stage 1** | < 30 DPD     | Performing            |
| **Stage 2** | 30 to 89 DPD | Increased credit risk |
| **Stage 3** | 90+ DPD      | Credit impaired       |

These delinquency thresholds are used as a simplified analytical staging framework because the dataset does not contain a full SICR model.

---

### 2. Portfolio Stage Distribution

Tracks how the number of loans in each stage changes over time.

This answers:

> **Is the portfolio becoming healthier or deteriorating?**

A rising Stage 2 population can provide an earlier warning than waiting for Stage 3 or default volumes to increase.

---

### 3. Exposure by Stage

Loan counts alone can hide financial concentration.

Ten small Stage 3 loans may represent less risk than one very large exposure.

The analysis therefore tracks loan exposure by stage alongside loan counts.

This helps distinguish:

```text
How many loans are deteriorating?
```

from:

```text
How much money is exposed to that deterioration?
```

---

### 4. Stage Migration

`LAG()` compares each loan's current stage with its own previous stage, producing a migration view across the portfolio.

Examples include:

```text
Stage 1 -> Stage 1
Stage 1 -> Stage 2
Stage 1 -> Stage 3

Stage 2 -> Stage 1
Stage 2 -> Stage 2
Stage 2 -> Stage 3

Stage 3 -> Stage 1
Stage 3 -> Stage 2
Stage 3 -> Stage 3
```

This separates stable exposures, deteriorating exposures, and curing exposures instead of treating every loan in a stage as equally risky.

---

### 5. Early Warning Migration Rate

The analysis isolates **Stage 1 -> Stage 2 migration** as a dedicated early-warning KPI.

Why?

Because Stage 3 tells the business about serious deterioration that has already occurred.

Stage 1 -> Stage 2 tells the business where deterioration is beginning.

That makes it a more useful metric for proactive monitoring.

---

### 6. Expected Loss

Expected loss is estimated using the available risk parameters:

```text
Expected Loss = Exposure x PD x LGD
```

where:

* **Exposure** represents the loan amount
* **PD** represents Probability of Default
* **LGD** represents Loss Given Default

The calculation is aggregated by reporting month and credit stage.

This moves the analysis beyond:

> **How many risky loans do we have?**

toward:

> **What financial loss is associated with the risk currently sitting in the portfolio?**

---

### 7. Credit Score Segmentation

Loans are grouped into credit-quality bands:

* Prime
* Mid
* Subprime

This helps determine whether deterioration is concentrated among borrowers already expected to be risky or spreading into stronger parts of the book.

That distinction matters for underwriting.

If deterioration is concentrated in Subprime borrowers, the response may involve tightening underwriting or repricing that segment.

If deterioration is appearing across Prime borrowers as well, the problem may be broader than borrower selection.

---

### 8. Origination Vintage Analysis

Loans originated during different periods can perform very differently.

Changes in underwriting standards, pricing, borrower quality, growth strategy, or external conditions can create weaker lending vintages.

The vintage analysis groups loans by origination month and compares their subsequent performance.

This answers:

> **Did a particular period of lending produce a riskier portfolio than others?**

---

## Data

The analysis uses three tables from a larger synthetic Retail and SME credit portfolio.

### `customers.csv`

**1,001 customer records**

Contains:

* Customer ID
* Country
* Customer Type
* Annual Income
* Credit Score
* Account Creation Date

---

### `loans.csv`

**1,001 loan records**

Contains:

* Loan ID
* Customer ID
* Loan Amount
* Interest Rate
* Tenure
* Origination Date

---

### `loan_panel.csv`

**10,001 monthly loan observations**

Contains:

* Loan ID
* Reporting Month
* Days Past Due
* Probability of Default
* Loss Given Default
* Previous DPD

This is the core analytical table because it captures how individual loans change through time.

---

## Analytical Architecture

The project uses a shared staging view as the foundation for every downstream KPI.

```text
CUSTOMERS
    |
    |
LOANS
    |
    |
LOAN PANEL
    |
    v
v_ifrs9_base
    |
    +--------------------------+
    |            |             |
    v            v             v
STAGING      EXPOSURE      MIGRATION
    |                          |
    |                          v
    |                    EARLY WARNING
    |
    +-------------+-------------+
                  |
                  v
           EXPECTED LOSS
                  |
          ----------------
          |              |
          v              v
     CREDIT BAND      VINTAGE
```

Centralizing staging in `v_ifrs9_base` ensures every downstream analysis uses the same risk classification logic.

If the staging methodology changes, it can be changed once rather than rewritten across every KPI.

---

## Methodology

The analytical workflow follows a layered process.

**Step 1: Build the staging layer**

Join monthly performance records with loan and borrower attributes and derive the credit stage.

**Step 2: Measure portfolio composition**

Track loan counts and exposure across Stage 1, Stage 2, and Stage 3.

**Step 3: Build the migration engine**

Use `LAG()` partitioned by loan to compare each observation against the previous reporting period.

**Step 4: Isolate early deterioration**

Calculate the Stage 1 -> Stage 2 migration rate separately from the full migration matrix.

**Step 5: Estimate expected loss**

Combine exposure, PD, and LGD to quantify the financial risk associated with each stage.

**Step 6: Segment the portfolio**

Break performance down by credit score band and origination vintage to identify where deterioration is concentrated.

The result is a monitoring system that connects:

```text
Portfolio Composition
        |
        v
Credit Deterioration
        |
        v
Migration
        |
        v
Expected Loss
        |
        v
Risk Concentration
        |
        v
Management Action
```

---

## SQL Review & Validation

The script was reviewed against the structure of the underlying data rather than only checked for syntax.

That review identified two material implementation issues and one reproducibility issue.

### Vintage Grain Error

The original vintage query grouped directly by `origination_date`.

The problem was that origination dates contain full timestamps.

For example:

```text
2020-11-30 15:47:58.812486410
```

Grouping by the complete timestamp effectively creates one vintage for almost every loan.

Instead of:

```text
JAN 2023 -> 85 loans
FEB 2023 -> 91 loans
MAR 2023 -> 76 loans
```

the analysis could behave more like:

```text
2023-01-04 09:31:12 -> 1 loan
2023-01-04 14:22:47 -> 1 loan
2023-01-05 08:16:03 -> 1 loan
```

The query runs, but the business analysis is wrong.

The corrected version truncates origination timestamps to calendar month before grouping, producing genuine lending vintages.

---

### SQL Dialect Inconsistency

The original script mixed database-selection syntax with identifier conventions from different SQL dialects.

That creates unnecessary execution dependencies and makes the project harder to reproduce.

The database naming and execution logic were standardized so the analytical SQL is easier to move between environments.

---

### Re-Runnable View Creation

The staging view originally assumed it did not already exist.

A safe view reset was added before creation so the analytical pipeline can be rerun without manual cleanup.

That matters if the analysis is later incorporated into a scheduled monthly monitoring process.

---

## Validation Against Delinquency Transitions

The project dataset also contains `roll_rates.csv`, a pre-aggregated delinquency transition table.

Its DPD buckets align with the staging framework:

```text
0 DPD       -> Stage 1

30 DPD      -> Stage 2
60 DPD      -> Stage 2

90 DPD      -> Stage 3
```

This provided an independent reference for checking whether the stage migration logic produced sensible results.

Across **9,000 recorded transitions**, the reconstructed migration pattern was:

| Previous Stage |      Stayed / Improved |                Stage 2 |               Stage 3 |
| -------------- | ---------------------: | ---------------------: | --------------------: |
| **Stage 1**    | 69.7% remained Stage 1 |              **26.2%** |                  4.1% |
| **Stage 2**    | 67.0% cured to Stage 1 | 27.4% remained Stage 2 |                  5.7% |
| **Stage 3**    | 65.7% moved to Stage 1 | 29.9% moved to Stage 2 | 4.4% remained Stage 3 |

---

## Key Finding

### 26.2% of Stage 1 observations migrated into Stage 2

That is the most important monitoring signal surfaced by the project.

Approximately **1 in 4 Stage 1 observations** in the reference transition data moved into Stage 2 at the next transition.

The implication is not that 26.2% represents a universal acceptable or unacceptable threshold.

It provides a **portfolio baseline**.

Future reporting periods can be compared against that baseline.

For example:

```text
Baseline:        26.2%

Month 1:         25.4%
Month 2:         27.1%
Month 3:         31.8%
Month 4:         36.5%
```

That progression would tell a very different story from:

```text
Month 1:         25.8%
Month 2:         24.9%
Month 3:         23.6%
Month 4:         21.7%
```

The first suggests accelerating deterioration.

The second suggests improving portfolio quality.

That is the value of migration monitoring: **direction matters as much as the current stage balance.**

---

## Important Data Limitation

The synthetic portfolio shows unusually strong cure behavior.

Most notably, **65.7% of Stage 3 observations moved directly back to Stage 1** in the reconstructed transition data.

That would be unusually aggressive recovery behavior for many real lending portfolios, where severe delinquency is generally more persistent and cures may occur gradually.

This means the transition percentages should be treated as **demonstration data for the analytical framework**, not as benchmarks for real-world credit performance.

The SQL logic remains useful.

The synthetic transition behavior should not be interpreted as representative of a live bank portfolio.

---

## Recommendation

### 1. Make Stage 1 -> Stage 2 migration a standing risk KPI

Do not wait for Stage 3 balances or defaults to rise before investigating deterioration.

Track the Stage 1 -> Stage 2 rate monthly and compare it against:

* Historical portfolio baseline
* Credit score segment
* Customer type
* Origination vintage
* Exposure size

The objective is to identify deterioration while intervention is still possible.

---

### 2. Monitor exposure alongside migration

A rising migration rate becomes significantly more important when the loans moving into Stage 2 carry large exposures.

Risk monitoring should therefore answer both:

> **How many loans deteriorated?**

and:

> **How much exposure deteriorated?**

---

### 3. Connect migration to expected loss

Stage migration should not sit as an isolated operational metric.

Combine it with PD, LGD, and exposure to understand whether deterioration is translating into materially higher expected loss.

That gives finance and credit risk a common financial view of the problem.

---

### 4. Investigate deterioration by segment

Portfolio-wide averages can hide the source of the problem.

If Stage 1 -> Stage 2 migration increases, the next question should be:

> **Which borrowers are driving it?**

Credit score and vintage segmentation provide the first layer of that diagnosis.

---

## Business Impact

This project turns credit monitoring from a backward-looking default report into an early-warning framework.

Instead of waiting for losses to become visible through Stage 3 exposure or realized defaults, risk teams can monitor deterioration while loans are moving through earlier stages.

That supports earlier decisions around:

* Collections prioritization
* Credit policy
* Underwriting standards
* Portfolio monitoring
* Expected loss provisioning
* Risk concentration
* Lending strategy

For finance, the expected loss layer translates credit deterioration into financial exposure.

For credit risk, migration identifies where the deterioration is coming from.

For underwriting, credit-score and vintage segmentation show whether the issue is concentrated in particular borrower groups or periods of lending.

For management, the result is a clearer answer to the question that matters:

> **Is portfolio risk getting better or worse, where is the change coming from, and what could it cost us?**

---

## Tools & SQL Techniques

### SQL

The project is implemented in SQL using a shared analytical view and layered queries.

### `LAG()`

Used to compare each loan's current stage against its previous stage and build the migration engine.

### `CASE`

Used for:

* Stage classification
* Credit score segmentation
* Business-readable risk categories

### CTEs

Used to separate transition logic from aggregation and keep migration calculations auditable.

### Date Truncation

Used to convert individual origination timestamps into meaningful monthly lending vintages.

### Conditional Aggregation

Used to calculate stage-level counts, migration rates, exposure, and expected loss.

### Defensive SQL

Includes safeguards for repeatable execution and consistent analytical grain.

---

## What Was Built

The final SQL project delivers:

* IFRS 9-style Stage 1 / 2 / 3 Classification
* Monthly Stage Distribution
* Exposure by Credit Stage
* Stage Migration Matrix
* Stage 1 -> Stage 2 Early Warning Rate
* Expected Loss by Stage
* Credit Score Risk Segmentation
* Origination Vintage Analysis
* Reusable Staging View
* Validation Against Independent Transition Data

The review also identified and corrected:

* Incorrect vintage aggregation
* SQL dialect inconsistency
* Non-repeatable view creation

---

## Results

The result is a reusable credit-risk monitoring layer that connects **portfolio condition, deterioration, exposure, expected loss, and risk concentration** in one analytical workflow.

The headline finding from the reference migration data is a **26.2% Stage 1 -> Stage 2 migration rate**, establishing an early-warning baseline that future periods can be measured against.

More importantly, the project demonstrates the analytical progression required for proactive credit monitoring:

```text
STAGE THE PORTFOLIO
        |
        v
TRACK DETERIORATION
        |
        v
MEASURE EXPOSURE
        |
        v
ESTIMATE EXPECTED LOSS
        |
        v
IDENTIFY RISK CONCENTRATION
        |
        v
PRIORITIZE ACTION
```

The output is not simply a report showing which loans are already in trouble.

It is a framework for identifying **where credit risk is developing before the final loss appears.**

---

## Project Files

* `ifrs9_staging_and_risk_classification.sql` - staging, migration, expected loss, segmentation, and vintage analysis
* Supporting portfolio datasets are maintained in the shared project data directory

---

## Note

This project uses synthetic data and a simplified delinquency-based staging framework for portfolio analytics.

It demonstrates the analytical concepts behind credit deterioration monitoring, stage migration, and expected loss estimation. It should not be interpreted as a complete production IFRS 9 impairment model, which would require additional institution-specific SICR criteria, ECL methodology, forward-looking scenarios, model governance, and accounting controls.
