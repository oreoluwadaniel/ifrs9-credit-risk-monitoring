# CreditRisk360: Portfolio Risk, IFRS 9 & Expected Loss Analytics

**A SQL credit risk analytics portfolio for monitoring loan deterioration, IFRS 9-style staging, expected credit loss, delinquency migration, collateral exposure, recoveries, and portfolio risk concentration.**

---

## Overview

A lending portfolio can look healthy today while risk is already building underneath it.

Defaults are late-stage outcomes.

Before a borrower reaches that point, the portfolio usually generates earlier signals:

* Payments become overdue
* Probability of default increases
* Loans migrate into higher-risk stages
* Credit quality deteriorates
* Collateral coverage weakens
* Recovery expectations change
* Risk begins concentrating in particular customer or lending segments

The challenge for a bank, lender, or credit risk team is turning those signals into something management can monitor and act on.

**CreditRisk360** is a SQL analytics portfolio built around that problem.

Using a synthetic Retail and SME loan book with **10,001 monthly loan-performance observations**, the repository develops analytical systems for answering questions such as:

> **Where is credit risk building?**

> **Which loans are deteriorating before they become non-performing?**

> **How is exposure moving between credit-risk stages?**

> **What level of expected loss is associated with the portfolio?**

> **Which customer, credit, and origination segments carry the greatest risk concentration?**

> **How quickly is portfolio quality improving or deteriorating?**

The repository is designed around the way credit risk is monitored in practice: as a portfolio that changes over time, not simply a list of loans that eventually default.

---

# Business Problem

Traditional portfolio reporting often focuses on outcomes that have already happened.

For example:

```text
Default Rate
NPL Ratio
Total Defaults
Outstanding Bad Debt
```

Those metrics matter.

But they answer:

> **How much risk has already materialized?**

Risk management also needs to answer:

> **What is deteriorating now?**

A stronger monitoring framework follows the progression of credit risk:

```text
PERFORMING LOAN
      |
      ↓
EARLY DETERIORATION
      |
      ↓
INCREASED CREDIT RISK
      |
      ↓
SERIOUS DELINQUENCY
      |
      ↓
DEFAULT / NON-PERFORMING
      |
      ↓
RECOVERY
```

At each stage, different decisions may be required.

That creates several analytical problems:

```text
How should loans be classified?

Which exposures are migrating toward higher risk?

How much loss should the portfolio expect?

Where is risk concentrated?

Which segments are deteriorating fastest?

What happens after default?

How much exposure can collateral or recoveries absorb?
```

This repository builds the SQL analytical layer for answering those questions.

---

# Portfolio Risk Framework

The projects follow the credit lifecycle from origination through deterioration and loss.

```text
                         LOAN PORTFOLIO
                               |
             ---------------------------------------
             |                  |                  |
             ↓                  ↓                  ↓
       BORROWER RISK      LOAN PERFORMANCE    COLLATERAL
             |                  |                  |
             |                  ↓                  |
             |             DELINQUENCY             |
             |                  |                  |
             -------------------|-------------------
                                |
                                ↓
                         CREDIT STAGING
                                |
                    ------------------------
                    |          |           |
                    ↓          ↓           ↓
                 STAGE 1    STAGE 2     STAGE 3
                    |          |           |
                    ------------|-----------
                                |
                                ↓
                        EXPECTED CREDIT LOSS
                                |
                    -------------------------
                    |                       |
                    ↓                       ↓
              PORTFOLIO RISK           RECOVERY
               MONITORING              ANALYSIS
```

This creates a foundation for moving from static credit reporting toward continuous portfolio risk monitoring.

---

# What the Data Represents

The dataset simulates a Retail and SME lending portfolio and combines borrower information, loan characteristics, monthly performance, payments, collateral, recoveries, and macroeconomic conditions.

The data is synthetic.

No real customers, loans, financial institutions, or credit exposures are represented.

