"""Read pinned source facts and reuse the existing host-JDK pool oracle.

No game classes or decompiled methods are compiled/copied. Shared/red inputs
must match the established fact TSV exactly; their runtime catalog is untouched.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

COMMIT = '319009d5df0a82d9fb0f23cc22322286c6a87ec0'
ROOT = Path(__file__).resolve().parents[2]
CLASSES = {'green': 'silent', 'blue': 'defect', 'purple': 'watcher'}
TIERS = ['common', 'uncommon', 'rare', 'shop', 'boss']
STARTERS = {'Ring of the Serpent': 'Ring of the Snake', 'FrozenCore': 'Cracked Core', 'HolyWater': 'PureWater'}

def sha(data):
    return hashlib.sha256(data.replace(b'\r\n', b'\n')).hexdigest()

def lua(value):
    if isinstance(value, dict):
        return '{'+','.join('['+json.dumps(key)+']='+lua(item) for key, item in value.items())+'}'
    if isinstance(value, list):
        return '{'+','.join(lua(item) for item in value)+'}'
    return json.dumps(value)

def read_facts(source):
    identity = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if identity != COMMIT:
        raise ValueError('wrong fixed source commit')
    code = (source / 'helpers/RelicLibrary.java').read_text()
    records, files = [], {}
    def fingerprint(path):
        data = (source / path).read_bytes()
        files[path] = {'sha256': sha(data), 'bytes': len(data), 'gitBlob': hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()}
    fingerprint('helpers/RelicLibrary.java')
    fingerprint('dungeons/AbstractDungeon.java')
    for suffix, cls in re.findall(r'RelicLibrary\.add(Green|Red|Blue|Purple)?\(new (\w+)\(\)\);', code):
        library = suffix.lower() if suffix else 'shared'
        path = 'relics/' + cls + '.java'
        text = (source / path).read_text()
        id_match = re.search(r'public static final String ID = "([^"]+)";', text)
        tier_match = re.search(r'super\(ID,.*?AbstractRelic\.RelicTier\.(\w+)', text, re.S)
        if not id_match or not tier_match:
            raise ValueError('unrecognized constructor facts: ' + path)
        records.append({'library': library, 'tier': tier_match[1].lower(), 'id': id_match[1], 'source': path})
        if library in CLASSES:
            if 'boolean canSpawn()' in text:
                expected = STARTERS.get(id_match[1])
                gate = re.search(r'boolean canSpawn\(\)\s*\{\s*return AbstractDungeon\.player\.hasRelic\("([^"]+)"\);\s*\}', text)
                if not expected or not gate or gate[1] != expected:
                    raise ValueError('unrecognized class spawn gate: ' + path)
            fingerprint(path)
    old = (ROOT / 'tests/fixtures/sts1-relic-library-registration.tsv').read_text()
    established = ''.join('\t'.join(row[k] for k in ['library', 'tier', 'id'])+'\n' for row in records if row['library'] in ['shared', 'red'])
    if established != old:
        raise ValueError('established shared/red registration drift')
    return records, files

def generate(source):
    records, files = read_facts(source)
    prior = json.loads((ROOT / 'data/catalogs/sts1-relic-queues.json').read_text())
    vectors_path = ROOT / 'tests/fixtures/sts1-relic-pool-vectors.json'
    old_vectors = json.loads(vectors_path.read_text())
    seed_rows = [row for row in old_vectors['cases'] if row['profile'] == 'all-unlocked']
    catalogs, vectors = {}, {'ironclad': {'jdk': old_vectors['jdk'], 'cases': seed_rows}}
    with tempfile.TemporaryDirectory(prefix='sts1-class-relics-') as tmp:
        temp = Path(tmp)
        longs = temp / 'longs.tsv'
        longs.write_text(''.join('\t'.join([row['seed']]+row['randomLongHex'])+'\n' for row in seed_rows))
        red_check = subprocess.check_output(['java', str(ROOT / 'tools/oracles/Sts1RelicPoolVectors.java'),
            str(ROOT / 'tests/fixtures/sts1-relic-library-registration.tsv'), str(longs)], text=True)
        if json.loads(red_check)['unshuffled'] != prior['queues']:
            raise ValueError('host JDK changed established shared/red HashMap iteration')
        for library, character in CLASSES.items():
            registration = temp / (library + '.tsv')
            registration.write_text(''.join('\t'.join(row[k] for k in ['library', 'tier', 'id'])+'\n' for row in records if row['library'] in ['shared', library]))
            output = subprocess.check_output(['java', str(ROOT / 'tools/oracles/Sts1RelicPoolVectors.java'), str(registration), str(longs)], text=True)
            result = json.loads(output)
            gates = {k: v for k, v in prior['spawnGates'].items() if k not in {row['id'] for row in records if row['library']=='red'}}
            for row in records:
                if row['library'] != library or row['tier'] not in TIERS:
                    continue
                gates[row['id']] = {'kind': 'owns-relic', 'id': STARTERS[row['id']]} if row['id'] in STARTERS else {'kind': 'always'}
            catalogs[character] = {'schemaVersion': 1, 'sourceCommit': COMMIT, 'character': character,
                'orderProvenance': 'Fixed-source shared + chosen-class HashMap iteration using the existing host-JDK oracle; not authenticated PC order',
                'queues': result['unshuffled'], 'spawnGates': gates}
            vectors[character] = {'jdk': result['jdk'], 'cases': [row for row in result['cases'] if row['profile']=='all-unlocked']}
    return catalogs, {'sourceCommit': COMMIT, 'generator': 'tools/oracles/sts1_class_relic_pools.py',
        'generatorSha256': sha(Path(__file__).read_bytes()), 'jdkGenerator': 'tools/oracles/Sts1RelicPoolVectors.java',
        'jdkGeneratorSha256': sha((ROOT/'tools/oracles/Sts1RelicPoolVectors.java').read_bytes()),
        'seedInput': 'tests/fixtures/sts1-relic-pool-vectors.json', 'seedInputSha256': sha(vectors_path.read_bytes()),
        'registration': [row for row in records if row['library'] in CLASSES], 'files': files, 'classes': vectors}

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: python tools/oracles/sts1_class_relic_pools.py <pinned-source-root>')
    catalogs, evidence = generate(Path(sys.argv[1]))
    expected_lua = 'return '+lua(evidence['classes'])+'\n'
    evidence['luaFixture'] = 'tests/fixtures/sts1-class-relic-pool-vectors.lua'
    evidence['luaSha256'] = sha(expected_lua.encode())
    for path, value in [('data/catalogs/sts1-class-relic-queues.json', catalogs), ('tests/fixtures/sts1-class-relic-pool-vectors.json', evidence)]:
        (ROOT/path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')
    (ROOT/evidence['luaFixture']).write_text(expected_lua)
    print({key: {tier: len(value['queues'][tier]) for tier in TIERS} for key, value in catalogs.items()})
