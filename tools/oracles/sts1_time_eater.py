"""Independent pinned319009 A0 Time Eater method interpretation.
No production Lua/data import; controlled pass-turn fixture, not PC execution.
"""
import argparse
import json
from sts1_combat_gold import Random, MASK
from sts1_shapes import lua


class Stream(Random):
    def floating(self):
        self.counter += 1
        a, b = self.a, self.b
        a ^= (a << 23) & MASK
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
        return (((self.b + b) & MASK) >> 40) / (1 << 24)


def vector(seed):
    ai = Stream(seed)
    history, used, health, player, vulnerable = [], False, 456, 1000, False

    def decide(number):
        nonlocal used
        last = history[-1] if history else None
        if health < 228 and not used:
            used = True
            return 'haste'
        if number < 45:
            return decide(ai.integer(50, 99)) if history[-2:] == ['reverberate'] * 2 else 'reverberate'
        if number < 80:
            if last != 'head_slam':
                return 'head_slam'
            return 'reverberate' if ai.floating() < 0.6600000262260437 else 'ripple'
        return decide(ai.integer(0, 74)) if last == 'ripple' else 'ripple'

    def choose():
        move = decide(ai.integer(0, 99))
        history.append(move)
        return move

    move, steps = choose(), []
    for turn in range(12):
        if turn == 4:
            health = 227  # Controlled source selection boundary; no fake full route.
        hits = 3 if move == 'reverberate' else 1 if move == 'head_slam' else 0
        base = 7 if hits == 3 else 26 if hits else 0
        damage = int(base * (1.5 if vulnerable else 1))
        player -= hits * damage
        if move == 'haste':
            health = 228
        steps.append({'intent': move, 'monsterHp': health, 'playerHp': player,
                      'unitDamage': damage, 'hits': hits, 'aiBeforeRoll': ai.counter,
                      'usedHaste': used})
        vulnerable = move == 'ripple'
        move = choose()
    hp_rng = Random(seed)
    hp_rng.integer(456, 456)
    return {'seed': str(seed), 'steps': steps, 'nextIntent': move,
            'ai': ai.snapshot(), 'hp': hp_rng.snapshot()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    values = [vector(seed) for seed in (1, 42, 77)]
    print('-- Independent sts1_time_eater.py; controlled offline vectors.\nreturn {\n'
          + ',\n'.join(lua(value) for value in values) + '\n}' if args.lua else json.dumps(values, indent=2))
