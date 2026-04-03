from pathlib import Path
import json
import pandas as pd

PROC = Path('data/processed')
OUT = Path('results/evaluation_batch.json')
OUT.parent.mkdir(parents=True, exist_ok=True)

LIGHT_STAGES = {'Sleep stage 1', 'Sleep stage 2', 'Sleep stage R'}
results = []

for data_path in sorted(PROC.glob('SC*_replay.csv')):
    df = pd.read_csv(data_path)
    sleep_df = df[df['is_sleep_stage']].copy()
    if sleep_df.empty:
        continue

    start_sleep = int(sleep_df['minute_index'].min())
    end_sleep = int(sleep_df['minute_index'].max())

    scenarios = [
        {'name': 'late_window', 'target': end_sleep - 10, 'window': 30},
        {'name': 'mid_window', 'target': end_sleep - 25, 'window': 45},
        {'name': 'tight_window', 'target': end_sleep - 5, 'window': 20},
    ]

    for scenario in scenarios:
        target = int(scenario['target'])
        window = int(scenario['window'])
        start_monitor = max(start_sleep - 15, 0)
        window_start = target - window
        if window_start < start_sleep:
            window_start = start_sleep

        def summarize(name, trigger_minute, reason):
            row = df.loc[df['minute_index'] == trigger_minute].iloc[0] if trigger_minute is not None else None
            return {
                'algorithm': name,
                'trigger_minute': int(trigger_minute) if trigger_minute is not None else None,
                'reason': reason,
                'stage_at_trigger': None if row is None else row['stage'],
                'is_light_stage_at_trigger': None if row is None else bool(row['is_light_stage']),
                'inside_window': bool(trigger_minute is not None and window_start <= trigger_minute <= target),
                'minutes_before_target': None if trigger_minute is None else int(target - trigger_minute),
            }

        baseline_trigger = None
        for _, row in df[(df['minute_index'] >= window_start) & (df['minute_index'] <= target)].iterrows():
            if row['is_sleep_stage'] and not row['is_deep_stage']:
                baseline_trigger = int(row['minute_index'])
                break
        if baseline_trigger is None:
            baseline_trigger = target

        poll_df = df[(df['minute_index'] >= start_monitor) & (df['minute_index'] <= target) & ((df['minute_index'] - start_monitor) % 5 == 0)].copy()

        # Revised heuristics from failure analysis:
        # - awake-like if EMG is clearly high
        # - trigger if REM-like (very low EMG) OR non-awake with strong score
        awake_like = poll_df['emg_mean'] >= 3.4
        rem_like = poll_df['emg_mean'] <= 1.2
        light_like = rem_like | (
            (poll_df['proxy_light_sleep_score'] >= 0.84) &
            (poll_df['emg_mean'] <= 2.95)
        )

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
            trigger = target

        oracle_trigger = None
        for _, row in df[(df['minute_index'] >= window_start) & (df['minute_index'] <= target)].iterrows():
            if row['stage'] in LIGHT_STAGES:
                oracle_trigger = int(row['minute_index'])
                break
        if oracle_trigger is None:
            oracle_trigger = target
        oracle_snapped = start_monitor + (((oracle_trigger - start_monitor) + 4) // 5) * 5

        results.append({
            'dataset': data_path.name,
            'dataset_id': df['dataset_id'].iloc[0],
            'scenario_name': scenario['name'],
            'sleep_interval': {'start_minute': start_sleep, 'end_minute': end_sleep},
            'scenario': {
                'target_minute': target,
                'window_minutes': window,
                'window_start': window_start,
                'poll_cadence_minutes': 5,
            },
            'algorithms': [
                summarize('baseline_current_style', baseline_trigger, 'first non-deep sleep minute in window, else target'),
                summarize('proposed_garmin_constrained', trigger, '5-min polls, repeated sleep confirmation, awake-like rejection, REM/light proxy trigger, else target'),
                summarize('oracle_ground_truth', oracle_trigger, 'first labeled light-sleep minute in window, else target'),
                summarize('oracle_ground_truth_snapped_to_5min', oracle_snapped, 'first labeled light-sleep minute snapped to Garmin 5-min polling cadence'),
            ]
        })

summary = {
    'scenarios_evaluated': len(results),
    'results': results,
}

passes = 0
window_hits = 0
for entry in results:
    algos = {a['algorithm']: a for a in entry['algorithms']}
    proposed = algos['proposed_garmin_constrained']
    oracle = algos['oracle_ground_truth_snapped_to_5min']
    if proposed['inside_window']:
        window_hits += 1
    if proposed['stage_at_trigger'] == oracle['stage_at_trigger'] and proposed['trigger_minute'] == oracle['trigger_minute']:
        passes += 1
summary['proposed_exact_match_count'] = passes
summary['proposed_exact_match_rate'] = (passes / len(results)) if results else 0.0
summary['proposed_inside_window_count'] = window_hits
summary['proposed_inside_window_rate'] = (window_hits / len(results)) if results else 0.0

OUT.write_text(json.dumps(summary, indent=2))
print(json.dumps({
    'scenarios_evaluated': summary['scenarios_evaluated'],
    'proposed_exact_match_count': summary['proposed_exact_match_count'],
    'proposed_exact_match_rate': summary['proposed_exact_match_rate'],
    'proposed_inside_window_count': summary['proposed_inside_window_count'],
    'proposed_inside_window_rate': summary['proposed_inside_window_rate'],
}, indent=2))
