"""Fixed319009 Transient/Shifting/Fading model, independent of product Lua/data.

The incoming hits/block and 1000 player HP are explicit arithmetic inputs, not
natural card acquisition or an original-PC execution oracle.
"""
import argparse
import json
from sts1_combat_gold import Random, MASK
from sts1_shapes import lua


def vector(seed):
    hp_rng, ai = Random(seed), Random(seed)
    primary = ai.integer(0, 99)  # inherited init/rollMove; no later rollMove
    # CardGroup.shuffle calls randomLong even for this empty initial deck.
    shuffle = Random(seed)
    a, b = shuffle.a, shuffle.b
    a ^= (a << 23) & MASK
    shuffle.a, shuffle.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
    shuffle.counter = 1
    health, monster_hp, rows = 1000, 999, []
    inputs = [('normal', 12, 3), ('fixed', 55, 5), ('hp_loss', 7, 40),
              ('thorns', 8, 0), ('normal', 3, 2)]
    for turn, (kind, damage, block) in enumerate(inputs, 1):
        damage_amount = damage if kind == 'hp_loss' else max(0, damage - block)
        monster_hp -= damage_amount
        strength = -min(999, damage_amount)
        debt = min(999, damage_amount)
        base = 20 + turn * 10
        loss = max(0, base + strength)
        health -= loss
        fading = 6 - turn
        if fading == 1:
            monster_hp = 0  # SuicideAction; no damage callback, owner-end skipped
        else:
            fading -= 1
            strength = min(999, strength + debt)
            debt = 0
        rows.append({'kind': kind, 'damage': damage, 'block': block,
                     'base': base, 'shift': damage_amount, 'playerLoss': loss,
                     'playerHp': health, 'monsterHp': monster_hp, 'fading': fading,
                     'strength': strength, 'shackled': debt, 'nextBase': base + 10})
    return {'seed': str(seed), 'openingRoll': primary, 'steps': rows,
            'hpRng': hp_rng.snapshot(), 'aiRng': ai.snapshot(), 'shuffleRng': shuffle.snapshot()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', action='store_true')
    args = parser.parse_args()
    values = [vector(seed) for seed in (1, 42, 77)]
    if args.lua:
        print('-- Independent fixed319009 model; explicit controlled inputs, not natural play.\nreturn {\n'
              + ',\n'.join(lua(v) for v in values) + '\n}')
    else:
        print(json.dumps(values, indent=2))