The analytical problems, SQL modeling decisions, validation work, and risk-monitoring logic are the focus of the portfolio.

---

# Dataset

| Dataset          |   Rows | Business Role                                                          |
| ---------------- | -----: | ---------------------------------------------------------------------- |
| `customers.csv`  |  1,001 | Borrower profile, geography, income, customer type, and credit score   |
| `loans.csv`      |  1,001 | Loan exposure, pricing, tenure, borrower relationship, and origination |
| `loan_panel.csv` | 10,001 | Monthly loan performance, delinquency, PD, LGD, and previous DPD       |
| `payments.csv`   |  1,001 | Payment activity and delinquency at payment                            |
| `collateral.csv` |  1,001 | Collateral type, collateral value, and loan-to-value information       |
| `recoveries.csv` |    453 | Recovery amounts associated with defaulted exposures                   |
| `roll_rates.csv` |     16 | Pre-aggregated delinquency transitions used for migration validation   |
| `macro.csv`      |     25 | Monthly inflation and unemployment indicators                          |
| `portfolio.csv`  |  1,001 | Current portfolio snapshot containing DPD, PD, LGD, and NPL status     |

Together, these datasets support analysis across the full credit-risk lifecycle.

---

# Analytical Areas

CreditRisk360 is structured as a collection of standalone credit risk projects built from the same underlying loan portfolio.

Each project answers a different management question.

---

## 01. IFRS 9 Staging, Migration & Expected Loss Monitoring

**Business question:**

> **Where is credit quality deteriorating, how are exposures moving between stages, and what expected loss is associated with that deterioration?**

The first project builds a monthly credit-risk monitoring layer from the loan performance panel.

It covers:

* Stage 1 / Stage 2 / Stage 3 Classification
* Monthly Stage Distribution
* Stage Migration
* Expected Loss by Stage
* Credit Score Risk Segmentation
* Origination Vintage Analysis
* Portfolio Deterioration Monitoring

The project transforms monthly loan-performance records into a structured view of how risk changes through time.

**Files**

`ifrs9_staging_and_risk_classification.sql`

`ifrs9_staging_and_risk_classification_README.md`

---

# Why Stage Migration Matters

A Stage 3 balance tells management how much severe credit deterioration exists today.

Migration tells management where tomorrow's Stage 3 exposure may be coming from.

Consider two portfolios with the same current Stage 3 exposure.

```text
PORTFOLIO A

Stage 1 → Stage 1
Stage 2 → Stage 1
Stage 3 → Stage 2
```

Credit quality is stabilizing or improving.

Now consider:

```text
PORTFOLIO B

Stage 1 → Stage 2
Stage 2 → Stage 3
Stage 3 → Stage 3
```

The current Stage 3 number could be identical.

But the second portfolio carries a much stronger deterioration signal.

That is why the project tracks **movement between stages**, not only the number of loans sitting in each stage.

---

# Expected Loss Monitoring

Credit exposure becomes more useful when translated into potential financial loss.

The dataset provides:

* Loan Exposure
* Probability of Default
* Loss Given Default

allowing the portfolio to estimate expected loss using the available risk parameters.

Conceptually:

```text
EXPECTED LOSS
     =
EXPOSURE
     ×
PROBABILITY OF DEFAULT
     ×
LOSS GIVEN DEFAULT
```

The resulting loss estimate can then be analyzed across:

* Credit Stage
* Credit Score Band
* Lending Vintage
* Customer Segment
* Portfolio Period

This moves the analysis from:

> **How many loans are risky?**

to:

> **What financial exposure is associated with that risk?**

---

# Credit Risk Segmentation

Portfolio averages can hide concentration.

A lender may have an acceptable overall risk profile while deterioration is concentrated among:

```text
Low Credit Score Borrowers

Specific Origination Vintages

SME Customers

Particular Countries

High-Exposure Loans

High-LTV Borrowers
```

