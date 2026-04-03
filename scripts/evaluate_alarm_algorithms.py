from pathlib import Path
import json
import pandas as pd

DATA = Path('data/processed/SC4001E0_replay.csv')
OUT = Path('results/evaluation_SC4001E0.json')
OUT.parent.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(DATA)

LIGHT_STAGES = {'Sleep stage 1', 'Sleep stage 2', 'Sleep stage R'}

sleep_df = df[df['is_sleep_stage']].copy()
start_sleep = int(sleep_df['minute_index'].min())
end_sleep = int(sleep_df['minute_index'].max())
TARGET = end_sleep - 10
WINDOW = 30
START_MONITOR = max(start_sleep - 15, 0)
window_start = TARGET - WINDOW


def snap_to_poll(minute: int) -> int:
    if minute < START_MONITOR:
        return START_MONITOR
    delta = minute - START_MONITOR
    return START_MONITOR + ((delta + 4) // 5) * 5


def summarize_trigger(name, trigger_minute, reason):
    row = df.loc[df['minute_index'] == trigger_minute].iloc[0] if trigger_minute is not None else None
    return {
        'algorithm': name,
        'target_minute': int(TARGET),
        'window_minutes': WINDOW,
        'monitor_start_minute': int(START_MONITOR),
        'triggered': trigger_minute is not None,
        'trigger_minute': int(trigger_minute) if trigger_minute is not None else None,
        'reason': reason,
        'inside_window': bool(trigger_minute is not None and window_start <= trigger_minute <= TARGET),
        'stage_at_trigger': None if row is None else row['stage'],
        'is_light_stage_at_trigger': None if row is None else bool(row['is_light_stage']),
        'minutes_before_target': None if trigger_minute is None else int(TARGET - trigger_minute),
    }

baseline_trigger = None
for _, row in df[(df['minute_index'] >= window_start) & (df['minute_index'] <= TARGET)].iterrows():
    if row['is_sleep_stage'] and not row['is_deep_stage']:
        baseline_trigger = int(row['minute_index'])
        break
if baseline_trigger is None:
    baseline_trigger = TARGET
baseline = summarize_trigger('baseline_current_style', baseline_trigger, 'first non-deep sleep minute in window, else target')

poll_df = df[(df['minute_index'] >= START_MONITOR) & (df['minute_index'] <= TARGET) & ((df['minute_index'] - START_MONITOR) % 5 == 0)].copy()
awake_like = poll_df['emg_mean'] >= 3.1
light_like = (poll_df['emg_mean'] <= 1.0) | ((poll_df['resp_std'] >= 220) & (poll_df['emg_mean'] <= 2.8))

sleep_confirm_count = 0
sleep_onset = None
trigger = None
for idx, row in poll_df.iterrows():
    minute = int(row['minute_index'])

    if not awake_like.loc[idx]:
        sleep_confirm_count += 1
        if sleep_confirm_count >= 2 and sleep_onset is None:
            sleep_onset = minute
    else:
        sleep_confirm_count = 0

    if minute < window_start or sleep_onset is None:
        continue

    if light_like.loc[idx] and not awake_like.loc[idx]:
        trigger = minute
        break

if trigger is None:
    trigger = TARGET
proposed = summarize_trigger('proposed_garmin_constrained', trigger, '5-min polls, repeated sleep confirmation, awake-like rejection, light-like proxy trigger, else target')

oracle_trigger = None
for _, row in df[(df['minute_index'] >= window_start) & (df['minute_index'] <= TARGET)].iterrows():
    if row['stage'] in LIGHT_STAGES:
        oracle_trigger = int(row['minute_index'])
        break
if oracle_trigger is None:
    oracle_trigger = TARGET
oracle = summarize_trigger('oracle_ground_truth', oracle_trigger, 'first labeled light-sleep minute in window, else target')
oracle_garmin = summarize_trigger('oracle_ground_truth_snapped_to_5min', snap_to_poll(oracle_trigger), 'first labeled light-sleep minute snapped to Garmin 5-min polling cadence')

result = {
    'dataset': str(DATA.name),
    'sleep_interval': {
        'start_minute': start_sleep,
        'end_minute': end_sleep,
    },
    'scenario': {
        'target_minute': TARGET,
        'window_minutes': WINDOW,
        'window_start': window_start,
        'poll_cadence_minutes': 5,
    },
    'algorithms': [baseline, proposed, oracle, oracle_garmin],
}
OUT.write_text(json.dumps(result, indent=2))
print(json.dumps(result, indent=2))
