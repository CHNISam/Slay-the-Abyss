"""Independent source-queue inputs for the three class-common relic hooks.

Uses the existing independent STS stream / java.util.Random shuffle model and
pinned RelicLibrary fact catalogs only. No production Lua or effect definitions.
Seed 113 exposes the natural common head (elite roll 1; small chest roll 25).
Seed 17 exposes the natural common tail used by the formal shop fixture.
"""
import hashlib
import json
from pathlib import Path
from sts1_combat_shuffle import ShuffleRandom
from sts1_combat_gold import Random
from sts1_class_relic_pools import lua

ROOT = Path(__file__).resolve().parents[2]
INPUT = 'data/catalogs/sts1-class-relic-queues.json'
TIERS = ['common', 'uncommon', 'rare', 'shop', 'boss']

def sha(path):
    return hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n', b'\n')).hexdigest()

def build():
    catalogs = json.loads((ROOT/INPUT).read_text())
    cases = []
    for character, target in [('silent', 'Snake Skull'), ('defect', 'DataDisk'), ('watcher', 'Damaru')]:
        for seed in ['17', '113']:
            rng = ShuffleRandom(seed)
            queues = {}
            for tier in TIERS:
                queues[tier] = list(catalogs[character]['queues'][tier])
                rng.shuffle(queues[tier])
            elite = Random(seed)
            elite.a, elite.b, elite.counter = rng.a, rng.b, rng.counter
            roll = elite.integer(0, 99)
            chest = Random(seed)
            kind, reward = chest.integer(0, 99), chest.integer(0, 99)
            assert queues['common'][-1 if seed == '17' else 0] == target
            if seed == '113':
                assert roll == 1 and kind == 46 and reward == 25
            cases.append({'character': character, 'sourceId': target, 'seed': seed,
                          'queues': queues, 'rawLongHex': [step['rawHex'] for step in rng.trace],
                          'afterInitialization': rng.snapshot(), 'eliteRoll': roll,
                          'afterEliteRoll': elite.snapshot(), 'chestKindRoll': kind, 'chestRewardRoll': reward})
    return {'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
            'generator': 'tools/oracles/sts1_class_common_relics.py',
            'generatorSha256': sha('tools/oracles/sts1_class_common_relics.py'),
            'inputs': {path: sha(path) for path in [INPUT, 'tools/oracles/sts1_combat_shuffle.py', 'tools/oracles/sts1_combat_gold.py', 'tools/oracles/sts1_class_relic_pools.py']},
            'luaFixture': 'tests/fixtures/class-common-relic-queue-vectors.lua',
            'luaSha256': hashlib.sha256(('return '+lua(cases)+'\n').encode()).hexdigest(),
            'cases': cases}

if __name__ == '__main__':
    result=build()
    (ROOT/result['luaFixture']).write_text('return '+lua(result['cases'])+'\n')
    print(json.dumps(result, indent=2))
