"""Fixed-source A0 combat gold interpretation, independent of production code.

aeubanks/sts@319009d5 AbstractRoom, MonsterGroup, AbstractDungeon and STS Random.
No game data, Lua or production-module imports. Not original-game execution.
"""
import hashlib
import json
from pathlib import Path

MASK = (1 << 64) - 1


class Random:
    def __init__(self, seed):
        def mix(n):
            n = ((n ^ (n >> 33)) * 0xff51afd7ed558ccd) & MASK
            n = ((n ^ (n >> 33)) * 0xc4ceb9fe1a85ec53) & MASK
            return n ^ (n >> 33)
        self.a = mix((int(seed) or -(1 << 63)) & MASK)
        self.b = mix(self.a)
        self.counter = 0

    def integer(self, low, high):
        self.counter += 1
        bound = high - low + 1
        while True:
            a, b = self.a, self.b
            a ^= (a << 23) & MASK
            self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
            bits = ((self.b + b) & MASK) >> 1
            remainder = bits % bound
            if bits - remainder + bound - 1 < 1 << 63:
                return low + remainder

    def snapshot(self):
        return {'words': [f'{self.a:016x}', f'{self.b:016x}'],
                'counter': self.counter}


def room_seed(seed, floor):
    n = (int(seed) + floor) & MASK
    return str(n if n < 1 << 63 else n - (1 << 64))


def build():
    cases = []
    for seed in ['0', '42', '65536', '-1', '2780424839485660359',
                 '9223372036854775807', '-9223372036854775808']:
        treasure = Random(seed)
        steps = []
        for tier, floor, escaped in [('normal', 1, False), ('normal', 2, True),
                                     ('elite', 7, False), ('normal', 8, False),
                                     ('elite', 11, False), ('boss', 16, False)]:
            room = room_seed(seed, floor)
            misc = Random(room)
            if tier == 'normal' and escaped:
                gold, owner, bounds = 0, None, None
            elif tier == 'boss':
                owner, bounds = 'miscRng', [-5, 5]
                gold = 100 + misc.integer(*bounds)
            else:
                owner = 'treasureRng'
                bounds = [10, 20] if tier == 'normal' else [25, 35]
                gold = treasure.integer(*bounds)
            step = {'tier': tier, 'floor': floor, 'allEscaped': escaped,
                    'roomSeed': room, 'gold': gold, 'treasure': treasure.snapshot()}
            if owner:
                step.update({'owner': owner, 'bounds': bounds})
            if tier == 'boss':
                step['bossMisc'] = misc.snapshot()
            steps.append(step)
        cases.append({'seed': seed, 'steps': steps})
    return {'schemaVersion': 1,
            'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
            'generatorSha256': hashlib.sha256(Path(__file__).read_text(encoding='utf-8').encode('utf-8')).hexdigest(),
            'boundary': 'Independent fixed-source normal A0/non-Daily interpretation. No Golden Idol/Ectoplasm or unsupported modifiers; no chest treasure-stream migration or PC execution claim.',
            'cases': cases}


if __name__ == '__main__':
    destination = Path(__file__).resolve().parents[2] / 'tests/fixtures/sts1-combat-gold-vectors.json'
    destination.write_text(json.dumps(build(), indent=2) + '\n', encoding='utf-8')
