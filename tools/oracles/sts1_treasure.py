"""Independent pinned-source chest/continuous treasure stream interpretation.

No production Lua or game-data imports. Primitive seeding/integer rejection is
shared with the existing independently implemented combat-gold oracle.
"""
import hashlib
import json
import struct
from pathlib import Path
from sts1_combat_gold import Random, MASK


def f32(value):
    return struct.unpack('>f', struct.pack('>f', value))[0]


class ChestRandom(Random):
    def next_raw(self):
        a, b = self.a, self.b
        a ^= (a << 23) & MASK
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
        return (self.b + b) & MASK

    def long_hex(self):
        self.counter += 1
        return f'{self.next_raw():016x}'

    def floating(self, low, high):
        self.counter += 1
        unit = (self.next_raw() >> 40) / float(1 << 24)
        return f32(low + f32(unit * f32(high - low)))


def build():
    cases = []
    seeds = ['0', '42', '65536', '-1', '2780424839485660359',
             '9223372036854775807', '-9223372036854775808'] + [str(i) for i in range(1, 17)]
    for seed in seeds:
        rng = ChestRandom(seed)
        relic = ChestRandom(seed)
        shuffle_longs = [relic.long_hex() for _ in range(5)]
        steps = []
        for act in [1, 3, 4]:
            combat_gold = rng.integer(10, 20)
            after_combat = rng.snapshot()
            kind_roll = rng.integer(0, 99)
            kind = 'medium' if act == 4 else 'small' if kind_roll < 50 else 'medium' if kind_roll < 83 else 'large'
            common, uncommon, chance, amount = {'small': (75, 100, 50, 25),
                                                'medium': (35, 85, 35, 50),
                                                'large': (0, 75, 50, 75)}[kind]
            roll = rng.integer(0, 99)
            tier = 'common' if roll < common else 'uncommon' if roll < uncommon else 'rare'
            gold = int(rng.floating(f32(amount * f32(.9)), f32(amount * f32(1.1))) + .5) if roll < chance else 0
            steps.append({'act': act, 'combatGold': combat_gold, 'afterCombat': after_combat,
                          'kindRoll': kind_roll, 'kind': kind, 'rewardRoll': roll,
                          'tier': tier, 'gold': gold, 'afterChest': rng.snapshot()})
        cases.append({'seed': seed, 'shuffleLongHex': shuffle_longs, 'steps': steps})
    return {'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
            'provenance': 'Independent fixed-source normal PC A0 interpretation; not authenticated PC execution.',
            'generatorSha256': hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
            'primitiveGeneratorSha256': hashlib.sha256(Path(__file__).with_name('sts1_combat_gold.py').read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
            'cases': cases}


if __name__ == '__main__':
    destination = Path(__file__).resolve().parents[2] / 'tests/fixtures/sts1-treasure-vectors.json'
    destination.write_text(json.dumps(build(), indent=2) + '\n', encoding='utf-8')
