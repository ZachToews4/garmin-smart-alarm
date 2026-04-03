import json
from pathlib import Path
import pandas as pd

batch = json.loads(Path('results/evaluation_batch.json').read_text())
rows = []
for entry in batch['results']:
    algos = {a['algorithm']: a for a in entry['algorithms']}
    p = algos['proposed_garmin_constrained']
    o = algos['oracle_ground_truth_snapped_to_5min']
    if p['trigger_minute'] == o['trigger_minute'] and p['stage_at_trigger'] == o['stage_at_trigger']:
        continue
    delta = p['trigger_minute'] - o['trigger_minute']
    classification = 'near_miss_same_stage' if p['stage_at_trigger'] == o['stage_at_trigger'] and abs(delta) <= 10 else 'true_decision_miss'
    rows.append({
        'dataset': entry['dataset'],
        'scenario_name': entry['scenario_name'],
        'proposed_trigger': p['trigger_minute'],
        'oracle_trigger': o['trigger_minute'],
        'delta_minutes': delta,
        'proposed_stage': p['stage_at_trigger'],
        'oracle_stage': o['stage_at_trigger'],
        'classification': classification,
    })

df = pd.DataFrame(rows)
out = Path('results/mismatch_analysis.csv')
df.to_csv(out, index=False)
print(df.to_string(index=False))
print('\ncounts')
print(df['classification'].value_counts().to_string())
