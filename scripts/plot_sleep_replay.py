from pathlib import Path
import json
import pandas as pd
import matplotlib.pyplot as plt

BATCH = json.loads(Path('results/evaluation_batch.json').read_text())
for entry in BATCH['results']:
    dataset = entry['dataset']
    df = pd.read_csv(Path('data/processed') / dataset)
    algos = {a['algorithm']: a for a in entry['algorithms']}
    window_start = entry['scenario']['window_start']
    target = entry['scenario']['target_minute']

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
    axes[0].set_title(dataset.replace('_replay.csv', ''))

    axes[1].plot(df['minute_index'], df['resp_std'], label='resp_std')
    axes[1].plot(df['minute_index'], df['emg_mean'], label='emg_mean')
    axes[1].legend(loc='upper right')
    axes[1].set_ylabel('Proxy drivers')

    axes[2].plot(df['minute_index'], df['proxy_light_sleep_score'], label='proxy_light_sleep_score')
    axes[2].plot(df['minute_index'], df['proxy_motion'], label='proxy_motion')
    axes[2].legend(loc='upper right')
    axes[2].set_ylabel('Derived proxies')
    axes[2].set_xlabel('Minute index from record start')

    for ax in axes:
        ax.axvspan(window_start, target, color='gold', alpha=0.15)
        ax.axvline(target, color='red', ls='--', lw=1)
        ax.axvline(algos['proposed_garmin_constrained']['trigger_minute'], color='green', ls=':', lw=1.2)
        ax.axvline(algos['oracle_ground_truth_snapped_to_5min']['trigger_minute'], color='blue', ls=':', lw=1.0)

    fig.tight_layout()
    out = Path('results') / f"{dataset.replace('_replay.csv','')}_replay_plot.png"
    fig.savefig(out, dpi=160)
    plt.close(fig)
    print(out)
