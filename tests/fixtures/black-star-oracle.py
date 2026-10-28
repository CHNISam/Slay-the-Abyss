"""Independent pinned-source interpretation; not original PC execution.

Uses full pinned host-JDK source catalog, never production selection code.
"""
import hashlib
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
model = ROOT / 'tools/oracles/sts1_combat_gold.py'
base = runpy.run_path(str(model))
MASK = (1 << 64) - 1


class Random(base['Random']):
    def long(self):
        self.counter += 1
        a, b = self.a, self.b
        a ^= (a << 23) & MASK
        self.a, self.b = b, (a ^ b ^ (a >> 17) ^ (b >> 26)) & MASK
        return (self.b + b) & MASK


def shuffle(values, seed):
    state = (seed ^ 0x5deece66d) & ((1 << 48) - 1)

    def integer(bound):
        nonlocal state
        while True:
            state = (state * 0x5deece66d + 11) & ((1 << 48) - 1)
            bits = state >> 17
            if bound & (bound - 1) == 0:
                return (bound * bits) >> 31
            value = bits % bound
            if bits - value + bound - 1 < (1 << 31):
                return value
    result = list(values)
    for size in range(len(result), 1, -1):
        index = integer(size)
        result[index], result[size - 1] = result[size - 1], result[index]
    return result


catalog_path = ROOT / 'data/catalogs/sts1-relic-queues.json'
catalog = json.loads(catalog_path.read_text(encoding='utf-8'))
rng = Random(144)
queues = {tier: shuffle(catalog['queues'][tier], rng.long())
          for tier in ['common', 'uncommon', 'rare', 'shop', 'boss']}
initial = rng.snapshot()
rolls = [rng.integer(0, 99), rng.integer(0, 99)]
vector = {'seed': '144', 'sourceCommit': catalog['sourceCommit'],
          'catalogLfSha256': hashlib.sha256(catalog_path.read_text(encoding='utf-8').encode('utf-8')).hexdigest(),
          'independentRandomLfSha256': hashlib.sha256(model.read_text(encoding='utf-8').encode('utf-8')).hexdigest(),
          'orderLimitation': catalog['orderProvenance'],
          'bossOffers': queues['boss'][:3], 'initialRng': initial,
          'tierRolls': rolls, 'afterEliteRng': rng.snapshot(),
          'uncommonPrefix': queues['uncommon'][:3], 'rarePrefix': queues['rare'][:5]}
print(json.dumps(vector, indent=2))
