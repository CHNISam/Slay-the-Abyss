"""Independent fixed319009 A0 GiantHead/Slow facts; never imports product Lua.

1000-HP arithmetic fixtures only observe the whole capped attack ramp. They
are not natural campaign play or original-PC binary execution.
"""
import argparse
import json
import math
import struct
from sts1_combat_gold import Random


def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(item) for item in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(key) + ']=' + lua(item) for key, item in value.items()) + '}'
    return str(value)


def f32(value):
    return struct.unpack('>f', struct.pack('>f', value))[0]


def vector(seed):
    hp_rng, ai = Random(seed), Random(seed)
    monster_hp = hp_rng.integer(500, 500)
    history, count, health = [], 5, 1000

    def choose():
        nonlocal count
        roll = ai.integer(0, 99)
        if count <= 1:
            count = max(-6, count - 1)
            move = 'it_is_time'
        else:
            count -= 1
            preferred = 'glare' if roll < 50 else 'count'
            move = ('count' if preferred == 'glare' else 'glare') if history[-2:] == [preferred] * 2 else preferred
        history.append(move)
        return move, roll

    move, roll = choose()
    steps = []
    for _ in range(12):
        damage = 0 if move == 'glare' else 13 if move == 'count' else 30 - count * 5
        health -= damage
        steps.append({'intent': move, 'primaryRoll': roll, 'count': count,
                      'damage': damage, 'hpAfter': health})
        move, roll = choose()
    return {'seed': str(seed), 'monsterHp': monster_hp, 'hpRng': hp_rng.snapshot(),
            'aiRng': ai.snapshot(), 'steps': steps, 'nextIntent': move, 'nextCount': count}


def damage(base, slow, vulnerable_first=False, vulnerable=False, stance=1, weak=False):
    value = f32(f32(base) + f32(3))
    value = f32(value * f32(2))
    if weak:
        value = f32(value * f32(.75))
    value = f32(value * f32(stance))
    multiplier = f32(1 + f32(f32(slow) * f32(.1)))
    for power in (('vulnerable', 'slow') if vulnerable_first else ('slow', 'vulnerable')):
        if power == 'slow':
            value = f32(value * multiplier)
        elif vulnerable:
            value = f32(value * f32(1.5))
    return math.floor(value)


def build():
    boundaries = [(10, 1), (7, 9), (31, 7), (16777217, 3), (9999999, 14)]
    return {'ai': [vector(seed) for seed in (1, 42)],
            'damage': [{'base': base, 'slow': slow, 'vulnerableFirst': first,
                        'vulnerable': vulnerable, 'stance': stance, 'weak': weak,
                        'strength': 3, 'doubleDamage': 1,
                        'expected': damage(base, slow, first, vulnerable, stance, weak)}
                       for base, slow in boundaries for first in (False, True)
                       for vulnerable in (False, True) for stance in (1, 3) for weak in (False, True)]}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    print('-- Independent fixed319009 interpretation; not PC execution.\nreturn ' + lua(build())
          if args.lua else json.dumps(build(), indent=2))
