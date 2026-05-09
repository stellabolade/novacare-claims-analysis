# 🏥 NovaCare Health Insurance — Claims Denial & Revenue Integrity Analysis

**Author - Stella Obase
April 2026**

---

## 📌 Project Overview

This end-to-end data analytics project investigates a systemic claims denial crisis at NovaCare Health Insurance. Starting from a raw, inconsistent claims dataset of **6,150 records**, the team performed structured data cleaning in SQL, exploratory analysis in Python, and built a Power BI dashboard — culminating in a **CFO-level executive memo and presentation** identifying **$7.22 million in revenue leakage** and recommending targeted recovery actions.

**Tools Used:** PostgreSQL · Python (Pandas/Jupyter) · Power BI · Microsoft Excel · PowerPoint

---

## 📂 Repository Structure

```
novacare-claims-analysis/
│
├── README.md
├── sql/
│   └── NOVACARE_CLAIMS_SQL_FINAL.sql          ← Full cleaning pipeline in PostgreSQL
├── python/
│   └── Claims.ipynb                           ← Exploratory data analysis in Python
├── data/
│   └── claims_output.xlsx                     ← Cleaned dataset exported for analysis
├── reports/
│   ├── NOVACARE_HEALTH_INSURANCE_CLEANING_REPORT.pdf  ← Detailed data cleaning report
│   └── NovaCare_CFO_Memo.pdf                  ← Executive memo to the CFO
├── presentation/
│   └── NovaCare_CFO_Presentation.pptx         ← Slide deck for executive audience
└── dashboard/
    └── Team_3_Claims_Visuals.pbix              ← Power BI dashboard
```

---

## 🗃️ Dataset Overview

| Property | Detail |
|---|---|
| Source Table | `novacare_claims_raw` |
| Total Records | 6,150 claims |
| Original Columns | 19 |
| Final Columns (post-cleaning) | 27 |
| Unique Providers | 12 |
| Departments | 8 (Cardiology, Emergency, General Surgery, Internal Medicine, Neurology, Oncology, Orthopedics, Pediatrics) |
| Claim Statuses | Paid · Denied · Pending · Appealed |

---

## 🧹 Data Cleaning — SQL Pipeline

The raw dataset was cleaned entirely in **PostgreSQL**. A new table `claims_clean` was created and enriched with **8 derived and flag columns** to support analysis without altering original source data.

### Issues Identified & Resolved

| # | Issue | Scale | Resolution |
|---|---|---|---|
| 1 | Provider name had 6+ casing/format variants per provider | ~60 raw variants | Standardized to `'Dr. [First] [Last]'` via `CASE` on `provider_id` |
| 2 | Department had 33 raw variants for only 8 departments | 33 variants → 8 | `UPPER()` matching + `INITCAP()` fallback |
| 3 | Claim status had 12 variants for 4 valid values | 12 variants → 4 | `UPPER(TRIM())` normalization |
| 4 | ICD-10 codes contained embedded periods | 15 codes affected | `REPLACE()` to strip periods |
| 5 | NULL `billed_amount` and `allowed_amount` | 188 nulls each | `COALESCE(allowed_amount, paid_amount)`; remainder set to 0 |
| 6 | NULL `denial_reason` on denied claims | 183 records | Tagged as `'Unknown'` |
| 7 | NULL `payer_type` | 249 records | Replaced with `'Unknown'` |
| 8 | Duplicate `encounter_id` claims | 480 records | Flagged `is_duplicate_claim = 1`; retained for audit |
| 9 | Paid amount > 0 with no billing record | 74 records | Flagged `paid_error = 1` |
| 10 | Claim submitted before discharge date | 121 records | Flagged `claim_before_discharge = 1` |
| 11 | Negative `claim_processing_days` | 123 records | Corrected with `ABS()`; flagged for audit |
| 12 | Pending claims not tracked | 553 records | Added `is_pending` flag column |

### New Columns Added