CreditRisk360 is structured to examine portfolio quality below the headline number.

The objective is to identify **where risk is accumulating**, not merely calculate an overall portfolio average.

---

# Vintage Analysis

Loans originated during different periods can perform differently.

Changes in:

* Underwriting Standards
* Pricing
* Borrower Quality
* Economic Conditions
* Growth Strategy

can produce lending vintages with very different risk profiles.

Vintage analysis groups loans by origination period and compares subsequent credit performance.

This helps answer:

> **Did a particular period of lending produce weaker credit quality than others?**

That question becomes especially important when rapid portfolio growth is followed by rising delinquency.

---

# Analytical Quality Review

The SQL in this repository was reviewed not only for whether it executed, but whether the resulting metrics represented the intended business question.

Two issues were identified in the first staging project.

---

## Vintage Grouping Error

The original vintage analysis grouped loans using the complete origination timestamp.

That meant loans originated on different dates remained separate observations instead of being consolidated into a common monthly vintage.

The output appeared grouped, but the analytical grain was wrong.

The corrected logic converts origination dates into a consistent calendar-month vintage before aggregation.

Conceptually:

```text
2024-03-02
2024-03-11
2024-03-27
       ↓
   2024-03
       ↓
MARCH 2024 VINTAGE
```

Now the metric measures cohorts rather than individual origination dates.

---

## SQL Dialect Consistency

The original script also contained a `USE` statement inconsistent with the intended execution environment.

That dependency was removed so the script follows one SQL dialect consistently.

This is a smaller issue analytically, but important operationally: a portfolio project should be reproducible without requiring someone to discover environment assumptions buried inside the script.

---

# Data Validation

Credit risk metrics are particularly sensitive to data quality.

Errors in fields such as:

```text
Days Past Due
Probability of Default
Loss Given Default
Exposure
Origination Date
Collateral Value
Recovery Amount
```

can directly change staging, loss estimates, and portfolio classifications.

The projects therefore treat validation as part of the analytical workflow rather than an optional cleanup step.

Checks are designed to identify problems such as:

* Duplicate Loan-Period Records
* Missing Loan Identifiers
* Invalid Delinquency Values
* Missing Risk Parameters
* Unexpected Stage Values
* Broken Loan-to-Customer Relationships
* Invalid Origination Dates
* Grain Mismatches

The objective is simple:

> **Do not build risk metrics on data whose structure has not been verified.**

---

# Business Use Cases

The portfolio is designed around decisions made by several functions within a lending organization.

### Credit Risk

Monitor deterioration, migration, risk concentration, and portfolio quality.

### Finance

Estimate expected loss and understand how changing credit quality affects financial exposure.

### Collections

Identify delinquency progression and segments moving toward severe arrears.

### Underwriting

Evaluate whether particular borrower or origination segments produce systematically weaker performance.

### Portfolio Management

Compare risk across products, vintages, borrower groups, and geographic markets.

### Leadership

Understand whether the loan book is improving, stable, or deteriorating before the problem is visible only through defaults.

---

# Repository Roadmap

The repository is designed to extend the same credit portfolio into several connected analytical systems.

### IFRS 9 Staging & Expected Loss

Classify portfolio risk, monitor stage migration, and estimate expected loss.

### Delinquency Migration & Roll Rates

Measure how quickly loans move between delinquency states and identify deterioration patterns before default.

### Collateral & Recovery Analytics

Evaluate collateral coverage, recovery performance, and residual exposure after default.

### Macroeconomic Credit Risk

Compare portfolio deterioration with inflation, unemployment, and other external conditions available in the dataset.

### Portfolio Concentration & Risk Monitoring

Identify where exposure and expected loss are concentrated across borrowers, geographies, credit bands, and lending vintages.

Each analysis remains a standalone project with its own business problem and decision context while using the same underlying portfolio.

---

# How the Projects Are Documented

Every project follows a consistent structure.

