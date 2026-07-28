# Credit risk portfolio: IFRS 9 staging and monitoring

This repo holds a synthetic loan portfolio dataset and a set of SQL analyses built on top of it, focused on credit risk monitoring the way a bank's risk or finance team would actually use it: not just "how many loans defaulted," but where risk is building, how fast it's moving, and what it's expected to cost.

Each SQL script in this project stands on its own, with its own write-up covering the business problem it solves, the approach taken, an honest review of the script for errors or logic gaps, what the data actually showed, and what a business would do with that information. That structure is intentional. A query without context is just a query. The point here is to show the thinking behind it.

## What's in the data

The dataset models a retail and SME loan book, generated to behave like a real portfolio rather than to look pretty:

| File | Rows | What it holds |
|---|---|---|
| `customers.csv` | 1,001 | Customer ID, country, customer type (Retail/SME), income, credit score, account creation date |
| `loans.csv` | 1,001 | Loan ID, customer ID, loan amount, interest rate, tenure, origination date |
| `loan_panel.csv` | 10,001 | Monthly panel of loan performance: days past due, PD estimate, LGD estimate, prior DPD |
| `payments.csv` | 1,001 | Payment records with amount paid and days past due at time of payment |
| `collateral.csv` | 1,001 | Collateral type, value, and loan-to-value ratio where applicable |
| `recoveries.csv` | 453 | Recovery amounts recorded against defaulted (90+ DPD) loans |
| `roll_rates.csv` | 16 | Pre-aggregated days-past-due transition counts, used to sanity-check migration logic |
| `macro.csv` | 25 | Monthly inflation and unemployment figures covering the panel period |
| `portfolio.csv` | 1,001 | A snapshot view of each loan's current DPD bucket, PD, LGD, and non-performing flag |

## Scripts in this project

### 1. IFRS 9 staging, migration, and expected loss monitoring
`ifrs9_staging_and_risk_classification.sql`, documented in full in `ifrs9_staging_and_risk_classification_README.md`.

Builds a monthly credit staging view (Stage 1 / 2 / 3) from raw days-past-due data, tracks how loans migrate between stages over time, estimates expected loss by stage, and segments risk by credit score band and lending vintage. Two real bugs were found and fixed during review: a vintage query that was grouping by a full timestamp instead of a calendar month (so it never actually grouped anything), and a `USE` statement mixing SQL dialects. Both are explained and corrected in the script and the write-up.

More scripts will be added to this repo over time, each using this same dataset from a different angle (collateral and recovery performance, roll rate modeling, macro-adjusted risk, and so on), each with its own standalone documentation.

## How to read the documentation

Every script's write-up follows the same structure: business problem, data source, methodology, analysis and error check, insight, recommendation, business impact, what was done, tools used, and results. If you're reviewing this as a portfolio piece, the error check and insight sections are the ones worth reading closely. That's where the actual thinking shows up, not just the finished query.
