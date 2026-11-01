"""Pinned319009 A0 Reptomancer/Dagger model; no product Lua/data imports.

Full monster-HP/AI stream and retained-corpse formation oracle. An empty deck
and 5000 HP isolate twelve enemy rounds; this is not natural campaign play.
"""
import argparse
import json
from sts1_combat_gold import Random
from sts1_shapes import lua


def vector(seed):
    hp, ai = Random(seed), Random(seed)
    actors, slots, serial, health, wounds = [], [None] * 4, 1, 5000, 0
    positions = [(210, 75), (-220, 115), (180, 345), (-250, 335)]

    def construct(kind, position):
        nonlocal serial
        if kind == 'reptomancer':
            hp.integer(180, 190)  # super constructor argument is overwritten
            amount = hp.integer(180, 190)
        else:
            amount = hp.integer(20, 25)
        actor = {'id': kind + '_' + str(serial), 'kind': kind, 'hp': amount,
                 'x': position[0], 'y': position[1], 'move': '', 'history': []}
        serial += 1
        return actor

    def choose(actor):
        n = ai.integer(0, 99)
        history = actor['history']
        if not history:
            move = 'summon' if actor['kind'] == 'reptomancer' else 'stab'
        elif actor['kind'] == 'snake_dagger':
            move = 'explode'
        else:
            last = history[-1]
            while True:
                if n <= 32 and last == 'snake_strike':
                    n = ai.integer(33, 99)
                    continue
                if n >= 66 and last == 'big_bite':
                    n = ai.integer(0, 65)
                    continue
                if n <= 32:
                    move = 'snake_strike'
                elif n <= 65:
                    count = sum(1 for candidate in actors if candidate is not actor and candidate['hp'] > 0)
                    move = 'summon' if history[-2:] != ['summon', 'summon'] and count < 4 else 'snake_strike'
                else:
                    move = 'big_bite'
                break
        actor['move'] = move
        history.append(move)

    actors = [construct('snake_dagger', positions[1]), construct('reptomancer', (-20, 10)),
              construct('snake_dagger', positions[0])]
    slots[0], slots[1] = actors[2], actors[0]
    for actor in actors:
        choose(actor)

    def snapshot():
        return {'actors': [{key: actor[key] for key in ('id', 'hp', 'x', 'y', 'move')} for actor in actors],
                'hpRng': hp.snapshot(), 'aiRng': ai.snapshot(), 'playerHp': health, 'wounds': wounds}

    opening, rounds = snapshot(), []
    for _ in range(12):
        actions = []
        for actor in list(actors):
            if actor['hp'] <= 0:
                continue
            move = actor['move']
            actions.append(actor['id'] + ':' + move)
            if move == 'summon':
                for slot in range(4):
                    if slots[slot] is None or slots[slot]['hp'] <= 0:
                        child = construct('snake_dagger', positions[slot])
                        slots[slot] = child
                        choose(child)
                        index = sum(1 for candidate in actors if candidate['x'] < child['x'])
                        actors.insert(index, child)
                        break
            elif move in ('snake_strike', 'big_bite'):
                health -= 26 if move == 'snake_strike' else 30
            elif move == 'stab':
                health -= 9
                wounds += 1
            else:
                health -= 25
                actor['hp'] = 0
            choose(actor)
        step = snapshot()
        step['actions'] = actions
        rounds.append(step)
    return {'seed': str(seed), 'opening': opening, 'rounds': rounds}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    values = [vector(seed) for seed in (1, 42, 77)]
    if args.lua:
        print('-- Independent pinned-source model; not original-PC execution.\nreturn {\n'
              + ',\n'.join(lua(value) for value in values) + '\n}')
    else:
        print(json.dumps(values, indent=2))