```text
BUSINESS PROBLEM
       ↓
DATA
       ↓
VALIDATION
       ↓
METHODOLOGY
       ↓
SQL MODEL
       ↓
ANALYSIS
       ↓
INSIGHT
       ↓
RECOMMENDATION
       ↓
BUSINESS IMPACT
```

The objective is not to publish isolated SQL queries.

It is to show the complete analytical process from business question to decision-ready output.

Each project therefore documents:

* What the business needs to know
* Which data supports the analysis
* How the analytical model was constructed
* What validation was performed
* Which logic problems were identified
* How those problems were corrected
* What the resulting analysis means
* What decision the output could support

---

# Tools & Techniques

The portfolio demonstrates SQL techniques used in credit risk and financial analytics, including:

### Window Functions

Used for tracking loan performance through time and comparing current observations with prior periods.

### `LAG()`

Supports month-over-month delinquency and stage migration analysis.

### Common Table Expressions

Break complex credit-risk calculations into reusable analytical layers.

### Conditional Aggregation

Calculates portfolio exposure across stages, delinquency states, and risk segments.

### `CASE`

Transforms risk conditions into business classifications such as staging and credit bands.

### Date Aggregation

Supports vintage analysis, monthly monitoring, and portfolio trend reporting.

### Grain Management

Ensures metrics are calculated at the correct level, particularly across loan-level and monthly panel data.

### Defensive SQL

Validation checks and safeguards reduce the risk of producing plausible but incorrect credit metrics.

---

# Skills Demonstrated

This repository demonstrates practical experience across:

* SQL
* Credit Risk Analytics
* IFRS 9-Style Staging
* Expected Credit Loss Analysis
* Probability of Default Analysis
* Loss Given Default Analysis
* Delinquency Monitoring
* Stage Migration Analysis
* Roll Rate Analysis
* Credit Portfolio Monitoring
* Vintage Analysis
* Credit Risk Segmentation
* Collateral Analytics
* Recovery Analytics
* Macroeconomic Risk Analysis
* Financial Risk Analytics
* Data Quality Validation
* Analytical Data Modeling
* SQL Debugging
* Business Decision Support

---

# Current Repository Structure

```text
credit-risk-portfolio/
│
├── README.md
│
├── data/
│   ├── customers.csv
│   ├── loans.csv
│   ├── loan_panel.csv
│   ├── payments.csv
│   ├── collateral.csv
│   ├── recoveries.csv
│   ├── roll_rates.csv
│   ├── macro.csv
│   └── portfolio.csv
│
├── ifrs9_staging_and_risk_classification.sql
│
└── ifrs9_staging_and_risk_classification_README.md
```

Additional credit risk projects can be added as separate analytical modules while preserving the shared portfolio dataset.

---

# Current Result

The first completed module turns monthly loan-performance data into a structured credit-risk monitoring system covering:

* Credit Stage Classification
* Stage Distribution
* Stage Migration
* Expected Loss
* Credit Score Segmentation
* Lending Vintage Analysis

The review also identified and corrected two implementation issues: incorrect vintage grouping and inconsistent SQL dialect usage.

More importantly, the repository establishes the analytical foundation for following the same portfolio through the rest of the credit lifecycle:

```text
ORIGINATION
     ↓
PERFORMANCE
     ↓
DELINQUENCY
     ↓
RISK MIGRATION
     ↓
EXPECTED LOSS
     ↓
DEFAULT
     ↓
RECOVERY
```

The goal of CreditRisk360 is therefore not simply to answer:

> **How many loans defaulted?**

It is to build the monitoring layer needed to answer the questions that come before and after default:

> **Where is risk building?**

> **How quickly is credit quality deteriorating?**

> **Which parts of the portfolio are driving expected loss?**

> **Which loans are migrating toward serious delinquency?**

> **And how much exposure remains once deterioration turns into actual loss?**

That is the difference between reporting defaults and managing credit risk.
