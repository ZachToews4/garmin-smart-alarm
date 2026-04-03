from pathlib import Path
import requests

ROOT = Path('.')
RAW = ROOT / 'data' / 'raw'
RAW.mkdir(parents=True, exist_ok=True)
BASE = 'https://physionet.org/files/sleep-edfx/1.0.0/sleep-cassette/'

pairs = [
    ('SC4001E0-PSG.edf', 'SC4001EC-Hypnogram.edf'),
    ('SC4011E0-PSG.edf', 'SC4011EH-Hypnogram.edf'),
    ('SC4031E0-PSG.edf', 'SC4031EC-Hypnogram.edf'),
    ('SC4041E0-PSG.edf', 'SC4041EC-Hypnogram.edf'),
]

session = requests.Session()

for psg, hyp in pairs:
    for name in [psg, hyp]:
        out = RAW / name
        url = BASE + name + '?download'
        expected = int(session.head(url, allow_redirects=True, timeout=60).headers.get('content-length', '0') or '0')
        if out.exists() and out.stat().st_size == expected and expected > 0:
            print('exists', out.name, out.stat().st_size)
            continue
        if out.exists():
            print('refetch', out.name, out.stat().st_size, 'expected', expected)
            out.unlink()
        print('downloading', name, flush=True)
        with session.get(url, stream=True, timeout=300) as r:
            r.raise_for_status()
            with open(out, 'wb') as f:
                for chunk in r.iter_content(chunk_size=1024*1024):
                    if chunk:
                        f.write(chunk)
        print('saved', out.name, out.stat().st_size, flush=True)
