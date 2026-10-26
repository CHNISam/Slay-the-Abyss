"""Independent integer source interpretation, never imports product Lua.

Read-only pinned Java inputs stay outside the product repository. This oracle
extracts encounter facts, not Java implementation bodies. It does not run STS.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
from sts1_encounter_queue import Stream, case as first_act, populate, roll, MASK


def method(source, name):
    start = source.index(' ' + name + '(')
    start = source.index('{', start)
    depth = 1
    for end in range(start + 1, len(source)):
        depth += (source[end] == '{') - (source[end] == '}')
        if not depth:
            return source[start + 1:end]
    raise ValueError('Unclosed source method')


def facts(path):
    source = path.read_text()
    pools = {}
    for key, name in [('weak', 'generateWeakEnemies'), ('strong', 'generateStrongEnemies'), ('elite', 'generateElites')]:
        pools[key] = [(name, float(weight)) for name, weight in re.findall(
            r'new MonsterInfo\("([^"]+)", ([0-9.]+)f\)', method(source, name))]
        assert pools[key]
    exclusions = {}
    for name, body in re.findall(r'case "([^"]+)": \{(.*?)\}', method(source, 'generateExclusions'), re.S):
        exclusions[name] = re.findall(r'retVal.add\("([^"]+)"\)', body)
    return pools, exclusions


def source_shuffle(stream, values):
    stream.draw()  # STS randomLong(): one wrapper draw, same raw step.
    raw = (stream.a + stream.b) & MASK
    state = (raw ^ 0x5DEECE66D) & ((1 << 48) - 1)

    def bits():
        nonlocal state
        state = (state * 0x5DEECE66D + 11) & ((1 << 48) - 1)
        return state >> 17

    def bounded(bound):
        if bound & (bound - 1) == 0:
            return (bound * bits()) >> 31
        while True:
            word = bits()
            value = word % bound
            if word - value + bound - 1 < (1 << 31):
                return value

    for size in range(len(values), 1, -1):
        index = bounded(size)
        values[size - 1], values[index] = values[index], values[size - 1]


def consecutive(seed, unlocked, configurations):
    prior = first_act(seed)['afterInitial']
    stream = Stream(seed)
    stream.a, stream.b = [int(word, 16) for word in prior['words']]
    stream.counter = prior['counter']
    result = []
    for act in [2, 3]:
        pools, exclusions = configurations[act]
        before = stream.snap()
        normal, elite = [], []
        populate(stream, normal, pools['weak'], 2, 2)
        candidate = roll(stream, pools['strong'])
        while candidate in exclusions.get(normal[-1], []):
            candidate = roll(stream, pools['strong'])
        normal.append(candidate)
        populate(stream, normal, pools['strong'], 12, 2)
        populate(stream, elite, pools['elite'], 10, 1)
        after_queues = stream.snap()
        bosses = (['Automaton', 'Collector', 'Champ'] if act == 2 else
                  ['Awakened One', 'Time Eater', 'Donu and Deca'])
        if unlocked:
            source_shuffle(stream, bosses)
        else:
            bosses = ['Champ', 'Champ'] if act == 2 else ['Awakened One', 'Awakened One']
        result.append({'act': act, 'before': before, 'normal': normal, 'elite': elite,
                       'afterQueues': after_queues, 'bosses': bosses, 'afterBoss': stream.snap()})
    return {'seed': seed, 'allLaterBossesSeen': unlocked, 'acts': result}


def card_boundaries(seed):
    result = []
    for counter in [0, 1, 249, 250, 251, 499, 500, 501, 749, 750, 751]:
        stream = Stream(seed)
        for _ in range(counter):
            stream.draw()
        before = stream.snap()
        target = next((n for n in [250, 500, 750] if n - 250 < counter < n), counter)
        for _ in range(target - counter):
            stream.draw()
        result.append({'before': before, 'after': stream.snap()})
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('pinned_source_directory', type=Path)
    args = parser.parse_args()
    root = args.pinned_source_directory
    paths = {2: root / 'dungeons/TheCity.java', 3: root / 'dungeons/TheBeyond.java'}
    configurations = {act: facts(path) for act, path in paths.items()}
    ending_path = root / 'dungeons/TheEnding.java'
    ending_source = ending_path.read_text()
    ending_monsters = method(ending_source, 'generateMonsters')
    fixed_ending = {'normal': re.findall(r'(?<![A-Za-z])monsterList.add\("([^"]+)"\)', ending_monsters),
                    'elite': re.findall(r'eliteMonsterList.add\("([^"]+)"\)', ending_monsters),
                    'bosses': re.findall(r'bossList.add\("([^"]+)"\)', method(ending_source, 'initializeBoss'))}
    paths[4] = ending_path
    seeds = ['0', '10', '42', '-1', '2780424839485660359', '9223372036854775807', '-9223372036854775808']
    print(json.dumps({'sourceCommit': '319009d5df0a82d9fb0f23cc22322286c6a87ec0',
        'generatorSha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'inputHashes': {path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths.values()},
        'provenance': __doc__,
        'cases': [consecutive(seed, unlocked, configurations) for seed in seeds for unlocked in [False, True]],
        'cardBoundaries': card_boundaries('42'), 'fixedEnding': fixed_ending}, indent=2))
