USE AML;
DESCRIBE transactions;
SELECT MAX(TX_AMOUNT) FROM transactions;

SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM accounts
UNION ALL
SELECT 'alerts', COUNT(*) FROM alerts
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions;

SELECT * FROM accounts LIMIT 10;
SELECT * FROM alerts LIMIT 10;
SELECT * FROM transactions LIMIT 10;

SELECT
    COUNT(DISTINCT ACCOUNT_ID)     AS distinct_account_id,
    COUNT(DISTINCT CUSTOMER_ID)    AS distinct_customer_id,
    COUNT(DISTINCT COUNTRY)        AS distinct_country,
    COUNT(DISTINCT ACCOUNT_TYPE)   AS distinct_account_type,
    COUNT(DISTINCT IS_FRAUD)       AS distinct_is_fraud,
    COUNT(DISTINCT TX_BEHAVIOR_ID) AS distinct_tx_behavior_id
FROM accounts;

SELECT DISTINCT COUNTRY FROM accounts;
SELECT DISTINCT ACCOUNT_TYPE FROM accounts;
SELECT DISTINCT IS_FRAUD FROM accounts;          
SELECT DISTINCT IS_FRAUD FROM transactions;      
SELECT DISTINCT TX_TYPE FROM transactions;
SELECT DISTINCT ALERT_TYPE FROM alerts;

SELECT
    SUM(ACCOUNT_ID IS NULL)     AS null_account_id,
    SUM(CUSTOMER_ID IS NULL)    AS null_customer_id,
    SUM(INIT_BALANCE IS NULL)   AS null_init_balance,
    SUM(COUNTRY IS NULL)        AS null_country,
    SUM(ACCOUNT_TYPE IS NULL)   AS null_account_type,
    SUM(IS_FRAUD IS NULL)       AS null_is_fraud,
    SUM(TX_BEHAVIOR_ID IS NULL) AS null_tx_behavior_id
FROM accounts;


SELECT
    SUM(TX_ID IS NULL)                AS null_tx_id,
    SUM(SENDER_ACCOUNT_ID IS NULL)    AS null_sender,
    SUM(RECEIVER_ACCOUNT_ID IS NULL)  AS null_receiver,
    SUM(TX_TYPE IS NULL)              AS null_tx_type,
    SUM(TX_AMOUNT IS NULL)            AS null_tx_amount,
    SUM(`TIMESTAMP` IS NULL)          AS null_timestamp,
    SUM(IS_FRAUD IS NULL)             AS null_is_fraud,
    SUM(ALERT_ID IS NULL)             AS null_alert_id
FROM transactions;

SELECT COUNT(*) AS blank_or_space_rows
FROM transactions
WHERE TRIM(TX_TYPE) = '' OR TRIM(IS_FRAUD) = '' OR TRIM(CAST(TX_AMOUNT AS CHAR)) = '';

SELECT COUNT(*) AS duplicate_row_groups FROM (
    SELECT ACCOUNT_ID, CUSTOMER_ID, INIT_BALANCE, COUNTRY, ACCOUNT_TYPE,
           IS_FRAUD, TX_BEHAVIOR_ID, COUNT(*) AS c
    FROM accounts
    GROUP BY 1,2,3,4,5,6,7
    HAVING c > 1
) d;


SELECT COUNT(*) AS duplicate_tx_id_groups FROM (
    SELECT TX_ID, COUNT(*) AS c FROM transactions GROUP BY TX_ID HAVING c > 1
) d;

SELECT ALERT_ID, COUNT(*) AS tx_in_ring
FROM alerts
GROUP BY ALERT_ID
HAVING COUNT(*) > 1
ORDER BY tx_in_ring DESC
LIMIT 10;

SELECT DISTINCT IS_FRAUD FROM accounts;      -- -> 'true' / 'false' (lowercase)
SELECT DISTINCT IS_FRAUD FROM transactions;  -- -> 'True' / 'False' (Titlecase)
SELECT DISTINCT IS_FRAUD FROM alerts;        
SELECT COUNT(*) AS negative_balances FROM accounts WHERE CAST(INIT_BALANCE AS DOUBLE) < 0;

