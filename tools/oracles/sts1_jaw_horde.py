"""Fixed319009 A0 JawWorm(hard=true) group, independent of product Lua/data.

1000 player HP and no player cards are arithmetic survival inputs, not natural
acquisition or an original-PC execution claim.
"""
import argparse
import json
import struct
from sts1_combat_gold import Random, MASK
from sts1_shapes import lua


def f32(value):
    return struct.unpack('>f', struct.pack('>f', value))[0]


def floating(rng):
    rng.counter += 1
    a, b = rng.a, rng.b
    a ^= (a << 23) & MASK
    rng.a, rng.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
    return (((rng.b + b) & MASK) >> 40) / (1 << 24)


def choose(rng, history):
    roll = rng.integer(0, 99)
    last = history[-1] if history else None
    coin = -1
    if roll < 25:
        if last == 'chomp':
            coin = floating(rng)
            move = 'bellow' if coin < f32(.5625) else 'thrash'
        else:
            move = 'chomp'
    elif roll < 55:
        if history[-2:] == ['thrash', 'thrash']:
            coin = floating(rng)
            move = 'chomp' if coin < f32(.357) else 'bellow'
        else:
            move = 'thrash'
    elif last == 'bellow':
        coin = floating(rng)
        move = 'chomp' if coin < f32(.416) else 'thrash'
    else:
        move = 'bellow'
    return move, roll, coin


def vector(seed):
    hp_rng, ai, misc = Random(seed), Random(seed), Random(seed)
    health = [hp_rng.integer(40, 44) for _ in range(3)]
    opening = [choose(ai, []) for _ in range(3)]
    moves = [row[0] for row in opening]
    initial = {'hp': health, 'moves': moves[:], 'ai': ai.snapshot()}
    histories, strength, player, rounds = [[], [], []], [3, 3, 3], 1000, []
    for _ in range(5):
        actors = []
        for index in range(3):
            move = moves[index]
            block = 0  # MonsterGroup.applyPreTurnLogic cleared initial/old block
            damage = 0
            if move == 'chomp':
                damage = 11 + strength[index]
            elif move == 'thrash':
                damage, block = 7 + strength[index], 5
            else:
                strength[index] += 3
                block = 6
            player -= damage
            histories[index].append(move)
            moves[index], roll, coin = choose(ai, histories[index])
            actors.append({'move': move, 'damage': damage, 'block': block,
                           'strength': strength[index], 'next': moves[index],
                           'primary': roll, 'coin': coin})
        rounds.append({'actors': actors, 'playerHp': player, 'ai': ai.snapshot()})
    return {'seed': str(seed), 'initial': initial, 'rounds': rounds,
            'hpRng': hp_rng.snapshot(), 'miscRng': misc.snapshot()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    rows = [vector(seed) for seed in (1, 42, 77, 52)]
    if args.lua:
        print('-- Independent fixed319009 source model, not PC/natural play.\nreturn {\n'
              + ',\n'.join(lua(row) for row in rows) + '\n}')
    else:
        print(json.dumps(rows, indent=2))
