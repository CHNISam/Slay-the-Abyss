"""Fixed319009 Tomb interpretation; no production Lua/data imports or writes on import."""
import json
from pathlib import Path
import runpy
import struct
import sys
ROOT = Path(__file__).resolve().parents[2]
Random = runpy.run_path(str(ROOT / 'tools/sts1-card-rng-oracle.py'))['Random']
def floating(rng):
    rng.counter += 1
    return struct.unpack('>f', struct.pack('>f', (rng.raw() >> 40) * 2 ** -24))[0]
def integer(rng, bound):
    rng.counter += 1
    while True:
        bits = rng.raw() >> 1
        value = bits % bound
        if bits - value + bound - 1 < 1 << 63:
            return value
def vectors():
    for seed in range(1, 101):
        room, selection = Random(seed), Random(seed)
        unknown = floating(room)
        integer(selection, 1000)  # Source Random(seed,counter1) replay.
        roll = floating(selection)
        if unknown >= .2 and roll >= .25 and integer(selection, 7) == 5:
            natural = dict(seed=str(seed), floor=35, zeroBasedIndex=5,
                           eventRng=room.snapshot(), selectionRng=selection.snapshot(),
                           miscRng=Random(seed + 35).snapshot())
            break
    else:
        raise AssertionError('No bounded Tomb component vector')
    return dict(natural=natural, goldReward=222, cases=[
        dict(gold=n, mask=False, choice='pay', resultGold=0, resultMask=True)
        for n in (0, 1, 99, 222)] + [
        dict(gold=17, mask=True, ectoplasm=False, choice='wear', resultGold=239, resultMask=True),
        dict(gold=17, mask=True, ectoplasm=True, choice='wear', resultGold=17, resultMask=True)])
def lua(v):
    if isinstance(v, dict): return '{' + ','.join('['+json.dumps(k)+']='+lua(x) for k,x in v.items()) + '}'
    if isinstance(v, list): return '{' + ','.join(lua(x) for x in v) + '}'
    if isinstance(v, str): return json.dumps(v)
    if isinstance(v, bool): return 'true' if v else 'false'
    return repr(v)
if __name__ == '__main__':
    value=vectors()
    for suffix,text in [('json',json.dumps(value,indent=2)+'\n'),('lua','return '+lua(value)+'\n')]:
        path=ROOT / ('tests/fixtures/tomb-red-mask-vectors.'+suffix)
        if '--check' in sys.argv: assert path.read_text()==text,'Tomb oracle drift'
        else: path.write_text(text,encoding='utf-8')
    print('TOMB_ORACLE seed',value['natural']['seed'],'six gold boundaries; no event-local RNG')