SELECT COUNT(*) AS negative_amounts FROM transactions WHERE CAST(TX_AMOUNT AS DOUBLE) < 0;

SELECT COUNT(*) AS zero_amount_transfers FROM transactions WHERE CAST(TX_AMOUNT AS DOUBLE) = 0;


SELECT COUNT(*) AS overflow_ceiling_rows
FROM transactions
WHERE CAST(TX_AMOUNT AS DOUBLE) = 21474836.47;

SELECT COUNT(*) AS scientific_notation_amounts
FROM transactions
WHERE CAST(TX_AMOUNT AS CHAR) LIKE '%E%';

DROP TABLE IF EXISTS accounts_clean;

CREATE TABLE accounts_clean AS
SELECT
    CAST(ACCOUNT_ID AS UNSIGNED) AS account_id,
    TRIM(CUSTOMER_ID) AS customer_id,
    CAST(ROUND(INIT_BALANCE,2) AS DECIMAL(14,2)) AS init_balance,
    UPPER(TRIM(COUNTRY)) AS country,
    UPPER(TRIM(ACCOUNT_TYPE)) AS account_type,
    CASE
        WHEN LOWER(TRIM(IS_FRAUD))='true' THEN 1
        ELSE 0
    END AS is_fraud,
    TX_BEHAVIOR_ID AS tx_behavior_segment
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY ACCOUNT_ID ORDER BY ACCOUNT_ID) AS rn
    FROM accounts
) d
WHERE rn = 1;

ALTER TABLE accounts_clean
    ADD PRIMARY KEY (account_id),
    MODIFY COLUMN customer_id VARCHAR(20) NOT NULL,
    ADD UNIQUE KEY uq_accounts_clean_customer_id (customer_id),
    ADD CONSTRAINT chk_init_balance_non_negative CHECK (init_balance >= 0),
    ADD CONSTRAINT chk_acc_is_fraud_bool CHECK (is_fraud IN (0,1));

CREATE INDEX idx_accounts_clean_is_fraud ON accounts_clean (is_fraud);

DROP TABLE IF EXISTS transactions_clean;

CREATE TABLE transactions_clean AS
SELECT
    CAST(TX_ID AS UNSIGNED) AS tx_id,
    CAST(SENDER_ACCOUNT_ID AS UNSIGNED) AS sender_account_id,
    CAST(RECEIVER_ACCOUNT_ID AS UNSIGNED) AS receiver_account_id,
    UPPER(TRIM(TX_TYPE)) AS tx_type,
    CAST(ROUND(TX_AMOUNT,2) AS DECIMAL(20,2)) AS tx_amount,
    CAST(`TIMESTAMP` AS UNSIGNED) AS tx_time_step,
    CASE
        WHEN LOWER(TRIM(IS_FRAUD)) = 'true' THEN 1
        ELSE 0
    END AS is_fraud,
    NULLIF(CAST(ALERT_ID AS SIGNED), -1) AS alert_id
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY TX_ID
               ORDER BY TX_ID
           ) AS rn
    FROM transactions
) d
WHERE rn = 1;

DROP TABLE IF EXISTS transactions_enriched;

CREATE TABLE transactions_enriched AS
WITH stats AS (
    SELECT MIN(amt) AS p99_amount
    FROM (
        SELECT tx_amount AS amt, PERCENT_RANK() OVER (ORDER BY tx_amount) AS pct_rank
        FROM transactions_clean
    ) ranked
    WHERE pct_rank >= 0.99
)
SELECT
    c.tx_id,
    c.sender_account_id,
    c.receiver_account_id,
    c.tx_type,
    c.tx_amount,
    c.tx_time_step,
    c.is_fraud,
    c.alert_id,

    CASE WHEN c.sender_account_id = c.receiver_account_id THEN 1 ELSE 0 END AS is_self_transfer,
    CASE WHEN c.tx_amount = 0 THEN 1 ELSE 0 END AS is_zero_amount,

    CASE WHEN c.tx_amount = 21474836.47 THEN 1 ELSE 0 END AS is_amount_overflow_suspected,

    CASE WHEN c.tx_amount > s.p99_amount THEN 1 ELSE 0 END AS is_amount_outlier_p99