| Column | Type | Purpose |
|---|---|---|
| `is_duplicate_claim` | Binary (0/1) | Flags duplicate encounter submissions |
| `paid_error` | Binary (0/1) | Flags paid claims with no billing record |
| `claim_before_discharge` | Binary (0/1) | Flags date logic violations |
| `days_to_submit` | Integer | Days between discharge and claim submission |
| `is_pending` | Binary (0/1) | Tracks unresolved pending claims |
| `negative_claim_processing_days` | Binary (0/1) | Audit trail for corrected processing days |
| `length_of_stay_days` | Integer | Discharge date minus admission date |

> ⚠️ **Known Gaps Documented:** A SQL naming bug caused the `claim_before_admission` flag to be misapplied. The `Gen. Surgery` department variant was not fully captured. NULL replacement for `billed_amount` and `payer_type` may not have applied before export. All gaps are documented in the cleaning report for transparency.

---

## 📊 Key Findings

### 🚨 The Denial Crisis

| Metric | Value |
|---|---|
| Total Billed | $18 million |
| Overall Denial Rate | **39.58%** |
| Industry Average Denial Rate | 5–10% |
| Total Revenue Leakage | **$7.22 million** |
| Immediately Recoverable (Pending + Appealed) | **$2.46 million** |

The 39.58% denial rate is **4 to 8 times higher than the industry benchmark** and remained consistent across every month of the year — confirming a structural operational failure, not a seasonal anomaly.

### Top Denial Drivers

| Denial Reason | Denial Rate | Revenue Lost |
|---|---|---|
| Duplicate Claims | 91.88% | $1.30M |
| Patient Not Eligible | 90.17% | $0.90M |
| Missing Authorization | 89.24% | $0.80M |
| Timely Filing Exceeded | 88.29% | $0.90M |
| Coding Error | — | $0.90M |
| Medical Necessity | — | $1.04M |
| Incomplete Documentation | — | $0.80M |
| Unknown / Other | — | $0.58M |

### Department & Provider Highlights
- **Emergency Department** leads in dollar leakage at **$1.0M**.
- **Pediatrics** has the highest denial rate at **41.45%** — higher than Emergency (40.71%).
- **Dr. Yetunde Okafor** shows a statistical outlier: **71% denial rate** on Viral Infection cases — flagged for audit.

### Financial Summary (Cleaned Data)

| Metric | Billed Amount | Allowed Amount | Paid Amount |
|---|---|---|---|
| Mean | $3,066.72 | $2,373.82 | $1,111.22 |
| Median | $2,801.76 | $2,147.53 | $0.00 |
| Maximum | $8,714.06 | $7,880.07 | $7,727.10 |

---

## 💡 Recommendations to the CFO

### 1. Deploy Duplicate Detection at Point of Submission → Target: $1.3M Recovery
Implement a real-time check in the claims management system to flag any submission sharing a patient ID, date of service, and procedure code with an existing claim. This is a 60-day technology change that prevents the single most preventable source of revenue loss.

### 2. Mandate Real-Time Eligibility Verification at Scheduling → Target: $0.9M Recovery
Patient eligibility must be confirmed at scheduling — not at billing. Most EHR systems include this feature but it is not enforced. A 90.17% denial rate on eligibility failures means patients are regularly being seen with unconfirmed coverage.

### 3. Launch a 30-Day Recovery Sprint on Pending & Appealed Claims → Target: $2.46M Recovery
$2.46 million is still recoverable today. These claims are filed and reviewed — they only need active follow-through before payer deadlines expire. Prioritize Pediatrics and Emergency departments.

---

## 🛠️ Skills Demonstrated

- End-to-end SQL data cleaning pipeline (`CREATE TABLE`, `UPDATE`, `ALTER TABLE`, `CASE WHEN`, `COALESCE`, `ABS`, `TRIM`)
- Data quality audit with documented gaps and limitations
- Python exploratory data analysis (Jupyter Notebook)
- Financial metrics analysis and revenue leakage quantification
- Executive communication — CFO memo and slide deck
- Power BI dashboard development
- Healthcare domain knowledge (ICD-10 codes, CPT codes, claims workflows, denial management)

---

## 👩‍💻 About

**Stella Obase — Dataverse Africa Internship**
Data Analyst Interns | April 2026

*Project focus: Transforming raw insurance claims data into executive-ready revenue intelligence.*
