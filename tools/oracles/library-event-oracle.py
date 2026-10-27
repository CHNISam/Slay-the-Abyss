"""Independent fixed-source Library identity/order/RNG vectors (no product imports).
Uses the existing independent integer Random interpretation and pinned registration
facts, not Lua rewards or runtime pools. This is not original-PC/native acceptance.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('card_oracle', ROOT / 'tools/sts1-card-rng-oracle.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
Random, signed32 = module.Random, module.signed32


def bounded(rng, maximum):
    rng.counter = signed32(rng.counter + 1)
    words = []
    bound = maximum + 1
    while True:
        raw = rng.raw()
        words.append(f'{raw:016x}')
        bits = raw >> 1
        result = bits % bound
        if bits - result + bound - 1 < (1 << 63):
            return result, words


def build():
    registered = json.loads((ROOT / 'data/reference/sts1-card-pools/registration.json').read_text())['registration']
    traversal = json.loads((ROOT / 'data/reference/sts1-card-pools/pools.json').read_text())['pools']['libraryHashMapTraversal']
    by_id = {row['id']: row for row in registered}
    pools = {}
    for character, color in [('ironclad', 'RED'), ('silent', 'GREEN'), ('defect', 'BLUE'), ('watcher', 'PURPLE')]:
        pools[character] = {rarity: [id for id in traversal if by_id[id]['color'] == color and by_id[id]['rarity'].lower() == rarity]
                            for rarity in ['common', 'uncommon', 'rare']}
    cases = []
    specs = [(character, offset, gift, None) for character in pools
             for offset, gift in [(5, False), (0, False), (-40, False), (5, True)]]
    specs.append(('ironclad', 5, False, {'words': ['07e07ff03fffe000', '0000000000000000'], 'counter': 0}))
    for character, offset, gift, controlled in specs:
            rng = Random.restore(controlled) if controlled else Random('1' if gift else '42')
            initial = rng.snapshot()
            accepted, attempts, used = [], [], set()
            while len(accepted) < 20:
                roll, rarity_words = bounded(rng, 99)
                adjusted = roll + offset
                rare = 9 if gift else 3
                rarity = 'rare' if adjusted < rare else 'uncommon' if adjusted < rare + 37 else 'common'
                index, index_words = bounded(rng, len(pools[character][rarity]) - 1)
                card = pools[character][rarity][index]
                unique = card not in used
                attempts.append({'roll': roll, 'rarity': rarity, 'index': index, 'sourceId': card, 'accepted': unique,
                                 'rarityWords': rarity_words, 'identityWords': index_words})
                if unique:
                    accepted.append(card)
                    used.add(card)
            assert rng.counter == 2 * len(attempts)
            cases.append({'character': character, 'offset': offset, 'gift': gift, 'initial': initial,
                          'attempts': attempts, 'offers': list(reversed(accepted)), 'final': rng.snapshot()})
    assert all(any(a['rarity'] == 'rare' for a in c['attempts']) for c in cases if c['gift'])
    # A bounded rejection consumes two primitive words, but one API counter.
    rng = Random.restore({'words': ['07e07ff03fffe000', '0000000000000000'], 'counter': 0})
    value, words = bounded(rng, 99)
    assert words[0] == 'ffffffffffffffff' and len(words) == 2 and rng.counter == 1
    return {'schemaVersion': 1, 'sourceCommit': module.COMMIT,
            'generatorSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'randomOracleSha256': hashlib.sha256((ROOT / 'tools/sts1-card-rng-oracle.py').read_bytes()).hexdigest(),
            'boundary': 'Independent fixed-source interpretation, not authenticated PC/native execution.',
            'pools': pools, 'cases': cases,
            'rejection': {'initial': {'words': ['07e07ff03fffe000', '0000000000000000'], 'counter': 0},
                          'value': value, 'rawWords': words, 'final': rng.snapshot()}}


def lua(value):
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, list):
        return '{' + ','.join(lua(v) for v in value) + '}'
    return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    vectors = build()
    files = {'tests/fixtures/library-event-vectors.json': json.dumps(vectors, indent=2) + '\n',
             'tests/fixtures/library-event-vectors.lua': '-- Independent oracle facts; regenerate with tools/oracles/library-event-oracle.py\nreturn ' + lua(vectors) + '\n'}
    for name, content in files.items():
        path = ROOT / name
        if args.check:
            assert path.read_text() == content, 'Library oracle fixture changed: ' + name
        else:
            path.write_text(content, newline='\n')
    print('LIBRARY_ORACLE_MATCH 4 ordered source pools / 17 full RNG continuations / primitive rejection')