FROM transactions_clean c
CROSS JOIN stats s;

ALTER TABLE transactions_clean
    ADD PRIMARY KEY (tx_id),
    MODIFY COLUMN tx_type VARCHAR(20) NOT NULL,
    ADD CONSTRAINT chk_tx_amount_non_negative CHECK (tx_amount >= 0),
    ADD CONSTRAINT chk_tx_is_fraud_bool CHECK (is_fraud IN (0,1)),
    ADD CONSTRAINT fk_tx_sender   FOREIGN KEY (sender_account_id)   REFERENCES accounts_clean(account_id),
    ADD CONSTRAINT fk_tx_receiver FOREIGN KEY (receiver_account_id) REFERENCES accounts_clean(account_id);

CREATE INDEX idx_tx_clean_sender      ON transactions_clean (sender_account_id);
CREATE INDEX idx_tx_clean_receiver    ON transactions_clean (receiver_account_id);
CREATE INDEX idx_tx_clean_alert_id    ON transactions_clean (alert_id);
CREATE INDEX idx_tx_clean_time_step   ON transactions_clean (tx_time_step);
CREATE INDEX idx_tx_clean_is_fraud    ON transactions_clean (is_fraud);


DROP TABLE IF EXISTS alerts_clean;
CREATE TABLE alerts_clean AS
SELECT * FROM (
WITH deduped AS (

    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY TX_ID ORDER BY TX_ID) AS rn
    FROM alerts
)
SELECT
    CAST(TX_ID AS UNSIGNED)               AS tx_id,
    CAST(ALERT_ID AS UNSIGNED)            AS alert_id,
    LOWER(TRIM(CAST(ALERT_TYPE AS CHAR))) AS alert_type,
    CASE WHEN LOWER(TRIM(CAST(IS_FRAUD AS CHAR))) = 'true' THEN 1 ELSE 0 END AS is_fraud,
    CAST(SENDER_ACCOUNT_ID AS UNSIGNED)   AS sender_account_id,
    CAST(RECEIVER_ACCOUNT_ID AS UNSIGNED) AS receiver_account_id,
    UPPER(TRIM(CAST(TX_TYPE AS CHAR)))    AS tx_type,
    CAST(ROUND(CAST(TX_AMOUNT AS DOUBLE), 2) AS DECIMAL(20,2)) AS tx_amount,
    CAST(`TIMESTAMP` AS UNSIGNED)         AS tx_time_step
FROM deduped
WHERE rn = 1
) q;

ALTER TABLE alerts_clean
    ADD PRIMARY KEY (tx_id);

DESCRIBE alerts_clean;
CREATE INDEX idx_alerts_clean_alert_id  
ON alerts_clean(alert_id);

CREATE INDEX idx_alerts_clean_alert_type 
ON alerts_clean (alert_type);

SELECT
    SUM(account_id IS NULL) AS null_account_id,
    SUM(customer_id IS NULL) AS null_customer_id,
    SUM(init_balance IS NULL) AS null_init_balance
FROM accounts_clean;

SELECT COUNT(*) AS bad_balances FROM accounts_clean WHERE init_balance < 0;
SELECT COUNT(*) AS bad_amounts  FROM transactions_clean WHERE tx_amount < 0;

SELECT
    (SELECT COUNT(*) FROM accounts_clean)      AS accounts_rows,
    (SELECT COUNT(*) FROM transactions_clean)  AS transactions_rows,
    (SELECT COUNT(*) FROM alerts_clean)        AS alerts_rows;

SELECT * FROM accounts_clean;
SELECT * FROM transactions_clean;
SELECT * FROM alerts_clean;

SHOW TABLES FROM bank_fraud_analytics;
SHOW TABLES FROM AML;
