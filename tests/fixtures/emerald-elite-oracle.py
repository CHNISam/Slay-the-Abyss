"""Independent integer source-call vectors, not complete map generation.

Uses the existing Python RandomXS128 interpretation; never imports product Lua.
Warmups make synthetic post-room-assignment states, not source-map checkpoints.
"""
import json
from pathlib import Path
import runpy
import struct

Random = runpy.run_path('tools/sts1-card-rng-oracle.py')['Random']


def draw(rng, bound):
    rng.counter = ((rng.counter + 1 + (1 << 31)) % (1 << 32)) - (1 << 31)
    while True:
        bits = rng.raw() >> 1
        value = bits % bound
        if bits - value + bound - 1 < (1 << 63):
            return value


def build():
    rows = []
    for i, seed in enumerate(['0', '1', '2', '4', '42', '-1', '65537', '2780424839485660359']):
        rng = Random(seed)
        for _ in range(i * 7):
            draw(rng, 100)
        row = {'seed': seed, 'warmup': i * 7, 'eliteCount': 1 if i == 0 else 4,
               'before': rng.snapshot()}
        row['selectionIndex'] = draw(rng, row['eliteCount'])
        row['afterSelection'] = rng.snapshot()
        row['roll'] = draw(rng, 4)
        row['afterBoost'] = rng.snapshot()
        row['next99'] = draw(rng, 100)
        row['continuation'] = rng.snapshot()
        rows.append(row)
    health = []
    for hp in [1, 2, 3, 61, 62, 63, 176, 185, 200]:
        product = struct.unpack('>f', struct.pack('>f', hp * .25))[0]
        health.append({'maxHp': hp, 'increase': int(product + .5)})
    return {'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
            'boundary': 'Synthetic post-assignment RNG states; not complete map or native acceptance.',
            'cases': rows, 'health': health}


if __name__ == '__main__':
    expected = build()
    assert {row['roll'] for row in expected['cases']} == {0, 1, 2, 3}
    target = Path('tests/fixtures/emerald-elite-vectors.json')
    assert json.loads(target.read_text()) == expected
    print('EMERALD_ORACLE 8 complete RNG continuations; 9 rounded HP vectors')
