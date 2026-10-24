"""Independent fixed-source potion pool interpretation, not deployed gameplay.

aeubanks/sts@319009d5 PotionHelper and AbstractDungeon/AbstractRoom.
Pool constants were authored from their declared order, not sorted rarity buckets.
No production Lua, catalog JSON or decompiled implementation is imported.
"""
import hashlib
import json
from pathlib import Path

MASK = (1 << 64) - 1
POOL = [
    ('BloodPotion', 'common'), ('ElixirPotion', 'uncommon'), ('HeartOfIron', 'rare'),
    ('Block Potion', 'common'), ('Dexterity Potion', 'common'), ('Energy Potion', 'common'),
    ('Explosive Potion', 'common'), ('Fire Potion', 'common'), ('Strength Potion', 'common'),
    ('Swift Potion', 'common'), ('Weak Potion', 'common'), ('FearPotion', 'common'),
    ('AttackPotion', 'common'), ('SkillPotion', 'common'), ('PowerPotion', 'common'),
    ('ColorlessPotion', 'common'), ('SteroidPotion', 'common'), ('SpeedPotion', 'common'),
    ('BlessingOfTheForge', 'common'), ('Regen Potion', 'uncommon'), ('Ancient Potion', 'uncommon'),
    ('LiquidBronze', 'uncommon'), ('GamblersBrew', 'uncommon'), ('EssenceOfSteel', 'uncommon'),
    ('DuplicationPotion', 'uncommon'), ('DistilledChaos', 'uncommon'), ('LiquidMemories', 'uncommon'),
    ('CultistPotion', 'rare'), ('Fruit Juice', 'rare'), ('SneckoOil', 'rare'),
    ('FairyPotion', 'rare'), ('SmokeBomb', 'rare'), ('EntropicBrew', 'rare'),
]


class Stream:
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

    def snapshot(self):
        return {'words': [f'{self.a:016x}', f'{self.b:016x}'], 'counter': self.counter}


def rarity(roll):
    assert 0 <= roll <= 99
    return 'common' if roll < 65 else 'uncommon' if roll < 90 else 'rare'


class Oracle:
    def __init__(self, seed):
        self.rng = Stream(seed)
        self.modifier = 0
        self.trace = []

    def draw(self, purpose, lo, hi):
        value = self.rng.integer(lo, hi)
        self.trace.append({'purpose': purpose, 'minimum': lo, 'maximum': hi,
                           'value': value, 'after': self.rng.snapshot()})
        return value

    def pick(self, wanted=None, limited=False, totally_random=False):
        if totally_random:
            index = self.draw('uniform_candidate', 0, 32)
            return {'sourceId': POOL[index][0], 'rarity': POOL[index][1], 'attempts': [index]}
        if wanted is None:
            wanted = rarity(self.draw('rarity', 0, 99))
        index = self.draw('candidate', 0, 32)
        attempts = [index]
        # In the limited overload even a valid first candidate is discarded.
        # Every later candidate must match rarity and must not be Fruit Juice.
        if limited:
            index = self.draw('candidate', 0, 32)
            attempts.append(index)
            while POOL[index][1] != wanted or POOL[index][0] == 'Fruit Juice':
                index = self.draw('candidate', 0, 32)
                attempts.append(index)
        else:
            while POOL[index][1] != wanted:
                index = self.draw('candidate', 0, 32)
                attempts.append(index)
        return {'sourceId': POOL[index][0], 'rarity': wanted, 'attempts': attempts}

    def drop(self, room='normal', escaped=False, reward_count=0, white_beast=False):
        chance = 0 if room in ('normal', 'boss') and escaped else 40 + self.modifier
        if white_beast:
            chance = 100
        if reward_count >= 4:
            chance = 0
        dropped = self.draw('drop', 0, 99) < chance
        result = {'chance': chance, 'dropped': dropped}
        if dropped:
            result['potion'] = self.pick()
            self.modifier -= 10
        else:
            self.modifier += 10
        result['modifier'] = self.modifier
        return result


def case(seed):
    oracle = Oracle(seed)
    records = []

    def add(action, result):
        records.append({'action': action, 'result': result, 'after': oracle.rng.snapshot(),
                        'modifier': oracle.modifier})

    for i in range(3):
        add('shop_initial_' + str(i), oracle.pick())
    add('normal_drop', oracle.drop())
    add('courier_purchase_refill', oracle.pick())
    add('elite_drop', oracle.drop(room='elite'))
    add('boss_drop', oracle.drop(room='boss'))
    add('event_combat_drop', oracle.drop(room='event'))
    add('all_escaped_normal_drop', oracle.drop(escaped=True))
    add('four_rewards_suppress_drop', oracle.drop(reward_count=4, white_beast=True))
    add('white_beast_statue_drop', oracle.drop(white_beast=True))
    for i in range(3):
        add('entropic_combat_slot_' + str(i), oracle.pick(limited=True))
    for i in range(3):
        add('entropic_outside_slot_' + str(i), oracle.pick())
    add('explicit_rare_limited', oracle.pick('rare', limited=True))
    add('explicit_rare', oracle.pick('rare'))
    add('totally_random', oracle.pick(totally_random=True))
    return {'seed': seed, 'records': records, 'trace': oracle.trace, 'after': oracle.rng.snapshot()}


if __name__ == '__main__':
    normalized = Path(__file__).read_text(encoding='utf8').encode('utf8')
    print(json.dumps({'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
                      'generatorCanonicalLfSha256': hashlib.sha256(normalized).hexdigest(),
                      'generatorHashBasis': 'UTF-8 text with universal-newline LF normalization',
                      'pool': [{'sourceId': source, 'rarity': r} for source, r in POOL],
                      'boundary': 'potion selection/drop stream only; no price, effect, cosmetic or full shop initialization replay',
                      'cases': [case(seed) for seed in ['0', '1', '42', '65535', '65536', '-1',
                                '2780424839485660359', '9223372036854775807', '-9223372036854775808']]}, indent=2))
