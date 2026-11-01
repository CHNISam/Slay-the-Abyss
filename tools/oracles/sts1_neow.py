"""Independent Neow offer oracle. No product imports or Java method copies.

Uses the existing integer stream model; reads the pinned source only to verify
its identity. Offers retain literal source order and the category-2 exclusions.
"""
import argparse
import hashlib
import json
from pathlib import Path
from sts1_encounter_queue import Stream, MASK

FIRST = ['THREE_CARDS', 'ONE_RANDOM_RARE_CARD', 'REMOVE_CARD', 'UPGRADE_CARD',
         'TRANSFORM_CARD', 'RANDOM_COLORLESS']
SECOND = ['THREE_SMALL_POTIONS', 'RANDOM_COMMON_RELIC', 'TEN_PERCENT_HP_BONUS',
          'THREE_ENEMY_KILL', 'HUNDRED_GOLD']
DRAWBACKS = ['TEN_PERCENT_HP_LOSS', 'NO_GOLD', 'CURSE', 'PERCENT_DAMAGE']


def choose(stream, items):
    # libGDX nextLong(bound) rejection; STS increments its wrapper once.
    count = stream.counter
    while True:
        stream.draw()
        bits = ((stream.a + stream.b) & MASK) >> 1
        value = bits % len(items)
        if bits - value + len(items) - 1 < (1 << 63):
            stream.counter = count + 1
            return items[value]


def case(seed):
    stream = Stream(seed)
    first, second = choose(stream, FIRST), choose(stream, SECOND)
    drawback = choose(stream, DRAWBACKS)
    third = ['RANDOM_COLORLESS_2']
    if drawback != 'CURSE':
        third.append('REMOVE_TWO')
    third += ['ONE_RARE_RELIC', 'THREE_RARE_CARDS']
    if drawback != 'NO_GOLD':
        third.append('TWO_FIFTY_GOLD')
    third.append('TRANSFORM_TWO_CARDS')
    if drawback != 'TEN_PERCENT_HP_LOSS':
        third.append('TWENTY_PERCENT_HP_BONUS')
    result = [first, second, choose(stream, third), choose(stream, ['BOSS_RELIC'])]
    return {'seed': str(seed), 'types': result, 'drawback': drawback, 'after': stream.snap()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source_root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    files = {}
    for path in ['neow/NeowEvent.java', 'neow/NeowReward.java', 'random/Random.java']:
        files[path] = hashlib.sha256((args.source_root / path).read_bytes()).hexdigest()
    result = {'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
              'sourceHashes': files, 'cases': [case(seed) for seed in range(128)]}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
