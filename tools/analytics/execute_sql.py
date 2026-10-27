"""Execute the shared aggregate SQL using standard-library SQLite; no network."""
import json,re,sqlite3,sys
from pathlib import Path
payload=json.load(sys.stdin)
con=sqlite3.connect(':memory:')
con.row_factory=sqlite3.Row
# Fixed schema makes empty-cohort results identical to populated cohorts.
ints='funnel_depth registered trial_started a1 a2 ready body_ready activity_ready generated viewed paid paywall checkout cancel_scheduled ended d1_eligible d1_retained d7_eligible d7_retained d14_eligible d14_retained d21_eligible d21_retained conversion_eligible converted landmark_eligible landmark_retained landmark_conversion_eligible landmark_converted'.split()
texts='user_id cohort_month registered_at trial_started_at first_report_viewed_at landmark_segment'.split()
cols=ints+texts
con.execute('CREATE TABLE journey_users ('+','.join(c+(' INTEGER' if c in ints else ' TEXT') for c in cols)+')')
con.executemany('INSERT INTO journey_users VALUES ('+','.join('?' for _ in cols)+')',[[r[c] for c in cols] for r in payload['facts']])
sql=Path(__file__).with_name('dashboard_queries.sql').read_text()
sections=re.split(r'^-- query: (\w+)\n',sql,flags=re.M)
result={}
for i in range(1,len(sections),2):
    result[sections[i]]=[dict(r) for r in con.execute(sections[i+1])]
print(json.dumps(result,sort_keys=True))
