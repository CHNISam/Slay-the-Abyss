"""Independent fixed-source Sensory Stone reward/Java-shuffle interpretation.

Reads audited card registration, never production Lua/pools/helper output.
The generic XS128 interpreter is shared with the existing card RNG oracle.
"""
import json
from pathlib import Path
import runpy
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
Random = runpy.run_path(str(ROOT / 'tools/sts1-card-rng-oracle.py'))['Random']


def f32(n):
    return struct.unpack('>f', struct.pack('>f', n))[0]


def integer(rng, bound):
    rng.counter += 1
    while True:
        bits = rng.raw() >> 1
        result = bits % bound
        if bits - result + bound - 1 < 1 << 63:
            return result


def floating(rng):
    rng.counter += 1
    return f32((rng.raw() >> 40) * 2 ** -24)


def memory(seed):
    rng = Random(int(seed) + 35)
    rng.counter += 1
    value = (rng.raw() ^ 0x5deece66d) & ((1 << 48) - 1)
    order = [1, 2, 3, 4]
    for size in range(4, 1, -1):
        while True:
            value = (value * 0x5deece66d + 11) & ((1 << 48) - 1)
            bits = value >> 17
            if size & (size - 1) == 0:
                index = (size * bits) >> 31
                break
            index = bits % size
            if bits - index + size - 1 < 1 << 31:
                break
        order[size - 1], order[index] = order[index], order[size - 1]
    return order[0], rng.snapshot()


def case(seed, count, pools):
    rng = Random(seed)
    groups, trace, offset = [], [], -17
    for _ in range(count):
        group = []
        for _ in range(3):
            roll = floating(rng)
            rarity = 'rare' if roll < f32(.3) else 'uncommon'
            indices = []
            while True:
                index = integer(rng, len(pools[rarity]))
                indices.append(index)
                card = pools[rarity][index]
                if card not in group:
                    break
            if rarity == 'rare':
                offset = 5
            group.append(card)
            trace.append({'roll': roll, 'rarity': rarity, 'indices': indices})
        groups.append(group)
    chosen, misc = memory(seed)
    return {'seed': str(seed), 'count': count, 'initialOffset': -17,
            'groups': groups, 'trace': trace, 'finalOffset': offset,
            'cardRng': rng.snapshot(), 'memory': chosen, 'miscRng': misc}


def lua(value):
    if isinstance(value, dict):
        return '{' + ','.join('[' + json.dumps(k) + ']=' + lua(v)
                              for k, v in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, str):
        return json.dumps(value)
    if value is True:
        return 'true'
    if value is False:
        return 'false'
    return repr(value)


def vectors():
    rows = json.loads((ROOT / 'data/reference/sts1-card-pools/registration.json').read_text())['registration']
    pools = {rarity: sorted(row['id'] for row in rows
                           if row['color'] == 'COLORLESS' and row['rarity'] == rarity.upper())
             for rarity in ('uncommon', 'rare')}
    assert len(pools['uncommon']) == 20 and len(pools['rare']) == 15
    seeds = [1, 5, 42, 81, 139]
    cases = [case(seed, count, pools) for seed in seeds for count in (1, 2, 3)]
    # Independent unknown-room and complete seven-item Act3 source draw.
    for seed in range(1, 101):
        room = Random(seed)
        unknown = floating(room)
        selection = Random(seed)
        integer(selection, 1000)  # Random(seed,counter1) constructor replay.
        roll = floating(selection)
        if unknown >= .2 and roll >= .25 and integer(selection, 7) == 4:
            natural = {'seed': str(seed), 'floor': 35, 'eventRng': room.snapshot(),
                       'selectionRng': selection.snapshot(), 'selectionIndex': 4}
            break
    else:
        raise AssertionError('No bounded natural component vector')
    assert any(len(row['indices']) > 1 for c in cases for row in c['trace'])
    return {'pools': pools, 'cases': cases, 'natural': natural}


if __name__ == '__main__':
    result = vectors()
    targets = {'tests/fixtures/sensory-stone-vectors.json': json.dumps(result, indent=2) + '\n',
               'tests/fixtures/sensory-stone-vectors.lua': 'return ' + lua(result) + '\n'}
    for name, text in targets.items():
        target = ROOT / name
        if '--check' in sys.argv:
            assert target.read_text() == text, 'Independent oracle drift: ' + name
        else:
            target.write_text(text, encoding='utf8')
    print('SENSORY_ORACLE', len(result['cases']), 'cases; full35 source pool, duplicate retries, card/misc words; natural', result['natural']['seed'])
