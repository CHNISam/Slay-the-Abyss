"""Independent fixed319009 A0 Shield/Spear shared-AI interpretation.

Only the existing independent libGDX integer primitive is reused. No Lua,
product definitions or component output is read. These are component vectors.
"""
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
Random = runpy.run_path(str(ROOT / 'tools/sts1-card-rng-oracle.py'))['Random']


def vector(seed, slots):
    rng = Random(seed)
    count, last = {'shield': 0, 'spear': 0}, {'shield': None, 'spear': None}

    def boolean():
        # libGDX RandomXS128.nextBoolean uses the low bit of nextLong.
        rng.counter += 1
        return bool(rng.raw() & 1)

    def roll(role):
        rng.draw('randomInt99')  # The source ignores num, not the inherited draw.
        phase = count[role] % 3
        if role == 'shield':
            move = ('fortify' if boolean() else 'bash') if phase == 0 else (
                ('fortify' if last[role] == 'bash' else 'bash') if phase == 1 else 'smash')
        else:
            move = ('piercer' if last[role] == 'burn_strike' else 'burn_strike') if phase == 0 else (
                'skewer' if phase == 1 else ('piercer' if boolean() else 'burn_strike'))
        count[role] += 1
        return move

    shield, spear = roll('shield'), roll('spear')
    opening = rng.snapshot()
    steps = []
    for turn in range(1, 7):
        entry = {'turn': turn, 'shield': shield, 'spear': spear}
        if shield == 'bash':
            entry['bashPower'] = 'focus' if slots > 0 and boolean() else 'strength'
        last['shield'] = shield
        shield = roll('shield')
        last['spear'] = spear
        spear = roll('spear')
        entry['after'] = rng.snapshot()
        steps.append(entry)
    return {'seed': str(seed), 'orbSlots': slots, 'openingAfter': opening,
            'steps': steps, 'nextShield': shield, 'nextSpear': spear, 'after': rng.snapshot()}


def build():
    return [vector(seed, slots) for seed in ('0', '1', '42', '-1') for slots in (0, 3)]


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
    print('-- Independent fixed319009 AI continuation vectors.\nreturn ' + lua(build())
          if '--lua' in sys.argv else json.dumps(build(), indent=2))
