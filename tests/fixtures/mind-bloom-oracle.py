"""Fixed319009 MindBloom shuffle/threshold interpretation, independent of Lua.

Only the already independent integer Random model is reused. No product data
or runtime module is read. These vectors are controlled components, not routes.
"""
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
Random = runpy.run_path(str(ROOT / 'tools/sts1-card-rng-oracle.py'))['Random']


def vector(seed, consumed):
    rng = Random(seed)
    for _ in range(consumed):
        rng.draw('randomInt99')
    before = rng.snapshot()
    rng.counter += 1
    raw = rng.raw()
    state = (raw ^ 0x5deece66d) & ((1 << 48) - 1)

    def integer(bound):
        nonlocal state
        while True:
            state = (state * 0x5deece66d + 11) & ((1 << 48) - 1)
            bits = state >> 17
            if bound & (bound - 1) == 0:
                return (bound * bits) >> 31
            value = bits % bound
            if bits - value + bound - 1 < 1 << 31:
                return value

    bosses = ['The Guardian', 'Hexaghost', 'Slime Boss']
    for size in (3, 2):
        index = integer(size)
        bosses[size - 1], bosses[index] = bosses[index], bosses[size - 1]
    return {'seed': str(seed), 'consumed': consumed, 'before': before,
            'after': rng.snapshot(), 'boss': bosses[0], 'shuffle': bosses}


def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    return str(value)


if __name__ == '__main__':
    import sys
    vectors = [vector(seed, count) for seed in ('0', '1', '42', '-1', '65537',
               '2780424839485660359', '9223372036854775807', '-9223372036854775808')
               for count in (0, 1, 7)]
    result = {'shuffle': vectors, 'floors': [
        {'floor': n, 'choice': 'rich' if n % 50 <= 40 else 'healthy'}
        for n in (35, 40, 41, 49, 50, 51, 90, 91)]}
    if '--lua' in sys.argv:
        print('-- Independent fixed319009 component oracle; not natural play.\nreturn ' + lua(result))
    else:
        print(json.dumps(result, indent=2))
