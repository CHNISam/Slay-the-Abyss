"""Independent integer/IEEE-float interpretation of the STS card state core.

No production imports, Lua execution, content pool reads or card identity draws.
This is a projection of source calls, NOT a complete getRewardCards replay.
Run --check to compare the checked-in vectors; --self-test checks hand boundaries.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct

MASK = (1 << 64) - 1
COMMIT = '319009d5df0a82d9fb0f23cc22322286c6a87ec0'
SEEDS = ['0', '1', '42', '65537', '-1', '2780424839485660359',
         '9223372036854775807', '-9223372036854775808']


def f32(n):
    return struct.unpack('>f', struct.pack('>f', n))[0]


def signed32(n):
    return ((n + (1 << 31)) % (1 << 32)) - (1 << 31)


class Random:
    def __init__(self, seed):
        value = int(seed)
        assert -(1 << 63) <= value < (1 << 63)
        def mix(n):
            n = ((n ^ (n >> 33)) * 0xff51afd7ed558ccd) & MASK
            n = ((n ^ (n >> 33)) * 0xc4ceb9fe1a85ec53) & MASK
            return n ^ (n >> 33)
        self.a = mix((value or -(1 << 63)) & MASK)
        self.b, self.counter = mix(self.a), 0

    @classmethod
    def restore(cls, snapshot):
        rng = cls.__new__(cls)
        rng.a, rng.b = (int(h, 16) for h in snapshot['words'])
        rng.counter = snapshot['counter']
        return rng

    def snapshot(self):
        return {'words': [f'{self.a:016x}', f'{self.b:016x}'],
                'counter': self.counter}

    def raw(self):
        a, b = self.a, self.b
        a ^= (a << 23) & MASK
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
        return (self.b + b) & MASK

    def draw(self, method):
        before, raws = self.snapshot(), []
        self.counter = signed32(self.counter + 1)
        if method == 'randomInt99':
            # libGDX bounded nextLong rejection uses Java signed64 overflow.
            while True:
                raw = self.raw()
                raws.append(f'{raw:016x}')
                bits = raw >> 1
                result = bits % 100
                if bits - result + 99 < (1 << 63):
                    break
            args = [99]
        elif method == 'randomBooleanZero':
            raw = self.raw()
            raws.append(f'{raw:016x}')
            # nextFloat takes high 24 bits, multiplication rounded to binary32.
            sample = f32((raw >> 40) * f32(2.0 ** -24))
            result, args = sample < f32(0.0), [0.0]
        else:
            raise ValueError(method)
        trace = {'method': method, 'arguments': args, 'before': before,
                 'after': self.snapshot(), 'rawOutputs': raws, 'result': result}
        if method == 'randomBooleanZero':
            trace['floatSample'] = sample
            trace['floatBits'] = struct.pack('>f', sample).hex()
        return result, trace


class Owner:
    def __init__(self, seed):
        self.rng, self.offset = Random(seed), 5

    @classmethod
    def restore(cls, snapshot):
        owner = cls.__new__(cls)
        owner.rng = Random.restore(snapshot['cardRng'])
        owner.offset = snapshot['cardRarityOffset']
        return owner

    def snapshot(self):
        return {'version': 1, 'cardRng': self.rng.snapshot(), 'cardRarityOffset': self.offset}

    def rarity(self, room, slot, update_offset=True):
        before = self.snapshot()
        raw, primitive = self.rng.draw('randomInt99')
        adjusted = raw + self.offset
        rare, uncommon = {'normal': (3, 40), 'elite': (10, 50),
                          'shop': (9, 46), 'boss': (0, 0)}[room]
        rarity = ('rare' if room == 'boss' or adjusted < rare else
                  'uncommon' if adjusted < uncommon else 'common')
        if update_offset and room != 'shop':
            if rarity == 'rare':
                self.offset = 5
            elif rarity == 'common':
                self.offset = max(-40, self.offset - 1)
        return {'slot': slot, 'before': before, 'rawRoll': raw,
                'adjustedRoll': adjusted, 'rarity': rarity,
                'primitive': primitive, 'after': self.snapshot()}

    def reward(self, room, slots=3):
        assert room in ('normal', 'elite', 'boss')
        before = self.snapshot()
        rarities = [self.rarity(room, i + 1) for i in range(slots)]
        upgrades = []
        for slot in rarities:
            step = {'slot': slot['slot'], 'rarity': slot['rarity'],
                    'before': self.snapshot(), 'upgraded': False}
            if slot['rarity'] == 'rare':
                step['skipped'] = True
            else:
                result, step['primitive'] = self.rng.draw('randomBooleanZero')
                assert result is False
                step['skipped'] = False
            step['after'] = self.snapshot()
            upgrades.append(step)
        return {'op': 'reward', 'room': room, 'slots': slots, 'before': before,
                'rarities': rarities, 'upgrades': upgrades,
                'identityDrawsOmitted': True, 'after': self.snapshot()}

    def shop(self, slots=3):
        before = self.snapshot()
        rolls = [self.rarity('shop', i + 1) for i in range(slots)]
        assert before['cardRarityOffset'] == self.offset
        return {'op': 'shop', 'room': 'shop', 'slots': slots, 'before': before,
                'rarities': rolls, 'identityDrawsOmitted': True,
                'after': self.snapshot()}


def seed_case(seed):
    owner, actions = Owner(seed), []
    initial = owner.snapshot()
    actions.append(owner.reward('normal'))
    assert all(s['rarity'] != 'rare' for s in actions[0]['rarities'])
    actions.append(owner.shop())
    checkpoint = owner.snapshot()
    clone = Owner.restore(checkpoint)
    probe = clone.reward('normal', 1)
    assert owner.snapshot() == checkpoint  # no shared words or offset owner
    actions.append({'op': 'checkpoint', 'id': 'before-elite',
                    'before': checkpoint, 'checkpoint': copy.deepcopy(checkpoint),
                    'cloneProbe': probe, 'after': owner.snapshot()})
    first_elite = owner.reward('elite')
    actions.append(first_elite)
    actions.append(owner.reward('boss'))
    before = owner.snapshot()
    owner = Owner.restore(checkpoint)
    actions.append({'op': 'restore', 'id': 'before-elite', 'before': before,
                    'after': owner.snapshot()})
    replay = owner.reward('elite')
    assert replay == first_elite
    actions.append(replay)
    # Floor labels document continuity; they do not reseed this persistent RNG.
    for action, floor in zip(actions, (1, 2, 2, 7, 16, 2, 7)):
        action['floor'] = floor
    return {'seed': seed, 'initial': initial, 'actions': actions}


def controlled_cases():
    # a=0, b=r<2^26 yields next64=2*r, hence bounded(100)=r.
    # Explicit primitive fixtures, not claims of naturally seeded reachability.
    cases = []
    inputs = [('normal', -40, r) for r in (42, 43, 79, 80)]
    inputs += [('elite', 5, r) for r in (4, 5, 44, 45)]
    inputs += [('shop', 5, r) for r in (3, 4, 40, 41)]
    inputs += [('boss', -40, 99), ('normal', -39, 99), ('normal', -40, 99)]
    for room, offset, roll in inputs:
        snapshot = {'version': 1, 'cardRng': {'words': ['0000000000000000', f'{roll:016x}'],
                                'counter': 0}, 'cardRarityOffset': offset}
        owner = Owner.restore(snapshot)
        step = owner.rarity(room, 1)
        assert step['rawRoll'] == roll
        cases.append({'name': f'{room}-offset{offset}-raw{roll}',
                      'initial': snapshot, 'action': {'op': 'rollRarity' if room == 'shop' else 'rewardRarity', 'room': room, **step}})
    for name, words, counter in [
        ('signed32-counter-wrap', ['0000000000000000', '0000000000000063'], (1 << 31) - 1),
        ('bounded-rejection-one-wrapper', ['07e07ff03fffe000', '0000000000000000'], 0),
    ]:
        snapshot = {'version': 1, 'cardRng': {'words': words, 'counter': counter}, 'cardRarityOffset': 5}
        owner = Owner.restore(snapshot)
        step = owner.rarity('normal', 1)
        if name.startswith('signed32'):
            assert step['after']['cardRng']['counter'] == -(1 << 31)
        else:
            assert step['primitive']['rawOutputs'][0] == 'ffffffffffffffff'
            assert len(step['primitive']['rawOutputs']) == 2
            assert step['after']['cardRng']['counter'] == 1
        cases.append({'name': name, 'initial': snapshot,
                      'action': {'op': 'rewardRarity', 'room': 'normal', **step}})
    # Core rollRarity reads offset; only rewardRarity applies the reward update.
    for room, offset, roll in [('normal', -40, 0), ('elite', 5, 99), ('boss', -40, 99)]:
        snapshot = {'version': 1, 'cardRng': {'words': ['0000000000000000', f'{roll:016x}'],
                                           'counter': 0}, 'cardRarityOffset': offset}
        owner = Owner.restore(snapshot)
        step = owner.rarity(room, 1, update_offset=False)
        assert owner.offset == offset
        cases.append({'name': f'roll-only-{room}', 'initial': snapshot,
                      'action': {'op': 'rollRarity', 'room': room, **step}})
    return cases


def self_test():
    for room, limits in [('normal', (3, 40)), ('elite', (10, 50)), ('shop', (9, 46))]:
        # Hand-counted offset5 distribution (rare/uncommon/common).
        counts = dict.fromkeys(('rare', 'uncommon', 'common'), 0)
        for roll in range(100):
            x = roll + 5
            counts['rare' if x < limits[0] else 'uncommon' if x < limits[1] else 'common'] += 1
        assert list(counts.values()) == {'normal': [0, 35, 65], 'elite': [5, 40, 55], 'shop': [4, 37, 59]}[room]
    assert f32(0) == 0 and f32(((1 << 24) - 1) * 2 ** -24) == 1 - 2 ** -24
    assert Random('0').snapshot() == Random('-9223372036854775808').snapshot()
    for seed in SEEDS:
        case = seed_case(seed)
        assert case['actions'][4]['after']['cardRng']['counter'] - case['actions'][4]['before']['cardRng']['counter'] == 3
    edges = controlled_cases()
    assert [c['action']['rarity'] for c in edges[:15]] == [
        'rare', 'uncommon', 'uncommon', 'common',
        'rare', 'uncommon', 'uncommon', 'common',
        'rare', 'uncommon', 'uncommon', 'common', 'rare', 'common', 'common']
    assert all(c['action']['after']['cardRarityOffset'] == -40 for c in edges[13:15])


def build():
    return {'schemaVersion': 1, 'sourceCommit': COMMIT,
            'generatorSha256': hashlib.sha256(Path(__file__).read_text(encoding='utf-8').encode()).hexdigest(),
            'profile': 'Ironclad all-unlocked Act1 PC A0 non-Daily; no rarity/slot-changing relics or mods',
            'boundary': 'State-core projection with identity draws deliberately omitted, not complete source rewards/shops. Ordered rarity calls then nonrare upgrade-zero floats; no card IDs, pool indices, duplicates, preview hooks or prices.',
            'snapshotFormat': '{version:1,cardRng:{words:[lowercase hex64,hex64],counter:signed32},cardRarityOffset}; full words are exact continuation, not seed+counter replay.',
            'seedCases': [seed_case(seed) for seed in SEEDS],
            'controlledCases': controlled_cases()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='compare existing fixture without writing')
    parser.add_argument('--self-test', action='store_true', help='run only independent hand-boundary assertions')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    self_test()
    if args.self_test:
        print('CARD_RNG_ORACLE_SELF_TEST_PASS')
    else:
        destination = args.output or Path(__file__).resolve().parents[1] / 'tests/fixtures/sts1-card-rng-state-vectors.json'
        content = json.dumps(build(), indent=2) + '\n'
        if args.check:
            assert destination.read_text(encoding='utf-8') == content, 'fixture differs from independent regeneration'
            print('CARD_RNG_STATE_VECTORS_MATCH')
        else:
            destination.write_text(content, encoding='utf-8', newline='\n')
            print(f'CARD_RNG_STATE_VECTORS_WRITTEN {destination}')
