"""Pinned319009 A0 Nemesis source interpretation; no product/data imports.
Explicit 65-Strike long fixture survives 12 actions at1000HP, not campaign play.
"""
import argparse
import json
from sts1_combat_gold import Random
def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('['+lua(k)+']='+lua(v) for k, v in value.items()) + '}'
    return str(value)



class SourceRandom(Random):
    def boolean(self):
        self.counter += 1
        a, b = self.a, self.b
        a ^= (a << 23) & ((1 << 64) - 1)
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & ((1 << 64) - 1)
        return bool((self.b + b) & 1)


def decision(number, first, history, cooldown, boolean):
    cooldown -= 1
    last = history[-1] if history else None
    twice = history[-2:] == ['fire', 'fire']
    if first:
        move = 'fire' if number < 50 else 'burn'
    elif number < 30:
        if last != 'scythe' and cooldown <= 0:
            move = 'scythe'
        elif boolean():
            move = 'burn' if twice else 'fire'
        else:
            move = 'burn' if last != 'burn' else 'fire'
    elif number < 65:
        if not twice:
            move = 'fire'
        elif boolean():
            move = 'burn' if cooldown > 0 else 'scythe'
        else:
            move = 'burn'
    elif last != 'burn':
        move = 'burn'
    elif boolean() and cooldown <= 0:
        move = 'scythe'
    else:
        move = 'fire'
    return move, 2 if move == 'scythe' else cooldown


def vector(seed):
    hp, ai = SourceRandom(seed), SourceRandom(seed)
    monster_hp = hp.integer(185, 185)
    history, cooldown, health, intangible = [], 0, 1000, False
    rows = []
    for _ in range(13):
        before = ai.counter
        number = ai.integer(0, 99)
        move, cooldown = decision(number, not history, history, cooldown, ai.boolean)
        history.append(move)
        if len(rows) == 12:
            break
        # Sixty-five untouched Strikes cover opening + twelve next draws.
        # Generated Burns stay in discard throughout this arithmetic fixture.
        loss = 18 if move == 'fire' else 45 if move == 'scythe' else 0
        health -= loss
        intangible = not intangible
        rows.append({'intent': move, 'primary': number, 'draws': ai.counter-before,
                     'cooldown': cooldown, 'loss': loss, 'health': health,
                     'intangibleAfter': intangible})
    return {'seed': str(seed), 'hp': monster_hp, 'steps': rows, 'nextIntent': move,
            'nextCooldown': cooldown, 'hpRng': hp.snapshot(), 'aiRng': ai.snapshot()}


def boundaries():
    rows = []
    for first, history, cooldown in [(True, [], 0)] + [
        (False, h, c) for h in (['fire'], ['fire', 'fire'], ['burn'], ['scythe'])
        for c in (0, 1, 2)]:
        for n in (0, 29, 30, 49, 50, 64, 65, 99):
            for value in (False, True):
                used = []
                def boolean():
                    used.append(True)
                    return value
                move, after = decision(n, first, history, cooldown, boolean)
                rows.append({'first': first, 'history': history, 'cooldown': cooldown,
                             'n': n, 'boolean': value, 'calls': len(used),
                             'move': move, 'after': after})
    return rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    result = {'vectors': [vector(s) for s in (1, 2, 42, 77)], 'boundaries': boundaries()}
    print('-- Independent fixed319009 model, not PC execution.\nreturn '+lua(result)
          if args.lua else json.dumps(result, indent=2))
