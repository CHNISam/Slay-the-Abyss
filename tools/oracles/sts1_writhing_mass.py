"""Pinned319009 A0 AI interpretation, independent of all product Lua/data.

Models selected-move history (including Reactive), integer rejection and float32
probability draws. Not STS execution and not a natural campaign-play claim.
"""
import argparse
import json
import struct
from sts1_combat_gold import Random, MASK


def f32(n):
    return struct.unpack('>f', struct.pack('>f', n))[0]


class Trace(Random):
    def __init__(self, seed):
        super().__init__(seed)
        self.trace = []

    def integer(self, low, high):
        value = super().integer(low, high)
        self.trace.append({'kind': 'int', 'lo': low, 'hi': high, 'value': value})
        return value

    def chance(self, threshold):
        a, b = self.a, self.b
        a ^= (a << 23) & MASK
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
        self.counter += 1
        value = (((self.b + b) & MASK) >> 40) / (1 << 24)
        self.trace.append({'kind': 'float', 'chance': f32(threshold), 'value': value})
        return value < f32(threshold)


def choose(ai, previous, used, opening=False):
    number = ai.integer(0, 99)
    if opening:
        return 'multi_hit' if number < 33 else 'attack_block' if number < 66 else 'attack_debuff'
    while True:
        if number < 10:
            if previous != 'big_hit':
                return 'big_hit'
            number = ai.integer(10, 99)
        elif number < 20:
            if not used and previous != 'implant':
                return 'implant'
            if ai.chance(.1):
                return 'big_hit'
            number = ai.integer(20, 99)
        elif number < 40:
            if previous != 'attack_debuff':
                return 'attack_debuff'
            number = ai.integer(0, 19) if ai.chance(.4) else ai.integer(40, 99)
        elif number < 70:
            if previous != 'multi_hit':
                return 'multi_hit'
            if ai.chance(.3):
                return 'attack_block'
            number = ai.integer(0, 39)
        elif previous != 'attack_block':
            return 'attack_block'
        else:
            number = ai.integer(0, 69)


def vector(seed):
    ai, hp = Trace(seed), Random(seed)
    monster_hp = hp.integer(160, 160)
    current, used = choose(ai, None, False, True), False
    result = {'seed': str(seed), 'hp': monster_hp, 'hpRng': hp.snapshot(),
              'opening': current, 'openingRng': ai.snapshot(), 'steps': []}
    for step in range(32):
        # A Reactive reroll does not execute an announced Implant.
        executed = step % 3 == 0
        if executed and current == 'implant':
            used = True
        start = len(ai.trace)
        current = choose(ai, current, used)
        result['steps'].append({'executed': executed, 'used': used, 'next': current,
                                'draws': ai.trace[start:], 'rng': ai.snapshot()})
    return result


def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    return str(value)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    values = [vector(seed) for seed in (1, 42, 77)]
    print('-- Independent fixed-source interpretation; not PC execution.\nreturn ' + lua(values)
          if args.lua else json.dumps(values, indent=2))
