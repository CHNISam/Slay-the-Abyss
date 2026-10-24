"""Independent source interpretation: room construction + opening AI/HP streams.

aeubanks/sts@319009d5 MonsterHelper/AbstractMonster/Exordium enemy constructors.
No production imports, Lua execution, JSON content reads or PC certification.
Cosmetic MathUtils, deck/shuffle/card/reward streams deliberately excluded.
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

    def raw(self):
        a, b = self.a, self.b
        a ^= (a << 23) & MASK
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
        return (self.b + b) & MASK

    def integer(self, lo, hi):
        self.counter += 1
        bound = hi - lo + 1
        while True:
            bits = self.raw() >> 1
            value = bits % bound
            if bits - value + bound - 1 < 1 << 63:
                return lo + value

    def boolean(self):
        self.counter += 1
        return self.raw() & 1 == 1

    def snapshot(self):
        return {'words': [f'{self.a:016x}', f'{self.b:016x}'], 'counter': self.counter}


HP = {
    'cultist': (48, 54), 'jaw_worm': (40, 44), 'red_louse': (10, 15),
    'green_louse': (11, 17), 'acid_slime_s': (8, 12), 'spike_slime_s': (10, 14),
    'acid_slime_m': (28, 32), 'spike_slime_m': (28, 32),
    'acid_slime_l': (65, 69), 'spike_slime_l': (64, 70),
    'looter': (44, 48), 'blue_slaver': (46, 50), 'red_slaver': (46, 50),
    'fungi_beast': (22, 28), 'mad_gremlin': (20, 24), 'sneaky_gremlin': (10, 14),
    'fat_gremlin': (13, 17), 'wizard_gremlin': (21, 25), 'shield_gremlin': (12, 15),
    'gremlin_nob': (82, 86), 'lagavulin': (109, 111), 'sentry': (38, 42),
    'guardian': (240, 240),
}
SOURCES = ['Cultist', 'Jaw Worm', '2 Louse', 'Small Slimes', 'Blue Slaver',
           'Gremlin Gang', 'Looter', 'Large Slime', 'Lots of Slimes', 'Exordium Thugs',
           'Exordium Wildlife', 'Red Slaver', '3 Louse', '2 Fungi Beasts',
           'Gremlin Nob', 'Lagavulin', '3 Sentries', 'The Guardian']
FIXED = {'Cultist': ['cultist'], 'Jaw Worm': ['jaw_worm'], 'Blue Slaver': ['blue_slaver'],
         'Looter': ['looter'], 'Red Slaver': ['red_slaver'],
         '2 Fungi Beasts': ['fungi_beast', 'fungi_beast'], 'Gremlin Nob': ['gremlin_nob'],
         'Lagavulin': ['lagavulin'], '3 Sentries': ['sentry'] * 3, 'The Guardian': ['guardian']}


def case(seed, floor, source):
    raw = (int(seed) + floor) & MASK
    room_seed = str(raw if raw < 1 << 63 else raw - (1 << 64))
    hp, ai, misc = Random(room_seed), Random(room_seed), Random(room_seed)
    trace = []

    def draw(stream, name, operation, *args):
        value = getattr(stream, operation)(*args)
        trace.append({'stream': name, 'operation': operation, 'args': list(args),
                      'value': value, 'after': stream.snapshot()})
        return value

    def make(enemy):
        actor = {'id': enemy, 'hp': draw(hp, 'hp', 'integer', *HP[enemy])}
        if enemy in ('red_louse', 'green_louse'):
            actor['bite'] = draw(hp, 'hp', 'integer', 5, 7)
        return actor

    def boolean():
        return draw(misc, 'misc', 'boolean')

    def index(hi):
        return draw(misc, 'misc', 'integer', 0, hi)

    def louse():
        return make('red_louse' if boolean() else 'green_louse')

    def weak():
        candidates = [louse(), make('spike_slime_m'), make('acid_slime_m')]
        return candidates[index(2)]

    def humanoid():
        candidates = [make('cultist'), make('red_slaver' if boolean() else 'blue_slaver'), make('looter')]
        return candidates[index(2)]

    if source in FIXED:
        actors = [make(enemy) for enemy in FIXED[source]]
    elif source in ('2 Louse', '3 Louse'):
        actors = [louse() for _ in range(int(source[0]))]
    elif source == 'Small Slimes':
        ids = ['spike_slime_s', 'acid_slime_m'] if boolean() else ['acid_slime_s', 'spike_slime_m']
        actors = [make(enemy) for enemy in ids]
    elif source == 'Large Slime':
        actors = [make('acid_slime_l' if boolean() else 'spike_slime_l')]
    elif source in ('Lots of Slimes', 'Gremlin Gang'):
        pool = (['spike_slime_s'] * 3 + ['acid_slime_s'] * 2 if source == 'Lots of Slimes'
                else ['mad_gremlin'] * 2 + ['sneaky_gremlin'] * 2 + ['fat_gremlin'] * 2 + ['shield_gremlin', 'wizard_gremlin'])
        actors = [make(pool.pop(index(len(pool) - 1))) for _ in range(5 if source == 'Lots of Slimes' else 4)]
    elif source == 'Exordium Thugs':
        actors = [weak(), humanoid()]
    else:
        strong = [make('fungi_beast'), make('jaw_worm')]
        actors = [strong[index(1)], weak()]
    for slot, actor in enumerate(actors):
        enemy = actor['id']
        roll = draw(ai, 'ai', 'integer', 0, 99)
        if enemy in ('red_louse', 'green_louse'):
            move = 2 if roll < 25 else 1
        elif enemy == 'acid_slime_s':
            move = 1 if draw(ai, 'ai', 'boolean') else 2
        elif enemy in ('acid_slime_m', 'acid_slime_l'):
            move = 1 if roll < 30 else 3 if roll < 70 else 2
        elif enemy in ('spike_slime_m', 'spike_slime_l'):
            move = 1 if roll < 30 else 2
        elif enemy == 'blue_slaver':
            move = 2 if roll < 40 else 1
        elif enemy == 'fungi_beast':
            move = 1 if roll < 60 else 2
        elif enemy == 'sentry':
            move = 2 if slot % 2 == 0 else 1
        else:
            move = 2 if enemy == 'cultist' else 1
        actor['intent'] = f'{enemy}_{move}'
    for actor in actors:
        if actor['id'] in ('red_louse', 'green_louse'):
            actor['curlUp'] = draw(hp, 'hp', 'integer', 3, 7)
    return {'seed': seed, 'floor': floor, 'roomSeed': room_seed, 'source': source,
            'actors': actors, 'trace': trace,
            'hp': hp.snapshot(), 'ai': ai.snapshot(), 'misc': misc.snapshot()}


if __name__ == '__main__':
    settings = [('0', 1), ('-1', 1), ('42', 4), ('65536', 14), ('2780424839485660359', 7),
                ('9223372036854775807', 1), ('-9223372036854775808', 17)]
    print(json.dumps({'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
                      'generatorSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                      'boundary': __doc__,
                      'cases': [case(seed, floor, source) for seed, floor in settings for source in SOURCES]}, indent=2))
