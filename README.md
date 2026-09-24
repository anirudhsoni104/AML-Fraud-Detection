# AML Fraud Detection & Network Analysis

Detecting money-laundering patterns in transaction data using SQL data cleaning, Python EDA, and graph-based anomaly detection — built on the IBM AMLSim synthetic dataset.

<img width="5691" height="3245" alt="fraud_intelligence_dashboard" src="https://github.com/user-attachments/assets/e3c365e9-6c62-451a-998d-3ebe0508e259" />


> **Note on the dashboard above:** it's rendered from a 1,000-row sample of the cleaned data for readability. Figures reference the full dataset stats below unless labeled "sample."

## Overview

Anti-money-laundering (AML) systems have to catch a needle-in-a-haystack pattern: fraud is rare, transactions are massive in volume, and the structure that matters (who's connected to whom) doesn't show up in a single row. This project builds a full pipeline — from raw, messy transaction data to a graph-based flagging system — to surface exactly that structure.

## Dataset

- **Source:** IBM AMLSim synthetic dataset
- **Scale:** 10,000 accounts, 1.32M transactions, 1,719 alert records
- **Fraud rate:** 0.13% (highly imbalanced — reflective of real-world AML data)

## Pipeline & Stack

| Stage | Tools |
|---|---|
| Data cleaning | SQL (MySQL Workbench) — dedup, type casting, null handling, constraint enforcement |
| Exploratory analysis | Python (pandas) |
| Network analysis | NetworkX (`MultiDiGraph`) — cycle detection, fan-in flagging |
| Dashboard | Python + Matplotlib |
| Classification *(in progress)* | XGBoost with SMOTE for class imbalance |

## Key Findings

- **Data integrity bug caught:** 22 transactions landed exactly on the signed 32-bit integer overflow ceiling (`2,147,483.647` scaled) — a data-generation artifact, not real activity. The detection flag was widened to `>10M` to catch the fuller pattern, surfacing 66 affected rows total.
- **Graph analysis:** 19 raw transaction cycles detected, 18 confirmed as genuine structural cycles after review. Fan-in flagging threshold was corrected to the 95th percentile after the naive threshold over-flagged normal accounts.
- **Boolean inconsistency across tables:** `IS_FRAUD` was stored as lowercase `'true'/'false'` in `accounts` but Titlecase `'True'/'False'` in `transactions` — normalized during cleaning.

## 🎯 Business Objectives

The main objectives of this project are to:

1. Clean and prepare transaction data using SQL.
2. Perform exploratory data analysis using Python.
3. Identify unusual transaction behavior and potential fraud signals.
4. Analyze transaction and account-level risk patterns.
5. Calculate important fraud and AML KPIs.
6. Create a management-friendly fraud intelligence dashboard.
7. Convert analytical findings into actionable business insights.


## Repo Structure

aml-fraud-detection/
├── sql/ # Cleaning pipeline: raw → *_clean tables
├── notebooks/ # EDA.ipynb, AML.ipynb (graph analysis)
├── dashboard/ # Matplotlib dashboard + exported PNG
├── data/sample/ # Small sample of cleaned data (full dataset not included — see below)
├── requirements.txt
└── README.md

**Full dataset not included in this repo** (1.32M rows exceeds practical GitHub limits). Download the source IBM AMLSim data here: *[https://www.kaggle.com/datasets/ealtman2019/ibm-transactions-for-anti-money-laundering-aml/data?utm_source=chatgpt.com]*. A 1,000-row sample is included under `data/sample/` so the schema and shape are visible without the full download.

## How to Run

```bash
git clone https://github.com/anirudhsoni104/AML-Fraud-Detection/edit/main/README.md
cd aml-fraud-detection
pip install -r requirements.txt
```

1. Run `fraud_data_clean.sql` against a MySQL instance loaded with the raw AMLSim tables to produce `accounts_clean`, `transactions_clean`, `alerts_clean`.
2. Open `EDA.ipynb` for exploratory analysis.
3. Dashboard is regenerated from `dashboard/` scripts (Matplotlib).

## Status

- ✅ SQL cleaning pipeline
- ✅ Exploratory data analysis
- ✅ Graph analysis<img width="5691" height="3245" alt="fraud_intelligence_dashboard" src="https://github.com/user-attachments/assets/9071f1c9-7f7f-412c-a89f-21400c9f6bdc" />


- ✅ Dashboard (Python/Matplotlib)

## Why This Project

Most portfolio fraud-detection projects stop at a classifier trained on a clean CSV. This one starts earlier: with a raw, inconsistent dataset that had to be interrogated before it could be trusted, and treats the network structure between accounts as a first-class signal rather than an afterthought.
