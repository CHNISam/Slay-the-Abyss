"""Independent integer interpretation of the fixed source's card-pile contract.

CardGroup.shuffle/initializeDeck, DrawCardAction and EmptyDeckShuffleAction,
aeubanks/sts@319009d5. No production imports, game data reads or Lua execution.
These are source-interpretation vectors, not an execution of the original PC game.
"""
import hashlib
import json
from pathlib import Path

MASK64 = (1 << 64) - 1


class ShuffleRandom:
    def __init__(self, seed):
        def mix(n):
            n = ((n ^ (n >> 33)) * 0xff51afd7ed558ccd) & MASK64
            n = ((n ^ (n >> 33)) * 0xc4ceb9fe1a85ec53) & MASK64
            return n ^ (n >> 33)
        self.a = mix((int(seed) or -(1 << 63)) & MASK64)
        self.b = mix(self.a)
        self.counter = 0
        self.trace = []

    def shuffle(self, cards):
        # STS consumes exactly one nextLong, including lists of size zero/one.
        a, b = self.a, self.b
        a ^= (a << 23) & MASK64
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK64
        raw = (self.b + b) & MASK64
        self.counter += 1
        java = (raw ^ 0x5deece66d) & ((1 << 48) - 1)

        def bits():
            nonlocal java
            java = (java * 0x5deece66d + 11) & ((1 << 48) - 1)
            return java >> 17

        def index(bound):
            if bound & (bound - 1) == 0:
                return (bound * bits()) >> 31
            while True:
                value = bits()
                result = value % bound
                if value - result + bound - 1 < 1 << 31:
                    return result

        for size in range(len(cards), 1, -1):
            j = index(size)
            cards[size - 1], cards[j] = cards[j], cards[size - 1]
        self.trace.append({'size': len(cards), 'cards': list(cards),
                           'rawHex': f'{raw:016x}', 'after': self.snapshot()})

    def snapshot(self):
        return {'words': [f'{self.a:016x}', f'{self.b:016x}'],
                'counter': self.counter}


def room_seed(seed, floor):
    n = (int(seed) + floor) & MASK64
    return str(n if n < 1 << 63 else n - (1 << 64))


def draw(rng, hand, pile, discard, amount, no_draw=False):
    # Source DrawCardAction: guard first, hand cap, split old-pile draw /
    # unconditional shuffle action / recursive remainder. No total-size clamp.
    if no_draw or amount <= 0 or not pile + discard or len(hand) == 10:
        return
    amount = min(amount, 10 - len(hand))
    old_size = len(pile)
    if amount > old_size:
        if old_size:
            draw(rng, hand, pile, discard, old_size)
        rng.shuffle(discard)
        pile.extend(discard)
        discard.clear()
        draw(rng, hand, pile, discard, amount - old_size)
    else:
        for _ in range(amount):
            hand.append(pile.pop())


SEEDS = [('0', 0), ('42', 1), ('65536', 7), ('-1', 1),
         ('2780424839485660359', 14), ('9223372036854775807', 1),
         ('-9223372036854775808', 16)]


def build():
    initial, redraw = [], []
    for seed, floor in SEEDS:
        room = room_seed(seed, floor)
        for size in [0, 1, 2, 10, 15]:
            rng = ShuffleRandom(room)
            pile, hand, discard = list(range(1, size + 1)), [], []
            rng.shuffle(pile)
            before_draw = list(pile)
            draw(rng, hand, pile, discard, 5)
            initial.append({'seed': seed, 'floor': floor, 'roomSeed': room,
                            'size': size, 'beforeDraw': before_draw,
                            'hand': hand, 'draw': pile, 'discard': discard,
                            'after': rng.snapshot(), 'trace': rng.trace})
        scenarios = [
            ('empty', [], [], [], 5, False),
            ('one-discard', [], [], [101], 1, False),
            ('old-pile-first', [], [1, 2], [101, 102, 103, 104], 4, False),
            ('overdraw-empty-discard', [], [1, 2], [], 5, False),
            ('overdraw-both-piles', [], [], [101, 102], 5, False),
            ('full-hand', list(range(201, 211)), [], [101, 102], 3, False),
            ('capped-before-split', list(range(201, 210)), [1], [101], 4, False),
            ('no-draw', [], [], [101, 102], 4, True),
            ('zero-amount', [], [1], [101], 0, False),
        ]
        for name, hand, pile, discard, amount, no_draw in scenarios:
            rng = ShuffleRandom(room)
            rng.shuffle([])  # initializeDeck(empty), before isolated redraw setup.
            inputs = {'hand': list(hand), 'draw': list(pile), 'discard': list(discard),
                      'amount': amount, 'noDraw': no_draw}
            draw(rng, hand, pile, discard, amount, no_draw)
            redraw.append({'seed': seed, 'floor': floor, 'roomSeed': room,
                           'name': name, 'input': inputs, 'hand': hand,
                           'draw': pile, 'discard': discard, 'after': rng.snapshot(),
                           'trace': rng.trace})
    return {'schemaVersion': 1,
            'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
            'boundary': 'Independent fixed-source interpretation; no PC/platform claim. No Innate, bottled cards or unsupported draw/shuffle hooks.',
            'generatorSha256': hashlib.sha256(Path(__file__).read_text(encoding='utf-8').encode('utf-8')).hexdigest(),
            'initial': initial, 'redraw': redraw}


if __name__ == '__main__':
    destination = Path(__file__).resolve().parents[2] / 'tests/fixtures/sts1-combat-shuffle-vectors.json'
    destination.write_text(json.dumps(build(), indent=2) + '\n', encoding='utf-8')
