from pathlib import Path
import math
import json
import pandas as pd
import numpy as np
import pyedflib

ROOT = Path('.')
RAW = ROOT / 'data' / 'raw'
PROC = ROOT / 'data' / 'processed'
PROC.mkdir(parents=True, exist_ok=True)

PSG_PATH = RAW / 'SC4001E0-PSG.edf'
HYP_PATH = RAW / 'SC4001EC-Hypnogram.edf'
OUT_CSV = PROC / 'SC4001E0_replay.csv'
OUT_JSON = PROC / 'SC4001E0_summary.json'

LIGHT_STAGES = {'Sleep stage 1', 'Sleep stage 2', 'Sleep stage R'}
DEEP_STAGES = {'Sleep stage 3', 'Sleep stage 4'}
WAKE_STAGES = {'Sleep stage W', 'Movement time', 'Sleep stage ?'}

f = pyedflib.EdfReader(str(PSG_PATH))
labels = f.getSignalLabels()
label_to_idx = {label: i for i, label in enumerate(labels)}
resp = f.readSignal(label_to_idx['Resp oro-nasal'])
emg = f.readSignal(label_to_idx['EMG submental'])
temp = f.readSignal(label_to_idx['Temp rectal'])
duration = int(f.getFileDuration())
f.close()

h = pyedflib.EdfReader(str(HYP_PATH))
starts, durations, descriptions = h.readAnnotations()
h.close()

rows = []
for start, dur, desc in zip(starts, durations, descriptions):
    start = int(round(float(start)))
    dur = int(round(float(dur)))
    if dur <= 0:
        continue
    end = min(start + dur, duration)
    rows.append((start, end, str(desc)))

stage_by_second = np.full(duration, 'Sleep stage ?', dtype=object)
for start, end, desc in rows:
    stage_by_second[start:end] = desc

seconds = np.arange(duration)
minutes = seconds // 60
minute_df = pd.DataFrame({'minute_index': np.arange(int(math.ceil(duration / 60)))})

# Aggregate respiration / EMG / temp to 1-minute bins.
def aggregate_by_minute(signal, name):
    ser = pd.Series(signal[:duration])
    grp = ser.groupby(minutes)
    return pd.DataFrame({
        f'{name}_mean': grp.mean(),
        f'{name}_std': grp.std(ddof=0).fillna(0.0),
        f'{name}_min': grp.min(),
        f'{name}_max': grp.max(),
    }).reset_index(names='minute_index')

for name, sig in [('resp', resp), ('emg', emg), ('temp', temp)]:
    minute_df = minute_df.merge(aggregate_by_minute(sig, name), on='minute_index', how='left')

stage_df = pd.DataFrame({'minute_index': minutes, 'stage': stage_by_second})
stage_mode = stage_df.groupby('minute_index')['stage'].agg(lambda s: s.value_counts().idxmax()).reset_index()
minute_df = minute_df.merge(stage_mode, on='minute_index', how='left')
minute_df['is_light_stage'] = minute_df['stage'].isin(LIGHT_STAGES)
minute_df['is_deep_stage'] = minute_df['stage'].isin(DEEP_STAGES)
minute_df['is_sleep_stage'] = ~minute_df['stage'].isin(WAKE_STAGES)
minute_df['minutes_since_start'] = minute_df['minute_index']
minute_df['clock_minutes'] = minute_df['minute_index'] % 1440

# Very rough wearable-like proxy features from available PSG channels.
# We explicitly mark these as proxies for offline algorithm work, not real Garmin-native values.
minute_df['proxy_stress'] = (
    100
    - np.clip((minute_df['resp_std'] * 12.0) + (minute_df['emg_mean'] * 0.25), 0, 100)
).clip(0, 100)
minute_df['proxy_body_battery'] = (
    100
    - (minute_df['minutes_since_start'] / max(minute_df['minutes_since_start'].max(), 1) * 35)
    - (minute_df['is_sleep_stage'].astype(int) * -10)
).clip(5, 100)
minute_df['proxy_motion'] = (minute_df['emg_std'] + minute_df['resp_std'] * 0.5)
minute_df['proxy_light_sleep_score'] = (
    minute_df['is_light_stage'].astype(int) * 0.65
    + (~minute_df['is_deep_stage']).astype(int) * 0.15
    + (1 - np.clip(minute_df['proxy_motion'] / (minute_df['proxy_motion'].quantile(0.9) + 1e-6), 0, 1)) * 0.20
)

minute_df.to_csv(OUT_CSV, index=False)
summary = {
    'source_psg': str(PSG_PATH.name),
    'source_hypnogram': str(HYP_PATH.name),
    'minutes': int(len(minute_df)),
    'stage_counts': minute_df['stage'].value_counts().to_dict(),
    'columns': list(minute_df.columns),
    'notes': [
        'Sleep stage labels are ground truth from hypnogram EDF annotations.',
        'proxy_* columns are offline approximations for wearable-like features, not direct Garmin measurements.',
        'This dataset currently uses one Sleep-EDF night as the first replay target.'
    ]
}
OUT_JSON.write_text(json.dumps(summary, indent=2))
print(f'wrote {OUT_CSV}')
print(json.dumps(summary, indent=2))
