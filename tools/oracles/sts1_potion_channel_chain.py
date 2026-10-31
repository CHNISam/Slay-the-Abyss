"""Compose the pinned source oracle across real potion consumer boundaries.

No production module/data import. Does not model card/relic/merchant prices.
"""
import json
from sts1_potion_pool import Oracle


def case(seed):
    oracle = Oracle(seed)
    records = []

    def add(action, result):
        records.append({'action': action, 'result': result,
                        'after': oracle.rng.snapshot(), 'modifier': oracle.modifier})

    for _ in range(3):
        add('shop', oracle.pick())
    add('courier', oracle.pick())
    add('normal', oracle.drop())
    for _ in range(3):
        add('entropic_combat', oracle.pick(limited=True))
    for _ in range(3):
        add('second_shop', oracle.pick())
    add('elite', oracle.drop(room='elite'))
    return {'seed': seed, 'records': records}


if __name__ == '__main__':
    print(json.dumps({'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
                      'oracle': 'tools/oracles/sts1_potion_channel_chain.py',
                      'scope': 'Controlled Run/shop/reward/Entropic ownership chain; no natural route or device claim.',
                      'cases': [case(seed) for seed in ['0', '42', '-1']]}, indent=2))
