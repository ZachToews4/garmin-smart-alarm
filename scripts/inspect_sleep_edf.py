from pathlib import Path
import pyedflib

psg = Path('data/raw/SC4001E0-PSG.edf')
hyp = Path('data/raw/SC4001EC-Hypnogram.edf')

f = pyedflib.EdfReader(str(psg))
print('signals', f.signals_in_file)
print('labels', f.getSignalLabels())
print('sample_frequencies', [f.getSampleFrequency(i) for i in range(f.signals_in_file)])
print('file_duration_sec', f.getFileDuration())
f.close()

h = pyedflib.EdfReader(str(hyp))
starts, durations, descriptions = h.readAnnotations()
print('annotation_count', len(starts))
print('first10')
for row in list(zip(starts[:10], durations[:10], descriptions[:10])):
    print(row)
h.close()
