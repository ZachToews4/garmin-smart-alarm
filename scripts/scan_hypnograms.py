import requests
from pathlib import Path

base='https://physionet.org/files/sleep-edfx/1.0.0/sleep-cassette/'
subjects=['SC4051E0-PSG.edf','SC4061E0-PSG.edf','SC4071E0-PSG.edf','SC4081E0-PSG.edf','SC4091E0-PSG.edf','SC4101E0-PSG.edf']
letters='CDEFGHIJKLMNOPQRSTUVWXYZ'
s=requests.Session()
for psg in subjects:
    stem=psg.replace('-PSG.edf','')
    prefix=stem[:6]
    night=stem[6]
    found=[]
    for letter in letters:
        hyp=f'{prefix}{night}{letter}-Hypnogram.edf'
        r=s.head(base+hyp+'?download', allow_redirects=True, timeout=20)
        if r.status_code==200:
            found.append(hyp)
    print(psg, found)
