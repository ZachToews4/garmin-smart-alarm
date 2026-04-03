import pandas as pd

df = pd.read_csv('data/processed/SC4001E0_replay.csv')
for stage in ['Sleep stage W','Sleep stage 1','Sleep stage 2','Sleep stage 3','Sleep stage 4','Sleep stage R']:
    sub = df[df.stage==stage]
    print('\n', stage, len(sub))
    print(sub[['resp_mean','resp_std','emg_mean','emg_std','proxy_motion','proxy_light_sleep_score']].mean().round(3).to_dict())
