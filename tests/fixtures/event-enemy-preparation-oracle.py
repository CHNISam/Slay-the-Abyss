"""Independent pinned319009 OrbWalker constructor interpretation, not gameplay."""
import json
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
Random = runpy.run_path(str(ROOT / 'tools/oracles/sts1_combat_gold.py'))['Random']


def build():
    result = []
    for seed in ('0', '1', '42', '-1', '65537', '2780424839485660359',
                 '9223372036854775807', '-9223372036854775808'):
        rng = Random(seed)
        hp, discarded = [], []
        for _ in range(2):
            discarded.append(rng.integer(90, 96))
            hp.append(rng.integer(90, 96))
        result.append({'seed': seed, 'hp': hp, 'discarded': discarded, 'after': rng.snapshot()})
    return result


def lua(value):
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    return str(value)


if __name__ == '__main__':
    import sys
    result = build()
    print('-- Independent fixed319009 constructor-only vectors.\nreturn ' + lua(result)
          if '--lua' in sys.argv else json.dumps(result, indent=2))
