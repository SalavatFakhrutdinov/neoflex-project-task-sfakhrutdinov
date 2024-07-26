from datetime import datetime
from airflow import DAG
from airflow.operators.empty import EmptyOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.python import PythonOperator
import pandas as pd


def insert_data(table_name):
    df = pd.read_csv(f"/data_tables/{table_name}.csv", delimiter=";", encoding_errors="ignore")
    postgres_hook = PostgresHook("postgres-db")
    df.drop_duplicates(inplace=True)
    engine = postgres_hook.get_sqlalchemy_engine()
    df.to_sql(table_name, engine, schema="ds", if_exists="replace", index=False)


default_args = {
    "owner": "sfakhrutdinov",
    "start_date": datetime(2024, 7, 25),
    "retries": 2
}

with DAG(
        dag_id="insert_data",
        default_args=default_args,
        description="Загрузка данных в DS",
        catchup=False,
        schedule="0 0 * * *"
) as dag:
    start = EmptyOperator(
        task_id='start'
    )

    ft_balance_f = PythonOperator(
        task_id="ft_balance_f",
        python_callable=insert_data,
        op_kwargs={"table_name": "ft_balance_f"}
    )

    ft_posting_f = PythonOperator(
        task_id="ft_posting_f",
        python_callable=insert_data,
        op_kwargs={"table_name": "ft_posting_f"}
    )

    md_account_d = PythonOperator(
        task_id="md_account_d",
        python_callable=insert_data,
        op_kwargs={"table_name": "md_account_d"}
    )

    md_currency_d = PythonOperator(
        task_id="md_currency_d",
        python_callable=insert_data,
        op_kwargs={"table_name": "md_currency_d"}
    )

    md_exchange_rate_d = PythonOperator(
        task_id="md_exchange_rate_d",
        python_callable=insert_data,
        op_kwargs={"table_name": "md_exchange_rate_d"}
    )

    md_ledger_account_s = PythonOperator(
        task_id="md_ledger_account_s",
        python_callable=insert_data,
        op_kwargs={"table_name": "md_ledger_account_s"}
    )

    end = EmptyOperator(
        task_id="end"
    )

    (
            start
            >> [ft_balance_f, ft_posting_f, md_account_d, md_currency_d, md_exchange_rate_d, md_ledger_account_s]
            >> end
    )
