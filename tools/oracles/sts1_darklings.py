"""Fixed319009 A0 Darklings model, independent of product Lua/data.

1000 HP/no cards are arithmetic survival inputs, not a natural route/PC replay.
Reuse only the independent Python Random/literal serializer, never product code.
"""
import argparse
import json
from sts1_combat_gold import Random
from sts1_shapes import lua


def choose(ai, slot, history, first=False):
    number = ai.integer(0, 99)
    trace = [[0, 99, number]]
    if first:
        return ('harden' if number < 50 else 'nip'), trace
    last = history[-1]
    while True:
        if number < 40:
            if slot % 2 == 0 and last != 'chomp':
                return 'chomp', trace
            number = ai.integer(40, 99)
            trace.append([40, 99, number])
        elif number < 70:
            return ('harden' if last != 'harden' else 'nip'), trace
        elif history[-2:] != ['nip', 'nip']:
            return 'nip', trace
        else:
            number = ai.integer(0, 99)
            trace.append([0, 99, number])


def vector(seed):
    hp, ai = Random(seed), Random(seed)
    actors = []
    for slot in range(3):
        actors.append({'maxHp': hp.integer(48, 56), 'nip': hp.integer(7, 11)})
    histories = [[], [], []]
    moves = []
    for slot in range(3):
        move, _ = choose(ai, slot, [], True)
        histories[slot].append(move)
        moves.append(move)
    initial = {'actors': actors, 'moves': moves[:], 'ai': ai.snapshot()}
    player, rounds = 1000, []
    for _ in range(7):
        results = []
        for slot in range(3):
            move = moves[slot]
            damage = 16 if move == 'chomp' else actors[slot]['nip'] if move == 'nip' else 0
            player -= damage
            moves[slot], trace = choose(ai, slot, histories[slot])
            histories[slot].append(moves[slot])
            results.append({'move': move, 'block': 12 if move == 'harden' else 0,
                            'damage': damage, 'next': moves[slot], 'trace': trace})
        rounds.append({'actors': results, 'playerHp': player, 'ai': ai.snapshot()})
    return {'seed': str(seed), 'initial': initial, 'rounds': rounds,
            'monsterHp': hp.snapshot(), 'misc': Random(seed).snapshot()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    rows = [vector(seed) for seed in (1, 42, 77, 36, 52, -1)]
    if args.lua:
        print('-- Independent fixed319009 model, not original-PC/natural play.\nreturn {\n'
              + ',\n'.join(lua(row) for row in rows) + '\n}')
    else:
        print(json.dumps(rows, indent=2))
