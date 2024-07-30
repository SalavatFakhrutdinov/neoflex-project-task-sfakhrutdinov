CREATE OR REPLACE FUNCTION dm.fill_f101_round_f(i_OnDate date)
RETURNS VOID AS $$
DECLARE
	i_FromDate date := date_trunc('month', i_OnDate) - interval '1 month';
	i_ToDate date := i_FromDate + interval '1 month' - interval '1 day';
BEGIN
	-- Удаляем существующие данные за дату расчета
	DELETE FROM 
		dm.dm_f101_round_f
	WHERE 
		from_date = date_trunc('month', i_OnDate) - interval '1 month';
	-- Наполняем витрину данными
	INSERT INTO dm.dm_f101_round_f (from_date, to_date, chapter, ledger_account, characteristic, balance_in_rub, balance_in_val, balance_in_total, turn_deb_rub, turn_deb_val, turn_deb_total, turn_cre_rub, turn_cre_val, turn_cre_total, balance_out_rub, balance_out_val, balance_out_total)
	WITH sum_balance_in AS (
		SELECT
			LEFT(ad."ACCOUNT_NUMBER", 5)::int AS ledger_account
			,ad."CHAR_TYPE" AS characteristic
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" IN ('810', '643') THEN ab.balance_out_rub ELSE 0 END), 0) AS balance_in_rub
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" NOT IN ('810', '643') THEN ab.balance_out_rub ELSE 0 END), 0) AS balance_in_val
			,COALESCE(SUM(ab.balance_out_rub), 0) AS balance_in_total
		FROM
			ds.md_account_d ad
		LEFT JOIN dm.dm_account_balance_f ab ON ad."ACCOUNT_RK" = ab.account_rk 
		WHERE
			ab.on_date = i_FromDate - interval '1 day'
		GROUP BY
			LEFT(ad."ACCOUNT_NUMBER", 5)::int
			,ad."CHAR_TYPE"
		ORDER BY ledger_account
	),
	sum_turnover_deb AS (
		SELECT
			LEFT(ad."ACCOUNT_NUMBER", 5)::int AS ledger_account
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" IN ('810', '643') THEN at.debet_amount_rub ELSE 0 END), 0) AS turn_deb_rub
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" NOT IN ('810', '643') THEN at.debet_amount_rub ELSE 0 END), 0) AS turn_deb_val
			,COALESCE(SUM(at.debet_amount_rub), 0) AS turn_deb_total
		FROM
			ds.md_account_d ad
		LEFT JOIN dm.dm_account_turnover_f at ON ad."ACCOUNT_RK" = at.account_rk
		WHERE
			at.on_date BETWEEN i_FromDate AND i_ToDate
		GROUP BY
			LEFT(ad."ACCOUNT_NUMBER", 5)::int
		ORDER BY ledger_account
	),
	sum_turnover_cre AS (
		SELECT
			LEFT(ad."ACCOUNT_NUMBER", 5)::int AS ledger_account
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" IN ('810', '643') THEN at.credit_amount_rub ELSE 0 END), 0) AS turn_cre_rub
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" NOT IN ('810', '643') THEN at.credit_amount_rub ELSE 0 END), 0) AS turn_cre_val
			,COALESCE(SUM(at.credit_amount_rub), 0) AS turn_cre_total
		FROM
			ds.md_account_d ad
		LEFT JOIN dm.dm_account_turnover_f at ON ad."ACCOUNT_RK" = at.account_rk 
		WHERE
			at.on_date BETWEEN i_FromDate AND i_ToDate
		GROUP BY
			LEFT(ad."ACCOUNT_NUMBER", 5)::int
		ORDER BY ledger_account
	),
	sum_balance_out AS (
		SELECT
			LEFT(ad."ACCOUNT_NUMBER", 5)::int AS ledger_account
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" IN ('810', '643') THEN ab.balance_out_rub ELSE 0 END), 0) AS balance_out_rub
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" NOT IN ('810', '643') THEN ab.balance_out_rub ELSE 0 END), 0) AS balance_out_val
			,COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" IN ('810', '643') THEN ab.balance_out_rub ELSE 0 END), 0) + COALESCE(SUM(CASE WHEN ad."CURRENCY_CODE" NOT IN ('810', '643') THEN ab.balance_out_rub ELSE 0 END), 0) AS balance_out_total
		FROM
			ds.md_account_d ad
		LEFT JOIN dm.dm_account_balance_f ab ON ad."ACCOUNT_RK" = ab.account_rk 
		WHERE
			ab.on_date = '2018-01-31'
		GROUP BY
			LEFT(ad."ACCOUNT_NUMBER", 5)::int
		ORDER BY ledger_account
	)
	SELECT DISTINCT
		i_FromDate AS from_date
		,i_ToDate AS to_date
		,la."CHAPTER" AS chapter
		,LEFT(ad."ACCOUNT_NUMBER", 5)::int AS ledger_account
		,la."CHARACTERISTIC" AS characteristic
		,t1.balance_in_rub
		,t1.balance_in_val
		,t1.balance_in_total
		,t2.turn_deb_rub
		,t2.turn_deb_val
		,t2.turn_deb_total
		,t3.turn_cre_rub
		,t3.turn_cre_val
		,t3.turn_cre_total
		,t4.balance_out_rub
		,t4.balance_out_val
		,t4.balance_out_total
	FROM
		ds.md_account_d ad
	LEFT JOIN ds.md_ledger_account_s la ON LEFT(ad."ACCOUNT_NUMBER", 5)::int = la."LEDGER_ACCOUNT"
	JOIN sum_balance_in t1 ON la."LEDGER_ACCOUNT" = t1.ledger_account
	JOIN sum_turnover_deb t2 ON t1.ledger_account = t2.ledger_account
	JOIN sum_turnover_cre t3 ON t1.ledger_account = t3.ledger_account
	JOIN sum_balance_out t4 ON t1.ledger_account = t4.ledger_account
	ORDER BY
		ledger_account;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE dm.dm_fill_f101_round_f(report_date date)
LANGUAGE plpgsql
AS $$
BEGIN
	PERFORM dm.fill_f101_round_f(report_date);
END $$;

CALL dm.dm_fill_f101_round_f('2018-02-01');