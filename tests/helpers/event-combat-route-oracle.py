"""Independent fixed-source facts/vectors. No product Lua or pool filtering.

Only new witnesses are emitted; historical fixture files are not rewritten.
The source mirror is not an authenticated PC binary.
"""
import json
from pathlib import Path
import runpy
Random = runpy.run_path('tools/oracles/sts1_encounter_runtime.py')['Random']
MASK = (1 << 64) - 1

def shuffle(rng, values):
    rng.counter += 1
    java = (rng.raw() ^ 0x5deece66d) & ((1 << 48) - 1)
    def bits():
        nonlocal java
        java = (java * 0x5deece66d + 11) & ((1 << 48) - 1)
        return java >> 17
    def bounded(bound):
        if bound & (bound - 1) == 0:
            return bound * bits() >> 31
        while True:
            word = bits()
            value = word % bound
            if word - value + bound - 1 < 1 << 31:
                return value
    for size in range(len(values), 1, -1):
        index = bounded(size)
        values[size - 1], values[index] = values[index], values[size - 1]

def dead(seed):
    rng = Random(seed)
    rewards = ['GOLD','NOTHING','RELIC']
    shuffle(rng,rewards)
    enemy = rng.integer(0,2) + 1
    constructor = rng.snapshot()
    searches = []
    for chance in (25,50,75):
        roll = rng.integer(0,99)
        row = {'chance':chance,'roll':roll,'encounter':roll<chance}
        if roll<chance:
            row['gold']=rng.integer(25,35)
        row['after']=rng.snapshot()
        searches.append(row)
        if row['encounter']:
            break
    return {'seed':str(seed),'rewards':rewards,'enemy':enemy,'afterConstructor':constructor,'searches':searches}

def build():
    # Each enemy plus the zero/one/two-success encounter and all-success paths.
    selected=[];coverage=set()
    for seed in range(1000):
        row=dead(seed)
        successes=sum(not item['encounter'] for item in row['searches'])
        key=(row['enemy'],successes)
        if key not in coverage:
            selected.append(row);coverage.add(key)
        if len(coverage)==12:
            break
    constructors=[]
    for seed in ('0','42','65537','-1','9223372036854775807'):
        rng=Random(seed)
        hp=[rng.integer(30,30),rng.integer(35,39),rng.integer(38,42)]
        run_seed=(int(seed)-18) & MASK
        if run_seed >= 1 << 63:
            run_seed -= 1 << 64
        constructors.append({'runSeed':str(run_seed),'floor':18,'roomSeed':seed,'hp':hp,'after':rng.snapshot()})
    return {'dead':selected,'bandits':constructors}

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');args=parser.parse_args()
    path=Path('tests/fixtures/event-combat-routes-vectors.json')
    result=build()
    if args.write:
        path.write_text(json.dumps(result,indent=2)+'\n')
    else:
        assert json.loads(path.read_text())==result
        print('EVENT_COMBAT_ROUTE_ORACLE 12 constructor/search branches and 5 bandit HP continuations')
