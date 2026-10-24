"""Independent integer/IEEE-754 interpretation of pinned source, not PC execution.

Exordium + AbstractDungeon + MonsterInfo at aeubanks/sts@319009d5;
RandomXS128 at libGDX@3b1fda1. Never imports or executes production Lua.
"""
import hashlib
import json
from pathlib import Path
import struct

MASK = (1 << 64) - 1


def f32(value):
    return struct.unpack('>f', struct.pack('>f', value))[0]


class Stream:
    def __init__(self, seed):
        def mix(x):
            x = ((x ^ (x >> 33)) * 0xff51afd7ed558ccd) & MASK
            x = ((x ^ (x >> 33)) * 0xc4ceb9fe1a85ec53) & MASK
            return x ^ (x >> 33)
        self.a = mix((int(seed) or -(1 << 63)) & MASK)
        self.b = mix(self.a)
        self.counter = 0
        self.draws = []

    def snap(self):
        return {'words': [f'{self.a:016x}', f'{self.b:016x}'], 'counter': self.counter}

    def draw(self):
        old = self.b
        t = self.a ^ ((self.a << 23) & MASK)
        self.a = old
        self.b = (t ^ old ^ (t >> 17) ^ (old >> 26)) & MASK
        raw = (self.b + old) & MASK
        self.counter += 1
        value = (raw >> 40) / (1 << 24)
        self.draws.append({'value': value, 'after': self.snap()})
        return value


WEAK = [('Cultist', 2), ('Jaw Worm', 2), ('2 Louse', 2), ('Small Slimes', 2)]
STRONG = [('Blue Slaver', 2), ('Gremlin Gang', 1), ('Looter', 2),
          ('Large Slime', 2), ('Lots of Slimes', 1), ('Exordium Thugs', 1.5),
          ('Exordium Wildlife', 1.5), ('Red Slaver', 1), ('3 Louse', 2), ('2 Fungi Beasts', 2)]
ELITE = [('Gremlin Nob', 1), ('Lagavulin', 1), ('3 Sentries', 1)]
EXCLUDE = {'Looter': ['Exordium Thugs'], 'Blue Slaver': ['Red Slaver', 'Exordium Thugs'],
           '2 Louse': ['3 Louse'], 'Small Slimes': ['Large Slime', 'Lots of Slimes']}


def pool(items):
    ordered = sorted(items, key=lambda item: item[1])  # Stable for equal weights.
    total = 0.0
    for _, weight in ordered:
        total = f32(total + weight)
    return [(name, f32(weight / total)) for name, weight in ordered]


def roll(stream, items):
    value = stream.draw()
    cumulative = 0.0
    for name, weight in pool(items):
        cumulative = f32(cumulative + weight)
        if value < cumulative:
            return name
    raise AssertionError('Source ERROR sentinel is unreachable for these pools')


def populate(stream, result, items, count, window):
    while count:
        candidate = roll(stream, items)
        if candidate not in result[-window:]:
            result.append(candidate)
            count -= 1


def case(seed):
    stream = Stream(seed)
    normal = []
    populate(stream, normal, WEAK, 3, 2)
    after_weak = stream.snap()
    exclusions = EXCLUDE.get(normal[-1], [])
    first = roll(stream, STRONG)
    while first in exclusions:
        first = roll(stream, STRONG)
    normal.append(first)
    populate(stream, normal, STRONG, 12, 2)
    after_normal = stream.snap()
    elite = []
    populate(stream, elite, ELITE, 10, 1)
    after_initial = stream.snap()
    initial_draws = list(stream.draws)
    refill = []
    populate(stream, refill, ELITE, 10, 1)  # Original elite refill starts with an empty list.
    return {'seed': seed, 'normal': normal, 'elite': elite, 'afterWeak': after_weak,
            'afterNormal': after_normal, 'afterInitial': after_initial, 'draws': initial_draws,
            'eliteRefill': refill, 'afterEliteRefill': stream.snap()}


if __name__ == '__main__':
    source = Path(__file__).read_bytes()
    print(json.dumps({'provenance': __doc__, 'generatorSha256': hashlib.sha256(source).hexdigest(),
                      'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
                      'cases': [case(seed) for seed in ['0', '1', '42', '65535', '65536', '-1',
                                '2780424839485660359', '9223372036854775807', '-9223372036854775808']]},
                     indent=2))
