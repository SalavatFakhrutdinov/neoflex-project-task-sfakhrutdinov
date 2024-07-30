from sqlalchemy import create_engine
import pandas as pd

engine = create_engine('postgresql://sfakhrutdinov:0799@localhost/neoflex_project_task')

df = pd.read_sql_query('SELECT * FROM dm.dm_f101_round_f', engine)

engine.dispose()

df.to_csv('dm.dm_f101_round_f.csv', index=False)
