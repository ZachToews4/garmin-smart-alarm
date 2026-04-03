from pathlib import Path
import json
import pandas as pd
import matplotlib.pyplot as plt

DATA = Path('data/processed/SC4001E0_replay.csv')
EVAL = Path('results/evaluation_SC4001E0.json')
PNG = Path('results/SC4001E0_replay_plot.png')

df = pd.read_csv(DATA)
eval_data = json.loads(EVAL.read_text())
algos = {a['algorithm']: a for a in eval_data['algorithms']}
window_start = eval_data['scenario']['window_start']
target = eval_data['scenario']['target_minute']

stage_map = {
    'Sleep stage W': 0,
    'Sleep stage 1': 1,
    'Sleep stage 2': 2,
    'Sleep stage 3': 3,
    'Sleep stage 4': 4,
    'Sleep stage R': 5,
}

df['stage_code'] = df['stage'].map(stage_map).fillna(-1)

fig, axes = plt.subplots(3, 1, figsize=(14, 9), sharex=True)
axes[0].plot(df['minute_index'], df['stage_code'], lw=1.0)
axes[0].set_ylabel('Sleep stage')
axes[0].set_yticks(list(stage_map.values()), list(stage_map.keys()))
axes[0].set_title('Sleep replay: SC4001E0')

axes[1].plot(df['minute_index'], df['proxy_motion'], label='proxy_motion')
axes[1].plot(df['minute_index'], df['proxy_light_sleep_score'], label='proxy_light_sleep_score')
axes[1].legend(loc='upper right')
axes[1].set_ylabel('Proxy features')

axes[2].plot(df['minute_index'], df['proxy_stress'], label='proxy_stress')
axes[2].plot(df['minute_index'], df['proxy_body_battery'], label='proxy_body_battery')
axes[2].legend(loc='upper right')
axes[2].set_ylabel('Watch-like proxies')
axes[2].set_xlabel('Minute index from record start')

for ax in axes:
    ax.axvspan(window_start, target, color='gold', alpha=0.15)
    ax.axvline(target, color='red', ls='--', lw=1)
    for name, algo in algos.items():
        ax.axvline(algo['trigger_minute'], lw=1, ls=':', label=name)

handles, labels = axes[2].get_legend_handles_labels()
fig.tight_layout()
fig.savefig(PNG, dpi=160)
print(PNG)
